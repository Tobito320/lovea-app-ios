import XCTest
@testable import Lovea

/// Schneller Start (Test): wann darf Start-Arbeit laufen. Reine Entscheidung, ohne UIKit.
final class StartPlanTests: XCTestCase {

    func testSchalterStandardAn() {
        let defaults = UserDefaults(suiteName: "lovea.test.startPlan")!
        defaults.removePersistentDomain(forName: "lovea.test.startPlan")

        XCTAssertEqual(StartPlan.schluessel, "lovea.schnellerStart")
        XCTAssertTrue(StartPlan.an(defaults))
        defaults.set(false, forKey: StartPlan.schluessel)
        XCTAssertFalse(StartPlan.an(defaults))
        defaults.set(true, forKey: StartPlan.schluessel)
        XCTAssertTrue(StartPlan.an(defaults))
        defaults.removePersistentDomain(forName: "lovea.test.startPlan")
    }

    func testAusIstImmerSofort() {
        XCTAssertEqual(StartPlan.zeitpunkt(schneller: false, hintergrundStart: false), .sofort)
        XCTAssertEqual(StartPlan.zeitpunkt(schneller: false, hintergrundStart: true), .sofort)
    }

    func testAnImVordergrundWartetAufErstesBild() {
        XCTAssertEqual(StartPlan.zeitpunkt(schneller: true, hintergrundStart: false), .nachErstemBild)
    }

    /// Ein Hintergrund-Start (HealthKit, Silent-Push) bekommt nie ein erstes Bild: nicht warten,
    /// sonst bliebe das Widget ohne Update.
    func testAnImHintergrundStartIstSofort() {
        XCTAssertEqual(StartPlan.zeitpunkt(schneller: true, hintergrundStart: true), .sofort)
    }
}
