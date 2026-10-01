import XCTest
@testable import Lovea

/// Pure math behind the lens pill (Z-R9): which chips a device offers, which one is "live", and how
/// a raw zoom factor becomes its label. No `AVCaptureDevice` needed.
final class KameraLinsenPilleTests: XCTestCase {
    func testWerteOhneUltraweitwinkel() {
        // Ein Gerät ohne Zoom unter 1x (z. B. Dual Camera ohne Ultraweitwinkel): nur 1x und Tele.
        let werte = KameraLinse.werte(minZoom: 1, switchOverFaktoren: [2], maxZoom: 5)
        XCTAssertEqual(werte, [1, 2])
    }

    func testWerteMitUltraweitwinkelUndTele() {
        // Triple Camera: Ultraweitwinkel (0.5), Weitwinkel (1), Tele (ein Switch-over-Faktor > 1).
        let werte = KameraLinse.werte(minZoom: 0.5, switchOverFaktoren: [2, 8], maxZoom: 8)
        XCTAssertEqual(werte, [0.5, 1, 2, 8])
    }

    func testSwitchOverUeberDemMaxZoomFaelltWeg() {
        let werte = KameraLinse.werte(minZoom: 0.5, switchOverFaktoren: [2, 15], maxZoom: 8)
        XCTAssertEqual(werte, [0.5, 1, 2])
    }

    func testOhneTeleBleibtNurWeitwinkel() {
        let werte = KameraLinse.werte(minZoom: 1, switchOverFaktoren: [], maxZoom: 1)
        XCTAssertEqual(werte, [1])
    }

    func testAktiverIndexWaehltDenHoechstenNichtUeberschrittenenWert() {
        let werte: [CGFloat] = [0.5, 1, 2]
        XCTAssertEqual(KameraLinse.aktiverIndex(werte: werte, zoomFaktor: 0.5), 0)
        XCTAssertEqual(KameraLinse.aktiverIndex(werte: werte, zoomFaktor: 0.9), 0)
        XCTAssertEqual(KameraLinse.aktiverIndex(werte: werte, zoomFaktor: 1), 1)
        XCTAssertEqual(KameraLinse.aktiverIndex(werte: werte, zoomFaktor: 2.7), 2)
    }

    func testAnzeigeEinsIstEinfachEinX() {
        XCTAssertEqual(KameraLinse.anzeige(1), "1x")
    }

    func testAnzeigeUnterEinsOhneFuehrendeNull() {
        XCTAssertEqual(KameraLinse.anzeige(0.5), ".5")
    }

    func testAnzeigeMitKommawertWieImReferenzScreenshot() {
        XCTAssertEqual(KameraLinse.anzeige(2.7), "2.7x")
    }

    func testAnzeigeGanzzahligerTeleWert() {
        XCTAssertEqual(KameraLinse.anzeige(5), "5x")
    }
}
