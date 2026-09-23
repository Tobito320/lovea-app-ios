import Foundation
import Observation
import UserNotifications

/// Folds every chat op (schnittstellen.md) into the one conversation. Registers with
/// `Raum.shared.beobachtenStapel` by default; tests feed ops directly via `anwenden(_:)`
/// using `init(registrieren: false)`, no `Raum` needed.
@MainActor
@Observable
final class ChatModell {
    static let shared = ChatModell()

    struct Nachricht: Identifiable, Sendable {
        let id: String
        let von: Person
        let zeit: Date
        var seq: Int?
        var text: String?
        var medien: [MedienEintrag] = []
        var antwortAuf: String?
        var snap: SnapInfo?
        var gif: GifInfo?
        var sticker: StickerInfo?
        var spiel: SpielInfo?
        var system: String?
        var bearbeitet = false
        var geloescht = false
        var reaktionen: [Person: String] = [:]
        var angeheftet = false
        var angeheftetBis: Date?
        var gesternt: Set<Person> = []
        // Block 6 (Z-6.3): folded from `snap.angesehen`/`snap.gespeichert`, not part of the
        // `nachricht.neu` payload itself.
        var snapAngesehen = false
        var snapLange = false
        var snapGespeichert = false
        /// Local chat line for a `zeichnung.einladung` (no own op, so no second push).
        var einladung: EinladungInfo?
        // Z-27.2: optional, at the end so every existing labeled `Nachricht(...)` call above still
        // compiles unchanged.
        var kapsel: KapselInfo?
        var brief: BriefInfo?
    }

    struct EinladungInfo: Sendable, Equatable { let zeichnungId: String; let name: String }
    /// `oeffnetAm` is a "yyyy-MM-dd" day (schnittstellen.md), compared in Europe/Berlin — see `verschlossen(_:)`.
    struct KapselInfo: Codable, Sendable, Equatable { let oeffnetAm: String }
    struct BriefInfo: Codable, Sendable, Equatable { let titel: String }

    // Blocks 5/6 extend these; fields already match the op payloads in schnittstellen.md.
    // `pegel` (Z-5.2 waveform, ≤64 dB-derived values) is an extra field beyond schnittstellen.md,
    // fine per Block 5's decision — Optional, so older `nachricht.neu` payloads decode unchanged.
    struct MedienEintrag: Codable, Sendable, Equatable { let id: String; let typ: String; let breite: Double; let hoehe: Double; var dauer: Double?; var pegel: [Float]? }
    struct SnapInfo: Codable, Sendable, Equatable { let bleibt: Bool }
    struct GifInfo: Codable, Sendable, Equatable { let url: String; let breite: Double; let hoehe: Double }
    struct StickerInfo: Codable, Sendable, Equatable { let medienId: String }
    struct SpielInfo: Codable, Sendable, Equatable { let id: String }

    private(set) var nachrichten: [Nachricht] = []
    private(set) var gelesenBis: [Person: Date] = [:]
    private(set) var letzteAktivitaet: [Person: Date] = [:]
    /// Voice message transcripts (Z-5.2), keyed by the medium's `id`. Kept out of `Nachricht`
    /// because that struct's init is called positionally all over this file and its tests.
    private(set) var abschriften: [String: String] = [:]

    private var byID: [String: Nachricht] = [:]
    private let registrieren: Bool

    /// Z-26.2: per-person draft fold — only ever read back for `Raum.shared.ich`'s own person
    /// (schnittstellen.md's "nur eigener"), but keyed by every `von` seen so a partner's ops never
    /// mix into it.
    private var entwuerfe: [Person: EntwurfFaltung] = [:]
    private var entwurfDebounce: Task<Void, Never>?
    private var letzterGesendeterEntwurf: EntwurfEintrag?

    static let arten: Set<String> = [
        "nachricht.neu", "nachricht.bearbeitet", "nachricht.geloescht", "nachricht.reaktion",
        "nachricht.gelesen", "nachricht.angeheftet", "nachricht.losgeloest", "stern",
        "medium.abschrift", "snap.angesehen", "snap.gespeichert", "snap.aufnahme", "zeichnung.einladung",
        "entwurf.setzen",
    ]

