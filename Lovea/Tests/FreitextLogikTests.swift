import XCTest
@testable import Lovea

final class FreitextLogikTests: XCTestCase {
    private let tag = "2026-09-27"

    private func uhr(_ tag: String, _ h: Int, _ m: Int) -> Date {
        Datum.kalender.date(bySettingHour: h, minute: m, second: 0, of: Datum.datum(tag))!
    }

    func testAhmedsSatzMitTippfehlern() {
        let e = FreitextLogik.lesen("Hab 23 Uhr geschlafn und bin un 5 uhr sufgescjr.", tag: tag)
        XCTAssertEqual(e, [.schlaf(bett: uhr("2026-09-26", 23, 0), auf: uhr(tag, 5, 0))])
    }

    func testAllesInEinemSatz() {
        let e = FreitextLogik.lesen("Um 23:30 ins Bett, 6:15 aufgestanden, 78,4 kg, 1,5 l getrunken, 7g Creatin", tag: tag)
        XCTAssertEqual(e, [
            .schlaf(bett: uhr("2026-09-26", 23, 30), auf: uhr(tag, 6, 15)),
            .gewicht(zehntel: 784),
            .wasser(glaeser: 6),
            .creatin(klicks: 2),
        ])
    }

    func testNachMitternachtUndHalb() {
        let e = FreitextLogik.lesen("erst halb 1 eingeschlafen, 8 uhr wach", tag: tag)
        XCTAssertEqual(e, [.schlaf(bett: uhr(tag, 0, 30), auf: uhr(tag, 8, 0))])
    }

    func testCreatinOhneMengeIstEinKlick() {
        XCTAssertEqual(FreitextLogik.lesen("creatin genommen", tag: tag), [.creatin(klicks: 1)])
        XCTAssertEqual(FreitextLogik.lesen("2x kreatin", tag: tag), [.creatin(klicks: 2)])
    }

    func testWasserInGlaesernUndKaffeeNicht() {
        XCTAssertEqual(FreitextLogik.lesen("3 Gläser Wasser", tag: tag), [.wasser(glaeser: 3)])
        XCTAssertEqual(FreitextLogik.lesen("500 ml", tag: tag), [.wasser(glaeser: 2)])
        XCTAssertEqual(FreitextLogik.lesen("kaffee getrunken", tag: tag), [])
    }

    func testNurEineUhrzeitIstKeinSchlaf() {
        XCTAssertEqual(FreitextLogik.lesen("um 7 uhr aufgestanden", tag: tag), [])
    }

    func testCreatinIstEingebautUndNurHeute() {
        XCTAssertTrue(Habit.eingebaut.contains { $0.id == "creatin" })
        XCTAssertTrue(Habit.nurHeute.contains("creatin"))
        XCTAssertEqual(Habit.creatin.tagesziel, 2)
    }
}
