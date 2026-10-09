# Message Catch-Up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Beim Öffnen der App, beim Tippen auf eine Nachricht und bei stillem Push fehlende Server-Ops auch dann nachholen, wenn der Socket nur scheinbar verbunden ist.

**Architecture:** `Raum` behält einen einzigen laufenden Nachholvorgang und verwendet den bereits gesicherten Sequenz-Cursor. Jede ausstehende Server-Seite erhält eine Frist von 10 Sekunden; nach Ablauf erfolgt einmal eine direkte Neuverbindung, danach der vorhandene Backoff. Die bestehende Op-Logik und der Serververtrag bleiben erhalten.

**Tech Stack:** Swift 6, SwiftUI, URLSession WebSocket, XCTest, GitHub Actions auf macOS 26.

**Spec:** `docs/superpowers/specs/2026-10-07-message-catchup-design.md`

## Global Constraints

- Kein neuer Server-Endpunkt, Dienst, Paket oder Hintergrund-Polling.
- Ein `pong` ist keine Nachhol-Seite. Nur `seite: true` bestätigt einen Nachhol-Abruf.
- Cursor erst nach `log.anhaengen` und `vollstaendigBisSeqSetzen` vorziehen; Live-Ops verändern ihn nicht.
- Alte Socket-Callbacks anhand der vorhandenen `generation` ignorieren.
- Die App navigiert beim Mitteilungs-Tap sofort in den Chat.
- Ziel: iOS/TestFlight, `runde-3`; PR vor Merge; Repo für GitHub Actions nur bis zum Ende aller Jobs öffentlich.

## Review Focus

- Start und Mitteilungs-Tap kurz nacheinander: nur eine Nachhol-Anfrage pro laufender Serie (Task 1).
- Live-Op mit höherer `seq` während des Nachholens: nächste Anfrage verwendet den vollständigen Cursor (Task 1).
- `pong` ohne Nachhol-Seite: Frist läuft weiter und erzwingt Neuverbindung (Task 2).
- Späte Antwort des alten Sockets: keine doppelte Chat-Auslieferung und kein Cursor-Sprung (Task 2).
- Stiller Push auf scheinbar verbundenem Socket: Handler wartet auf eine echte Seite oder sein Timeout (Task 3).

---

### Task 1: Abruf auf einem verbundenen Socket

**Files:**
- Modify: `Lovea/Sources/Sync/Raum.swift:102-122,323-351,478-497`
- Test: `Lovea/Tests/SyncTests.swift`

**Interfaces:**
- Consumes: `OpLog.vollstaendigBisSeq()`, `NachholenNachricht(seit:)`, `Raum.start()`.
- Produces: `Raum.nachholenJetzt()`, `nachholenLaeuft: Bool`; Task 2 ergänzt die Frist.

- [ ] **Step 1: Failing test.** In `SyncTests`, persist cursor 7, connect, deliver an empty `seite:true`, then call `raum.nachholenJetzt()` twice. Assert exactly one `nachholen` with `seit:7`; after another completed page, a new call may send a second request. Also deliver a live op with `seq:99` before the first explicit request and assert the request still uses 7.

```swift
func testConnectedRefreshUsesCompleteCursorAndDedupesRequests() async {
    let dir = makeTempDirectory()
    let transport = FakeTransport()
    let log = OpLog(rootURL: dir)
    await log.vollstaendigBisSeqSetzen(7)
    let raum = Raum(transport: transport, log: log, warteschlange: Warteschlange(rootURL: dir),
                    server: URL(string: "https://sync.example.com")!, schluessel: "schluessel",
                    medienBeimStartFortsetzen: false)
    raum.ich = .ahmed
    raum.start()
    await raum.leer()
    await transport.receive("{\"t\":\"ops\",\"ops\":[],\"mehr\":false,\"seite\":true}")
    await transport.receive(makeOpsMessage(ops: [(id: "live-99", seq: 99)], mehr: false, seite: false))
    raum.nachholenJetzt()
    raum.nachholenJetzt()
    XCTAssertEqual(transport.sent.filter { $0.contains("\"nachholen\"") }.count, 1)
    XCTAssertTrue(transport.sent.contains { $0.contains("\"seit\":7") })
    await transport.receive("{\"t\":\"ops\",\"ops\":[],\"mehr\":false,\"seite\":true}")
    raum.nachholenJetzt()
    XCTAssertEqual(transport.sent.filter { $0.contains("\"nachholen\"") }.count, 2)
}
```

- [ ] **Step 2: Confirm red.** Push the test-only commit to PR #103 while the repo is temporarily public; `iOS CI` must fail on the missing `nachholenJetzt()` behavior. Do not mark a red run as a product regression.
- [ ] **Step 3: Minimal implementation.** In `Raum.start()`, call `nachholenAnfordern()` when `verbunden` is true; on a new connection set `nachholenLaeuft = true` before `transport.verbinden`, because the server sends the first page automatically. Add `func nachholenJetzt() { start() }`. `nachholenAnfordern()` guards `!nachholenLaeuft`, sets it, then sends `NachholenNachricht(seit: empfangenBisSeq)` through the existing transport. On the final `seite:true` page, clear the flag after persistence; on `mehr:true`, leave it set.

