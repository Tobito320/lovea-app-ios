import XCTest
@testable import Lovea

final class SatzzeitTests: XCTestCase {
    override func setUp() { UserDefaults.standard.removeObject(forKey: WorkoutLogik.satzzeitSchluessel) }
    override func tearDown() { UserDefaults.standard.removeObject(forKey: WorkoutLogik.satzzeitSchluessel) }

    func testStandardAus() {
        XCTAssertFalse(WorkoutLogik.satzzeitAn)
        XCTAssertEqual(WorkoutLogik.zeitenText(sek: 42, pause: 118, satzzeit: WorkoutLogik.satzzeitAn), "Pause 1:58")
        XCTAssertNil(WorkoutLogik.zeitenText(sek: 42, pause: nil, satzzeit: false))
    }

    func testSchalterAnZeigtSatzzeit() {
        UserDefaults.standard.set(true, forKey: WorkoutLogik.satzzeitSchluessel)
        XCTAssertTrue(WorkoutLogik.satzzeitAn)
        XCTAssertEqual(WorkoutLogik.zeitenText(sek: 42, pause: 118, satzzeit: true), "Satz 0:42 · Pause 1:58")
        XCTAssertEqual(WorkoutLogik.zeitenText(sek: 42, pause: nil, satzzeit: true), "Satz 0:42")
    }

    func testGespeicherteWerteBleibenUnveraendert() {
        var satz = PlanSatz(wdh: 8, kg: nil, failure: false)
        satz.sek = 30
        _ = WorkoutLogik.zeitenText(sek: satz.sek, pause: satz.pause, satzzeit: false)
        XCTAssertEqual(satz.sek, 30)
    }
}
