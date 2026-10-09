import XCTest
@testable import Lovea

/// Z-32.2: FaceTime links from a typed number or Apple-ID mail.
final class FaceTimeTests: XCTestCase {
    func testNummerMitLeerzeichenUndBindestrich() {
        XCTAssertEqual(FaceTime.url(audio: false, kontakt: "0151 234-5678")?.absoluteString, "facetime://01512345678")
    }

    func testPlus49UndKlammernBleibenNurPlus() {
        XCTAssertEqual(FaceTime.url(audio: true, kontakt: "+49 (151) 234 5678")?.absoluteString, "facetime-audio://+491512345678")
    }

    func testMailBleibtWieGetippt() {
        XCTAssertEqual(FaceTime.url(audio: false, kontakt: " annika@icloud.com ")?.absoluteString, "facetime://annika@icloud.com")
        XCTAssertEqual(FaceTime.url(audio: true, kontakt: "annika@icloud.com")?.absoluteString, "facetime-audio://annika@icloud.com")
    }

    func testLeerIstNil() {
        XCTAssertNil(FaceTime.url(audio: false, kontakt: ""))
        XCTAssertNil(FaceTime.url(audio: true, kontakt: "   "))
        XCTAssertNil(FaceTime.url(audio: false, kontakt: "(-)"))
    }
}
