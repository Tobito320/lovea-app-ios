import XCTest
@testable import Lovea

final class GewichtLogikTests: XCTestCase {
    func testSchnittDerLetztenSiebenTage() {
        // 80,0 am 20., dann 78,0 / 79,0 / 78,5 in der Woche bis 27. -> 20. liegt außerhalb.
        let werte = ["2026-09-20": 800, "2026-09-21": 780, "2026-09-24": 790, "2026-09-27": 785]
        XCTAssertEqual(GewichtLogik.berechnet(werte), 785)
    }

    func testFensterEndetAmNeuestenEintrag() {
        XCTAssertEqual(GewichtLogik.berechnet(["2026-08-01": 770, "2026-08-03": 780]), 775)
    }

    func testOhneEintragIstNil() {
        XCTAssertNil(GewichtLogik.berechnet([:]))
        XCTAssertNil(GewichtLogik.berechnet(["2026-09-27": 0]))
    }
}
