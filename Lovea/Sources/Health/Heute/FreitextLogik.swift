import Foundation

/// Ein erkannter Eintrag aus dem Freitext-Feld. Schlaf und Gewicht ersetzen, Wasser und Creatin zählen dazu.
enum FreitextEintrag: Equatable, Sendable {
    case schlaf(bett: Date, auf: Date)
    /// Zehntel-kg wie `Habit.gewicht`.
    case gewicht(zehntel: Int)
    case wasser(glaeser: Int)
    case creatin(klicks: Int)
}

/// Liest "23 Uhr geschlafen, um 5 aufgestanden, 78,4 kg, 1,5 l getrunken, creatin genommen" ohne KI.
/// ponytail: feste Muster statt Sprachmodell; was hier nichts findet, geht an `FreitextKI`.
enum FreitextLogik {
    /// Ein Glas = 250 ml, so zählt auch die Wasser-Kachel.
    static let glasMl = 250.0

    static func lesen(_ eingabe: String, tag: String) -> [FreitextEintrag] {
        let text = " " + eingabe.lowercased().replacingOccurrences(of: "ß", with: "ss") + " "
        return [schlaf(text, tag: tag), gewicht(text), wasser(text), creatin(text)].compactMap { $0 }
    }

    // MARK: Schlaf

    private static let schlafWorte = ["schlaf", "bett", "penn", "auf", "wach", "eingeschl"]

    private static func schlaf(_ text: String, tag: String) -> FreitextEintrag? {
        guard schlafWorte.contains(where: text.contains) else { return nil }
        let zeiten = uhrzeiten(text)
        guard zeiten.count >= 2 else { return nil }
        return schlafDaten(bett: zeiten[0], auf: zeiten[1], tag: tag)
    }

    /// `tag` = der Morgen des Aufwachens (wie `SchlafZeitenD.datum`). Bett nach der Aufstehzeit = Vorabend.
    static func schlafDaten(bett: (h: Int, m: Int), auf: (h: Int, m: Int), tag: String) -> FreitextEintrag? {
        let k = Datum.kalender
        let morgen = Datum.datum(tag)
        guard let aufDatum = k.date(bySettingHour: auf.h, minute: auf.m, second: 0, of: morgen),
              var bettDatum = k.date(bySettingHour: bett.h, minute: bett.m, second: 0, of: morgen) else { return nil }
        if bettDatum >= aufDatum { bettDatum = k.date(byAdding: .day, value: -1, to: bettDatum) ?? bettDatum }
        let stunden = aufDatum.timeIntervalSince(bettDatum) / 3600
        guard stunden >= 1, stunden <= 16 else { return nil }
        return .schlaf(bett: bettDatum, auf: aufDatum)
    }

    /// "23 uhr", "23:30", "23.30", "halb 12", "um 5". Reihenfolge wie im Text.
    static func uhrzeiten(_ text: String) -> [(h: Int, m: Int)] {
        let muster = #"halb\s+(\d{1,2})|(\d{1,2})[:.](\d{2})(?!\d)|(\d{1,2})\s*uhr|\bum\s+(\d{1,2})(?![\d,.:]|\s*(?:kg|kilo|l\b|liter|ml|g\b))"#
        guard let re = try? NSRegularExpression(pattern: muster) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            func zahl(_ i: Int) -> Int? { m.range(at: i).location == NSNotFound ? nil : Int(ns.substring(with: m.range(at: i))) }
            let zeit: (Int, Int)?
            if let h = zahl(1) { zeit = ((h + 23) % 24, 30) }
            else if let h = zahl(2), let min = zahl(3) { zeit = (h, min) }
            else if let h = zahl(4) { zeit = (h, 0) }
            else if let h = zahl(5) { zeit = (h, 0) }
            else { zeit = nil }
            guard let (h, min) = zeit, (0...24).contains(h), (0...59).contains(min) else { return nil }
            return (h % 24, min)
        }
    }

    // MARK: Gewicht, Wasser, Creatin

    private static func gewicht(_ text: String) -> FreitextEintrag? {
        guard let kilo = zahl(vor: #"\s*(?:kg|kilo)"#, in: text), kilo >= 20, kilo < 400 else { return nil }
        return .gewicht(zehntel: Int((kilo * 10).rounded()))
    }

    private static func wasser(_ text: String) -> FreitextEintrag? {
        let ml: Double?
        if let l = zahl(vor: #"\s*(?:l|liter)\b"#, in: text) { ml = l * 1000 }
        else if let m = zahl(vor: #"\s*ml\b"#, in: text) { ml = m }
        else if let g = zahl(vor: #"\s*gl(?:ä|ae|a)s"#, in: text) { ml = g * glasMl }
        else if text.contains("wasser") || text.contains("glas") || (text.contains("getrunken") && !text.contains("kaffee")) {
            ml = (anzahlWort(text) ?? 1) * glasMl
        }
        else { ml = nil }
        guard let ml, ml > 0, ml <= 8000 else { return nil }
        return .wasser(glaeser: max(1, Int((ml / glasMl).rounded())))
    }

    private static func creatin(_ text: String) -> FreitextEintrag? {
        guard ["creat", "kreat", "krea "].contains(where: text.contains) else { return nil }
        if let g = zahl(vor: #"\s*(?:g|gramm)\b"#, in: text), g > 0, g <= 30 {
            return .creatin(klicks: max(1, Int((g / Habit.creatinGramm).rounded())))
        }
        if let n = zahl(vor: #"\s*(?:x|mal|klicks?|portion(?:en)?|l(?:ö|oe)ffel)\b"#, in: text) { return .creatin(klicks: max(1, Int(n))) }
        return .creatin(klicks: Int(anzahlWort(text) ?? 1))
    }

    // MARK: Zahlen

    /// Erste Zahl direkt vor `einheit`, Komma oder Punkt als Dezimaltrenner.
    private static func zahl(vor einheit: String, in text: String) -> Double? {
        guard let re = try? NSRegularExpression(pattern: #"(\d+(?:[.,]\d+)?)"# + einheit),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return Double(text[r].replacingOccurrences(of: ",", with: "."))
    }

    private static let worte: [(String, Double)] = [(" ein ", 1), (" eine ", 1), (" einen ", 1), (" zwei ", 2), (" drei ", 3), (" vier ", 4), (" fünf ", 5), (" doppelt", 2)]

    private static func anzahlWort(_ text: String) -> Double? {
        worte.first { text.contains($0.0) }?.1
    }
}
