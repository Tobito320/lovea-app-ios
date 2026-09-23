import Foundation
import Observation

// Usage: set `Raum.shared.ich = person` once at app start, call `Raum.shared.start()` and
// `Raum.shared.aktiv(_:)` from `scenePhase`. Faltungen register with `beobachten`/`beobachtenStapel`;
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

    private var backoff: TimeInterval = 1
    private var aktivZustand = false
    private var generation = 0
    private var empfangenBisSeq = 0
    private var geraeteToken: String?
    private var reconnectTask: Task<Void, Never>?
    private var hintergrundTask: Task<Void, Never>?

    /// Serializes disk writes and sends so they happen in call order (a fast echo must never
    /// run before the `senden` that caused it finishes queuing). Tests await `leer()`.
    private var arbeit: Task<Void, Never>?

    init(
        transport: RaumTransport? = nil,
        log: OpLog = OpLog(),
        warteschlange: Warteschlange = Warteschlange(),
        server: URL? = Raum.plistServer(),
        schluessel: String = Raum.plistSchluessel()
    ) {
        self.transport = transport ?? WebSocketTransport()
        self.log = log
        self.warteschlange = warteschlange
        self.baseURL = server
        self.appKey = schluessel
        self.eingerichtet = server != nil && !schluessel.isEmpty
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
        reconnectTask?.cancel(); reconnectTask = nil
        backoff = 1
        guard !verbunden else { return }
        // Chained (not a bare Task) so `leer()` also waits for the connect + queue flush below.
        reiheOhneWarten { [weak self] in
            guard let self else { return }
            self.empfangenBisSeq = await self.log.letzteSeq
            await self.wartetAktualisieren() // e.g. after an offline restart, before anything is sent
            self.verbinden()
        }
    }

    /// Call from `scenePhase`: connect when active, disconnect 30 s after going to background.
    func aktiv(_ ist: Bool) {
        if ist {
            start()
        } else {
            guard aktivZustand else { return }
            aktivZustand = false
            hintergrundTask?.cancel()
            hintergrundTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { return }
                self.trennen()
            }
        }
    }

    func leer() async {
        await arbeit?.value
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

    func fluechtig<T: Encodable>(_ art: String, _ d: T) {
        sende(FluechtigNachricht(art: art, d: d))
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
        verbunden = true
        backoff = 1
        if let token = geraeteToken { sende(GeraetNachricht(token: token)) }
        reiheOhneWarten { [weak self] in
            guard let self else { return }
            for op in await self.warteschlange.offen { self.sendeOp(op) }
        }
    }

    private func trennen() {
        reconnectTask?.cancel(); reconnectTask = nil
        generation += 1
        transport.trennen()
        verbunden = false
    }

    private func getrenntBehandeln(gen: Int) async {
        guard gen == generation else { return }
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
            return .ops(msg.ops, mehr: msg.mehr)
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
        switch nachricht {
        case .ops(let ops, let mehr):
            await reiheUndWarte { [weak self] in
                guard let self else { return }
                await self.opsVerarbeiten(ops, mehr: mehr)
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

    private func opsVerarbeiten(_ ops: [Op], mehr: Bool) async {
        await log.anhaengen(ops)
        for op in ops { await warteschlange.raus(id: op.id) }
        await wartetAktualisieren()
        if let maxSeq = ops.compactMap(\.seq).max() { empfangenBisSeq = max(empfangenBisSeq, maxSeq) }
        liefereBatch(ops)
        if mehr { sende(NachholenNachricht(seit: empfangenBisSeq)) }
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
    case ops([Op], mehr: Bool)
    case fl(Person, String, Data)
    case da(ahmed: Bool, annika: Bool)
    case standort(Person, Data)
}

private struct TypHuelle: Decodable { let t: String }
private struct OpsHuelle: Decodable { let ops: [Op]; let mehr: Bool }
private struct FlHuelle: Decodable { let von: Person; let art: String; let d: JSONValue }
private struct DaHuelle: Decodable { let ahmed: Bool; let annika: Bool }
private struct StandortHuelle: Decodable { let person: Person; let d: JSONValue }

private struct OpNachricht: Encodable { let t = "op"; let op: Op }
private struct NachholenNachricht: Encodable { let t = "nachholen"; let seit: Int }
private struct GeraetNachricht: Encodable { let t = "geraet"; let token: String }
private struct FluechtigNachricht<D: Encodable>: Encodable { let t = "fl"; let art: String; let d: D }
