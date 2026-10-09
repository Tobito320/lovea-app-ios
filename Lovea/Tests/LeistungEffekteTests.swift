import XCTest
@testable import Lovea

final class LeistungEffekteTests: XCTestCase {
    func testStandardIstAn() {
        let defaults = UserDefaults(suiteName: "LeistungEffekteTests")!
        defaults.removePersistentDomain(forName: "LeistungEffekteTests")
        XCTAssertTrue(LeistungEffekte.an(defaults))
        defaults.set(false, forKey: LeistungEffekte.schluessel)
        XCTAssertFalse(LeistungEffekte.an(defaults))
    }

    func testBildrateWirdNurBeiAusGedeckelt() {
        XCTAssertEqual(LeistungEffekte.bildrate(normal: 30, effekte: true), 30)
        XCTAssertEqual(LeistungEffekte.bildrate(normal: 30, effekte: false), LeistungEffekte.figurBildrate)
        XCTAssertEqual(LeistungEffekte.bildrate(normal: 5, effekte: false), 5)
    }
}
