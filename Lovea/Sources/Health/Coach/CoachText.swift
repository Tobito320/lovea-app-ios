import Foundation

// Health-Coach, Darstellung: reine Textlogik für den Chat. Das Modell antwortet mit Absätzen, Listen, Nummern und
// gelegentlich einer Überschrift. Hier wird das Zeile für Zeile erkannt, damit der Chat sie als Antwort ohne Blase
// setzen kann. Nichts hier liest Modelle oder die Uhr.

enum CoachText {
    enum Art: Equatable, Sendable {
        case absatz
        case ueberschrift
        case punkt
        case nummer(Int)
    }

    /// Eine Zeile der Antwort. `text` enthält noch Inline-Markdown (**fett**, *kursiv*), siehe `inline`.
    struct Zeile: Equatable, Sendable {
        let art: Art
        let text: String
    }

    /// Leere Zeilen und Trennlinien (`---`) fallen weg, der Chat setzt den Abstand selbst.
    static func zeilen(_ roh: String) -> [Zeile] {
        roh.split(whereSeparator: \.isNewline).compactMap { zeile(String($0)) }
    }

    /// Zeilenumbrüche bleiben, ohne gültiges Markdown gilt der Rohtext.
    static func inline(_ text: String) -> AttributedString {
        let optionen = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: optionen)) ?? AttributedString(text)
    }

    /// Eine Trennzeile über der Nachricht: bei der ersten, an einem neuen Tag oder nach mehr als 6 Stunden Pause.
    static func trennerNoetig(vorher: Date?, jetzt: Date, kalender: Calendar) -> Bool {
        guard let vorher else { return true }
        return !kalender.isDate(vorher, inSameDayAs: jetzt) || jetzt.timeIntervalSince(vorher) > 6 * 3600
    }

    static func begruessung(stunde: Int) -> String {
        switch stunde {
        case 5..<11: "Guten Morgen"
        case 18..<23: "Guten Abend"
        default: "Hallo"
        }
    }

    // MARK: - Eine Zeile

    private static let punktMarken = ["- ", "* ", "• "]

    private static func zeile(_ roh: String) -> Zeile? {
        let text = roh.trimmingCharacters(in: .whitespaces)
        if text.isEmpty || istTrennlinie(text) { return nil }

        let raute = text.prefix { $0 == "#" }
        if (1...6).contains(raute.count), text.dropFirst(raute.count).first == " " {
            return Zeile(art: .ueberschrift, text: rest(text, nach: raute.count + 1))
        }

        if let marke = punktMarken.first(where: { text.hasPrefix($0) }) {
            return Zeile(art: .punkt, text: rest(text, nach: marke.count))
        }

        let ziffern = text.prefix { $0.isASCII && $0.isNumber }
        let danach = text.dropFirst(ziffern.count)
        if (1...3).contains(ziffern.count), let nummer = Int(ziffern),
           let zeichen = danach.first, zeichen == "." || zeichen == ")", danach.dropFirst().first == " " {
            return Zeile(art: .nummer(nummer), text: rest(text, nach: ziffern.count + 2))
        }

        return Zeile(art: .absatz, text: text)
    }

    private static func rest(_ text: String, nach n: Int) -> String {
        String(text.dropFirst(n)).trimmingCharacters(in: .whitespaces)
    }

    private static func istTrennlinie(_ text: String) -> Bool {
        text.count >= 3 && text.allSatisfy { $0 == "-" || $0 == "*" || $0 == "_" }
    }
}
