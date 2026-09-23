import XCTest
@testable import Lovea

final class BesondereTageTests: XCTestCase {
    private func berlin(_ tag: Int, _ monat: Int, _ jahr: Int = 2026, _ stunde: Int = 12, _ minute: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal.date(from: DateComponents(year: jahr, month: monat, day: tag, hour: stunde, minute: minute))!
    }

    func testGeburtstagAnnika() {
        let heute = berlin(6, 6)
        XCTAssertTrue(BesondereTage.abzeichen(person: .annika, datum: heute, jahrestag: nil, dateHeute: false).contains("partyhut"))
        XCTAssertFalse(BesondereTage.abzeichen(person: .ahmed, datum: heute, jahrestag: nil, dateHeute: false).contains("partyhut"))
    }

    func testGeburtstagAnnikaUeberBerlinMitternacht() {
        // 00:30 in Berlin ist in UTC noch der 05.06. — scheitert, wenn nicht in Europe/Berlin gerechnet wird.
        let heute = berlin(6, 6, 2026, 0, 30)
        XCTAssertTrue(BesondereTage.abzeichen(person: .annika, datum: heute, jahrestag: nil, dateHeute: false).contains("partyhut"))
    }

    func testGeburtstagAhmed() {
        let heute = berlin(27, 2)
        XCTAssertTrue(BesondereTage.abzeichen(person: .ahmed, datum: heute, jahrestag: nil, dateHeute: false).contains("partyhut"))
        XCTAssertFalse(BesondereTage.abzeichen(person: .annika, datum: heute, jahrestag: nil, dateHeute: false).contains("partyhut"))
    }

    func testJahrestagBeideBekommenHerzaugen() {
        let jahrestag = berlin(26, 8, 2026)
        let heute = berlin(26, 8, 2027)
        XCTAssertTrue(BesondereTage.abzeichen(person: .ahmed, datum: heute, jahrestag: jahrestag, dateHeute: false).contains("herzaugen"))
        XCTAssertTrue(BesondereTage.abzeichen(person: .annika, datum: heute, jahrestag: jahrestag, dateHeute: false).contains("herzaugen"))
    }

    func testJahrestagNurAmTag() {
        let jahrestag = berlin(26, 8, 2026)
        let heute = berlin(27, 8, 2027)
        XCTAssertFalse(BesondereTage.abzeichen(person: .ahmed, datum: heute, jahrestag: jahrestag, dateHeute: false).contains("herzaugen"))
    }

    func testDateTag() {
        let ohne = BesondereTage.abzeichen(person: .ahmed, datum: berlin(10, 3), jahrestag: nil, dateHeute: false)
        XCTAssertFalse(ohne.contains("outfit"))
        let mit = BesondereTage.abzeichen(person: .ahmed, datum: berlin(10, 3), jahrestag: nil, dateHeute: true)
        XCTAssertTrue(mit.contains("outfit"))
    }

    func testMehrereAbzeichenGleichzeitig() {
        let jahrestag = berlin(6, 6, 2020)
        let ergebnis = BesondereTage.abzeichen(person: .annika, datum: berlin(6, 6), jahrestag: jahrestag, dateHeute: true)
        XCTAssertEqual(Set(ergebnis), Set(["partyhut", "herzaugen", "outfit"]))
    }
}
