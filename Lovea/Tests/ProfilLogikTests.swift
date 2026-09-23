import XCTest
@testable import Lovea

final class ProfilLogikTests: XCTestCase {
    func testSternzeichen() {
        XCTAssertEqual(Sternzeichen.fuer(monat: 2, tag: 27).name, "Fische")
        XCTAssertEqual(Sternzeichen.fuer(monat: 6, tag: 6).name, "Zwillinge")
        XCTAssertEqual(Sternzeichen.fuer(monat: 1, tag: 19).name, "Steinbock")
        XCTAssertEqual(Sternzeichen.fuer(monat: 1, tag: 20).name, "Wassermann")
        XCTAssertEqual(Sternzeichen.fuer(monat: 6, tag: 21).name, "Zwillinge")
        XCTAssertEqual(Sternzeichen.fuer(monat: 6, tag: 22).name, "Krebs")
        XCTAssertEqual(Sternzeichen.fuer(monat: 12, tag: 31).name, "Steinbock")
    }

    func testFaceTimeLink() {
        XCTAssertEqual(FaceTimeLink.url("+49 (151) 234-5678", audio: true)?.absoluteString, "facetime-audio://+491512345678")
        XCTAssertEqual(FaceTimeLink.url("0151 2345678", audio: false)?.absoluteString, "facetime://01512345678")
        XCTAssertNil(FaceTimeLink.url("", audio: false))
        XCTAssertNil(FaceTimeLink.url("12", audio: false))
    }
}
