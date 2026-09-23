import XCTest
@testable import Lovea

/// Z-31.2: relative time never shows the future or "in 0 Sek.", calendar days in Europe/Berlin.
final class ZeitTextTests: XCTestCase {
    private let jetzt = Datum.datum("2026-09-23").addingTimeInterval(15 * 3600) // 23.09.2026, 15:00 Berlin

    func testOneHourInTheFutureIsJustNow() {
        XCTAssertEqual(ZeitText.relativ(jetzt.addingTimeInterval(3600), jetzt: jetzt), "gerade eben")
    }

    func testThirtySecondsAgoIsJustNow() {
        XCTAssertEqual(ZeitText.relativ(jetzt.addingTimeInterval(-30), jetzt: jetzt), "gerade eben")
    }

    func testFiveMinutesAgo() {
        XCTAssertEqual(ZeitText.relativ(jetzt.addingTimeInterval(-5 * 60), jetzt: jetzt), "vor 5 Minuten")
    }

    func testPreviousBerlinDayIsYesterday() {
        let yesterdayEvening = Datum.datum("2026-09-22").addingTimeInterval(21 * 3600) // 22.09.2026, 21:00 Berlin
        XCTAssertEqual(ZeitText.relativ(yesterdayEvening, jetzt: jetzt), "gestern")
    }
}
