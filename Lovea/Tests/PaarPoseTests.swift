import XCTest
@testable import Lovea

final class PaarPoseTests: XCTestCase {
    func testMixGleitetUndSchaltetInDerMitte() {
        let a = NaehePose.stufe(0, vorn: .annika), b = NaehePose.kuss
        XCTAssertEqual(NaehePose.mix(a, b, 0).abstand, 106)
        XCTAssertEqual(NaehePose.mix(a, b, 1).abstand, 34)
        XCTAssertEqual(NaehePose.mix(a, b, 0.25).ahmed.augenZu, false)
        XCTAssertEqual(NaehePose.mix(a, b, 0.75).ahmed.augenZu, true)
        XCTAssertEqual(NaehePose.mix(a, b, 0.75).vorn, .ahmed)
    }

    func testVersatzSymmetrisch() {
        let p = NaehePose.stufe(3, vorn: .ahmed)
        XCTAssertEqual(p.versatz(.ahmed), -p.versatz(.annika))
    }
}
