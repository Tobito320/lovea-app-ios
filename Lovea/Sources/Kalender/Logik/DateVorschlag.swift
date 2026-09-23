import Foundation

enum DateVorschlag {
    /// Die nächsten 3 Tage in den 14 Tagen ab `ab` (`ab` eingeschlossen), an denen beide Personen
    /// laut Wochenplan am Abend (nach 17 Uhr) frei sind.
    static func naechste(daten: KalenderDaten, ab: String) -> [String] {
        var treffer: [String] = []
        var tag = ab
        for _ in 0..<14 {
            if istAbendFrei(tag, person: "ahmed", daten: daten), istAbendFrei(tag, person: "annika", daten: daten) {
                treffer.append(tag)
                if treffer.count == 3 { break }
            }
            tag = Datum.addTage(tag, 1)
        }
        return treffer
    }

    private static func istAbendFrei(_ tag: String, person: String, daten: KalenderDaten) -> Bool {
        let bloecke = Wochenplan.tag(tag, person: person, daten: daten)
        return !bloecke.contains { block in
            // Urlaub oder frei macht den Block nicht mehr „belegt“, auch wenn er ganztägig ist.
            if block.status == "urlaub" || block.status == "frei" { return false }
            // Ohne Ende gilt ein Block als ganztägig belegt.
            guard let ende = block.ende else { return true }
            return ende > "17:00"
        }
    }
}
