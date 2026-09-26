import Foundation

/// Eingebaute Grund-Datenbank frischer Lebensmittel mit Portionsgrößen (wie YAZIO), aus
/// `lebensmittel-basis.json`. Läuft komplett offline, ohne Open Food Facts.
enum LebensmittelBasis {
    static let alle: [Lebensmittel] = laden(.main)

    static func laden(_ bundle: Bundle) -> [Lebensmittel] {
        guard let url = bundle.url(forResource: "lebensmittel-basis", withExtension: "json")
                ?? bundle.url(forResource: "lebensmittel-basis", withExtension: "json", subdirectory: "Health/Ernaehrung"),
              let daten = try? Data(contentsOf: url),
              let liste = try? JSONDecoder().decode([Lebensmittel].self, from: daten) else { return [] }
        return liste
    }

    /// Treffer ab 2 Zeichen, Wortanfang im Namen zählt (ohne Groß/Klein, ohne Umlaute).
    static func suchen(_ text: String, anzahl: Int = 20) -> [Lebensmittel] {
        treffer(alle, text, anzahl: anzahl)
    }

    static func normal(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    /// Jedes Wort im Suchtext muss als Wortanfang irgendwo im Namen vorkommen. Treffer, deren Name
    /// selbst mit dem Suchtext beginnt, kommen zuerst.
    static func treffer(_ liste: [Lebensmittel], _ text: String, anzahl: Int = 20) -> [Lebensmittel] {
        let t = normal(text.trimmingCharacters(in: .whitespaces))
        guard t.count >= 2 else { return [] }
        let woerter = t.split(separator: " ").map(String.init)
        let gefunden = liste.filter { l in
            let namensWoerter = normal(l.name).split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            return woerter.allSatisfy { wort in namensWoerter.contains { $0.hasPrefix(wort) } }
        }
        let sortiert = gefunden.sorted { a, b in
            let vornA = normal(a.name).hasPrefix(t), vornB = normal(b.name).hasPrefix(t)
            if vornA != vornB { return vornA }
            if a.name.count != b.name.count { return a.name.count < b.name.count }
            return a.name < b.name
        }
        return Array(sortiert.prefix(anzahl))
    }
}