    init(registrieren: Bool = true) {
        self.registrieren = registrieren
        guard registrieren else { return }
        Raum.shared.beobachtenStapel(Self.arten) { [weak self] ops in
            self?.anwenden(ops)
        }
    }

    // MARK: - Fold (Z-4.1)

    /// Pure fold, idempotent by the message id inside each op's `d` (not the op id itself —
    /// an optimistic send and its server echo share one op id, but only `nachricht.neu`'s own
    /// `id` field is what edits/reactions/deletes reference).
    func anwenden(_ ops: [Op]) {
        for op in ops { anwendenEins(op) }
        nachrichten = byID.values.sorted { ($0.seq ?? Int.max, $0.zeit) < ($1.seq ?? Int.max, $1.zeit) }
        if registrieren { badgeAktualisieren() }
    }

    private func anwendenEins(_ op: Op) {
        letzteAktivitaet[op.von] = max(letzteAktivitaet[op.von] ?? .distantPast, op.zeit)
        switch op.art {
        case "nachricht.neu":
            guard let p = op.daten(NachrichtNeuPayload.self) else { return }
            if var vorhanden = byID[p.id] {
                if let seq = op.seq { vorhanden.seq = seq }
                byID[p.id] = vorhanden
            } else {
                byID[p.id] = Nachricht(
                    id: p.id, von: op.von, zeit: op.zeit, seq: op.seq, text: p.text,
                    medien: p.medien ?? [], antwortAuf: p.antwortAuf, snap: p.snap,
                    gif: p.gif, sticker: p.sticker, spiel: p.spiel, system: p.system,
                    kapsel: p.kapsel, brief: p.brief
                )
            }
        case "nachricht.bearbeitet":
            guard let p = op.daten(BearbeitetPayload.self) else { return }
            byID[p.id]?.text = p.text
            byID[p.id]?.bearbeitet = true
        case "nachricht.geloescht":
            guard let p = op.daten(IDPayload.self) else { return }
            if p.id.hasPrefix("umzug:zeichnung/") {
                // Z-26.4: "aus dem Chat gelöscht" — vanishes outright, no "Nachricht gelöscht" spur.
                byID.removeValue(forKey: p.id)
            } else {
                byID[p.id]?.geloescht = true
            }
        case "nachricht.reaktion":
            guard let p = op.daten(ReaktionPayload.self) else { return }
            byID[p.id]?.reaktionen[op.von] = p.emoji
        case "nachricht.gelesen":
            guard let p = op.daten(GelesenPayload.self), let bis = Self.datum(p.bis) else { return }
            gelesenBis[op.von] = max(gelesenBis[op.von] ?? .distantPast, bis)
        case "nachricht.angeheftet":
            guard let p = op.daten(AngeheftetPayload.self) else { return }
            byID[p.id]?.angeheftet = true
            byID[p.id]?.angeheftetBis = p.bis.flatMap(Self.datum)
        case "nachricht.losgeloest":
            guard let p = op.daten(IDPayload.self) else { return }
            byID[p.id]?.angeheftet = false
            byID[p.id]?.angeheftetBis = nil
        case "stern":
            // "nur für von sichtbar" (schnittstellen.md): folded for whoever sent it, the UI
            // only ever shows a person their own stars (see `meineSterne`).
            guard let p = op.daten(SternPayload.self) else { return }
            if p.an { byID[p.id]?.gesternt.insert(op.von) } else { byID[p.id]?.gesternt.remove(op.von) }
        case "medium.abschrift":
            guard let p = op.daten(AbschriftPayload.self) else { return }
            abschriften[p.id] = p.text
        case "snap.angesehen":
            guard let p = op.daten(SnapAngesehenPayload.self) else { return }
            byID[p.id]?.snapAngesehen = true
            if p.lange { byID[p.id]?.snapLange = true }
        case "snap.gespeichert":
            guard let p = op.daten(IDPayload.self) else { return }
            byID[p.id]?.snapGespeichert = true
        case "snap.aufnahme":
            // Not folded onto the snap message itself (that `id` is someone else's to own) — this
            // becomes its own system-style row, keyed by `op.id` so the optimistic send and its
            // echo share one row (same dedupe contract as every other op here).
            guard let p = op.daten(SnapAufnahmePayload.self) else { return }
            if var vorhanden = byID[op.id] {
                if let seq = op.seq { vorhanden.seq = seq }
                byID[op.id] = vorhanden
            } else {
                let text = op.von.name + (p.art == "bildschirmaufnahme" ? " hat den Bildschirm aufgenommen" : " hat einen Screenshot gemacht")
                byID[op.id] = Nachricht(id: op.id, von: op.von, zeit: op.zeit, seq: op.seq, system: text)
            }
        case "entwurf.setzen":
            entwuerfe[op.von, default: EntwurfFaltung()].anwenden(op)
        case "zeichnung.einladung":
            // Keyed by the op id: the optimistic op and its echo share it.
            guard let p = op.daten(EinladungPayload.self) else { return }
            let id = "einladung-\(op.id)"
            if var vorhanden = byID[id] {
                if let seq = op.seq { vorhanden.seq = seq }
                byID[id] = vorhanden
            } else {
                var zeile = Nachricht(id: id, von: op.von, zeit: op.zeit, seq: op.seq)
                zeile.einladung = EinladungInfo(zeichnungId: p.zeichnungId, name: p.name)
                byID[id] = zeile
            }
        default:
            break
        }
    }