```swift
private var nachholenLaeuft = false

func nachholenJetzt() { start() }

// In start(), after the existing setup but before its queued connect:
if verbunden { nachholenAnfordern(); return }

private func nachholenAnfordern() {
    guard verbunden, !nachholenLaeuft else { return }
    nachholenLaeuft = true
    sende(NachholenNachricht(seit: empfangenBisSeq))
}

// In verbinden(), before transport.verbinden(...):
nachholenLaeuft = true

// In opsVerarbeiten(...), after the final page is persisted:
if !mehr { nachholenLaeuft = false }
```

- [ ] **Step 4: Confirm green.** Push the implementation, require the new test plus existing paging/cursor tests to pass on iPhone and iPad CI. Commit message: `fix(sync): request catch-up on foreground even while connected`.

### Task 2: Seitenfrist und Wiederverbindung

**Files:**
- Modify: `Lovea/Sources/Sync/Raum.swift:33-88,323-402,438-498`
- Test: `Lovea/Tests/SyncTests.swift:190-450` and its private `FakeTransport`.

**Interfaces:**
- Consumes: `nachholenLaeuft` from Task 1 and existing `trennen()`, `verbinden()`, `scheduleReconnect()`, `generation`.
- Produces: constructor parameter `nachholFrist: Duration = .seconds(10)` for fast deterministic tests; private `nachholFristStarten(gen:)`.

- [ ] **Step 1: Failing tests.** With `nachholFrist: .milliseconds(120)` and `pingAbstand: .seconds(10)`, establish an initial page. Request catch-up, send only `pong`, wait 180 ms, and require a second `FakeTransport.urls` entry with the same cursor. In another test, deliver a valid page after 60 ms and require one connection after 180 ms. In a third test, let two successive requests time out: require no immediate third connection and a later connection through the existing 1-second backoff; repeated failures must increase that delay despite `pong` frames. Extend the fake with retained receive closures to deliver one old-generation page after reconnect; assert no observer delivery and no cursor advance from that stale page.

```swift
func testPongDoesNotSatisfyCatchUpDeadline() async throws {
    let dir = makeTempDirectory()
    let transport = FakeTransport()
    let log = OpLog(rootURL: dir)
    await log.vollstaendigBisSeqSetzen(7)
    let raum = Raum(transport: transport, log: log, warteschlange: Warteschlange(rootURL: dir),
                    server: URL(string: "https://sync.example.com")!, schluessel: "schluessel",
                    medienBeimStartFortsetzen: false, pingAbstand: .seconds(10),
                    nachholFrist: .milliseconds(120))
    raum.ich = .ahmed
    raum.start()
    await raum.leer()
    await transport.receive("{\"t\":\"ops\",\"ops\":[],\"mehr\":false,\"seite\":true}")
    raum.nachholenJetzt()
    await transport.receive("pong")
    try await Task.sleep(for: .milliseconds(250))
    XCTAssertEqual(transport.urls.count, 2)
    XCTAssertEqual(transport.urls.last?.query, "seit=7")
}

// Add to FakeTransport for the old-generation regression test:
private var empfaenger: [(@Sendable (String) async -> Void)] = []
// In FakeTransport.verbinden:
empfaenger.append(nachricht)
// Test helper:
func receive(_ text: String, connection: Int) async { await empfaenger[connection](text) }
```

For the delayed-page case, deliver the empty `seite:true` page 60 ms after `nachholenJetzt()` and assert `transport.urls.count == 1` after 200 ms. For the second-timeout case, keep both requests unanswered, assert two URLs after 300 ms and a third only after the backoff; send a stale page through `receive(_:connection: 0)` and assert the cursor remains 7 and no observer receives it.

- [ ] **Step 2: Confirm red.** Run the affected tests on iPhone CI; verify that `pong` currently prevents the explicit 120 ms recovery because no page deadline exists.
- [ ] **Step 3: Minimal implementation.** Store `nachholFrist`, `nachholFristTask` and consecutive page timeouts. Arm the deadline for the first page before `transport.verbinden`, after `nachholenAnfordern()`, and after each `mehr:true` request. Cancel it as soon as a genuine page arrives, before asynchronous disk work. On first timeout, `trennen(); verbinden()`; on second, `trennen(); scheduleReconnect()`. Cancel the task and clear `nachholenLaeuft` in both `trennen()` and `getrenntBehandeln(gen:)`. Any genuine page resets the consecutive timeout count and existing backoff. While a page is pending, `pong` must not reset backoff or the page deadline; a live broadcast must not reset the deadline.

```swift
private let nachholFrist: Duration
private var nachholFristTask: Task<Void, Never>?
private var nachholAusfaelle = 0

// Add `nachholFrist: Duration = .seconds(10)` to init(...), then assign:
self.nachholFrist = nachholFrist

private func nachholFristStarten(gen: Int) {
    nachholFristTask?.cancel()
    let frist = nachholFrist
    nachholFristTask = Task { @MainActor [weak self, frist] in
        try? await Task.sleep(for: frist)
        guard let self, !Task.isCancelled, self.generation == gen, self.nachholenLaeuft else { return }
        self.nachholAusfaelle += 1
        self.trennen()
        if self.nachholAusfaelle == 1 { self.verbinden() }
        else { self.scheduleReconnect() }
    }
}
```

