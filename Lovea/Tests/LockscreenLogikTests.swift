import XCTest
@testable import Lovea

/// Sperrbildschirm-Widgets "Wiedersehen" und "Schlaf": reine Rechnung, kein App Group nötig.
final class LockscreenLogikTests: XCTestCase {
    func testTageBisTreffen() {
        XCTAssertEqual(LockscreenLogik.tageBis(treffen: "2026-10-18", heute: "2026-10-08"), 10)
        XCTAssertEqual(LockscreenLogik.tageBis(treffen: "2026-10-08", heute: "2026-10-08"), 0)
    }

    func testVergangenesOderFehlendesTreffenGibtNil() {
        XCTAssertNil(LockscreenLogik.tageBis(treffen: "2026-10-01", heute: "2026-10-08"))
        XCTAssertNil(LockscreenLogik.tageBis(treffen: nil, heute: "2026-10-08"))
    }

    func testCountdownText() {
        XCTAssertEqual(LockscreenLogik.countdownText(tage: 0), "heute")
        XCTAssertEqual(LockscreenLogik.countdownText(tage: 1), "morgen")
        XCTAssertEqual(LockscreenLogik.countdownText(tage: 12), "in 12 Tagen")
    }

    func testDatumKurzUndSchlafText() {
        XCTAssertEqual(LockscreenLogik.datumKurz("2026-10-08"), "8.10.")
        XCTAssertEqual(LockscreenLogik.schlafText(minuten: 432), "7:12")
        XCTAssertEqual(LockscreenLogik.schlafText(minuten: 485), "8:05")
    }

    func testAlterWidgetStandOhneNeueFelderLaesstSichLesen() throws {
        let alt = Data(#"{"eigenePerson":"ahmed","schritteHeute":{},"zielSchritte":{},"gymLetzte7":{},"zielGymWoche":{},"punkte":{},"partnerFigurVorhanden":false,"partnerFotoVorhanden":false}"#.utf8)
        let stand = try JSONDecoder().decode(WidgetStand.self, from: alt)
        XCTAssertNil(stand.naechstesTreffen)
        XCTAssertNil(stand.schlafMinutenHeute)
    }
}
