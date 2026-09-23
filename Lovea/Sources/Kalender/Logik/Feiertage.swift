import Foundation

/// Gesetzliche Feiertage in Nordrhein-Westfalen.
enum Feiertage {
    static func nrw(jahr: Int) -> Set<String> {
        var tage: Set<String> = [
            String(format: "%04d-01-01", jahr), // Neujahr
            String(format: "%04d-05-01", jahr), // 1. Mai
            String(format: "%04d-10-03", jahr), // Tag der Deutschen Einheit
            String(format: "%04d-11-01", jahr), // Allerheiligen
            String(format: "%04d-12-25", jahr), // 1. Weihnachtstag
            String(format: "%04d-12-26", jahr), // 2. Weihnachtstag
        ]

        let ostersonntag = osterSonntag(jahr: jahr)
        tage.insert(Datum.text(Datum.kalender.date(byAdding: .day, value: -2, to: ostersonntag)!)) // Karfreitag
        tage.insert(Datum.text(Datum.kalender.date(byAdding: .day, value: 1, to: ostersonntag)!)) // Ostermontag
        tage.insert(Datum.text(Datum.kalender.date(byAdding: .day, value: 39, to: ostersonntag)!)) // Christi Himmelfahrt
        tage.insert(Datum.text(Datum.kalender.date(byAdding: .day, value: 50, to: ostersonntag)!)) // Pfingstmontag
        tage.insert(Datum.text(Datum.kalender.date(byAdding: .day, value: 60, to: ostersonntag)!)) // Fronleichnam

        return tage
    }

    /// Ostersonntag nach dem Gaußschen Osteralgorithmus (gregorianischer Kalender).
    static func osterSonntag(jahr: Int) -> Date {
        let a = jahr % 19
        let b = jahr % 4
        let c = jahr % 7
        let k = jahr / 100
        let p = (13 + 8 * k) / 25
        let q = k / 4
        let m = (15 - p + k - q) % 30
        let n = (4 + k - q) % 7
        let d = (19 * a + m) % 30
        let e = (2 * b + 4 * c + 6 * d + n) % 7

        var tag: Int
        var monat: Int
        if d == 29 && e == 6 {
            tag = 19
            monat = 4
        } else if d == 28 && e == 6 && (11 * m + 11) % 30 < 19 {
            tag = 18
            monat = 4
        } else {
            let roh = 22 + d + e
            if roh > 31 {
                tag = roh - 31
                monat = 4
            } else {
                tag = roh
                monat = 3
            }
        }

        var teilwerte = DateComponents()
        teilwerte.year = jahr
        teilwerte.month = monat
        teilwerte.day = tag
        return Datum.kalender.date(from: teilwerte)!
    }
}
