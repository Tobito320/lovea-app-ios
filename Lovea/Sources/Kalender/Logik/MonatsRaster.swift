import Foundation

/// Z-42.1: alles, was das Monatsraster zeigt, einmal pro Monat und Datenstand berechnet
/// (`KalenderModell.monatsRaster`), nicht pro Zelle und Render.
struct MonatsRaster {
    struct Zelle {
        let tag: String
        /// "schule" | "arbeit" | nil, linke Hälfte.
        let ahmed: String?
        /// "schule" | "arbeit" | nil, rechte Hälfte.
        let annika: String?
        let termin: Bool
        let treffen: Bool
        /// „Mittwoch, 23. September", für VoiceOver.
        let anzeige: String

        var nummer: String { String(Int(tag.suffix(2)) ?? 0) }

        func vorlesen(heute: Bool) -> String {
            var teile = heute ? ["Heute", anzeige] : [anzeige]
            if let ahmed { teile.append("Ahmed: \(ahmed.capitalized)") }
            if let annika { teile.append("Annika: \(annika.capitalized)") }
            if termin { teile.append("Termin") }
            if treffen { teile.append("Treffen") }
            return teile.joined(separator: ", ")
        }
    }

    /// „September 2026".
    let titel: String
    /// 42 Plätze (6 Wochen ab Montag), nil vor dem 1. und nach dem Monatsende.
    let zellen: [Zelle?]

    /// `erster`: der 1. des Monats als `yyyy-MM-dd`.
    init(erster: String, daten: KalenderDaten) {
        let anfang = Datum.datum(erster)
        let anzahl = Datum.kalender.range(of: .day, in: .month, for: anfang)?.count ?? 30
        let feiertage = Feiertage.nrw(jahr: Int(erster.prefix(4)) ?? 0)
        let termine = Set(daten.termine.map(\.datum))
        let treffen = Set(daten.treffen.map(\.datum))
        var zellen: [Zelle?] = Array(repeating: nil, count: Datum.wochentag(erster) - 1)
        for i in 0..<anzahl {
            let tag = Datum.addTage(erster, i)
            zellen.append(Zelle(
                tag: tag,
                ahmed: Self.routine(tag, person: "ahmed", daten: daten, feiertage: feiertage),
                annika: Self.routine(tag, person: "annika", daten: daten, feiertage: feiertage),
                termin: termine.contains(tag),
                treffen: treffen.contains(tag),
                anzeige: Datum.anzeige(tag)
            ))
        }
        self.zellen = zellen + Array(repeating: nil, count: 42 - zellen.count)
        let stil = Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
        titel = anfang.formatted(stil.month(.wide).year())
    }

    /// Schule vor Arbeit. Zählt nur Muster, die an dem Tag stattfinden: normal oder verschoben,
    /// nicht krank, Urlaub oder frei. Fahrschule und Sonstiges stehen nur in der Tagesansicht.
    static func routine(_ tag: String, person: String, daten: KalenderDaten, feiertage: Set<String>) -> String? {
        let typen = Set(Wochenplan.tag(tag, person: person, daten: daten, feiertage: feiertage)
            .filter { $0.quelle == "muster" && ($0.status == "normal" || $0.status == "verschoben") }
            .map(\.typ))
        return ["schule", "arbeit"].first(where: typen.contains)
    }
}
