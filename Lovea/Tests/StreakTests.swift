import XCTest
@testable import Lovea

final class StreakTests: XCTestCase {

    // MARK: - Z-6.5

    /// 25.10.2026 is the DST fallback in Europe/Berlin (CEST → CET) — `Calendar.date(byAdding:)`
    /// must still count it as exactly one day, not clipped/duplicated by the extra hour.
    func testStreakUeberlebtDieZeitumstellung() {
        let snaps = beideSenden(tage: [23, 24, 25, 26], monat: 10, jahr: 2026)
        let jetzt = berlin(2026, 10, 27, stunde: 8) // today (27.) hasn't sent yet, still morning

        let ergebnis = Streak.berechnen(snaps: snaps, jetzt: jetzt)

        XCTAssertEqual(ergebnis.tage, 4, "23.–26.10. zählen trotz Zeitumstellung als vier Tage in Folge")
        XCTAssertFalse(ergebnis.laeuftAb, "vor 20 Uhr noch keine Sanduhr")
    }

    func testLueckeSetztStreakAufNull() {
        var snaps = beideSenden(tage: [24], monat: 10, jahr: 2026)
        // 25.10.: nur Ahmed schickt einen Snap — der Tag zählt nicht, die Folge reißt.
        snaps.append((von: .ahmed, zeit: berlin(2026, 10, 25)))
        let jetzt = berlin(2026, 10, 26, stunde: 10) // 26.10. noch offen

        let ergebnis = Streak.berechnen(snaps: snaps, jetzt: jetzt)

        XCTAssertEqual(ergebnis.tage, 0)
        XCTAssertFalse(ergebnis.laeuftAb, "kein Streak zu verlieren")
    }

    /// "heute noch offen zählt gestern": bevor beide heute gesendet haben, zeigt die Zahl weiter die
    /// Länge der Folge bis gestern — sie fällt nicht schon morgens auf 0.
    func testHeuteNochOffenZaehltGestern() {
        let snaps = beideSenden(tage: [20, 21, 22], monat: 10, jahr: 2026)
        let jetzt = berlin(2026, 10, 23, stunde: 10)

        let ergebnis = Streak.berechnen(snaps: snaps, jetzt: jetzt)

        XCTAssertEqual(ergebnis.tage, 3)
        XCTAssertFalse(ergebnis.laeuftAb)
    }

    func testSanduhrAbZwanzigUhrWennHeuteNochOffen() {
        let snaps = beideSenden(tage: [20, 21, 22], monat: 10, jahr: 2026)
        let jetzt = berlin(2026, 10, 23, stunde: 20)

        let ergebnis = Streak.berechnen(snaps: snaps, jetzt: jetzt)

        XCTAssertEqual(ergebnis.tage, 3)
        XCTAssertTrue(ergebnis.laeuftAb)
    }

    func testKeineSanduhrWennHeuteSchonBeideGesendetHaben() {
        let snaps = beideSenden(tage: [22, 23], monat: 10, jahr: 2026)
        let jetzt = berlin(2026, 10, 23, stunde: 21)

        let ergebnis = Streak.berechnen(snaps: snaps, jetzt: jetzt)

        XCTAssertEqual(ergebnis.tage, 2)
        XCTAssertFalse(ergebnis.laeuftAb, "heute ist schon gesichert")
    }

    // MARK: - Helpers

    private func beideSenden(tage: [Int], monat: Int, jahr: Int) -> [(von: Person, zeit: Date)] {
        tage.flatMap { tag in
            Person.allCases.map { (von: $0, zeit: berlin(jahr, monat, tag)) }
        }
    }

    private func berlin(_ jahr: Int, _ monat: Int, _ tag: Int, stunde: Int = 12) -> Date {
        Calendar.berlin.date(from: DateComponents(year: jahr, month: monat, day: tag, hour: stunde))!
    }
}
