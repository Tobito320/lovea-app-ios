import XCTest
@testable import Lovea

final class MengenRadLogikTests: XCTestCase {
    func testZusammensetzen() {
        XCTAssertEqual(MengenRad.zahl(ganz: 721, bruch: 7), 721.875)   // 7 = Index von 7/8
        XCTAssertEqual(MengenRad.zahl(ganz: 1, bruch: 0), 1)
    }

    func testZerlegen() {
        XCTAssertEqual(MengenRad.zerlegen(721.875).ganz, 721)
        XCTAssertEqual(MengenRad.brueche[MengenRad.zerlegen(721.875).bruch].text, "⅞")
        XCTAssertEqual(MengenRad.brueche[MengenRad.zerlegen(0.3).bruch].text, "⅓")
        XCTAssertEqual(MengenRad.zerlegen(500).ganz, 500)
        XCTAssertEqual(MengenRad.zerlegen(99999).ganz, MengenRad.maxGanz)
    }

    func testFeldText() {
        XCTAssertEqual(MengenRad.feldText(721.875), "721,875")
        XCTAssertEqual(MengenRad.feldText(500), "500")
        XCTAssertEqual(MengenRad.feldText(0.5), "0,5")
    }

    func testEingabe() {
        XCTAssertEqual(ErnaehrungLogik.eingabe("0,5"), 0.5)
        XCTAssertEqual(ErnaehrungLogik.eingabe("1.5"), 1.5)
        XCTAssertEqual(ErnaehrungLogik.eingabe("500"), 500)
        XCTAssertNil(ErnaehrungLogik.eingabe(""))
        XCTAssertNil(ErnaehrungLogik.eingabe("abc"))
        XCTAssertEqual(ErnaehrungLogik.eingabe("99999"), 99999)
    }
}
