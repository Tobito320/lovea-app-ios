import Foundation

// "Wer von uns ist eher?": reine Logik. Beide tippen geheim auf eine Person (Ahmed oder Annika).
// Die Antwort ist absolut kodiert (0 = Ahmed, 1 = Annika), nicht als "ich"/"du": sagt Ahmed "ich"
// und Annika "du", haben beide 0 geantwortet und stimmen überein.

enum Eher {
    static let anzahl = 10

    /// Antwort-Code einer Person.
    static func wahl(_ p: Person) -> Int { p == .ahmed ? 0 : 1 }

    static func person(wahl: Int) -> Person? {
        switch wahl {
        case 0: .ahmed
        case 1: .annika
        default: nil
        }
    }

    // MARK: - Aussagen

    /// `eher-aussagen.json`: ein Array mit Aussagen.
    static func dekodieren(_ daten: Data) -> [String]? {
        try? JSONDecoder().decode([String].self, from: daten)
    }

    static func laden(bundle: Bundle = .main) -> [String] {
        let url = bundle.url(forResource: "eher-aussagen", withExtension: "json")
            ?? bundle.url(forResource: "eher-aussagen", withExtension: "json", subdirectory: "Spiele")
        return url.flatMap { try? Data(contentsOf: $0) }.flatMap(dekodieren) ?? []
    }

    static let pool: [String] = laden()

    /// Die Aussagen einer Runde. Der Pool wird je Spiel einmal gemischt (auf beiden Geräten gleich),
    /// jede Partie nimmt das nächste Stück davon. So wiederholt sich innerhalb einer Runde nichts,
    /// und über Partien hinweg erst, wenn der ganze Pool durch ist.
    static func aussagen(pool: [String], spiel: String, partie: Int) -> [String] {
        var gesehen = Set<String>()
        let eindeutig = pool.filter { gesehen.insert($0).inserted }
        guard !eindeutig.isEmpty else { return [] }
        var z = Zufall(Zufall.seed("\(spiel)#eher"))
        let gemischt = z.gemischt(eindeutig)
        let n = min(anzahl, gemischt.count)
        let start = (max(partie, 0) * anzahl) % gemischt.count
        return (0..<n).map { gemischt[(start + $0) % gemischt.count] }
    }

    // MARK: - Auflösung

    struct Stand: Equatable, Sendable {
        var gleich = 0
        /// Fragen, die beide beantwortet haben (höchstens `anzahl`).
        var fertig = 0
    }

    /// Frage `i` zählt als gleich, wenn beide dieselbe gültige Person gewählt haben.
    static func gleich(_ a: [Int], _ b: [Int], frage i: Int) -> Bool {
        guard a.indices.contains(i), b.indices.contains(i) else { return false }
        return a[i] == b[i] && person(wahl: a[i]) != nil
    }

    static func stand(zuege: [Person: [Int]]) -> Stand {
        let a = zuege[.ahmed] ?? [], b = zuege[.annika] ?? []
        let fertig = min(anzahl, min(a.count, b.count))
        let treffer = (0..<fertig).filter { gleich(a, b, frage: $0) }.count
        return Stand(gleich: treffer, fertig: fertig)
    }

    /// Ende einer Runde. Kein Sieger: `punkte.ahmed` zählt die gleichen, `punkte.annika` die
    /// verschiedenen Antworten (siehe `SpielArt.paarWertung`).
    static func ende(_ s: Stand) -> PartieEnde {
        let titel: String
        switch s.gleich {
        case 8...: titel = "Ihr tickt gleich!"
        case 5...: titel = "Ziemlich im Takt"
        default: titel = "Gegensätze ziehen sich an"
        }
        return PartieEnde(
            punkte: SpielPunkte(ahmed: s.gleich, annika: anzahl - s.gleich),
            sieger: nil,
            text: "\(s.gleich) von \(anzahl) gleich",
            titel: titel
        )
    }
}
