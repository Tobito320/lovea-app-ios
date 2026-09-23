import Foundation

/// Datumshilfen für den Kalender. Tage sind überall als `yyyy-MM-dd`-Strings unterwegs.
enum Datum {
    static let kalender: Calendar = {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "Europe/Berlin")!
        kalender.firstWeekday = 2 // Montag
        return kalender
    }()

    static func datum(_ tag: String) -> Date {
        let teile = tag.split(separator: "-").compactMap { Int($0) }
        var teilwerte = DateComponents()
        teilwerte.year = teile[0]
        teilwerte.month = teile[1]
        teilwerte.day = teile[2]
        return kalender.date(from: teilwerte)!
    }

    static func text(_ datum: Date) -> String {
        let teile = kalender.dateComponents([.year, .month, .day], from: datum)
        return String(format: "%04d-%02d-%02d", teile.year!, teile.month!, teile.day!)
    }

    /// „Mittwoch, 23. September" für Oberfläche und VoiceOver. FormatStyle ist ein Sendable-Wert,
    /// anders als DateFormatter, und wird vom System gecacht.
    static func anzeige(_ tag: String) -> String {
        let stil = Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: kalender, timeZone: kalender.timeZone)
        return datum(tag).formatted(stil.weekday(.wide).day().month(.wide))
    }

    static func addTage(_ tag: String, _ anzahl: Int) -> String {
        text(kalender.date(byAdding: .day, value: anzahl, to: datum(tag))!)
    }

    static func tageZwischen(_ von: String, _ bis: String) -> Int {
        kalender.dateComponents([.day], from: datum(von), to: datum(bis)).day!
    }

    /// 1 = Montag … 7 = Sonntag.
    static func wochentag(_ tag: String) -> Int {
        let weekday = kalender.component(.weekday, from: datum(tag)) // 1 = Sonntag … 7 = Samstag
        return weekday == 1 ? 7 : weekday - 1
    }

    static func montagDerWoche(_ tag: String) -> String {
        addTage(tag, -(wochentag(tag) - 1))
    }

    /// Wechselwoche A/B. Woche A = die Woche ab Montag, 21.09.2026, danach abwechselnd in beide Richtungen.
    static func wechselwoche(_ tag: String) -> String {
        let referenzMontag = "2026-09-21"
        let wochenDiff = tageZwischen(referenzMontag, montagDerWoche(tag)) / 7
        let mod = ((wochenDiff % 2) + 2) % 2
        return mod == 0 ? "A" : "B"
    }
}
