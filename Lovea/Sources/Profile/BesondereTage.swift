import Foundation

/// Z-15.3: reine Abzeichen-Logik für besondere Tage. Geburtstage, Jahrestag und Date-Tag.
/// "Pünktlich" und "Monats-Krone" sind eigene Abzeichen (Spec 4.3), die aus `KalenderModell`/
/// `Puenktlich` kommen, nicht von hier.
///
/// ponytail: `Figuren/FigurZustand.bestimmen` berechnet Geburtstag/Jahrestag/Date-Tag noch einmal
/// inline (dieselben drei Zeilen) statt hierher zu delegieren — Figuren/** gehört nicht zu diesem
/// Block. Upgrade: `bestimmen` durch einen Aufruf von `BesondereTage.abzeichen` ersetzen, sobald
/// jemand mit Schreibrecht auf Figuren/ das übernimmt.
enum BesondereTage {
    /// Ahmed 27.02., Annika 06.06. (Spec 4.3).
    private static func geburtstag(_ person: Person) -> (monat: Int, tag: Int) {
        person == .ahmed ? (2, 27) : (6, 6)
    }

    static func abzeichen(person: Person, datum: Date, jahrestag: Date?, dateHeute: Bool) -> [String] {
        var abzeichen: [String] = []
        let heute = Calendar.berlin.dateComponents([.month, .day], from: datum)
        let g = geburtstag(person)
        if heute.month == g.monat, heute.day == g.tag { abzeichen.append("partyhut") }
        if let jahrestag {
            let j = Calendar.berlin.dateComponents([.month, .day], from: jahrestag)
            if j.month == heute.month, j.day == heute.day { abzeichen.append("herzaugen") }
        }
        if dateHeute { abzeichen.append("outfit") }
        return abzeichen
    }
}
