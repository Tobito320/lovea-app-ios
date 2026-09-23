import Foundation
import Observation

/// One player's full contribution to the running round (`partie`), sent as `fl spiel.zug`.
/// Always a complete snapshot, never a delta, and re-sent every 2 s while the game is open:
/// `fl` is not stored and not echoed, so a lost packet or a late partner heals on the next send.
struct Zug: Codable, Sendable, Equatable {
    var id: String
    var partie = 0
    var zuege: [Int] = []           // XO cells, SSP hands, Memory flips, Duell word picks, Kennen answers, Reaktion ms
    var texte: [String]?            // Memory motifs, chosen by the inviter
    var fragen: [KennenFrage]?      // Kennen questions, chosen by the one asked
    var raus: Bool?                 // left the game
}

struct OffenesSpiel: Identifiable, Equatable { let id: String }

/// Folds every `spiel.*` op, the chat messages that carry a game, and the own Duell words.
/// Live moves (`fl spiel.zug`) are kept here too, so exactly one observer exists for them.
@MainActor
@Observable
final class SpieleModell {
    static let shared = SpieleModell()

    struct Einstellungen: Codable, Sendable, Equatable {
        var runden: Int?
        var dauer: Int?
        var vibes: [String]?
    }

    struct Ergebnis: Codable, Sendable, Equatable {
        var gespielt: Int
        var punkte: SpielPunkte
    }

    struct Spiel: Identifiable, Sendable {
        let id: String
        let art: SpielArt
        let von: Person
        let zeit: Date
        var einstellungen: Einstellungen
        var bis: Date?
        var angenommen = false
        var verfallen = false
        var nachrichtId: String?
        var bilder: [Int: [Person: String]] = [:]      // runde → person → medienId
        var stimmen: [Int: [Person: Person]] = [:]     // runde → voter → voted for
        var ergebnis: Ergebnis?

        func wartet(jetzt: Date = Date()) -> Bool {
            !angenommen && !verfallen && (bis.map { $0 > jetzt } ?? true)
        }

        func sichtbar(jetzt: Date = Date()) -> Bool { angenommen || wartet(jetzt: jetzt) }
    }

    private(set) var spiele: [String: Spiel] = [:]
    private(set) var eigeneWoerter: [Person: [String]] = [:]
    /// Latest snapshot per game and person (mine when I send, the partner's when it arrives).
    private(set) var zuege: [String: [Person: Zug]] = [:]
    private(set) var partnerGesehen: [String: Date] = [:]
    /// The game shown full screen by `.spieleBuehne()`.
    var offen: OffenesSpiel?

    private var gemeldet: Set<String> = []
    private let registriert: Bool

    static let arten: Set<String> = [
        "spiel.einladung", "spiel.angenommen", "spiel.verfallen", "spiel.bild", "spiel.stimme",
        "spiel.ergebnis", "nachricht.neu", "einstellung.setzen",
    ]

    init(registrieren: Bool = true) {
        registriert = registrieren
        guard registrieren else { return }
        Raum.shared.beobachten(Self.arten) { [weak self] op in self?.anwenden(op) }
        Raum.shared.fluechtigBeobachten("spiel.zug") { [weak self] person, daten in
            guard let zug = try? JSONDecoder().decode(Zug.self, from: daten) else { return }
            self?.zugAnwenden(zug, von: person)
        }
    }

    // MARK: - Fold

