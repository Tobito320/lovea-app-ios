import XCTest
@testable import Lovea

/// Stimmungspflanze: Serie, Stufen, Hängen und die gemeinsame Aufgabe als reine Logik.
final class StimmungsPflanzeLogikTests: XCTestCase {
    private typealias L = StimmungsPflanzeLogik
    private let heute = "2026-10-09"

    func testVortagUeberMonatsgrenze() {
        XCTAssertEqual(L.vortag("2026-10-01"), "2026-09-30")
        XCTAssertEqual(L.vortag("2026-01-01"), "2025-12-31")
    }

    func testNochNieGegossenIstSetzlingUndHaengtNicht() {
        let s = L.stand(tage: [], heute: heute)
        XCTAssertEqual(s, L.Stand(stufe: 0, serie: 0, haengt: false, heuteGegossen: false))
    }

    func testHeuteGegossenZaehltSerieBisHeute() {
        let s = L.stand(tage: ["2026-10-07", "2026-10-08", "2026-10-09"], heute: heute)
        XCTAssertEqual(s.serie, 3)
        XCTAssertEqual(s.stufe, 2)
        XCTAssertTrue(s.heuteGegossen)
        XCTAssertFalse(s.haengt)
    }

    func testHeuteNochNichtGegossenBrichtDieSerieNichtUndHaengtNicht() {
        let s = L.stand(tage: ["2026-10-07", "2026-10-08"], heute: heute)
        XCTAssertEqual(s.serie, 2)
        XCTAssertEqual(s.stufe, 1)
        XCTAssertFalse(s.heuteGegossen)
        XCTAssertFalse(s.haengt)
    }

    func testEinTagAusgelassenLaesstSieHaengenMitSerieNull() {
        let s = L.stand(tage: ["2026-10-05", "2026-10-06", "2026-10-07"], heute: heute)
        XCTAssertEqual(s.serie, 0)
        XCTAssertEqual(s.stufe, 0)
        XCTAssertTrue(s.haengt)
    }

    func testNachDemHaengenGiessenRichtetSieWiederAuf() {
        let s = L.stand(tage: ["2026-10-05", "2026-10-09"], heute: heute)
        XCTAssertEqual(s.serie, 1)
        XCTAssertEqual(s.stufe, 1)
        XCTAssertFalse(s.haengt)
    }

    func testStufenSchwellen() {
        XCTAssertEqual(L.stufe(serie: 0), 0)
        XCTAssertEqual(L.stufe(serie: 1), 1)
        XCTAssertEqual(L.stufe(serie: 2), 1)
        XCTAssertEqual(L.stufe(serie: 3), 2)
        XCTAssertEqual(L.stufe(serie: 6), 2)
        XCTAssertEqual(L.stufe(serie: 7), 3)
        XCTAssertEqual(L.stufe(serie: 13), 3)
        XCTAssertEqual(L.stufe(serie: 14), 4)
        XCTAssertEqual(L.stufe(serie: 99), L.hoechststufe)
    }

    func testSerieUeberMonatsgrenze() {
        XCTAssertEqual(L.serie(tage: ["2026-09-29", "2026-09-30", "2026-10-01"], heute: "2026-10-01"), 3)
    }

    func testGegossenFuegtHeuteEinSortiertUndKuerzt() {
        XCTAssertEqual(L.gegossen(["2026-10-08", "2026-10-09"], heute: heute), ["2026-10-08", "2026-10-09"])
        XCTAssertEqual(L.gegossen(["2026-10-08"], heute: heute), ["2026-10-08", "2026-10-09"])
        let viele = (1...40).map { String(format: "2026-08-%02d", min($0, 31)) + ($0 > 31 ? "x\($0)" : "") }
        XCTAssertEqual(L.gegossen(viele, heute: heute).count, L.behalteTage)
        XCTAssertEqual(L.gegossen(viele, heute: heute).last, heute)
    }

    func testBeideHeute() {
        XCTAssertTrue(L.beideHeute(ich: [heute], partner: [heute, "2026-10-01"], heute: heute))
        XCTAssertFalse(L.beideHeute(ich: [heute], partner: ["2026-10-08"], heute: heute))
        XCTAssertFalse(L.beideHeute(ich: [], partner: [heute], heute: heute))
    }
}
