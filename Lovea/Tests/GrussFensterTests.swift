import XCTest
@testable import Lovea

final class GrussFensterTests: XCTestCase {
    private let jetzt = Date(timeIntervalSince1970: 1_790_000_000)

    func testMorgenNur4bis9UndEinmalAmTag() {
        XCTAssertEqual(GrussFenster.knopf(stunde: 4, jetzt: jetzt, letzteNacht: nil, morgenGesendetHeute: false), "morgen")
        XCTAssertEqual(GrussFenster.knopf(stunde: 8, jetzt: jetzt, letzteNacht: nil, morgenGesendetHeute: false), "morgen")
        XCTAssertNil(GrussFenster.knopf(stunde: 8, jetzt: jetzt, letzteNacht: nil, morgenGesendetHeute: true))
        XCTAssertNil(GrussFenster.knopf(stunde: 9, jetzt: jetzt, letzteNacht: nil, morgenGesendetHeute: false))
    }

    func testNachtAb20bis4() {
        XCTAssertNil(GrussFenster.knopf(stunde: 19, jetzt: jetzt, letzteNacht: nil, morgenGesendetHeute: false))
        XCTAssertEqual(GrussFenster.knopf(stunde: 20, jetzt: jetzt, letzteNacht: nil, morgenGesendetHeute: false), "nacht")
        XCTAssertEqual(GrussFenster.knopf(stunde: 2, jetzt: jetzt, letzteNacht: nil, morgenGesendetHeute: false), "nacht")
        XCTAssertNil(GrussFenster.knopf(stunde: 14, jetzt: jetzt, letzteNacht: nil, morgenGesendetHeute: false))
    }

    func testNachtFruehestensNach5Minuten() {
        let vor4 = jetzt.addingTimeInterval(-4 * 60)
        let vor5 = jetzt.addingTimeInterval(-5 * 60)
        XCTAssertNil(GrussFenster.knopf(stunde: 22, jetzt: jetzt, letzteNacht: vor4, morgenGesendetHeute: false))
        XCTAssertEqual(GrussFenster.knopf(stunde: 22, jetzt: jetzt, letzteNacht: vor5, morgenGesendetHeute: false), "nacht")
    }
}
