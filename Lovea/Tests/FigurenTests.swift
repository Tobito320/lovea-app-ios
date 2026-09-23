import XCTest
@testable import Lovea

final class FigurenTests: XCTestCase {
    private func berlin(_ tag: Int, _ monat: Int, _ stunde: Int, _ minute: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal.date(from: DateComponents(year: 2026, month: monat, day: tag, hour: stunde, minute: minute))!
    }

    func testGesteSchlaegtAlles() {
        var e = FigurEingabe(person: .ahmed, jetzt: berlin(10, 3, 22))
        e.geste = .herz
        e.online = false
        e.app = .tippt
        e.ort = .gym
        e.bewegung = .rennt
        e.akku = 0.05
        e.fokus = "schlafen"
        e.stimmung = "schlecht"
        e.brauche = "ruhe"
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .herz)
    }

    func testTipptSchlaegtGym() {
        var e = FigurEingabe(person: .annika, jetzt: berlin(10, 3, 14))
        e.app = .tippt
        e.ort = .gym
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .tippt)
    }

    func testOfflineSchlaegtOrt() {
        var e = FigurEingabe(person: .annika, jetzt: berlin(10, 3, 14))
        e.ort = .zuhause
        e.bewegung = .laeuft
        e.online = false
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .offline)
    }

    func testGeburtstagAnnikaPartyhut() {
        // 00:30 in Berlin is still 05.06. in UTC, so this fails if the calendar is not Europe/Berlin.
        let datum = berlin(6, 6, 0, 30)
        XCTAssertTrue(FigurZustand.bestimmen(FigurEingabe(person: .annika, jetzt: datum)).abzeichen.contains("partyhut"))
        XCTAssertFalse(FigurZustand.bestimmen(FigurEingabe(person: .ahmed, jetzt: datum)).abzeichen.contains("partyhut"))
    }
}
