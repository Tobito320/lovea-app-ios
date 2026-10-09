import Foundation
import Observation

/// Speichert die Mahlzeiten und Ziele nur auf dem Gerät (Gesundheitsdaten gehören nicht auf den
/// Server). Eine Datei für beide Personen, damit "Person wechseln" nichts vermischt.
@MainActor
@Observable
final class EssenStore {
    static let shared = EssenStore()

    private(set) var mahlzeiten: [String: [EssenMahlzeit]] = [:]
    /// Wird bei jeder Ziel-Änderung erhöht, damit SwiftUI neu zeichnet (UserDefaults meldet nichts).
    private(set) var zielVersion = 0

    private let datei: URL
    private let zielPrefix: String

    init(datei: URL = EssenStore.standardDatei(), zielPrefix: String = "lovea.essen.ziele.") {
        self.datei = datei
        self.zielPrefix = zielPrefix
        laden()
    }

    nonisolated static func standardDatei() -> URL {
        let basis = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return basis.appendingPathComponent("lovea-essen.json")
    }

    // MARK: - Lesen

    func liste(_ person: Person, tag: String) -> [EssenMahlzeit] {
        (mahlzeiten[person.rawValue] ?? []).filter { $0.tag == tag }.sorted { $0.zeit < $1.zeit }
    }

    func summe(_ person: Person, tag: String) -> EssenSumme {
        liste(person, tag: tag).reduce(into: EssenSumme()) { summe, m in
            summe.kcal += m.kcal
            summe.protein += m.protein
            summe.kohlenhydrate += m.kohlenhydrate
            summe.fett += m.fett
        }
    }

    func ziele(_ person: Person) -> EssenZiele {
        _ = zielVersion
        guard let daten = UserDefaults.standard.data(forKey: zielPrefix + person.rawValue),
              let ziele = try? JSONDecoder().decode(EssenZiele.self, from: daten)
        else { return EssenZiele() }
        return ziele
    }

    // MARK: - Schreiben

    func speichern(_ mahlzeit: EssenMahlzeit, fuer person: Person) {
        var liste = mahlzeiten[person.rawValue] ?? []
        if let i = liste.firstIndex(where: { $0.id == mahlzeit.id }) {
            liste[i] = mahlzeit
        } else {
            liste.append(mahlzeit)
        }
        mahlzeiten[person.rawValue] = liste
        sichern()
    }

    func loeschen(_ id: UUID, fuer person: Person) {
        mahlzeiten[person.rawValue]?.removeAll { $0.id == id }
        sichern()
    }

    func setzeZiele(_ neu: EssenZiele, fuer person: Person) {
        var ziele = neu
        ziele.kcal = max(ziele.kcal, EssenZiele.mindestKcal)
        ziele.protein = max(ziele.protein, 0)
        if let daten = try? JSONEncoder().encode(ziele) {
            UserDefaults.standard.set(daten, forKey: zielPrefix + person.rawValue)
        }
        zielVersion += 1
    }

    // MARK: - Datei

    private func laden() {
        guard let daten = try? Data(contentsOf: datei),
              let geladen = try? JSONDecoder().decode([String: [EssenMahlzeit]].self, from: daten)
        else { return }
        mahlzeiten = geladen
    }

    private func sichern() {
        guard let daten = try? JSONEncoder().encode(mahlzeiten) else { return }
        try? FileManager.default.createDirectory(at: datei.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? daten.write(to: datei, options: [.atomic, .completeFileProtection])
    }
}
