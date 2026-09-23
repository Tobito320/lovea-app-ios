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

    /// Set by the Karte/Orte block to react to a `karte.offen` push before the socket is even
    /// open — see `LoveaAppDelegate.application(_:didReceiveRemoteNotification:)`. The payload
    /// keys (`art`/`an`) are assumed, mirroring the `fl "karte.offen" {an}` WS message — no
    /// server push payload for this exists yet to confirm against.
    var onKarteOffen: ((Bool) -> Void)?

    struct HttpKonfiguration: Sendable { let basis: URL; let headers: [String: String] }

    private let transport: RaumTransport
    private let log: OpLog
    private let warteschlange: Warteschlange
    private let baseURL: URL?
    private let appKey: String

    private var beobachter: [(arten: Set<String>, f: (Op) -> Void)] = []
    private var stapelBeobachter: [(arten: Set<String>, f: ([Op]) -> Void)] = []
    private var fluechtigBeobachter: [String: [(Person, Data) -> Void]] = [:]

    private var backoff: TimeInterval = 1
    private var aktivZustand = false
    private var generation = 0
    private var empfangenBisSeq = 0
    private var geraeteToken: String?
    private var reconnectTask: Task<Void, Never>?
    private var hintergrundTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
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
        medienBeimStartFortsetzen: Bool = true
    ) {
        self.transport = transport ?? WebSocketTransport()
        self.log = log
        self.warteschlange = warteschlange
        self.baseURL = server
        self.appKey = schluessel
        self.eingerichtet = server != nil && !schluessel.isEmpty
        self.medienBeimStartFortsetzen = medienBeimStartFortsetzen
    }

    nonisolated static func plistServer() -> URL? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: "LoveaServer") as? String, !text.isEmpty else { return nil }
        return URL(string: text)
    }

    nonisolated static func plistSchluessel() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "LoveaAppKey") as? String) ?? ""
    }

    // MARK: - Lifecycle

    func start() {
        guard eingerichtet, ich != nil else { return }
        aktivZustand = true
        hintergrundTask?.cancel(); hintergrundTask = nil
        beendeHintergrundAufgabe()
        reconnectTask?.cancel(); reconnectTask = nil
        backoff = 1 // explicit start() means "try fresh"; verbinden() itself no longer resets this (I-1)
        if medienBeimStartFortsetzen { Medien.fortsetzen() }
        guard !verbunden else { return }
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

    /// Call from `scenePhase`: connect when active. `.inactive` (app switcher, Control Center)
    /// disconnects after 30 s. `.background` (`hintergrund`) disconnects right after a short flush
    /// (I-4): while the socket is open the server counts the person as there and sends no push.
    func aktiv(_ ist: Bool, hintergrund: Bool = false) {
        if ist {
            beendeHintergrundAufgabe()
            start()
            return
        }
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

    /// Connects (if needed) and waits for a real catch-up — the first page response after
    /// connecting, or `timeout`, whichever comes first — instead of returning immediately.
    /// Meant for a silent push's `didReceiveRemoteNotification`, so iOS doesn't suspend the app
    /// again before anything was actually fetched.
    func nachholenBisFertig(timeout: Duration = .seconds(20)) async {
        guard eingerichtet, ich != nil else { return }
        if verbunden { return } // already caught up / actively connected, nothing to wait for
        start()
        let zaehlerVorher = catchUpZaehler
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
    }

    /// Waits for the `arbeit` chain to fully settle — not just for whatever the tail was at the
    /// moment of the call, but for any further work a running link chains onto it meanwhile.
    func leer() async {
        while true {
            let versionVorher = arbeitVersion
            guard let letzte = arbeit else { return }
            await letzte.value
            if arbeitVersion == versionVorher { return }
        }
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
        let op = Op.neu(art, d, von: ich)
        liefereBatch([op])
        wartet += 1
        reiheOhneWarten { [weak self] in
            guard let self else { return }
            await self.warteschlange.rein(op)
            await self.wartetAktualisieren()
            if self.verbunden { self.sendeOp(op) }
        }
    }

    /// `standort` still reaches the server while disconnected (e.g. backgrounded, no open
    /// socket) via an HTTP fallback — everything else stays WS-only and is dropped while
    /// disconnected, same as before.
    func fluechtig<T: Encodable>(_ art: String, _ d: T) {
        guard verbunden else {
            if art == "standort" { fluechtigPerHttp(art: art, d: d) }
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
        // attempted. Resetting here made scheduleReconnect always see backoff == 1, so it never
        // actually grew past 1 s between retries. It resets on the first received frame instead,
        // in nachrichtAnwenden — real proof the connection is up.
        verbunden = true
        if let token = geraeteToken { sende(GeraetNachricht(token: token)) }
        reiheOhneWarten { [weak self] in
            guard let self else { return }
            for op in await self.warteschlange.offen { self.sendeOp(op) }
        }
        pingTask?.cancel()
        pingTask = Task { @MainActor [weak self] in
            // The server only counts a socket as alive if it heard SOMETHING (ping or any
            // message) in the last 60 s and pushes are otherwise suppressed for it — 25 s keeps
            // comfortably inside that. A native WebSocket ping isn't enough: the server can't see
            // it as a message, so this sends the same JSON text frame it treats a real "ping" as.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                guard !Task.isCancelled, let self, self.generation == gen else { return }
                self.sende(PingNachricht())
            }
        }
    }

    private func trennen() {
        reconnectTask?.cancel(); reconnectTask = nil
        pingTask?.cancel(); pingTask = nil
        generation += 1
        transport.trennen()
        verbunden = false
    }

    private func getrenntBehandeln(gen: Int) async {
        guard gen == generation else { return }
        pingTask?.cancel(); pingTask = nil
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
        // Real proof the connection is up — see the comment on backoff in `verbinden` (I-1).
        backoff = 1
        switch nachricht {
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
        await log.anhaengen(ops)
        for op in ops { await warteschlange.raus(id: op.id) }
        await wartetAktualisieren()
        liefereBatch(ops)
        guard seite else { return }
        if let hoechsteSeq {
            empfangenBisSeq = hoechsteSeq
            await log.vollstaendigBisSeqSetzen(hoechsteSeq)
        }
        if mehr {
            if let hoechsteSeq { sende(NachholenNachricht(seit: hoechsteSeq)) }
        } else {
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
private struct PingNachricht: Encodable { let t = "ping" }
private struct FluechtigNachricht<D: Encodable>: Encodable { let t = "fl"; let art: String; let d: D }
private struct FluechtigHttpBody<D: Encodable>: Encodable { let art: String; let d: D }
