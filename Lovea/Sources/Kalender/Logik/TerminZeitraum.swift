import Foundation

/// Termin-Editor: zwei Zeilen „Ab" und „Bis", jede mit eigenem Datum und eigener Uhrzeit. „Bis"
/// liegt nie vor „Ab". Ändert sich „Ab", rückt „Bis" mit (die Länge bleibt). Gespeichert wird in
/// die alten Felder: `datum`/`start` für Ab, `ende` für die Uhrzeit von Bis, neu `bisDatum` nur bei
/// mehrtägigen Terminen. Alte Termine laden und speichern deshalb unverändert.
struct TerminZeitraum: Equatable {
    private(set) var ab: Date
    private(set) var bis: Date
    private(set) var ganztaegig: Bool
    /// Alter Termin mit Beginn, aber ohne Ende: bleibt ohne Ende, bis jemand „Bis" ändert.
    private(set) var ohneEnde: Bool

    private static let standardBeginn = 10 * 60

    /// Neuer Termin: ganztägig am `datum`. Mit `termin`: dessen Werte.
    init(datum: String, termin: Termin?) {
        guard let termin else {
            ab = Self.zeitpunkt(datum, nil)
            bis = ab
            ganztaegig = true
            ohneEnde = false
            return
        }
        ganztaegig = termin.start == nil
        ab = Self.zeitpunkt(termin.datum, ganztaegig ? nil : termin.start)
        if ganztaegig {
            bis = Self.zeitpunkt(termin.letzterTag, nil)
            ohneEnde = false
        } else if let ende = termin.ende {
            bis = max(Self.zeitpunkt(termin.letzterTag, ende), ab)
            ohneEnde = false
        } else {
            bis = ab.addingTimeInterval(60 * 60)
            ohneEnde = true
        }
    }

    mutating func setzeAb(_ neu: Date) {
        if ganztaegig {
            let tage = Datum.kalender.dateComponents([.day], from: ab, to: bis).day ?? 0
            ab = Datum.kalender.startOfDay(for: neu)
            bis = Datum.kalender.date(byAdding: .day, value: max(0, tage), to: ab) ?? ab
        } else {
            let laenge = max(0, bis.timeIntervalSince(ab))
            ab = neu
            bis = neu.addingTimeInterval(laenge)
        }
    }

    mutating func setzeBis(_ neu: Date) {
        ohneEnde = false
        bis = max(ganztaegig ? Datum.kalender.startOfDay(for: neu) : neu, ab)
    }

    mutating func setzeGanztaegig(_ an: Bool) {
        guard an != ganztaegig else { return }
        ganztaegig = an
        ohneEnde = false
        if an {
            ab = Datum.kalender.startOfDay(for: ab)
            bis = Datum.kalender.startOfDay(for: bis)
        } else {
            ab = Self.zeitpunkt(Datum.text(ab), Datum.uhrzeit(minuten: Self.standardBeginn))
            bis = max(Self.zeitpunkt(Datum.text(bis), Datum.uhrzeit(minuten: Self.standardBeginn + 60)), ab)
        }
    }

    /// `termin` mit den Zeitfeldern aus Ab und Bis.
    func angewandt(auf termin: Termin) -> Termin {
        var neu = termin
        neu.datum = Datum.text(ab)
        let letzter = ohneEnde ? neu.datum : Datum.text(bis)
        neu.bisDatum = letzter > neu.datum ? letzter : nil
        neu.start = ganztaegig ? nil : Datum.uhrzeit(ab)
        neu.ende = (ganztaegig || ohneEnde) ? nil : Datum.uhrzeit(bis)
        return neu
    }

    /// `yyyy-MM-dd` plus `HH:mm` in Berlin; ohne Uhrzeit Mitternacht.
    private static func zeitpunkt(_ tag: String, _ zeit: String?) -> Date {
        var komponenten = Datum.kalender.dateComponents([.year, .month, .day], from: Datum.datum(tag))
        let minuten = Datum.minuten(zeit) ?? 0
        komponenten.hour = minuten / 60
        komponenten.minute = minuten % 60
        return Datum.kalender.date(from: komponenten) ?? Datum.datum(tag)
    }
}
