import XCTest
@testable import Lovea

final class HealthDatenTests: XCTestCase {
    func testGewichtKommaWirdZehntel() {
        XCTAssertEqual(GewichtText.zehntel("78,4"), 784)
        XCTAssertEqual(GewichtText.zehntel("78.4"), 784)
        XCTAssertEqual(GewichtText.zehntel("78"), 780)
        XCTAssertEqual(GewichtText.zehntel(" 78,45 "), 785)
        XCTAssertNil(GewichtText.zehntel("abc"))
        XCTAssertNil(GewichtText.zehntel(""))
        XCTAssertNil(GewichtText.zehntel("-5"))
        XCTAssertNil(GewichtText.zehntel("inf"))
        XCTAssertEqual(GewichtText.anzeige(784), "78,4 kg")
        XCTAssertEqual(GewichtText.anzeige(780), "78,0 kg")
    }

    func testNeueHabitsSindEingebaut() {
        XCTAssertTrue(Habit.eingebaut.contains { $0.id == "koffein" })
        XCTAssertTrue(Habit.eingebaut.contains { $0.id == "protein" })
        XCTAssertTrue(Habit.eingebaut.contains { $0.id == "gewicht" })
    }

    func testNeueHabitsNichtInAlterListe() {
        let ids = Habit.sichtbar.map(\.id)
        XCTAssertFalse(ids.contains("koffein"))
        XCTAssertFalse(ids.contains("protein"))
        XCTAssertFalse(ids.contains("gewicht"))
        XCTAssertTrue(ids.contains("gym"))
        XCTAssertTrue(ids.contains("wasser"))
    }

    func testHabitIdsEindeutig() {
        XCTAssertEqual(Set(Habit.eingebaut.map(\.id)).count, Habit.eingebaut.count)
    }
}
