import Foundation

/// Schalter „Schneller Start (Test)" (Einstellungen, Standard an). Entscheidet, wann Start-Arbeit
/// laufen darf, die erst nach dem ersten Bild gebraucht wird (Galerie-Sync-Bibliothek, Widget-Stand).
/// Aus: alles sofort, wie vorher. Der Absturz-Schutz (`StartProtokoll`, `AbsturzFaenger`) und
/// `StartPuls` hängen nie daran.
enum StartPlan {
    static let schluessel = "lovea.schnellerStart"

    enum Zeitpunkt: Equatable {
        case sofort
        case nachErstemBild
    }

    static func an(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: schluessel) as? Bool ?? true
    }

    /// `hintergrundStart`: der Prozess startete ohne Szene (HealthKit, Silent-Push). Dort kommt kein
    /// erstes Bild, also sofort arbeiten, sonst bliebe etwa das Widget ohne Update.
    static func zeitpunkt(schneller: Bool, hintergrundStart: Bool) -> Zeitpunkt {
        schneller && !hintergrundStart ? .nachErstemBild : .sofort
    }
}
