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

    /// Gleiche Regel wie `suchschluessel` in `tools/bls-import/bls_import.py`: Python behält nach dem
    /// Falten nur `[a-z0-9]+` (ASCII), ein Zeichen ohne NFKD-Zerlegung (z. B. Kyrillisch) fällt dort
    /// komplett weg – deshalb hier zusätzlich `isASCII`, sonst würden Swift und Python unterschiedliche
    /// Schlüssel für exotische Namen bauen.
    static func normal(_ text: String) -> String {
        let t = text.lowercased().replacingOccurrences(of: "ß", with: "ss")
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "de_DE"))
        return t.split(whereSeparator: { !$0.isASCII || !($0.isLetter || $0.isNumber) }).joined(separator: " ")
    }

    static func schluessel(_ l: Lebensmittel) -> String { l.suche ?? normal(l.name + " " + (l.marke ?? "")) }

    /// YAZIO-artige Suche: ein Suchwort trifft ein Namenswort als Präfix ODER als Suffix (deutsche
    /// Komposita hängen das Hauptwort hinten an: "Hühner-ei", "Grieß-brei"). Rang 1: der ganze Name
    /// beginnt mit dem Suchtext. Rang 2: jedes Suchwort trifft mindestens ein Namenswort als Präfix.
    /// Rang 3: mindestens ein Suchwort trifft nur über das Suffix. Innerhalb eines Rangs kürzere Namen
    /// zuerst (Länge einmal pro Treffer berechnet, nicht im Sortier-Vergleich).
    static func treffer(_ liste: [Lebensmittel], _ text: String, anzahl: Int = 50) -> [Lebensmittel] {
        let t = normal(text)
        guard t.count >= 2 else { return [] }
        let woerter = t.split(separator: " ")
        var namensanfang: [Lebensmittel] = [], allePraefix: [Lebensmittel] = [], nurSuffix: [Lebensmittel] = []
        for l in liste {
            let s = schluessel(l)
            let sWoerter = s.split(separator: " ")
            var nurUeberSuffix = false
            var trifftAlle = true
            for w in woerter {
                let praefix = sWoerter.contains { $0.hasPrefix(w) }
                let suffix = sWoerter.contains { $0.hasSuffix(w) }
                guard praefix || suffix else { trifftAlle = false; break }
                if !praefix { nurUeberSuffix = true }
            }
            guard trifftAlle else { continue }
            if s.hasPrefix(t) { namensanfang.append(l) }
            else if !nurUeberSuffix { allePraefix.append(l) }
            else { nurSuffix.append(l) }
        }
        // String.count ist O(n); Länge einmal pro Treffer rechnen statt bei jedem Vergleich.
        func kurzZuerst(_ liste: [Lebensmittel]) -> [Lebensmittel] {
            liste.map { ($0, $0.name.utf8.count) }.sorted { $0.1 < $1.1 }.map(\.0)
        }
        return Array((kurzZuerst(namensanfang) + kurzZuerst(allePraefix) + kurzZuerst(nurSuffix)).prefix(anzahl))
    }
}

/// BLS-Index im Speicher. Lädt erst, wenn die Ernährung geöffnet wird, und gibt beim Verlassen frei (Akku, Speicher).
final class LebensmittelIndex: @unchecked Sendable {
    static let shared = LebensmittelIndex()
    private let sperre = NSLock()
    private var daten: [Lebensmittel] = []
    private var laedt = false
    /// Zählt jedes `freigeben()` mit. Ein Ladevorgang schreibt sein Ergebnis nur, wenn die Generation
    /// seit seinem Start unverändert ist – sonst hat der Nutzer die Ernährung schon wieder verlassen,
    /// und ein verspätetes `laden()` darf die Daten nicht erneut befüllen (Akku/Speicher-Vorgabe).
    private var generation = 0

    init() {}
    init(testDaten: [Lebensmittel]) { daten = testDaten }

    var bereit: Bool { sperre.withLock { !daten.isEmpty } }

    func laden() { laden(lader: { LebensmittelBasis.laden(.main) }, prioritaet: .utility) }

    /// Testbarer Einstieg: `lader` ersetzt den echten Bundle-Zugriff, `prioritaet` die feste
    /// `.utility`-Hintergrundpriorität (Tests geben `.userInitiated`, damit der Task auf einem
    /// überlasteten CI-Simulator zuverlässig startet; `laden()` selbst bleibt bei `.utility`,
    /// das Produktionsverhalten ändert sich nicht). `lader` ist `async`, damit Tests mit
    /// `await`-Signalen genau auf den Start/Abschluss des Ladevorgangs warten können statt mit
    /// Semaphoren einen Thread zu blockieren.
    func laden(lader: @escaping @Sendable () async -> [Lebensmittel], prioritaet: TaskPriority = .utility) {
        let (starten, meineGeneration) = sperre.withLock { () -> (Bool, Int) in
            guard daten.isEmpty, !laedt else { return (false, generation) }
            laedt = true
            return (true, generation)
        }
        guard starten else { return }
        Task.detached(priority: prioritaet) { [weak self] in
            let liste = await lader()
            guard let self else { return }
            self.sperre.withLock {
                // Nur der Ladevorgang der noch gültigen Generation darf `laedt` freigeben – sonst
                // räumt ein verspätetes, bereits verworfenes `laden()` das Flag ab, während ein
                // danach gestartetes (gültiges) `laden()` noch läuft, und ein dritter Aufruf
                // startet fälschlich einen weiteren, parallelen Ladevorgang.
                guard self.generation == meineGeneration else { return }
                self.daten = liste
                self.laedt = false
            }
        }
    }

    func freigeben() { sperre.withLock { daten = []; generation += 1; laedt = false } }

    /// `vorne` (Verlauf, Favoriten, eigene) zuerst, dann BLS, ohne doppelte IDs, höchstens `anzahl`.
    func suchen(_ text: String, vorne: [Lebensmittel], anzahl: Int = 50) -> [Lebensmittel] {
        let basis = sperre.withLock { daten }
        var gesehen: Set<String> = []
        let a = LebensmittelBasis.treffer(vorne, text, anzahl: anzahl).filter { gesehen.insert($0.id).inserted }
        let b = LebensmittelBasis.treffer(basis, text, anzahl: anzahl).filter { gesehen.insert($0.id).inserted }
        return Array((a + b).prefix(anzahl))
    }
}
