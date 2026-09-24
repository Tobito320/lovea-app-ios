import XCTest
@testable import Lovea

/// Brief G fix 2: the one sleep decision (`SchlafLogik`) and how `FigurZustand.bestimmen` uses it.
final class SchlafLogikTests: XCTestCase {
    private func berlin(_ tag: Int, _ stunde: Int, _ minute: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal.date(from: DateComponents(year: 2026, month: 9, day: tag, hour: stunde, minute: minute))!
    }

    private let nacht = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func nachMinuten(_ m: Double, bewegung: Date? = nil, zuhause: Bool = true, fokus: Bool = false) -> SchlafZustand {
        SchlafLogik.zustand(guteNachtSeit: nacht, fokusSchlafen: fokus, zuhause: zuhause, letzteBewegung: bewegung, jetzt: nacht.addingTimeInterval(m * 60))
    }

    func testNullDreiFuenfMinuten() {
        XCTAssertEqual(nachMinuten(0), .wach)
        XCTAssertEqual(nachMinuten(2.9), .wach)
        XCTAssertEqual(nachMinuten(3), .sitzt)
        XCTAssertEqual(nachMinuten(4.9), .sitzt)
        XCTAssertEqual(nachMinuten(5), .schlaeft)
        XCTAssertEqual(nachMinuten(240), .schlaeft)
    }

    func testBewegungStartetNeu() {
        // Moved at minute 10: awake right away, sits 3 min later, sleeps 5 min later.
        let bewegt = nacht.addingTimeInterval(10 * 60)
        XCTAssertEqual(nachMinuten(10, bewegung: bewegt), .wach)
        XCTAssertEqual(nachMinuten(13, bewegung: bewegt), .sitzt)
        XCTAssertEqual(nachMinuten(15, bewegung: bewegt), .schlaeft)
        // Movement before the "Gute Nacht" changes nothing.
        XCTAssertEqual(nachMinuten(5, bewegung: nacht.addingTimeInterval(-600)), .schlaeft)
    }

    func testNichtZuHauseNieSchlafend() {
        XCTAssertEqual(nachMinuten(60, zuhause: false), .wach)
        XCTAssertEqual(nachMinuten(60, zuhause: false, fokus: true), .wach)
    }

    func testHoechstensZwoelfStunden() {
        XCTAssertEqual(nachMinuten(12 * 60), .schlaeft)
        XCTAssertEqual(nachMinuten(12 * 60 + 1), .wach)
    }

    func testNurFokus() {
        let jetzt = berlin(25, 2)
        XCTAssertEqual(SchlafLogik.zustand(guteNachtSeit: nil, fokusSchlafen: true, zuhause: true, letzteBewegung: nil, jetzt: jetzt), .schlaeft)
        // Moving right now: not asleep.
        XCTAssertEqual(SchlafLogik.zustand(guteNachtSeit: nil, fokusSchlafen: true, zuhause: true, letzteBewegung: jetzt, jetzt: jetzt), .wach)
        XCTAssertEqual(SchlafLogik.zustand(guteNachtSeit: nil, fokusSchlafen: false, zuhause: true, letzteBewegung: nil, jetzt: jetzt), .wach)
    }

    func testGutenMorgenBeendet() {
        let gn = berlin(24, 23)
        XCTAssertEqual(SchlafLogik.guteNachtSeit(nacht: gn, morgen: nil, jetzt: berlin(25, 2)), gn)
        XCTAssertNil(SchlafLogik.guteNachtSeit(nacht: gn, morgen: berlin(25, 7), jetzt: berlin(25, 7, 1)))
        // An older "Guten Morgen" doesn't undo tonight's "Gute Nacht".
        XCTAssertEqual(SchlafLogik.guteNachtSeit(nacht: gn, morgen: berlin(24, 8), jetzt: berlin(25, 2)), gn)
        // Only since the last 20:00.
        XCTAssertNil(SchlafLogik.guteNachtSeit(nacht: berlin(24, 19), morgen: nil, jetzt: berlin(24, 22)))
        XCTAssertNil(SchlafLogik.guteNachtSeit(nacht: nil, morgen: nil, jetzt: berlin(25, 2)))
    }

    func testImFigurZustand() {
        var e = FigurEingabe(person: .ahmed, jetzt: berlin(25, 2, 35))
        e.guteNacht = berlin(25, 2, 31)
        e.ort = .zuhause
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .sitztImBett)
        e.guteNacht = berlin(25, 2, 29)
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .schlaeft)
        // Walking right now: awake.
        e.bewegung = .laeuft
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .zuhause)
        e.bewegung = nil
        e.letzteBewegung = berlin(25, 2, 34)
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .zuhause)
        // No Home saved: counts as at Home.
        e.letzteBewegung = nil
        e.ort = nil
        e.zuhauseBekannt = false
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .schlaeft)
        // Home saved but somewhere else: never asleep.
        e.zuhauseBekannt = true
        e.ort = .arbeit
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .arbeit)
    }

    func testTitelUndGeteilterZustand() {
        XCTAssertEqual(FigurZustand.sitztImBett.rawValue, "sitztImBett")
        XCTAssertEqual(SchlafZustand(.sitztImBett), .sitzt)
        XCTAssertEqual(SchlafZustand(.schlaeft), .schlaeft)
        XCTAssertEqual(SchlafZustand(nil), .wach)
    }
}
