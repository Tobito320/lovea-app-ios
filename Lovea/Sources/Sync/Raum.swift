import Foundation
import Observation
import UIKit

// Usage: set `Raum.shared.ich = person` once at app start, call `Raum.shared.start()` and
// `Raum.shared.aktiv(_:hintergrund:)` from `scenePhase`. Faltungen register with `beobachten`/`beobachtenStapel`;
// UI reads `verbunden`/`wartet`/`eingerichtet` for `SyncStatusZeile`.
@MainActor
@Observable
final class Raum {
    static let shared = Raum()

    var ich: Person?
    private(set) var partnerDa = false
    private(set) var verbunden = false
    private(set) var wartet = 0
    let eingerichtet: Bool

    struct HttpKonfiguration: Sendable { let basis: URL; let headers: [String: String] }

    private let transport: RaumTransport
    private let log: OpLog
    private let warteschlange: Warteschlange
    private let baseURL: URL?
    private let appKey: String

    private var beobachter: [(arten: Set<String>, f: (Op) -> Void)] = []
    private var stapelBeobachter: [(arten: Set<String>, f: ([Op]) -> Void)] = []
    private var fluechtigBeobachter: [String: [(Person, Data) -> Void]] = [:]
    /// Build 78 (Absturz-Breadcrumbs): nur das erste ausgelieferte Batch markieren, nicht jedes.
    private var erstesBatchMarkiert = false

    private var backoff: TimeInterval = 1
    private var aktivZustand = false
    private var generation = 0
    private var empfangenBisSeq = 0
    private var nachholenLaeuft = false
    private var geraeteToken: String?
    private var reconnectTask: Task<Void, Never>?
    private var hintergrundTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var nachholFristTask: Task<Void, Never>?
    private var nachholAusfaelle = 0
    /// Last frame of any kind from the server — the ping watchdog in `verbinden` compares against it.
    private var letzterEmpfang = ContinuousClock.now
    /// A frame still being applied blocks the receive loop, so a pong behind it can't arrive yet.
    private var empfangLaeuft = false
    private let pingAbstand: Duration
    private let pongFrist: Duration
    private let nachholFrist: Duration
    private var hintergrundAufgabe: UIBackgroundTaskIdentifier = .invalid
    /// Only `Raum.shared` should rescan disk for interrupted uploads on `start()` — a test's own
    /// `Raum` instance must not touch the real Application Support folder.
    private let medienBeimStartFortsetzen: Bool
    /// Bumped every time a genuine page response (`seite:true`) with `mehr == false` is applied —
    /// i.e. we just caught up. `nachholenBisFertig` polls this instead of using a continuation,
    /// to sidestep continuation/cancellation bookkeeping for what's a coarse, low-frequency wait.
    private var catchUpZaehler = 0

    /// I-2: true once the first full catch-up since launch finished (a page with `mehr == false`), so
    /// the log holds everything the server had. Its ops were already handed to the folds by then.
    var nachgeholt: Bool { catchUpZaehler > 0 }

    /// Serializes disk writes and sends so they happen in call order (a fast echo must never
    /// run before the `senden` that caused it finishes queuing). Tests await `leer()`.
    private var arbeit: Task<Void, Never>?
    /// Bumped every time `reiheOhneWarten` chains a new tail — including a tail chained by a
    /// closure that is itself already running as part of the chain (`start()` chains its own
    /// work, whose body calls `verbinden()`, which chains the queue flush again). `leer()` uses
    /// this to notice such nesting and keep waiting instead of returning after only the outer
    /// task finishes while the freshly-nested one is still pending.
    private var arbeitVersion = 0

    init(
        transport: RaumTransport? = nil,
        log: OpLog = OpLog(),
        warteschlange: Warteschlange = Warteschlange(),
        server: URL? = Raum.plistServer(),
        schluessel: String = Raum.plistSchluessel(),
        medienBeimStartFortsetzen: Bool = true,
        pingAbstand: Duration = .seconds(10),
        pongFrist: Duration = .seconds(5),
        nachholFrist: Duration = .seconds(10)
    ) {
        self.transport = transport ?? WebSocketTransport()
        self.log = log
        self.warteschlange = warteschlange
        self.baseURL = server
        self.appKey = schluessel
        self.eingerichtet = server != nil && !schluessel.isEmpty
        self.medienBeimStartFortsetzen = medienBeimStartFortsetzen
        self.pingAbstand = pingAbstand
        self.pongFrist = pongFrist
        self.nachholFrist = nachholFrist
    }

