import Foundation

/// Z-19.3 (Spec 8.1 Nr. 6): solange nichts gewürfelt/gewählt ist, zeigt "Unsere Liste" als
/// Vorschlag die häufigste im Kalender eingetragene Idee (`KalenderModell.treffenText`). Reine
/// Funktion ohne `Raum`, testbar ohne Sync-Infrastruktur.
enum UnsereListeVorschlag {
    /// Häufigster Text; bei Gleichstand der zuletzt eingetragene (höchste `zeit`). Leere/nur
    /// Leerzeichen-Texte (Treffen ohne Idee) zählen nicht mit.
    static func haeufigste(_ eintraege: [(text: String, zeit: Date)]) -> String? {
        var anzahl: [String: Int] = [:]
        var letzte: [String: Date] = [:]
        for eintrag in eintraege {
            let text = eintrag.text.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            anzahl[text, default: 0] += 1
            if eintrag.zeit > (letzte[text] ?? .distantPast) { letzte[text] = eintrag.zeit }
        }
        return anzahl.keys.max { a, b in
            anzahl[a]! != anzahl[b]! ? anzahl[a]! < anzahl[b]! : letzte[a]! < letzte[b]!
        }
    }
}
