import Foundation

/// Das Zimmer pflegt sich selbst: Bett, Schuhe und Pokale folgen den Daten, das Kleiderstangen-Verlauf
/// merkt sich die zuletzt getragenen Outfits. Alles reine Werte, nichts liest ein Modell.
enum ZimmerZustandLogik {
    // MARK: Bett

    /// Gemacht, wenn die letzte Nacht mindestens 75 % des Schlafziels hatte. Ohne Daten bleibt es gemacht.
    static func bettGemacht(schlafMinuten: Int?, ziel: Int) -> Bool {
        guard let schlafMinuten else { return true }
        return schlafMinuten * 4 >= ziel * 3
    }

    // MARK: Schuhe

    /// Die Sneaker stehen im Regal, sobald das Schrittziel von heute erreicht ist.
    static func schuheDa(schritte: Int?, ziel: Int) -> Bool {
        guard let schritte, ziel > 0 else { return false }
        return schritte >= ziel
    }

    // MARK: Pokale

    /// Punkte, ab denen der Pokal der Stufe im Regal steht.
    static func schwelle(_ stufe: ZimmerPokal.Stufe) -> Int {
        switch stufe {
        case .bronze: 500
        case .silber: 2_000
        case .gold: 5_000
        }
    }

    /// Alle Stufen, die `punkte` erreicht haben, die höchste zuerst.
    static func pokale(punkte: Int) -> [ZimmerPokal.Stufe] {
        [ZimmerPokal.Stufe.gold, .silber, .bronze].filter { punkte >= schwelle($0) }
    }

    /// Die Pokale aus Spielsiegen und aus Punkten zusammen, die höchste Stufe zuerst, höchstens `maximal`.
    static func pokale(spiel: [ZimmerPokal.Stufe], punkte: Int, maximal: Int = 3) -> [ZimmerPokal.Stufe] {
        Array((spiel + pokale(punkte: punkte)).sorted { $0.rawValue > $1.rawValue }.prefix(maximal))
    }

    // MARK: Getragene Outfits

    static let verlaufMax = 5

    /// Gleiche Kleidung: Oberteil, Jacke, Hose, Schuhe samt Farben, Kopfbedeckung, Brille, Schmuck.
    static func gleicheKleidung(_ a: FigurAussehen, _ b: FigurAussehen) -> Bool {
        a.mitKleidung(von: b) == a
    }

    /// `neu` kommt als Neuestes nach vorn; eine gleiche Kleidung aus dem Verlauf rutscht nach vorn
    /// statt doppelt zu hängen; höchstens `verlaufMax` bleiben.
    static func verlauf(_ alt: [FigurAussehen], neu: FigurAussehen) -> [FigurAussehen] {
        Array(([neu] + alt.filter { !gleicheKleidung($0, neu) }).prefix(verlaufMax))
    }

    /// Gekaufte Kleidung, die noch nicht ausgepackt wurde: kommt als Paket auf den Boden. Feste Reihenfolge.
    static func neuePakete(besitz: Set<String>, gesehen: Set<String>) -> [String] {
        besitz.subtracting(gesehen).sorted()
    }
}
