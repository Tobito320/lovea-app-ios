import Foundation
import Observation

/// Was jemand an einem Gerät eingestellt hat. Leere Felder = nicht gesetzt.
struct EinstellWerte: Codable, Equatable, Sendable {
    var bankstufe: Int? = nil
    var sitzhoehe: Int? = nil
    var polster: Int? = nil
    var notiz = ""

    var istLeer: Bool { bankstufe == nil && sitzhoehe == nil && polster == nil && notiz.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// Einstellungen je (Person, Studio, Übung), nur auf diesem Gerät (`UserDefaults`, kein Sync).
@MainActor @Observable
final class EinstellGedaechtnis {
    static let shared = EinstellGedaechtnis()

    private static let schluessel = "lovea.gym.einstellungen"
    @ObservationIgnored private let defaults: UserDefaults
    private var tabelle: [String: EinstellWerte]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        tabelle = defaults.data(forKey: Self.schluessel).flatMap { try? JSONDecoder().decode([String: EinstellWerte].self, from: $0) } ?? [:]
    }

    /// Katalog-ID, bei eigenen Übungen der Name.
    static func uebungsSchluessel(_ u: PlanUebung) -> String { u.uebung == PlanUebung.eigen ? u.anzeigeName : u.uebung }

    private static func key(_ person: Person, _ studio: GymStudio, _ uebung: String) -> String {
        "\(person.rawValue)|\(studio.rawValue)|\(uebung)"
    }

    func werte(_ person: Person, _ studio: GymStudio, uebung: String) -> EinstellWerte? {
        tabelle[Self.key(person, studio, uebung)]
    }

    /// Überschreibt; leere Werte löschen den Eintrag.
    func setzen(_ werte: EinstellWerte, _ person: Person, _ studio: GymStudio, uebung: String) {
        let k = Self.key(person, studio, uebung)
        if werte.istLeer { tabelle[k] = nil } else { tabelle[k] = werte }
        if let daten = try? JSONEncoder().encode(tabelle) { defaults.set(daten, forKey: Self.schluessel) }
    }
}
