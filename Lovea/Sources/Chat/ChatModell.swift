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
    }

    // Blocks 5/6 extend these; fields already match the op payloads in schnittstellen.md.
    struct MedienEintrag: Codable, Sendable, Equatable { let id: String; let typ: String; let breite: Double; let hoehe: Double; var dauer: Double? }
    struct SnapInfo: Codable, Sendable, Equatable { let bleibt: Bool }
    struct GifInfo: Codable, Sendable, Equatable { let url: String; let breite: Double; let hoehe: Double }
    struct StickerInfo: Codable, Sendable, Equatable { let medienId: String }
    struct SpielInfo: Codable, Sendable, Equatable { let id: String }

    private(set) var nachrichten: [Nachricht] = []
    private(set) var gelesenBis: [Person: Date] = [:]
    private(set) var letzteAktivitaet: [Person: Date] = [:]

    private var byID: [String: Nachricht] = [:]
    private let registrieren: Bool

    static let arten: Set<String> = [
        "nachricht.neu", "nachricht.bearbeitet", "nachricht.geloescht", "nachricht.reaktion",
        "nachricht.gelesen", "nachricht.angeheftet", "nachricht.losgeloest", "stern",
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
                    gif: p.gif, sticker: p.sticker, spiel: p.spiel, system: p.system
                )
            }
        case "nachricht.bearbeitet":
            guard let p = op.daten(BearbeitetPayload.self) else { return }
            byID[p.id]?.text = p.text
            byID[p.id]?.bearbeitet = true
        case "nachricht.geloescht":
            guard let p = op.daten(IDPayload.self) else { return }
            byID[p.id]?.geloescht = true
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
        return nachrichten.filter { $0.von != ich && !$0.geloescht && $0.zeit > grenze }.count
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
}

private struct BearbeitetPayload: Codable { let id: String; let text: String }
private struct IDPayload: Codable { let id: String }
private struct ReaktionPayload: Codable { let id: String; let emoji: String? }
private struct GelesenPayload: Codable { let bis: String }
private struct AngeheftetPayload: Codable { let id: String; let bis: String? }
private struct SternPayload: Codable { let id: String; let an: Bool }
