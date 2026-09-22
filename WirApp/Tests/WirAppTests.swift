import XCTest
@testable import WirApp

final class WirAppTests: XCTestCase {
    func testAppTitleIsWir() {
        XCTAssertEqual(AppConfiguration.title, "Wir")
    }
}
