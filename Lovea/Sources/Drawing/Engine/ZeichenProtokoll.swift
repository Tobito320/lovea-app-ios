import Foundation
import os

/// Q-R10: Ahmed testet nur über TestFlight (Release), wo `#if DEBUG`-Logs nie laufen. Dieser Ring-
/// Puffer hält die letzten paar SELTENEN, verdächtigen Zeichen-Ereignisse (nicht pro Frame, nicht pro
/// Strich) im Speicher und in UserDefaults, damit Ahmed sie über die Leistungsanzeige kopieren und uns
/// schicken kann, wenn ein Strich wieder verschwindet. os.Logger bleibt zusätzlich bestehen (sichtbar
/// über Console.app an einem angeschlossenen Gerät), ist aber für Ahmed selbst nicht erreichbar.
let strokeLogger = Logger(subsystem: "app.lovea.drawing", category: "stroke")

@MainActor
enum ZeichenProtokoll {
    struct Eintrag: Codable {
        let zeit: Date
        let text: String
    }

    private static let key = "zeichnen.protokoll.v1"
    private static let limit = 50
    private(set) static var eintraege: [Eintrag] = load()

    /// Nur für die seltenen Warn-Ereignisse rufen, nie pro Frame oder pro Stempel – der Puffer wird bei
    /// jedem Eintrag auf UserDefaults geschrieben, das ist bei ein paar Einträgen pro Sitzung egal, bei
    /// hundert pro Sekunde nicht.
    static func log(_ text: String) {
        strokeLogger.warning("\(text, privacy: .public)")
        eintraege.append(Eintrag(zeit: Date(), text: text))
        if eintraege.count > limit { eintraege.removeFirst(eintraege.count - limit) }
        save()
    }

    static func clear() {
        eintraege = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Text für den "Kopieren"-Knopf in der Leistungsanzeige.
    static func copyText() -> String {
        guard !eintraege.isEmpty else { return "Zeichen-Protokoll ist leer." }
        return eintraege.map { "\(formatter.string(from: $0.zeit)) \($0.text)" }.joined(separator: "\n")
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM. HH:mm:ss"
        return f
    }()

    private static func load() -> [Eintrag] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Eintrag].self, from: data) else { return [] }
        return decoded
    }

    private static func save() {
        guard let data = try? JSONEncoder().encode(eintraege) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
