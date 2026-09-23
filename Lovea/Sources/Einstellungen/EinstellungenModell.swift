import Foundation
import Observation

/// Faltet `einstellung.setzen` (schnittstellen.md: pro `von` z. B. `flamme`, `hintergrund`,
/// `mitteilungen.<kategorie>`, `duellWoerter`) pro Person. Jede Person sendet nur ihre eigenen
/// Werte, aber beide Seiten lesen mit — Block 14 (Duell) braucht z. B. die eigenen Wörter des
/// Partners, deshalb `[Person: [String: JSONValue]]` statt nur "meine Werte".
@MainActor @Observable
final class EinstellungenModell {
    static let shared = EinstellungenModell()

    private(set) var werte: [Person: [String: JSONValue]] = [:]
    private var angewendet: Set<String> = []

    private init() {
        Raum.shared.beobachten(["einstellung.setzen"]) { [weak self] op in
            guard let self, self.angewendet.insert(op.id).inserted, let d = op.daten(EinstellungD.self) else { return }
            self.werte[op.von, default: [:]][d.schluessel] = d.wert
        }
        geburtstagsNachrichtFallsNoetig()
    }

    func setzen(_ schluessel: String, _ wert: JSONValue) {
        Raum.shared.senden("einstellung.setzen", EinstellungD(schluessel: schluessel, wert: wert))
    }

    private func wert(_ schluessel: String, von: Person?) -> JSONValue? {
        werte[von ?? Raum.shared.ich ?? .ahmed]?[schluessel]
    }

    func bool(_ schluessel: String, default def: Bool, von: Person? = nil) -> Bool {
        if case .bool(let v) = wert(schluessel, von: von) { return v }
        return def
    }

    func string(_ schluessel: String, default def: String, von: Person? = nil) -> String {
        if case .string(let v) = wert(schluessel, von: von) { return v }
        return def
    }

    func stringListe(_ schluessel: String, von: Person? = nil) -> [String] {
        guard case .array(let arr) = wert(schluessel, von: von) else { return [] }
        return arr.compactMap { if case .string(let s) = $0 { s } else { nil } }
    }

    // MARK: - Z-15.3 (Zusatz): Morgen-Systemnachricht bei Geburtstag

    /// Beim ersten Öffnen des Tages: Ist heute Ahmeds oder Annikas Geburtstag, kommt einmalig eine
    /// System-Nachricht in den Chat. Feste `id` pro Tag+Person macht doppeltes Senden (beide
    /// Geräte prüfen das) harmlos — `ChatModell` faltet über genau diese `id` (Z-4.1).
    private func geburtstagsNachrichtFallsNoetig() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await Raum.shared.leer()
            let heuteStr = Datum.text(Date())
            let schluessel = "einstellungen.letzterGeburtstagsCheck"
            guard UserDefaults.standard.string(forKey: schluessel) != heuteStr else { return }
            UserDefaults.standard.set(heuteStr, forKey: schluessel)
            let heute = Calendar.berlin.dateComponents([.month, .day], from: Date())
            for person in Person.allCases {
                let geburtstag = person == .ahmed ? (monat: 2, tag: 27) : (monat: 6, tag: 6)
                guard heute.month == geburtstag.monat, heute.day == geburtstag.tag else { continue }
                Raum.shared.senden("nachricht.neu", [
                    "id": "geburtstag-\(heuteStr)-\(person.rawValue)",
                    "system": "Heute hat \(person.name) Geburtstag",
                ])
            }
        }
    }
}

private struct EinstellungD: Codable { var schluessel: String; var wert: JSONValue }