    // MARK: - Derived state

    var angeheftete: [Nachricht] {
        let jetzt = Date()
        return nachrichten.filter { $0.angeheftet && !$0.geloescht && ($0.angeheftetBis.map { $0 > jetzt } ?? true) }
    }

    func meineSterne(_ ich: Person) -> [Nachricht] {
        nachrichten.filter { $0.gesternt.contains(ich) && !$0.geloescht }
    }

    func ungelesen(fuer ich: Person) -> Int {
        let grenze = gelesenBis[ich] ?? .distantPast
        return nachrichten.filter { $0.von != ich && !$0.geloescht && $0.zeit > grenze && Self.sichtbar($0) }.count
    }

    /// Game rows whose card is hidden (expired/cancelled invite) count for nothing: no badge, no preview.
    static func sichtbar(_ nachricht: Nachricht) -> Bool {
        guard let spiel = nachricht.spiel else { return true }
        return SpieleModell.shared.sichtbar(spiel.id)
    }

    /// Z-26.2: the current draft — text, already-uploaded medien ids, an optional voice note id.
    /// Only ever meaningful for `Raum.shared.ich` (the partner's own draft is never surfaced).
    func entwurf(fuer person: Person) -> EntwurfEintrag {
        entwuerfe[person]?.aktuell ?? EntwurfEintrag()
    }

    private func badgeAktualisieren() {
        guard let ich = Raum.shared.ich else { return }
        let anzahl = ungelesen(fuer: ich)
        Task { @MainActor in try? await UNUserNotificationCenter.current().setBadgeCount(anzahl) }
    }

    // MARK: - Sending

    func nachrichtSenden(text: String, antwortAuf: String? = nil) {
        let getrimmt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !getrimmt.isEmpty else { return }
        Raum.shared.senden("nachricht.neu", NachrichtNeuPayload(id: UUID().uuidString, text: getrimmt, antwortAuf: antwortAuf))
    }

    /// Z-27.2: Zeitkapsel — `oeffnetAm` ist der Öffnungstag (Europe/Berlin), verschlossen bis dahin.
    /// Spec 9 "Nachricht, Foto oder Zeichnung": `medium` ist optional, Text oder Foto reicht.
    func kapselSenden(text: String, oeffnetAm: Date, medium: MedienEintrag? = nil) {
        let getrimmt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !getrimmt.isEmpty || medium != nil else { return }
        Raum.shared.senden(
            "nachricht.neu",
            NachrichtNeuPayload(
                id: UUID().uuidString, text: getrimmt.isEmpty ? nil : getrimmt, medien: medium.map { [$0] },
                kapsel: KapselInfo(oeffnetAm: Datum.text(oeffnetAm))
            )
        )
    }

