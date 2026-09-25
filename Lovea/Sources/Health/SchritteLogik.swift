import Foundation

/// One day of the steps line chart.
struct SchrittPunkt: Identifiable, Equatable, Sendable {
    let tag: String
    let schritte: Int
    var id: String { tag }
}

/// Tag / Woche / Monat of the steps detail.
enum SchritteZeitraum: String, CaseIterable, Sendable {
    case tag, woche, monat
}

/// Pure logic of the steps detail: which days a period covers, stepping between periods, the chart
/// window and points, and the challenge ranking. Days are `Datum` strings (Europe/Berlin).
enum SchritteLogik {
    /// Every day of the period that contains `anker` (incl. future days of a running week/month).
    static func tage(_ zeitraum: SchritteZeitraum, anker: String) -> [String] {
        switch zeitraum {
        case .tag:
            return [anker]
        case .woche:
            return HabitLogik.wochenTage(heute: anker)
        case .monat:
            return HealthLogik.monatsGitter(heute: anker, monateZurueck: 0).compactMap { $0 }
        }
    }

    /// The anchor one period before (`schritte` −1) or after (+1); `nil` if that lies in the future.
    static func verschoben(_ anker: String, _ zeitraum: SchritteZeitraum, um schritte: Int, heute: String) -> String? {
        let neu: String
        switch zeitraum {
        case .tag: neu = Datum.addTage(anker, schritte)
        case .woche: neu = Datum.addTage(anker, 7 * schritte)
        case .monat:
            let erster = String(anker.prefix(7)) + "-01"
            guard let datum = Datum.kalender.date(byAdding: .month, value: schritte, to: Datum.datum(erster)) else { return nil }
            neu = Datum.text(datum)
        }
        guard let ersterTag = tage(zeitraum, anker: neu).first, ersterTag <= heute else { return nil }
        return min(neu, heute)
    }

    /// Sum of the period's days up to today; `nil` when none has a value.
    static func summe(_ werte: [String: Int], tage: [String], heute: String) -> Int? {
        let vorhanden = tage.filter { $0 <= heute }.compactMap { werte[$0] }
        return vorhanden.isEmpty ? nil : vorhanden.reduce(0, +)
    }

    /// The chart shows 7 days in pages that end on today, today−7, …; the page of `anker` never
    /// moves while one taps inside it.
    static func fensterTage(anker: String, heute: String) -> [String] {
        let seite = max(0, Datum.tageZwischen(anker, heute)) / 7
        let ende = Datum.addTage(heute, -7 * seite)
        return (0..<7).map { Datum.addTage(ende, $0 - 6) }
    }

    /// Chart points: future days left out, a past day without data counts 0 so the smooth line
    /// stays continuous.
    static func linienPunkte(tage: [String], werte: [String: Int], heute: String) -> [SchrittPunkt] {
        tage.filter { $0 <= heute }.map { SchrittPunkt(tag: $0, schritte: werte[$0] ?? 0) }
    }

    struct Platz: Equatable, Sendable {
        var person: Person
        var schritte: Int
        var rang: Int
    }

    /// Most steps first; a tie shares the rank, then by name.
    static func rangliste(_ schritte: [Person: Int]) -> [Platz] {
        let sortiert = schritte.sorted { ($1.value, $0.key.name) < ($0.value, $1.key.name) }
        return sortiert.map { eintrag in
            Platz(person: eintrag.key, schritte: eintrag.value, rang: 1 + sortiert.filter { $0.value > eintrag.value }.count)
        }
    }
}
