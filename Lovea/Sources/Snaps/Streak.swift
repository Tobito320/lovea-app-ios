import Foundation

/// Pure streak logic (Z-6.5). A Berlin calendar day counts once every person has sent at least one
/// snap that day. `tage` is the length of the run ending today (if today already counts) or ending
/// yesterday (if today is still open — an open day doesn't break the streak, it just isn't secured
/// yet). `Calendar.date(byAdding:.day,...)` (not a fixed 86_400s step) is what makes this correct
/// across a DST change (Review-Fokus #4, tested against 25.10.2026).
enum Streak {
    static func berechnen(snaps: [(von: Person, zeit: Date)], jetzt: Date) -> (tage: Int, laeuftAb: Bool) {
        let kalender = Calendar.berlin
        var sendendeProTag: [Date: Set<Person>] = [:]
        for snap in snaps {
            let tag = kalender.startOfDay(for: snap.zeit)
            sendendeProTag[tag, default: []].insert(snap.von)
        }
        let zaehlt = Set(sendendeProTag.filter { $0.value.count >= Person.allCases.count }.keys)

        let heute = kalender.startOfDay(for: jetzt)
        let gestern = kalender.date(byAdding: .day, value: -1, to: heute) ?? heute

        func laenge(ab start: Date) -> Int {
            var anzahl = 0
            var tag = start
            while zaehlt.contains(tag) {
                anzahl += 1
                tag = kalender.date(byAdding: .day, value: -1, to: tag) ?? tag.addingTimeInterval(-86_400)
            }
            return anzahl
        }

        let heuteZaehlt = zaehlt.contains(heute)
        let tage = heuteZaehlt ? laenge(ab: heute) : (zaehlt.contains(gestern) ? laenge(ab: gestern) : 0)
        let stunde = kalender.component(.hour, from: jetzt)
        let laeuftAb = tage > 0 && !heuteZaehlt && stunde >= 20

        return (tage, laeuftAb)
    }
}