    /// Z-27.2: Liebesbrief — kein Verschluss-Datum, nur Siegel + Öffnen-Animation (`ChatNachrichtRow`).
    func briefSenden(titel: String, text: String) {
        let titelGetrimmt = titel.trimmingCharacters(in: .whitespacesAndNewlines)
        let textGetrimmt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titelGetrimmt.isEmpty, !textGetrimmt.isEmpty else { return }
        Raum.shared.senden(
            "nachricht.neu",
            NachrichtNeuPayload(id: UUID().uuidString, text: textGetrimmt, brief: BriefInfo(titel: titelGetrimmt))
        )
    }

    /// Z-27.2 "ist sie schon offen": Kalendertag-Vergleich in Europe/Berlin (`Datum`, wie der Server
    /// bei `kapselOeffnetZeit`), NICHT die genaue Uhrzeit — die Push kommt bewusst erst um 09:00,
    /// aber die Kapsel selbst öffnet sich schon ab Mitternacht des Tages (Spec 9).
    // `nonisolated`: pure (no `self`/instance state), called from non-MainActor call sites too —
    // `HeuteVorLogik` (plain enum) and `ChatVorschau.inhalt` (plain enum) both call this.
    nonisolated static func verschlossen(oeffnetAm: String, jetzt: Date = Date()) -> Bool {
        Datum.tageZwischen(oeffnetAm, Datum.text(jetzt)) < 0
    }

    nonisolated static func verschlossen(_ n: Nachricht, jetzt: Date = Date()) -> Bool {
        guard let kapsel = n.kapsel else { return false }
        return verschlossen(oeffnetAm: kapsel.oeffnetAm, jetzt: jetzt)
    }

    func bearbeiten(_ id: String, text: String) {
        Raum.shared.senden("nachricht.bearbeitet", BearbeitetPayload(id: id, text: text))
    }

    func loeschen(_ id: String) {
        Raum.shared.senden("nachricht.geloescht", IDPayload(id: id))
    }

    func reagieren(_ id: String, emoji: String?) {
        Raum.shared.senden("nachricht.reaktion", ReaktionPayload(id: id, emoji: emoji))
    }

    /// Called when the chat is visible and there are unread partner messages (Z-4.6).
    func gelesenSenden(bis: Date = Date()) {
        Raum.shared.senden("nachricht.gelesen", GelesenPayload(bis: Self.datumString(bis)))
    }

    func anheften(_ id: String, bis: Date?) {
        Raum.shared.senden("nachricht.angeheftet", AngeheftetPayload(id: id, bis: bis.map(Self.datumString)))
    }

    func loesen(_ id: String) {
        Raum.shared.senden("nachricht.losgeloest", IDPayload(id: id))
    }

    func sternSetzen(_ id: String, an: Bool) {
        Raum.shared.senden("stern", SternPayload(id: id, an: an))
    }

    // MARK: - Draft (Z-26.2)

