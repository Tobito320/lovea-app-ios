import XCTest
@testable import Lovea

/// Szene belebt: Schalter, Ziel per Tippen und Ziehen auf die eigene Figur.
final class ZuhauseBelebungTests: XCTestCase {
    func testLaeuftNurMitSchalterUndAktiverSzene() {
        XCTAssertTrue(ZuhauseBelebung.laeuft(an: true, aktiv: true))
        XCTAssertFalse(ZuhauseBelebung.laeuft(an: false, aktiv: true))
        XCTAssertFalse(ZuhauseBelebung.laeuft(an: true, aktiv: false))
    }

    func testZiehenWaehltDenNaechstenPlatz() {
        for p in Platz.allCases {
            let x = ZuhauseOrte.fuss(p, .ahmed, welt: .panorama).x
            XCTAssertEqual(ZuhauseBelebung.naechsterPlatz(x: x + 3, person: .ahmed, welt: .panorama), p)
        }
    }

    func testTippenGehtReihumWeiter() {
        var p = Platz.bett
        for _ in Platz.allCases { p = ZuhauseBelebung.weiter(von: p) }
        XCTAssertEqual(p, .bett)
        XCTAssertNotEqual(ZuhauseBelebung.weiter(von: .sofa), .sofa)
    }
}
