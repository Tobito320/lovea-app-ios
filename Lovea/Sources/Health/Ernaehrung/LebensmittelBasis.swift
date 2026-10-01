import Foundation

/// Eingebaute Grund-Datenbank (BLS 4.0) aus `lebensmittel-basis.json`, läuft offline.
enum LebensmittelBasis {
    static func laden(_ bundle: Bundle) -> [Lebensmittel] {
        guard let url = bundle.url(forResource: "lebensmittel-basis", withExtension: "json")
                ?? bundle.url(forResource: "lebensmittel-basis", withExtension: "json", subdirectory: "Health/Ernaehrung"),
              let daten = try? Data(contentsOf: url),
              let liste = try? JSONDecoder().decode([Lebensmittel].self, from: daten) else { return [] }
        return liste
    }

    /// Gleiche Regel wie `suchschluessel` in `tools/bls-import/bls_import.py`.
    static func normal(_ text: String) -> String {
        let t = text.lowercased().replacingOccurrences(of: "ß", with: "ss")
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "de_DE"))
        return t.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
    }

    static func schluessel(_ l: Lebensmittel) -> String { l.suche ?? normal(l.name + " " + (l.marke ?? "")) }

    /// Jedes Wort im Suchtext muss als Wortanfang vorkommen. Name beginnt mit dem Suchtext zuerst, dann kürzere Namen.
    static func treffer(_ liste: [Lebensmittel], _ text: String, anzahl: Int = 50) -> [Lebensmittel] {
        let t = normal(text)
        guard !t.isEmpty else { return [] }
        let woerter = t.split(separator: " ")
        var vorn: [Lebensmittel] = [], sonst: [Lebensmittel] = []
        for l in liste {
            let s = schluessel(l)
            guard woerter.allSatisfy({ w in s.hasPrefix(w) || s.contains(" " + w) }) else { continue }
            if s.hasPrefix(t) { vorn.append(l) } else { sonst.append(l) }
        }
        // String.count ist O(n); Länge einmal pro Treffer rechnen statt bei jedem Vergleich.
        func kurzZuerst(_ liste: [Lebensmittel]) -> [Lebensmittel] {
            liste.map { ($0, $0.name.utf8.count) }.sorted { $0.1 < $1.1 }.map(\.0)
        }
        return Array((kurzZuerst(vorn) + kurzZuerst(sonst)).prefix(anzahl))
    }
}

/// BLS-Index im Speicher. Lädt erst, wenn die Ernährung geöffnet wird, und gibt beim Verlassen frei (Akku, Speicher).
final class LebensmittelIndex: @unchecked Sendable {
    static let shared = LebensmittelIndex()
    private let sperre = NSLock()
    private var daten: [Lebensmittel] = []
    private var laedt = false

    init() {}
    init(testDaten: [Lebensmittel]) { daten = testDaten }

    var bereit: Bool { sperre.withLock { !daten.isEmpty } }

    func laden() {
        let starten = sperre.withLock { () -> Bool in
            guard daten.isEmpty, !laedt else { return false }
            laedt = true
            return true
        }
        guard starten else { return }
        Task.detached(priority: .utility) { [weak self] in
            let liste = LebensmittelBasis.laden(.main)
            self?.sperre.withLock { self?.daten = liste; self?.laedt = false }
        }
    }

    func freigeben() { sperre.withLock { daten = [] } }

    /// `vorne` (Verlauf, Favoriten, eigene) zuerst, dann BLS, ohne doppelte IDs, höchstens `anzahl`.
    func suchen(_ text: String, vorne: [Lebensmittel], anzahl: Int = 50) -> [Lebensmittel] {
        let basis = sperre.withLock { daten }
        var gesehen: Set<String> = []
        let a = LebensmittelBasis.treffer(vorne, text, anzahl: anzahl).filter { gesehen.insert($0.id).inserted }
        let b = LebensmittelBasis.treffer(basis, text, anzahl: anzahl).filter { gesehen.insert($0.id).inserted }
        return Array((a + b).prefix(anzahl))
    }
}
