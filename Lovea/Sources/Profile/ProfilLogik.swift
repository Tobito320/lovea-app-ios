import SwiftUI

/// Tropical zodiac sign by start date (German names). Ahmed 27.02. → Fische, Annika 06.06. → Zwillinge.
enum Sternzeichen {
    private static let anfaenge: [(monat: Int, tag: Int, name: String, symbol: String)] = [
        (1, 20, "Wassermann", "♒"), (2, 19, "Fische", "♓"), (3, 21, "Widder", "♈"), (4, 21, "Stier", "♉"),
        (5, 21, "Zwillinge", "♊"), (6, 22, "Krebs", "♋"), (7, 23, "Löwe", "♌"), (8, 24, "Jungfrau", "♍"),
        (9, 24, "Waage", "♎"), (10, 24, "Skorpion", "♏"), (11, 23, "Schütze", "♐"), (12, 22, "Steinbock", "♑"),
    ]

    static func fuer(monat: Int, tag: Int) -> (name: String, symbol: String) {
        // Before 20.01. nothing matches: still Steinbock from last December.
        let z = anfaenge.last { ($0.monat, $0.tag) <= (monat, tag) } ?? anfaenge[11]
        return (z.name, z.symbol)
    }
}

/// `facetime://` / `facetime-audio://` from a typed phone number ("+49 151 234-567" → "+49151234567").
enum FaceTimeLink {
    static func url(_ nummer: String, audio: Bool) -> URL? {
        let rein = nummer.filter { ($0.isASCII && $0.isNumber) || $0 == "+" }
        guard rein.count >= 5 else { return nil }
        return URL(string: (audio ? "facetime-audio://" : "facetime://") + rein)
    }
}