    /// Idempotent: every case either sets a value or takes a maximum, so the optimistic copy and
    /// the server echo of the same op land on the same state.
    func anwenden(_ op: Op) {
        switch op.art {
        case "spiel.einladung":
            guard let d = op.daten(SpielEinladungD.self), let art = SpielArt(rawValue: d.art), spiele[d.id] == nil else { return }
            spiele[d.id] = Spiel(id: d.id, art: art, von: op.von, zeit: op.zeit, einstellungen: d.einstellungen ?? Einstellungen(), bis: d.bis.flatMap(Self.datum))
        case "spiel.angenommen":
            guard let d = op.daten(SpielIdD.self), let spiel = spiele[d.id] else { return }
            spiele[d.id]?.angenommen = true
            // Only a fresh acceptance opens the game for the inviter; replayed history never does.
            if registriert, op.von != Raum.shared.ich, spiel.von == Raum.shared.ich, Date().timeIntervalSince(op.zeit) < 30 {
                offen = OffenesSpiel(id: d.id)
            }
        case "spiel.verfallen":
            guard let d = op.daten(SpielIdD.self) else { return }
            spiele[d.id]?.verfallen = true
        case "spiel.bild":
            guard let d = op.daten(SpielBildD.self) else { return }
            spiele[d.id]?.bilder[d.runde, default: [:]][op.von] = d.medienId
        case "spiel.stimme":
            guard let d = op.daten(SpielStimmeD.self) else { return }
            spiele[d.id]?.stimmen[d.runde, default: [:]][op.von] = d.fuer
        case "spiel.ergebnis":
            guard let d = op.daten(SpielErgebnisD.self), spiele[d.id] != nil else { return }
            if (spiele[d.id]?.ergebnis?.gespielt ?? -1) < d.gespielt {
                spiele[d.id]?.ergebnis = Ergebnis(gespielt: d.gespielt, punkte: d.punkte)
            }
        case "nachricht.neu":
            guard let d = op.daten(SpielNachrichtD.self), let spielId = d.spiel?.id else { return }
            spiele[spielId]?.nachrichtId = d.id
        case "einstellung.setzen":
            guard let d = op.daten(SpielWoerterD.self), d.schluessel == Self.woerterSchluessel else { return }
            eigeneWoerter[op.von] = d.wert ?? []
        default:
            break
        }
    }

    func zugAnwenden(_ zug: Zug, von person: Person) {
        if registriert, person != Raum.shared.ich { partnerGesehen[zug.id] = Date() }
        if let alt = zuege[zug.id]?[person], alt.partie > zug.partie { return }
        zuege[zug.id, default: [:]][person] = zug
    }

    // MARK: - Derived

    func sichtbar(_ spielId: String) -> Bool { spiele[spielId]?.sichtbar() ?? true }

    /// Tally per game type for the profile ("Bilanz").
    var bilanz: [SpielArt: SpielPunkte] {
        var b: [SpielArt: SpielPunkte] = [:]
        for s in spiele.values { if let e = s.ergebnis { b[s.art, default: SpielPunkte()] = b[s.art, default: SpielPunkte()] + e.punkte } }
        return b
    }

    var gespielt: [SpielArt: Int] {
        var g: [SpielArt: Int] = [:]
        for s in spiele.values { if let e = s.ergebnis { g[s.art, default: 0] += e.gespielt } }
        return g
    }

    /// Everyone's own Duell words and insiders, merged.
    var alleEigenenWoerter: [String] {
        var gesehen = Set<String>()
        return (eigeneWoerter[.ahmed, default: []] + eigeneWoerter[.annika, default: []]).filter { gesehen.insert($0).inserted }
    }

    func partie(_ spielId: String) -> Int {
        (zuege[spielId]?.values.map(\.partie).max()) ?? 0
    }

    func zug(_ spielId: String, _ person: Person) -> Zug? { zuege[spielId]?[person] }

    // MARK: - Sending

    @discardableResult
    func einladen(_ art: SpielArt, einstellungen: Einstellungen = Einstellungen()) -> String {
        let id = UUID().uuidString
        // Invitation first, then the chat card that points at it.
        Raum.shared.senden("spiel.einladung", SpielEinladungD(id: id, art: art.rawValue, einstellungen: einstellungen, bis: Self.datumString(Date().addingTimeInterval(120))))
        Raum.shared.senden("nachricht.neu", SpielNachrichtD(id: UUID().uuidString, spiel: ChatModell.SpielInfo(id: id)))
        return id
    }

    func annehmen(_ spielId: String) {
        Raum.shared.senden("spiel.angenommen", SpielIdD(id: spielId))
        offen = OffenesSpiel(id: spielId)
    }

    func bildSenden(_ spielId: String, runde: Int, medienId: String) {
        Raum.shared.senden("spiel.bild", SpielBildD(id: spielId, runde: runde, medienId: medienId))
    }

