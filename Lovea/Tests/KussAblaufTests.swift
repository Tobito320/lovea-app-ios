import XCTest
@testable import Lovea

/// Brief K: the profile kiss timeline (come in, hug, kiss, let go) over the 4 s window.
final class KussAblaufTests: XCTestCase {
    func testAblauf() {
        let start = KussAblauf.stand(0)
        XCTAssertEqual(start.weg, 0)
        XCTAssertEqual(start.arme, 0)
        XCTAssertEqual(start.kuss, 0)
        XCTAssertTrue(start.geht)

        let kommt = KussAblauf.stand(0.35)
        XCTAssertGreaterThan(kommt.weg, 0.3)
        XCTAssertLessThan(kommt.weg, 0.7)
        XCTAssertEqual(kommt.kuss, 0)
        XCTAssertTrue(kommt.geht)

        let umarmt = KussAblauf.stand(1.2)
        XCTAssertEqual(umarmt.weg, 1)
        XCTAssertEqual(umarmt.arme, 1)
        XCTAssertEqual(umarmt.kuss, 0)
        XCTAssertFalse(umarmt.geht)

        XCTAssertEqual(KussAblauf.stand(2.4), KussAblauf.voll)

        for t in [4.0, 5.0, -1.0] {
            let ruhe = KussAblauf.stand(t)
            XCTAssertEqual(ruhe.weg, 0)
            XCTAssertEqual(ruhe.arme, 0)
            XCTAssertEqual(ruhe.kuss, 0)
            XCTAssertFalse(ruhe.geht)
        }
    }

    func testWerteBleibenZwischenNullUndEins() {
        for i in 0...80 {
            let s = KussAblauf.stand(Double(i) * 0.05)
            for wert in [s.weg, s.arme, s.kuss] {
                XCTAssertGreaterThanOrEqual(wert, 0)
                XCTAssertLessThanOrEqual(wert, 1)
            }
        }
    }

    /// Teil 2: a kiss glides the pair into Stufe 3 (head to head); Ahmed is in front there.
    func testKussFuehrtZuKopfAnKopf() {
        let voll = NaehePose.mix(.stufe(0, vorn: .annika), .stufe(3, vorn: .annika), KussAblauf.voll.arme)
        XCTAssertEqual(voll.vorn, .ahmed)
        XCTAssertEqual(voll.annika.hand, .brust)
        XCTAssertLessThan(voll.abstand, 106)
        XCTAssertTrue(KussAblauf.stand(0.3).geht)
    }
}
