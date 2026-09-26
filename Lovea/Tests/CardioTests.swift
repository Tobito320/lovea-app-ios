import XCTest
@testable import Lovea

final class CardioTests: XCTestCase {
    func testSchritteGeschaetzt() {
        XCTAssertEqual(CardioEintrag(datum: "2026-09-23", geraet: "laufband", minuten: 40, km: 2.47).schritteCa, 3211)
        XCTAssertEqual(CardioEintrag(datum: "2026-09-23", geraet: "stairmaster", minuten: 20, stufen: 900).schritteCa, 900)
        XCTAssertNil(CardioEintrag(datum: "2026-09-23", geraet: "laufband", minuten: 40).schritteCa)
    }
}
