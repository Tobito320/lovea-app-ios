import XCTest
@testable import Lovea

final class PostLogikTests: XCTestCase {
    func testPunktNurBeiNeuem() {
        XCTAssertFalse(PostLogik.punkt(0))
        XCTAssertTrue(PostLogik.punkt(1))
    }

    func testBeschriftung() {
        XCTAssertEqual(PostLogik.beschriftung("Briefkasten", neu: 0), "Briefkasten")
        XCTAssertEqual(PostLogik.beschriftung("Telefon", neu: 2), "Telefon, 2 neu")
    }
}
