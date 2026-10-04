import Foundation
import Observation

/// "Gerät kaputt / wackelig": eine Notiz je (Person, Studio, Übung). Tage als `yyyy-MM-dd`.
struct DefektNotiz: Codable, Equatable, Sendable {
    var text: String? = nil
    var gemeldetAm: String
    /// "Wieder in Ordnung": gesetzt = erledigt, die Notiz zeigt sich nicht mehr.
    var erledigtAm: String? = nil

    var istOffen: Bool { erledigtAm == nil }
}

enum DefektLogik {
    /// Ab so vielen Tagen fragt die Karte "Noch defekt?".
    static let veraltetNachTagen = 30

    static func alter(_ notiz: DefektNotiz, heute: String) -> Int {
        max(0, Datum.tageZwischen(notiz.gemeldetAm, heute))
    }

    static func veraltet(_ notiz: DefektNotiz, heute: String) -> Bool {
        alter(notiz, heute: heute) > veraltetNachTagen
    }

    /// "heute", "gestern", "vor 3 Tagen".
    static func alterText(_ notiz: DefektNotiz, heute: String) -> String {
        switch alter(notiz, heute: heute) {
        case 0: "heute"
        case 1: "gestern"
        case let n: "vor \(n) Tagen"
        }
    }

    /// Die Ausweich-Übung aus Punkt 2 (`AusweichLogik`), die als Erste vorgeschlagen wird. Nach einem
    /// Tausch rechnet die Logik von der ursprünglichen Übung aus, nicht von der aktuellen.
    static func vorschlag(fuer u: WorkoutUebung) -> Uebung? {
        guard let aktuell = u.planUebung.katalog else { return nil }
        let vorlage = u.ersatzFuer.flatMap { UebungsKatalog.nachId[$0] } ?? aktuell
        return AusweichLogik.alternativen(fuer: vorlage).first { $0.id != aktuell.id }
    }
}

/// Defekt-Notizen, nur auf diesem Gerät (`UserDefaults`). Kein Sync: die Notiz hängt am Studio und
/// betrifft nur den Besuch dort, die Partnerin trainiert woanders.
@MainActor @Observable
final class DefektNotizen {
    static let shared = DefektNotizen()

    private static let schluessel = "lovea.gym.defekt"
    @ObservationIgnored private let defaults: UserDefaults
    private var tabelle: [String: DefektNotiz]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        tabelle = defaults.data(forKey: Self.schluessel).flatMap { try? JSONDecoder().decode([String: DefektNotiz].self, from: $0) } ?? [:]
    }

    private static func key(_ person: Person, _ studio: GymStudio, _ uebung: String) -> String {
        "\(person.rawValue)|\(studio.notizSchluessel)|\(uebung)"
    }

    /// Nur die offene Notiz; erledigte zählen nicht.
    func offen(_ person: Person, _ studio: GymStudio, uebung: String) -> DefektNotiz? {
        tabelle[Self.key(person, studio, uebung)].flatMap { $0.istOffen ? $0 : nil }
    }

    /// Meldet neu; eine frühere Notiz (auch eine erledigte) wird überschrieben. Leerer Text = ohne Text.
    func melden(text: String, _ person: Person, _ studio: GymStudio, uebung: String, am tag: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        sichern(DefektNotiz(text: t.isEmpty ? nil : t, gemeldetAm: tag), person, studio, uebung)
    }

    func erledigen(_ person: Person, _ studio: GymStudio, uebung: String, am tag: String) {
        guard var n = tabelle[Self.key(person, studio, uebung)] else { return }
        n.erledigtAm = tag
        sichern(n, person, studio, uebung)
    }

    /// "Noch defekt?" mit Ja: das Datum rückt auf heute.
    func bestaetigen(_ person: Person, _ studio: GymStudio, uebung: String, am tag: String) {
        guard var n = tabelle[Self.key(person, studio, uebung)], n.istOffen else { return }
        n.gemeldetAm = tag
        sichern(n, person, studio, uebung)
    }

    func loeschen(_ person: Person, _ studio: GymStudio, uebung: String) {
        tabelle[Self.key(person, studio, uebung)] = nil
        speichern()
    }

    private func sichern(_ n: DefektNotiz, _ person: Person, _ studio: GymStudio, _ uebung: String) {
        tabelle[Self.key(person, studio, uebung)] = n
        speichern()
    }

    private func speichern() {
        if let daten = try? JSONEncoder().encode(tabelle) { defaults.set(daten, forKey: Self.schluessel) }
    }
}
