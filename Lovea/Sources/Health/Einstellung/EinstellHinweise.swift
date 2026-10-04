import Foundation

/// Welches Studio: nur Typ und Standard je Person, kein Umschalter (kommt mit dem Profil).
enum GymStudio: String, Codable, CaseIterable, Sendable {
    case fitxHagenMitte, absolutFit

    var name: String {
        switch self {
        case .fitxHagenMitte: "FitX Hagen Mitte"
        case .absolutFit: "Absolut Fit"
        }
    }

    static func standard(_ person: Person) -> GymStudio { person == .ahmed ? .fitxHagenMitte : .absolutFit }
}

struct StudioTipp: Codable, Equatable, Sendable {
    let studio: GymStudio
    let text: String
    let unsicher: Bool
}

/// Eigene, kuratierte Kurz-Anleitung zu einer Geräteübung (`hinweise.json`). `unsicher` = ohne
/// Beleg, die App sagt dann "selbst prüfen".
struct EinstellHinweis: Codable, Equatable, Sendable {
    /// Alle Wörter müssen im normalisierten Übungsnamen vorkommen (`UebungsKatalog.normal`).
    let muster: [String]
    /// Kommt eines dieser Wörter im Namen vor, passt der Eintrag nicht.
    var ohne: [String]? = nil
    let anleitung: String
    let einstellung: String
    let fehler: String
    let unsicher: Bool
    var studioTipps: [StudioTipp]? = nil

    func tipps(fuer studio: GymStudio) -> [StudioTipp] { (studioTipps ?? []).filter { $0.studio == studio } }
}

enum EinstellHinweise {
    /// `Bundle(for:)` statt `.main`: im XCTest ist `.main` leer.
    static let alle: [EinstellHinweis] = laden(Bundle(for: BundleMarke.self))

    static func laden(_ bundle: Bundle) -> [EinstellHinweis] {
        guard let url = bundle.url(forResource: "hinweise", withExtension: "json")
                ?? bundle.url(forResource: "hinweise", withExtension: "json", subdirectory: "Health/Einstellung"),
              let daten = try? Data(contentsOf: url),
              let liste = try? JSONDecoder().decode([EinstellHinweis].self, from: daten) else { return [] }
        return liste
    }

    /// Erster passender Eintrag; die Reihenfolge in der Datei geht von speziell zu allgemein.
    /// Unbekannte Übung: nil.
    static func finden(name: String, in liste: [EinstellHinweis] = alle) -> EinstellHinweis? {
        let n = UebungsKatalog.normal(name)
        return liste.first { h in
            h.muster.allSatisfy { n.contains(UebungsKatalog.normal($0)) }
                && !(h.ohne ?? []).contains { n.contains(UebungsKatalog.normal($0)) }
        }
    }

    static func finden(_ u: PlanUebung, in liste: [EinstellHinweis] = alle) -> EinstellHinweis? {
        finden(name: u.katalog?.name ?? u.anzeigeName, in: liste)
    }
}

private final class BundleMarke {}
