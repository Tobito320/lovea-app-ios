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

/// Name colour in the chat (`einstellung.setzen chatfarbe`, "#RRGGBB"; empty = person colour).
enum ChatFarbe {
    struct Option: Hashable {
        let name: String
        let hex: String
    }

    static let auswahl: [Option] = [
        Option(name: "Kirsche", hex: "#E0284A"), Option(name: "Koralle", hex: "#F2613F"),
        Option(name: "Gold", hex: "#C98A00"), Option(name: "Grün", hex: "#2E9E4F"),
        Option(name: "Petrol", hex: "#0A8F94"), Option(name: "Blau", hex: "#2F6BFF"),
        Option(name: "Lila", hex: "#8A56F0"), Option(name: "Beere", hex: "#9B2C6B"),
    ]

    static func rgb(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, s.allSatisfy(\.isHexDigit), let v = UInt32(s, radix: 16) else { return nil }
        return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    static func farbe(hex: String) -> Color? {
        rgb(hex).map { Color(red: $0.r, green: $0.g, blue: $0.b) }
    }

    /// For the chat's name label: the person's own pick, else their person colour.
    @MainActor static func farbe(_ person: Person) -> Color {
        farbe(hex: EinstellungenModell.shared.string("chatfarbe", default: "", von: person)) ?? .person(person)
    }
}
