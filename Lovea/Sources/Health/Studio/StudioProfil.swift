import Foundation
import Observation

/// Studio und Trainings-Slot einer Person. `slotStart` in Minuten seit Mitternacht, nil = keine feste Uhrzeit.
struct StudioProfil: Codable, Equatable, Sendable {
    var studio: GymStudio
    var slotStart: Int?
    var dauer: Int

    /// Ahmed: FitX Hagen-Mitte, Slot 05:00, 45 min. Annika: Absolut Fit, ohne feste Uhrzeit.
    static func standard(_ person: Person) -> StudioProfil {
        StudioProfil(studio: .standard(person), slotStart: person == .ahmed ? 5 * 60 : nil, dauer: 45)
    }
}

extension GymStudio {
    /// Schlüssel für Dinge, die am Studio hängen (Defekt-Notizen, Punkt 4).
    var notizSchluessel: String { "studio.\(rawValue)" }
}

/// Studio-Profil je Person, nur auf diesem Gerät (`UserDefaults`, kein Sync).
@MainActor @Observable
final class StudioGedaechtnis {
    static let shared = StudioGedaechtnis()

    private static let schluessel = "lovea.gym.studioprofil"
    @ObservationIgnored private let defaults: UserDefaults
    private var tabelle: [String: StudioProfil]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        tabelle = defaults.data(forKey: Self.schluessel).flatMap { try? JSONDecoder().decode([String: StudioProfil].self, from: $0) } ?? [:]
    }

    func profil(_ person: Person) -> StudioProfil { tabelle[person.rawValue] ?? .standard(person) }

    func studio(_ person: Person) -> GymStudio { profil(person).studio }

    func setzen(_ profil: StudioProfil, _ person: Person) {
        tabelle[person.rawValue] = profil
        if let daten = try? JSONEncoder().encode(tabelle) { defaults.set(daten, forKey: Self.schluessel) }
    }
}
