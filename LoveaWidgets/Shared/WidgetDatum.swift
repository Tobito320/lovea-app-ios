import Foundation

/// Berlin-Datumshilfen fürs Widget-Ziel und die Erweiterung — bewusst eine eigene, winzige Kopie
/// statt `Kalender/Logik/Datum.swift` zu teilen: diese Datei kompiliert in BEIDE Targets (App und
/// `LoveaWidgets`), darf also keine Typen aus dem App-Target (`Person`, `Op`, `Raum`, `Datum`)
/// anfassen (Doppel-Symbole/fremde Abhängigkeiten in der Erweiterung). Nur die paar Funktionen, die
/// Timeline-Provider und App Intent wirklich brauchen: "was ist heute" und "Tage zwischen zwei
/// yyyy-MM-dd-Strings" (Review-Fokus 1: Tageswechsel/Zeitumstellung rechnen mit Ortszeit, nicht UTC).
enum WidgetDatum {
    static let berlin: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    static func heute(_ jetzt: Date = Date()) -> String { text(jetzt) }

    static func text(_ datum: Date) -> String {
        let teile = berlin.dateComponents([.year, .month, .day], from: datum)
        return String(format: "%04d-%02d-%02d", teile.year!, teile.month!, teile.day!)
    }

    static func datum(_ tag: String) -> Date {
        let teile = tag.split(separator: "-").compactMap { Int($0) }
        var komponenten = DateComponents()
        komponenten.year = teile[safe: 0]
        komponenten.month = teile[safe: 1]
        komponenten.day = teile[safe: 2]
        return berlin.date(from: komponenten) ?? Date()
    }

    static func tageZwischen(_ von: String, _ bis: String) -> Int {
        berlin.dateComponents([.day], from: datum(von), to: datum(bis)).day ?? 0
    }

    /// Für die Timeline-Reload-Policy: kurz nach der nächsten Berlin-Mitternacht, damit "heute" im
    /// Widget spätestens dann neu berechnet wird, auch wenn die App zwischenzeitlich nicht schreibt.
    static func naechsteMitternacht(_ jetzt: Date = Date()) -> Date {
        let start = berlin.startOfDay(for: jetzt)
        return berlin.date(byAdding: .day, value: 1, to: start) ?? jetzt.addingTimeInterval(3600)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