    /// Debounced ~1s on change; a no-op if the content doesn't actually differ from what this
    /// device last sent (including whatever was restored at launch — see `entwurfBasislinie`).
    func entwurfGeaendert(text: String, medien: [String], sprache: String?) {
        entwurfBasislinie()
        entwurfDebounce?.cancel()
        let neu = EntwurfEintrag(text: text, medien: medien, sprache: sprache)
        guard neu != letzterGesendeterEntwurf else { return }
        entwurfDebounce = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.entwurfSendenJetzt(neu)
        }
    }

    /// Flushes any pending debounce right away — call on disappear/background so the last second
    /// of typing isn't lost if the app is killed right after.
    func entwurfFlush(text: String, medien: [String], sprache: String?) {
        entwurfBasislinie()
        entwurfDebounce?.cancel()
        entwurfDebounce = nil
        let neu = EntwurfEintrag(text: text, medien: medien, sprache: sprache)
        guard neu != letzterGesendeterEntwurf else { return }
        entwurfSendenJetzt(neu)
    }

    /// After actually sending the composed message: "ein leerer entwurf.setzen räumt ihn auf".
    func entwurfLeeren() {
        entwurfBasislinie()
        entwurfDebounce?.cancel()
        entwurfDebounce = nil
        guard letzterGesendeterEntwurf?.leer != true else { return }
        entwurfSendenJetzt(EntwurfEintrag())
    }

    /// The composer just restored `entwurf` (Minor 1): that is now the baseline, so flushing it
    /// unchanged later sends nothing — even if the fold moved on meanwhile (another own device sent
    /// and cleared it), which would otherwise resurrect the old draft there.
    func entwurfWiederhergestellt(_ entwurf: EntwurfEintrag) {
        letzterGesendeterEntwurf = entwurf
    }

    /// Seeds `letzterGesendeterEntwurf` from whatever this person's own fold already holds (a
    /// restored draft, or one sent earlier this launch) — otherwise the very first flush after a
    /// plain restore-with-no-edit would resend the identical draft as a redundant op.
    private func entwurfBasislinie() {
        guard letzterGesendeterEntwurf == nil, let ich = Raum.shared.ich else { return }
        letzterGesendeterEntwurf = entwurf(fuer: ich)
    }

    private func entwurfSendenJetzt(_ entwurf: EntwurfEintrag) {
        letzterGesendeterEntwurf = entwurf
        Raum.shared.senden(
            "entwurf.setzen",
            EntwurfPayload(text: entwurf.text.isEmpty ? nil : entwurf.text, medien: entwurf.medien.isEmpty ? nil : entwurf.medien, sprache: entwurf.sprache)
        )
    }

    // MARK: - Sending media (Z-5.1/Z-5.2/Z-5.3/Z-5.5)

    /// One or more media entries (multi-photo select shares one `nachricht.neu`, Z-5.1).
    @discardableResult
    func medienSenden(_ medien: [MedienEintrag], antwortAuf: String? = nil) -> String {
        let id = UUID().uuidString
        Raum.shared.senden("nachricht.neu", NachrichtNeuPayload(id: id, medien: medien, antwortAuf: antwortAuf))
        return id
    }

    func gifSenden(url: String, breite: Double, hoehe: Double, antwortAuf: String? = nil) {
        Raum.shared.senden(
            "nachricht.neu",
            NachrichtNeuPayload(id: UUID().uuidString, antwortAuf: antwortAuf, gif: GifInfo(url: url, breite: breite, hoehe: hoehe))
        )
    }

    func stickerSenden(medienId: String, antwortAuf: String? = nil) {
        Raum.shared.senden(
            "nachricht.neu",
            NachrichtNeuPayload(id: UUID().uuidString, antwortAuf: antwortAuf, sticker: StickerInfo(medienId: medienId))
        )
    }

    /// Voice-message transcript (Z-5.2), attached after the message itself is already sent.
    func abschriftSenden(medienId: String, text: String) {
        Raum.shared.senden("medium.abschrift", AbschriftPayload(id: medienId, text: text))
    }

    // MARK: - Sending snaps (Z-6.1–Z-6.4)

    @discardableResult
    func snapSenden(_ medium: MedienEintrag, bleibt: Bool, antwortAuf: String? = nil) -> String {
        let id = UUID().uuidString
        Raum.shared.senden("nachricht.neu", NachrichtNeuPayload(id: id, medien: [medium], antwortAuf: antwortAuf, snap: SnapInfo(bleibt: bleibt)))
        return id
    }

    /// `lange` = viewed at least 2 minutes at a stretch (Z-6.3). Only the recipient ever calls this
    /// — a re-view via "Erneut ansehen" does not resend it (that menu item only re-opens the viewer).
    func snapAngesehenSenden(_ id: String, lange: Bool) {
        Raum.shared.senden("snap.angesehen", SnapAngesehenPayload(id: id, lange: lange))
    }

    func snapGespeichertSenden(_ id: String) {
        Raum.shared.senden("snap.gespeichert", IDPayload(id: id))
    }

    /// `art` is `"screenshot"` or `"bildschirmaufnahme"` (Z-6.4); `von` (i.e. `Raum.shared.ich`) is
    /// whoever is looking right now, not the snap's original sender.
    func snapAufnahmeSenden(_ id: String, art: String) {
        Raum.shared.senden("snap.aufnahme", SnapAufnahmePayload(id: id, art: art))
    }

    /// Z-6.5: every sent snap (not views/saves/screenshots) feeds the streak. Recomputed on demand
    /// — cheap enough for a two-person chat, no reason to cache it alongside `nachrichten`.
    var streak: (tage: Int, laeuftAb: Bool) {
        let snaps = nachrichten.compactMap { nachricht in nachricht.snap != nil ? (von: nachricht.von, zeit: nachricht.zeit) : nil }
        return Streak.berechnen(snaps: snaps, jetzt: Date())
    }

    // MARK: - ISO dates for `bis` fields (Op itself formats `zeit` the same way, but keeps that formatter private)

    private static func isoFormatierer(fraktional: Bool) -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = fraktional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return f
    }

    private static func datumString(_ datum: Date) -> String { isoFormatierer(fraktional: true).string(from: datum) }

    private static func datum(_ text: String) -> Date? {
        isoFormatierer(fraktional: true).date(from: text) ?? isoFormatierer(fraktional: false).date(from: text)
    }
}

