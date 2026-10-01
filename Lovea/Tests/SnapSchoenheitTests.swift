import XCTest
@testable import Lovea

/// Pure part of the front-camera beauty filter (Z-R9): the blend-strength clamp. The CoreImage
/// pipeline itself needs a device/simulator, this doesn't.
final class SnapSchoenheitTests: XCTestCase {
    func testStaerkeImGueltigenBereichBleibtUnveraendert() {
        XCTAssertEqual(SnapSchoenheit.geklemmteStaerke(0.28), 0.28)
    }

    func testNegativeStaerkeWirdAufNullGeklemmt() {
        XCTAssertEqual(SnapSchoenheit.geklemmteStaerke(-0.5), 0)
    }

    func testStaerkeUeberEinsWirdAufEinsGeklemmt() {
        XCTAssertEqual(SnapSchoenheit.geklemmteStaerke(1.4), 1)
    }

    /// Ahmeds Vorgabe: "~25-30 %".
    func testVorgabeStaerkeIstSubtil() {
        XCTAssertGreaterThanOrEqual(SnapSchoenheit.staerke, 0.25)
        XCTAssertLessThanOrEqual(SnapSchoenheit.staerke, 0.30)
    }
}
