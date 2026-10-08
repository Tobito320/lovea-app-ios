import XCTest
@testable import Lovea

/// p63: Wiedersehen-Schild und Feier.
final class ZimmerCountdownTests: XCTestCase {
    private func merker() -> UserDefaults { UserDefaults(suiteName: "zimmer-countdown-" + UUID().uuidString)! }

    func testStandAusTageAbstand() {
        XCTAssertEqual(ZimmerCountdown.stand(treffen: nil, heute: "2026-10-08"), .keins)
        XCTAssertEqual(ZimmerCountdown.stand(treffen: "2026-10-08", heute: "2026-10-08"), .heute)
        XCTAssertEqual(ZimmerCountdown.stand(treffen: "2026-10-09", heute: "2026-10-08"), .noch(1))
        XCTAssertEqual(ZimmerCountdown.stand(treffen: "2026-10-11", heute: "2026-10-08"), .noch(3))
        XCTAssertEqual(ZimmerCountdown.stand(treffen: "2026-10-07", heute: "2026-10-08"), .keins)
    }

    func testStandUeberMonatsUndJahresgrenze() {
        XCTAssertEqual(ZimmerCountdown.stand(treffen: "2027-01-02", heute: "2026-12-30"), .noch(3))
    }

    func testTexte() {
        XCTAssertEqual(ZimmerCountdown.text(.noch(3)), "noch 3 Tage")
        XCTAssertEqual(ZimmerCountdown.text(.noch(1)), "noch 1 Tag")
        XCTAssertEqual(ZimmerCountdown.text(.heute), "heute!")
        XCTAssertEqual(ZimmerCountdown.text(.keins), "bald?")
    }

    func testFeierNurAmTagUndEinmalJeTag() {
        let m = merker()
        XCTAssertFalse(ZimmerCountdown.feiern(.noch(2), heute: "2026-10-08", merker: m))
        XCTAssertFalse(ZimmerCountdown.feiern(.keins, heute: "2026-10-08", merker: m))
        XCTAssertTrue(ZimmerCountdown.feiern(.heute, heute: "2026-10-08", merker: m))
        XCTAssertFalse(ZimmerCountdown.feiern(.heute, heute: "2026-10-08", merker: m))
        XCTAssertTrue(ZimmerCountdown.feiern(.heute, heute: "2026-10-15", merker: m))
    }
}