// MARK: - Wire payloads (schnittstellen.md field names, verbatim)

private struct NachrichtNeuPayload: Codable {
    let id: String
    var text: String?
    var medien: [ChatModell.MedienEintrag]?
    var antwortAuf: String?
    var snap: ChatModell.SnapInfo?
    var gif: ChatModell.GifInfo?
    var sticker: ChatModell.StickerInfo?
    var spiel: ChatModell.SpielInfo?
    var system: String?
    var kapsel: ChatModell.KapselInfo?
    var brief: ChatModell.BriefInfo?
}

/// Z-26.2 draft content: text, already-uploaded photo/voice medien ids.
struct EntwurfEintrag: Sendable, Equatable {
    var text: String = ""
    var medien: [String] = []
    var sprache: String?
    var leer: Bool { text.isEmpty && medien.isEmpty && sprache == nil }
}

/// Pure per-person fold (Z-26.2, Review-Fokus #5 "auf zwei Geräten"): the current draft is the
/// newest still-*unconfirmed* send (by client `zeit` — a fresh local edit always wins immediately),
/// if there is one; otherwise the highest-`seq` *confirmed* one. An op moving from unconfirmed to
/// confirmed only updates its own bookkeeping (`offen[op.id]` → folded into `bestesBestaetigt`) —
/// it never lets a still-unconfirmed local echo permanently out-rank a genuinely newer, already-
/// confirmed op that arrived from a second device in between.
struct EntwurfFaltung: Sendable {
    private var bestesBestaetigt: (seq: Int, entwurf: EntwurfEintrag)?
    private var offen: [String: (zeit: Date, entwurf: EntwurfEintrag)] = [:]

    var aktuell: EntwurfEintrag {
        if let neuestesOffenes = offen.values.max(by: { $0.zeit < $1.zeit }) { return neuestesOffenes.entwurf }
        return bestesBestaetigt?.entwurf ?? EntwurfEintrag()
    }

    mutating func anwenden(_ op: Op) {
        guard let p = op.daten(EntwurfPayload.self) else { return }
        let entwurf = EntwurfEintrag(text: p.text ?? "", medien: p.medien ?? [], sprache: p.sprache)
        if let seq = op.seq {
            offen.removeValue(forKey: op.id)
            if seq >= (bestesBestaetigt?.seq ?? Int.min) { bestesBestaetigt = (seq, entwurf) }
        } else {
            offen[op.id] = (op.zeit, entwurf)
        }
    }
}

private struct EntwurfPayload: Codable {
    var text: String?
    var medien: [String]?
    var sprache: String?
}

private struct BearbeitetPayload: Codable { let id: String; let text: String }
private struct IDPayload: Codable { let id: String }
private struct ReaktionPayload: Codable { let id: String; let emoji: String? }
private struct GelesenPayload: Codable { let bis: String }
private struct AngeheftetPayload: Codable { let id: String; let bis: String? }
private struct SternPayload: Codable { let id: String; let an: Bool }
private struct AbschriftPayload: Codable { let id: String; let text: String }
private struct SnapAngesehenPayload: Codable { let id: String; let lange: Bool }
private struct SnapAufnahmePayload: Codable { let id: String; let art: String }
private struct EinladungPayload: Codable { let zeichnungId: String; let name: String }