    nonisolated static func plistServer() -> URL? {
        guard !TiefenTest.aktiv, let text = Bundle.main.object(forInfoDictionaryKey: "LoveaServer") as? String, !text.isEmpty else { return nil }
        return URL(string: text)
    }

    nonisolated static func plistSchluessel() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "LoveaAppKey") as? String) ?? ""
    }

    // MARK: - Lifecycle

    func start() {
        StartProtokoll.marke("raum.start.funktion.vor")
        defer { StartProtokoll.marke("raum.start.funktion.nach") }
        guard eingerichtet, ich != nil else { return }
        aktivZustand = true
        hintergrundTask?.cancel(); hintergrundTask = nil
        beendeHintergrundAufgabe()
        reconnectTask?.cancel(); reconnectTask = nil
        if medienBeimStartFortsetzen { Medien.fortsetzen() }
        if verbunden { nachholenAnfordern(); return }
        backoff = 1 // explicit start() means "try fresh"; verbinden() itself no longer resets this (I-1)
        // Chained (not a bare Task) so `leer()` also waits for the connect + queue flush below.
        reiheOhneWarten { [weak self] in
            guard let self else { return }
            // The persisted "complete up to" cursor, NOT log.letzteSeq (which can be higher than
            // what we actually finished paging through, if a live broadcast with a high seq
            // landed in the log before the pages below it were ever fetched).
            self.empfangenBisSeq = await self.log.vollstaendigBisSeq()
            await self.wartetAktualisieren() // e.g. after an offline restart, before anything is sent
            self.verbinden()
        }
    }

    func nachholenJetzt() { start() }

    private func nachholenAnfordern() {
        guard verbunden, !nachholenLaeuft else { return }
        nachholenLaeuft = true
        nachholFristStarten(gen: generation)
        sende(NachholenNachricht(seit: empfangenBisSeq))
    }

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

    /// Call from `scenePhase`: connect when active. `.inactive` (app switcher, Control Center)
    /// disconnects after 30 s. `.background` (`hintergrund`) disconnects right after a short flush
    /// (I-4): while the socket is open the server counts the person as there and sends no push.
    func aktiv(_ ist: Bool, hintergrund: Bool = false) {
        if ist {
            beendeHintergrundAufgabe()
            start()
            return
        }
        // Audit #7: the queue writes are coalesced; flush after everything queued so far.
        reiheOhneWarten { [weak self] in await self?.warteschlange.sichern() }
        if aktivZustand {
            aktivZustand = false
            beendeHintergrundAufgabe() // defensive: never overwrite a still-valid identifier
            // iOS can suspend the app within seconds of backgrounding — without real background
            // time, `trennen()` (and its close frame) would just never run, leaving a socket the
            // server only notices via its own ping timeout.
            hintergrundAufgabe = UIApplication.shared.beginBackgroundTask(withName: "Lovea-Sync-Trennen") { [weak self] in
                // Apple's overlay doesn't document this handler's closure as @MainActor, but it is
                // documented to run on the main thread — assumeIsolated is the correct, safe way
                // to call MainActor code from it without an (unavailable, since this isn't async) await.
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.trennen()
                    self.beendeHintergrundAufgabe()
                }
            }
        } else if !hintergrund || hintergrundTask == nil {
            // A repeated `.inactive`, or no foreground session to end (e.g. a silent-push catch-up
            // from `nachholenBisFertig`, which disconnects on its own).
            return
        }
        // `.inactive` then `.background`: keeps the background task begun above, only the timer changes.
        hintergrundTask?.cancel()
        hintergrundTask = Task { @MainActor [weak self] in
            if hintergrund {
                await self?.warteschlangeKurzLeeren()
            } else {
                try? await Task.sleep(for: .seconds(30))
            }
            guard let self, !Task.isCancelled else { return }
            self.hintergrundTask = nil
            self.trennen()
            self.beendeHintergrundAufgabe()
        }
    }

    /// I-4: gives just-queued ops up to 3 s to go out and come back confirmed before the socket
    /// closes. Whatever is still open stays in the queue and goes out on the next connect.
    private func warteschlangeKurzLeeren() async {
        await leer()
        let ende = ContinuousClock.now + .seconds(3)
        while wartet > 0, verbunden, ContinuousClock.now < ende, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    private func beendeHintergrundAufgabe() {
        guard hintergrundAufgabe != .invalid else { return }
        UIApplication.shared.endBackgroundTask(hintergrundAufgabe)
        hintergrundAufgabe = .invalid
    }

    /// Requests catch-up even on an open socket and waits for a real page or `timeout`.
    /// Meant for a silent push's `didReceiveRemoteNotification`, so iOS doesn't suspend the app
    /// again before anything was actually fetched.
    func nachholenBisFertig(timeout: Duration = .seconds(20)) async {
        guard eingerichtet, ich != nil else { return }
        let zaehlerVorher = catchUpZaehler
        nachholenJetzt()
        let deadline = ContinuousClock.now + timeout
        while catchUpZaehler == zaehlerVorher, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        // `start()` set aktivZustand = true, which would otherwise leave the socket open and
        // "verbunden" past this point even though nothing is foreground to keep it alive — the
        // NEXT silent push would then see verbunden == true above and return without catching up,
        // background `fluechtig("standort")` would go to a socket the server times out on its own
        // 60 s ping check anyway, and pushes stay suppressed for it in the meantime (I-5).
        if UIApplication.shared.applicationState != .active {
            aktivZustand = false
            trennen()
        }
        await leer()
    }

    /// Waits for the `arbeit` chain to fully settle — not just for whatever the tail was at the
    /// moment of the call, but for any further work a running link chains onto it meanwhile.
    /// Then the queue is on disk (its writes are coalesced, audit #7).
    func leer() async {
        while true {
            let versionVorher = arbeitVersion
            guard let letzte = arbeit else { break }
            await letzte.value
            if arbeitVersion == versionVorher { break }
        }
        await warteschlange.sichern()
    }

    func httpKonfiguration() -> HttpKonfiguration? {
        guard eingerichtet, let ich, let baseURL else { return nil }
        return HttpKonfiguration(basis: baseURL, headers: ["X-Lovea-Key": appKey, "X-Lovea-Person": ich.rawValue])
    }

    func geraetRegistrieren(_ tokenHex: String) {
        geraeteToken = tokenHex
        if verbunden { sende(GeraetNachricht(token: tokenHex)) }
    }

    // MARK: - Observing

    /// Delivers matching ops one at a time: log history first, then anything still unconfirmed
    /// in the offline queue (so a message you sent right before quitting doesn't vanish).
    func beobachten(_ arten: Set<String>, _ f: @escaping (Op) -> Void) {
        beobachter.append((arten, f))
        // Chained (not a bare Task): a replay racing an in-flight `senden`/incoming batch could
        // otherwise deliver out of order, or run after — not before — ops that arrive right after
        // registration.
        reiheOhneWarten { [weak self] in
            guard let self else { return }
            for op in await self.verlauf(arten) { f(op) }
        }
    }

    /// Same replay, delivered as one array — use for logs that can be large (paging etc.).
    func beobachtenStapel(_ arten: Set<String>, _ f: @escaping ([Op]) -> Void) {
        stapelBeobachter.append((arten, f))
        reiheOhneWarten { [weak self] in
            guard let self else { return }
            let ops = await self.verlauf(arten)
            if !ops.isEmpty { f(ops) }
        }
    }

    func fluechtigBeobachten(_ art: String, _ f: @escaping (Person, Data) -> Void) {
        fluechtigBeobachter[art, default: []].append(f)
    }

    // MARK: - Sending

    /// Contract: `f` (from `beobachten`/`beobachtenStapel`) must be idempotent by `Op.id` —
    /// a sent op is delivered once optimistically (seq nil) and again once confirmed (seq set).
    func senden<T: Encodable>(_ art: String, _ d: T) {
        guard let ich else { return }
        einreihen(Op.neu(art, d, von: ich))
    }

    /// Tiefentest ("Test-Raum"): Ops nur an die Faltungen, nie in Warteschlange oder Netz.
    func lokalEinspielen(_ ops: [Op]) { liefereBatch(ops) }

    /// Same as `senden`, but for a caller that already built the `Op` itself — e.g. the widgets'
    /// pending-op merge (`WidgetPendingOpsMerge`), which reuses the exact `id` an App Intent wrote
    /// into the App Group so a redelivery (POST from the extension AND this replay both landing)
    /// dedups server-side (`INSERT OR IGNORE`) instead of creating two ops for one tap.
    func einreihen(_ op: Op) {
        liefereBatch([op])
        wartet += 1
        reiheOhneWarten { [weak self] in
            guard let self else { return }
            await self.warteschlange.rein(op)
            await self.wartetAktualisieren()
            if self.verbunden { ChatPerf.shared.anfrageGestartet(opId: op.id); self.sendeOp(op) }
        }
    }

    /// `standort` still reaches the server while disconnected (e.g. backgrounded, no open
    /// socket) via an HTTP fallback — everything else stays WS-only and is dropped while
    /// disconnected, same as before.
    func fluechtig<T: Encodable>(_ art: String, _ d: T) {
        guard verbunden else {
            // Background: the socket is closed ~30 s after backgrounding. Position and the own
            // state still reach the partner (the server keeps the last of each for a reconnect).
            // `karte.offen` too: sent right on foregrounding, before the socket is up, and the
            // server wakes a backgrounded partner with it.
            if art == "standort" || art == "zustand" || art == "karte.offen" { fluechtigPerHttp(art: art, d: d) }
            return
        }
        sende(FluechtigNachricht(art: art, d: d))
    }

    private func fluechtigPerHttp<T: Encodable>(art: String, d: T) {
        guard let konfig = httpKonfiguration() else { return }
        guard let body = try? JSONEncoder().encode(FluechtigHttpBody(art: art, d: d)) else { return }
        var request = URLRequest(url: konfig.basis.appendingPathComponent("fl"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (feld, wert) in konfig.headers { request.setValue(wert, forHTTPHeaderField: feld) }
        request.httpBody = body
        let anfrage = request // capture a `let` — whether Task{} here inherits MainActor isn't
        // something a `var` capture should rely on without a compiler to check it.
        Task {
            _ = try? await URLSession.shared.data(for: anfrage)
        }
    }

    // MARK: - Connecting

    private func verbinden() {
        guard eingerichtet, let ich, !verbunden, let url = wsURL(seit: empfangenBisSeq) else { return }
        generation += 1
        let gen = generation
        let headers = ["X-Lovea-Key": appKey, "X-Lovea-Person": ich.rawValue]
        nachholenLaeuft = true
        nachholFristStarten(gen: gen)
        transport.verbinden(
            url: url,
            headers: headers,
            // Decoding (up to 500 Ops, each rebuilding a JSONValue tree) runs here, off the main
            // actor — this closure has no actor isolation of its own, so it executes wherever the
            // transport's receive loop calls it from. Only the already-parsed result crosses over.
            nachricht: { [weak self] text in
                guard let nachricht = Raum.nachrichtDekodieren(text) else { return }
                guard let self else { return }
                await self.nachrichtAnwenden(nachricht, gen: gen)
            },
            getrennt: { [weak self] _ in
                guard let self else { return }
                await self.getrenntBehandeln(gen: gen)
            }
        )
        // NOT backoff = 1 here (I-1): the connection isn't confirmed yet at this point, only
        // attempted. A real catch-up page resets backoff in nachrichtAnwenden; pongs cannot
        // confirm that pending messages were delivered.
        verbunden = true
        if let token = geraeteToken { sende(GeraetNachricht(token: token)) }
        reiheOhneWarten { [weak self] in
            guard let self else { return }
            for op in await self.warteschlange.offen { self.sendeOp(op) }
        }
        letzterEmpfang = .now
        pingTask?.cancel()
        pingTask = Task { @MainActor [weak self, pingAbstand, pongFrist] in
            // Raw "ping": the server's auto-response answers "pong" without waking the Durable
            // Object, and its timestamp keeps the server's 60 s liveness check fresh (so no push
            // while we're here). No frame at all within `pongFrist` means a dead socket (network
            // switch, half-open after a suspend): reconnect now instead of sending into it until
            // iOS gives up on TCP, while the server keeps holding back pushes for us.
            while !Task.isCancelled {
                try? await Task.sleep(for: pingAbstand)
                guard !Task.isCancelled, let self, self.generation == gen else { return }
                let gesendet = ContinuousClock.now
                self.transport.senden("ping")
                try? await Task.sleep(for: pongFrist)
                guard !Task.isCancelled, self.generation == gen else { return }
                if self.letzterEmpfang < gesendet, !self.empfangLaeuft {
                    self.trennen()
                    self.verbinden()
                    return
                }
            }
        }
    }

    private func trennen() {
        reconnectTask?.cancel(); reconnectTask = nil
        pingTask?.cancel(); pingTask = nil
        nachholFristTask?.cancel(); nachholFristTask = nil
        nachholenLaeuft = false
        generation += 1
        transport.trennen()
        verbunden = false
    }

    private func getrenntBehandeln(gen: Int) async {
        guard gen == generation else { return }
        pingTask?.cancel(); pingTask = nil
        nachholFristTask?.cancel(); nachholFristTask = nil
        nachholenLaeuft = false
        generation += 1
        verbunden = false
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard aktivZustand else { return }
        reconnectTask?.cancel()
        let delay = backoff
        backoff = min(backoff * 2, 30)
        reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.verbinden()
        }
    }

    private func wsURL(seit: Int) -> URL? {
        guard let baseURL, var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        comps.scheme = comps.scheme == "https" ? "wss" : (comps.scheme == "http" ? "ws" : comps.scheme)
        comps.path = comps.path + "/raum"
        comps.queryItems = [URLQueryItem(name: "seit", value: String(seit))]
        return comps.url
    }

    // MARK: - Receiving

    /// Decodes a raw server message. `nonisolated` and `static` on purpose: this does the actual
    /// parsing (a `JSONValue` tree per op, for up to 500 ops on a page) and must NOT run on the
    /// main actor — see the comment at the call site in `verbinden`.
    private nonisolated static func nachrichtDekodieren(_ text: String) -> EingehendeNachricht? {
        if text == "pong" { return .pong }
        guard let data = text.data(using: .utf8) else { return nil }
        guard let huelle = try? JSONDecoder().decode(TypHuelle.self, from: data) else { return nil }
        switch huelle.t {
        case "ops":
            guard let msg = try? JSONDecoder().decode(OpsHuelle.self, from: data) else { return nil }
            if msg.uebersprungen > 0 {
                print("Raum: \(msg.uebersprungen) Op(s) in einer Seite konnten nicht dekodiert werden")
            }
            return .ops(msg.ops, mehr: msg.mehr, seite: msg.seite, hoechsteSeq: msg.hoechsteSeq)
        case "fl":
            guard let msg = try? JSONDecoder().decode(FlHuelle.self, from: data) else { return nil }
            let daten = (try? JSONEncoder().encode(msg.d)) ?? Data("{}".utf8)
            return .fl(msg.von, msg.art, daten)
        case "da":
            guard let msg = try? JSONDecoder().decode(DaHuelle.self, from: data) else { return nil }
            return .da(ahmed: msg.ahmed, annika: msg.annika)
        case "standort":
            guard let msg = try? JSONDecoder().decode(StandortHuelle.self, from: data) else { return nil }
            let daten = (try? JSONEncoder().encode(msg.d)) ?? Data("{}".utf8)
            return .standort(msg.person, daten)
        default:
            return nil
        }
    }

    /// Applies an already-decoded message. Cheap: actor calls, dictionary lookups, no parsing.
    private func nachrichtAnwenden(_ nachricht: EingehendeNachricht, gen: Int) async {
        guard gen == generation else { return }
        // Only a page proves a pending catch-up succeeded; pongs and live ops may still arrive
        // while the server has not answered our request.
        if case .ops(_, _, let seite, _) = nachricht, seite {
            nachholFristTask?.cancel(); nachholFristTask = nil
            nachholAusfaelle = 0
            backoff = 1
        } else if !nachholenLaeuft {
            backoff = 1
        }
        letzterEmpfang = .now
        empfangLaeuft = true
        defer { empfangLaeuft = false; letzterEmpfang = .now }
        switch nachricht {
        case .pong:
            break
        case .ops(let ops, let mehr, let seite, let hoechsteSeq):
            await reiheUndWarte { [weak self] in
                guard let self else { return }
                await self.opsVerarbeiten(ops, mehr: mehr, seite: seite, hoechsteSeq: hoechsteSeq)
            }
        case .fl(let von, let art, let daten):
            for f in fluechtigBeobachter[art] ?? [] { f(von, daten) }
        case .da(let ahmed, let annika):
            guard let ich else { return }
            partnerDa = ich == .ahmed ? annika : ahmed
        case .standort(let person, let daten):
            for f in fluechtigBeobachter["standort"] ?? [] { f(person, daten) }
        }
    }

    /// `seite` (server's `seite:true`) distinguishes a genuine catch-up page from a live
    /// broadcast (an echo, the partner's op, …) that happens to arrive while paging — a live
    /// broadcast still gets logged and delivered above, but must never move the paging cursor or
    /// be mistaken for "we just caught up" (C-2). `hoechsteSeq` is the highest `seq` seen across
    /// the whole page even if some ops in it failed to decode (I-3), so one malformed op can't
    /// stall pagination.
    private func opsVerarbeiten(_ ops: [Op], mehr: Bool, seite: Bool, hoechsteSeq: Int?) async {
        // UI first, persistence right after (Chat-Tempo-Befund 3): the folds are idempotent by
        // `Op.id` (see `beobachten`'s contract above), and the paging cursor below only ever moves
        // AFTER `log.anhaengen` — so a crash between these two lines just means the same ops get
        // redelivered (log) or re-sent (queue) next time, never lost, never double-shown.
        for op in ops where op.seq != nil { ChatPerf.shared.antwortErhalten(opId: op.id) }
        liefereBatch(ops)
        await log.anhaengen(ops)
        await warteschlange.rausBatch(ids: ops.map(\.id))
        await wartetAktualisieren()
        guard seite else { return }
        if let hoechsteSeq {
            empfangenBisSeq = hoechsteSeq
            await log.vollstaendigBisSeqSetzen(hoechsteSeq)
        }
        if mehr {
            if let hoechsteSeq { sende(NachholenNachricht(seit: hoechsteSeq)) }
            nachholFristStarten(gen: generation)
        } else {
            nachholenLaeuft = false
            catchUpZaehler += 1
        }
    }

    // MARK: - Helpers

    private func sendeOp(_ op: Op) {
        sende(OpNachricht(op: op))
    }

    private func sende<T: Encodable>(_ nachricht: T) {
        guard let daten = try? JSONEncoder().encode(nachricht), let text = String(data: daten, encoding: .utf8) else { return }
        transport.senden(text)
    }

    private func wartetAktualisieren() async {
        wartet = await warteschlange.offen.count
    }

    private func verlauf(_ arten: Set<String>) async -> [Op] {
        let bestaetigt = await log.alle(arten: arten)
        let bekannteIDs = Set(bestaetigt.map(\.id))
        let offen = await warteschlange.offen.filter { (arten.isEmpty || arten.contains($0.art)) && !bekannteIDs.contains($0.id) }
        return bestaetigt + offen
    }

    private func liefereBatch(_ ops: [Op]) {
        guard !ops.isEmpty else { return }
        if !erstesBatchMarkiert {
            erstesBatchMarkiert = true
            StartProtokoll.marke("raum.erstesBatch.\(ops.count)")
        }
        for eintrag in stapelBeobachter {
            let treffer = eintrag.arten.isEmpty ? ops : ops.filter { eintrag.arten.contains($0.art) }
            if !treffer.isEmpty { eintrag.f(treffer) }
        }
        for op in ops {
            for eintrag in beobachter where eintrag.arten.contains(op.art) { eintrag.f(op) }
        }
    }

    /// Chains `arbeit` without waiting for it — used by fire-and-forget callers like `senden`.
    private func reiheOhneWarten(_ neu: @escaping @MainActor () async -> Void) {
        let vorherige = arbeit
        arbeitVersion += 1
        arbeit = Task { @MainActor in
            await vorherige?.value
            await neu()
        }
    }

    /// Chains `arbeit` and waits for it — used by the receive loop so one message is fully
    /// processed (including any queue writes) before the next `receive()` is awaited.
    private func reiheUndWarte(_ neu: @escaping @MainActor () async -> Void) async {
        reiheOhneWarten(neu)
        await arbeit?.value
    }
}

/// Result of `Raum.nachrichtDekodieren` — everything needed to apply a message, already parsed.
private enum EingehendeNachricht: Sendable {
    case ops([Op], mehr: Bool, seite: Bool, hoechsteSeq: Int?)
    case fl(Person, String, Data)
    case da(ahmed: Bool, annika: Bool)
    case standort(Person, Data)
    case pong
}

private struct TypHuelle: Decodable { let t: String }

/// Decodes `{ops:[Op], mehr:Bool, seite:Bool}` tolerantly, per element (I-3): one malformed op
/// (unknown `von`, missing `d`, …) is skipped instead of failing the whole array, which would
/// otherwise silently drop `mehr`/`seite` too and stall paging. `hoechsteSeq` is the highest raw
/// `seq` across ALL elements, decoded or not, so pagination doesn't stall even when it's exactly
/// the highest-seq op in a page that fails to decode fully.
private struct OpsHuelle: Decodable {
    let ops: [Op]
    let mehr: Bool
    let seite: Bool
    let hoechsteSeq: Int?
    let uebersprungen: Int

    private enum CodingKeys: String, CodingKey { case ops, mehr, seite }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mehr = try c.decodeIfPresent(Bool.self, forKey: .mehr) ?? false
        seite = try c.decodeIfPresent(Bool.self, forKey: .seite) ?? false

        var opsContainer = try c.nestedUnkeyedContainer(forKey: .ops)
        var geladen: [Op] = []
        var uebersprungenZaehler = 0
        var hoechste: Int?
        while !opsContainer.isAtEnd {
            let element = try opsContainer.decode(OpElement.self)
            if let op = element.op { geladen.append(op) } else { uebersprungenZaehler += 1 }
            if let seq = element.seq { hoechste = max(hoechste ?? seq, seq) }
        }
        ops = geladen
        uebersprungen = uebersprungenZaehler
        hoechsteSeq = hoechste
    }
}

/// Never throws (both inner decodes are `try?`) — required so the unkeyed container in
/// `OpsHuelle` always advances past a malformed element instead of getting stuck re-decoding it.
private struct OpElement: Decodable {
    let op: Op?
    let seq: Int?

    init(from decoder: Decoder) throws {
        op = try? Op(from: decoder)
        seq = try? SeqNur(from: decoder).seq
    }
}

private struct SeqNur: Decodable { let seq: Int? }

private struct FlHuelle: Decodable { let von: Person; let art: String; let d: JSONValue }
private struct DaHuelle: Decodable { let ahmed: Bool; let annika: Bool }
private struct StandortHuelle: Decodable { let person: Person; let d: JSONValue }

private struct OpNachricht: Encodable { let t = "op"; let op: Op }
private struct NachholenNachricht: Encodable { let t = "nachholen"; let seit: Int }
private struct GeraetNachricht: Encodable { let t = "geraet"; let token: String }
private struct FluechtigNachricht<D: Encodable>: Encodable { let t = "fl"; let art: String; let d: D }
private struct FluechtigHttpBody<D: Encodable>: Encodable { let art: String; let d: D }