- [ ] **Step 4: Confirm green.** Require timeout, delayed-page, `pong`, old-generation, multi-page, and existing watchdog tests to pass on both simulators. Commit message: `fix(sync): reconnect when catch-up pages stall`.

### Task 3: Mitteilung und stillen Push an denselben Abruf binden

**Files:**
- Modify: `Lovea/Sources/Sync/LoveaAppDelegate.swift:68-83`
- Modify: `Lovea/Sources/Sync/Raum.swift:192-213`
- Test: `Lovea/Tests/SyncTests.swift`

**Interfaces:**
- Consumes: `Raum.nachholenJetzt()` and `catchUpZaehler` from Tasks 1–2.
- Produces: no new public API.

- [ ] **Step 1: Failing test.** Connect and finish the initial page, then start `nachholenBisFertig(timeout: .seconds(1))` while the fake socket stays connected. Assert it sends `nachholen`, remains pending after `pong`, and finishes after a delayed `seite:true` page. Assert concurrent foreground request does not send another `nachholen`.

```swift
func testSilentPushWaitsForPageOnConnectedSocket() async throws {
    let dir = makeTempDirectory()
    let transport = FakeTransport()
    let raum = Raum(transport: transport, log: OpLog(rootURL: dir),
                    warteschlange: Warteschlange(rootURL: dir),
                    server: URL(string: "https://sync.example.com")!, schluessel: "schluessel",
                    medienBeimStartFortsetzen: false)
    raum.ich = .ahmed
    raum.start()
    await raum.leer()
    await transport.receive("{\"t\":\"ops\",\"ops\":[],\"mehr\":false,\"seite\":true}")
    var fertig = false
    let push = Task { @MainActor in
        await raum.nachholenBisFertig(timeout: .seconds(1))
        fertig = true
    }
    try await Task.sleep(for: .milliseconds(50))
    raum.nachholenJetzt()
    XCTAssertEqual(transport.sent.filter { $0.contains("\"nachholen\"") }.count, 1)
    await transport.receive("pong")
    try await Task.sleep(for: .milliseconds(50))
    XCTAssertFalse(fertig)
    await transport.receive("{\"t\":\"ops\",\"ops\":[],\"mehr\":false,\"seite\":true}")
    await push.value
    XCTAssertTrue(fertig)
}
```
- [ ] **Step 2: Confirm red.** On iPhone CI the test must expose the current early return when `verbunden == true`.
- [ ] **Step 3: Minimal implementation.** In `nachholenBisFertig`, record `catchUpZaehler`, call `nachholenJetzt()` regardless of socket status, and retain the existing wait and background disconnect. In the notification tap, replace `Raum.shared.start()` with `Raum.shared.nachholenJetzt()`; keep `AppNavigation.shared.mitteilungGeoeffnet(...)` and the completion handler order unchanged.

```swift
let zaehlerVorher = catchUpZaehler
nachholenJetzt()
let deadline = ContinuousClock.now + timeout
while catchUpZaehler == zaehlerVorher, ContinuousClock.now < deadline {
    try? await Task.sleep(for: .milliseconds(200))
}
```

- [ ] **Step 4: Confirm green.** iPhone and iPad CI pass; review notification-tap navigation and silent-push timeout in code. Commit message: `fix(sync): catch up on notification open and silent push`.

### Task 4: Review, TestFlight und Geräteprüfung

**Files:**
- Update only after verified shipment: `C:/Users/ahmed/Documents/Obsidian/Personal/01 Inbox/improvements for the Lovea app.md`.

**Interfaces:** PR #103 targets `runde-3`; TestFlight workflow uses `runde-3`; no server deployment.

- [ ] **Step 1: Review the whole diff.** Check that no timer continues after background disconnect; callbacks from earlier generations are inert; all three event sources use the saved cursor; no background polling or server change. Run `git diff --check` and review the CI test names and outcomes.
- [ ] **Step 2: Merge.** Convert PR #103 from draft, require all iPhone, iPad, server and pattern checks green, then merge into `runde-3` (only the authorized repo maintainer branch receives the merge).
- [ ] **Step 3: Build.** Temporarily set the GitHub repo public, run `.github/workflows/testflight.yml` on merged `runde-3`, verify `Zu TestFlight hochladen` succeeds for that exact merge SHA, wait for every GitHub job to finish, and restore/verify private visibility.
- [ ] **Step 4: Device test and checkbox.** On Ahmed’s and Annika’s iPhones, test slow network, offline→online, notification tap, foreground resume, duplicate display and battery behavior. Leave the hard latency item unchecked until these measurements and TestFlight availability are confirmed. Once verified, run `git -c safe.directory='C:/Users/ahmed/Documents/Obsidian/Personal' -C 'C:\Users\ahmed\Documents\Obsidian\Personal' pull --rebase --autostash`, check the exact item, commit and push.
