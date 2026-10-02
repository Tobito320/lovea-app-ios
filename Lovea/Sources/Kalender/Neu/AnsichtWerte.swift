import Foundation

/// Eine Alltag-Zeile (Muster-Block) mit der Person, zu der sie gehört.
struct AlltagEintrag {
    let person: Person
    let block: Block
}

/// Kleine reine Hilfen hinter den Ansichten des neuen Kalenders. Kein SwiftUI, kein Modell.
enum AnsichtWerte {
    private static let wochentagKurz = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    /// Die sieben Tage der Woche von `tag`, Montag bis Sonntag.
    static func wochenTage(_ tag: String) -> [String] {
        let montag = Datum.montagDerWoche(tag)
        return (0..<7).map { Datum.addTage(montag, $0) }
    }

    static func kurz(_ tag: String) -> String { wochentagKurz[Datum.wochentag(tag) - 1] }

    /// Termine des Tages, ganztägige zuerst, dann nach Uhrzeit.
    static func tagesTermine(_ daten: KalenderDaten, tag: String) -> [Termin] {
        daten.termine.filter { $0.datum == tag }.sorted { ($0.start ?? "", $0.id) < ($1.start ?? "", $1.id) }
    }

    static func zeitSpalte(_ termin: Termin) -> String { termin.start ?? "ganztägig" }

    /// „Ahmed · bis 19:00", „Ahmed und Annika".
    static func terminUnterzeile(_ termin: Termin) -> String {
        let namen = Person.allCases.filter { termin.fuer.contains($0.rawValue) }.map(\.name).joined(separator: " und ")
        return [namen, termin.ende.map { "bis \($0)" } ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Satz für VoiceOver auf einer Rasterzelle.
    static func zellenText(anzeige: String, marken: TagesMarken?, heute: Bool, gewaehlt: Bool) -> String {
        var teile = heute ? ["Heute", anzeige] : [anzeige]
        if gewaehlt { teile.append("gewählt") }
        if marken?.ahmed == true { teile.append("Termin Ahmed") }
        if marken?.annika == true { teile.append("Termin Annika") }
        if marken?.treffen == true { teile.append("Treffen") }
        return teile.joined(separator: ", ")
    }

    /// Muster-Blöcke des Tages beider Personen (Schule, Arbeit …), Ahmed zuerst.
    static func alltag(_ daten: KalenderDaten, tag: String) -> [AlltagEintrag] {
        Person.allCases.flatMap { person in
            Wochenplan.tag(tag, person: person.rawValue, daten: daten)
                .filter { $0.quelle == "muster" }
                .map { AlltagEintrag(person: person, block: $0) }
        }
    }

    static func alltagSymbol(_ block: Block) -> String {
        switch block.typ {
        case "arbeit": "briefcase"
        case "schule": "book"
        case "fahrschule": "car"
        default: "calendar"
        }
    }

    /// Die Person eines Termins für den Punkt vor dem Titel; nil, wenn er für beide (oder keinen) gilt.
    static func terminPerson(_ termin: Termin) -> Person? {
        let personen = Person.allCases.filter { termin.fuer.contains($0.rawValue) }
        return personen.count == 1 ? personen[0] : nil
    }

    /// Die Plätze des Rasters in Wochen zu sieben, ganz leere Wochen fallen weg.
    static func wochenZeilen<T>(_ plaetze: [T?]) -> [[T?]] {
        stride(from: 0, to: plaetze.count, by: 7)
            .map { Array(plaetze[$0..<min($0 + 7, plaetze.count)]) }
            .filter { $0.contains { $0 != nil } }
    }

    /// Gewählter Tag nach einem Monatswechsel: heute, wenn heute im neuen Monat liegt, sonst der 1.
    static func tagNachMonatswechsel(erster: String, heute: String) -> String {
        heute.hasPrefix(erster.prefix(7)) ? heute : erster
    }

    /// Lage einer Uhrzeit auf der Achse 8 bis 22 Uhr, 0 bis 1.
    static func anteil(_ minuten: Int) -> Double {
        let klemmt = min(max(minuten, TagesWerte.fensterVon), TagesWerte.fensterBis)
        return Double(klemmt - TagesWerte.fensterVon) / Double(TagesWerte.fensterBis - TagesWerte.fensterVon)
    }
}
