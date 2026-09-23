import SwiftUI

/// Z-33.2: full-screen effects (Spec 2.5). The sender decides (`ChatModell.nachrichtSenden`), the
/// op carries the raw value as `effekt`.
enum ChatEffekt: String, CaseIterable, Sendable {
    case herzen, sterne, sonne, ballons, konfetti, glitzer, kuesse

    var titel: String {
        switch self {
        case .herzen: "Herzen"
        case .sterne: "Sterne"
        case .sonne: "Sonnenaufgang"
        case .ballons: "Ballons"
        case .konfetti: "Konfetti"
        case .glitzer: "Glitzer"
        case .kuesse: "Küsse"
        }
    }

    var symbol: String {
        switch self {
        case .herzen: "heart.fill"
        case .sterne: "moon.stars.fill"
        case .sonne: "sun.horizon.fill"
        case .ballons: "balloon.fill"
        case .konfetti: "party.popper.fill"
        case .glitzer: "sparkles"
        case .kuesse: "mouth.fill"
        }
    }

    /// Spec 2.5 trigger words, first matching effect wins. "vermisse dich" is the everyday spelling of
    /// "vermiss dich", which whole-word matching would otherwise miss.
    private static let ausloeser: [(effekt: ChatEffekt, woerter: [String])] = [
        (.herzen, ["ich liebe dich", "hdl", "love you"]),
        (.sterne, ["gute nacht"]),
        (.sonne, ["guten morgen"]),
        (.ballons, ["alles gute", "happy birthday"]),
        (.konfetti, ["glückwunsch"]),
        (.glitzer, ["vermiss dich", "vermisse dich"]),
        (.kuesse, ["kuss", "küsschen"]),
    ]

    /// Whole words only ("gute Nachtschicht", "Kussmund" don't count), anywhere in the text, case
    /// and umlaut spelling ignored ("Küsschen" = "Kuesschen" = "KÜSSCHEN").
    static func erkennen(_ text: String) -> ChatEffekt? {
        let t = normalisiert(text)
        return ausloeser.first { eintrag in eintrag.woerter.contains { enthaeltWort(t, normalisiert($0)) } }?.effekt
    }

    private static func normalisiert(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .replacingOccurrences(of: "ae", with: "a")
            .replacingOccurrences(of: "oe", with: "o")
            .replacingOccurrences(of: "ue", with: "u")
            .replacingOccurrences(of: "ß", with: "ss")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func enthaeltWort(_ text: String, _ wort: String) -> Bool {
        var ab = text.startIndex
        while ab < text.endIndex, let treffer = text.range(of: wort, range: ab..<text.endIndex) {
            let davor: Character? = treffer.lowerBound > text.startIndex ? text[text.index(before: treffer.lowerBound)] : nil
            let danach: Character? = treffer.upperBound < text.endIndex ? text[treffer.upperBound] : nil
            if !istWortzeichen(davor), !istWortzeichen(danach) { return true }
            ab = text.index(after: treffer.lowerBound)
        }
        return false
    }

    private static func istWortzeichen(_ zeichen: Character?) -> Bool {
        guard let zeichen else { return false }
        return zeichen.isLetter || zeichen.isNumber
    }
}