    func stimmeSenden(_ spielId: String, runde: Int, fuer: Person) {
        Raum.shared.senden("spiel.stimme", SpielStimmeD(id: spielId, runde: runde, fuer: fuer))
    }

    /// Adds one finished round to the game's tally, once. Both devices call this with the same
    /// result; whoever is second sees `gespielt` already past this round and stays quiet.
    func partieBeendet(_ spielId: String, partie: Int, punkte: SpielPunkte) {
        guard gemeldet.insert("\(spielId)#\(partie)").inserted else { return }
        let basis = spiele[spielId]?.ergebnis ?? Ergebnis(gespielt: 0, punkte: SpielPunkte())
        guard basis.gespielt <= partie else { return }
        Raum.shared.senden("spiel.ergebnis", SpielErgebnisD(id: spielId, gespielt: partie + 1, punkte: basis.punkte + punkte))
    }

    static let woerterSchluessel = "duellWoerter"

    func eigeneWoerterSetzen(_ woerter: [String]) {
        Raum.shared.senden("einstellung.setzen", SpielWoerterD(schluessel: Self.woerterSchluessel, wert: woerter))
    }

    /// Changes my snapshot for the current round and sends it right away.
    func ziehen(_ spielId: String, _ aendern: (inout Zug) -> Void) {
        guard let ich = Raum.shared.ich else { return }
        let aktuell = partie(spielId)
        // ponytail: live snapshots live in memory only. After an app restart a reopened game
        // continues at partie = gespielt instead of replaying round 0 (same seed, result dropped).
        let boden = max(aktuell, spiele[spielId]?.ergebnis?.gespielt ?? 0)
        var z = zug(spielId, ich) ?? Zug(id: spielId, partie: boden)
        if z.partie < aktuell { z = Zug(id: spielId, partie: aktuell) }
        aendern(&z)
        zuege[spielId, default: [:]][ich] = z
        Raum.shared.fluechtig("spiel.zug", z)
    }

    func nochmal(_ spielId: String) {
        let naechste = partie(spielId) + 1
        ziehen(spielId) { $0 = Zug(id: spielId, partie: naechste) }
    }

    func verlassen(_ spielId: String) {
        ziehen(spielId) { $0.raus = true }
        offen = nil
    }

    /// Called every 2 s by the open game: resend my snapshot (or announce myself).
    func erneutSenden(_ spielId: String) {
        // After "Fertig" the sheet still animates out; a tick then must not clear `raus`.
        guard offen?.id == spielId, let ich = Raum.shared.ich else { return }
        if let z = zug(spielId, ich), z.partie >= partie(spielId) {
            var z = z
            z.raus = nil
            zuege[spielId, default: [:]][ich] = z
            Raum.shared.fluechtig("spiel.zug", z)
        } else {
            ziehen(spielId) { _ in }
        }
    }

    // MARK: - ISO dates (the server runs `Date.parse` on `bis`)

    private static func isoFormatierer(fraktional: Bool) -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = fraktional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return f
    }

    static func datumString(_ datum: Date) -> String { isoFormatierer(fraktional: true).string(from: datum) }

    static func datum(_ text: String) -> Date? {
        isoFormatierer(fraktional: true).date(from: text) ?? isoFormatierer(fraktional: false).date(from: text)
    }
}

// MARK: - Wire payloads (schnittstellen.md field names, verbatim)

struct SpielEinladungD: Codable { var id: String; var art: String; var einstellungen: SpieleModell.Einstellungen?; var bis: String? }
private struct SpielIdD: Codable { var id: String }
struct SpielBildD: Codable { var id: String; var runde: Int; var medienId: String }
struct SpielStimmeD: Codable { var id: String; var runde: Int; var fuer: Person }
struct SpielErgebnisD: Codable { var id: String; var gespielt: Int; var punkte: SpielPunkte }
private struct SpielNachrichtD: Codable { var id: String; var spiel: ChatModell.SpielInfo? }
private struct SpielWoerterD: Codable { var schluessel: String; var wert: [String]? }
