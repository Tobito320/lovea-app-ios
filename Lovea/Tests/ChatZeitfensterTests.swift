import XCTest
@testable import Lovea

/// Z-33.3: edit within 15 min and at most 5 times, unsend within 2 min.
final class ChatZeitfensterTests: XCTestCase {
    private let gesendet = Date(timeIntervalSince1970: 1_800_000_000)

    private func nach(_ minuten: Int, _ sekunden: Int) -> Date {
        gesendet.addingTimeInterval(TimeInterval(minuten * 60 + sekunden))
    }

    func testBearbeitenBis15Minuten() {
        XCTAssertTrue(ChatZeitfenster.darfBearbeiten(gesendet: gesendet, bearbeitungen: 0, jetzt: nach(14, 59)))
        XCTAssertFalse(ChatZeitfenster.darfBearbeiten(gesendet: gesendet, bearbeitungen: 0, jetzt: nach(15, 1)))
    }

    func testHoechstensFuenfBearbeitungen() {
        XCTAssertTrue(ChatZeitfenster.darfBearbeiten(gesendet: gesendet, bearbeitungen: 4, jetzt: nach(1, 0)), "die 5. Bearbeitung geht noch")
        XCTAssertFalse(ChatZeitfenster.darfBearbeiten(gesendet: gesendet, bearbeitungen: 5, jetzt: nach(1, 0)), "nach 5 Bearbeitungen ist Schluss")
    }

    func testZurueckziehenBis2Minuten() {
        XCTAssertTrue(ChatZeitfenster.darfZurueckziehen(gesendet: gesendet, jetzt: nach(1, 59)))
        XCTAssertFalse(ChatZeitfenster.darfZurueckziehen(gesendet: gesendet, jetzt: nach(2, 1)))
    }
}
