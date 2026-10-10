import XCTest
@testable import Lovea

/// Zyklus fuer Coach und Bericht: ohne Freigabe nichts, nur vom Geraet, das den Zyklus fuehrt.
@MainActor
final class KiZyklusTests: XCTestCase {
    private let start = "2026-09-01"

    private func plus(_ tag: String, _ n: Int) -> String {
        Datum.text(Datum.kalender.date(byAdding: .day, value: n, to: Datum.datum(tag))!)
    }

    private func logik(heute: String) -> ZyklusLogik {
        let tage = (0..<5).map { ZyklusTag(id: plus(start, $0), blutung: .mittel) }
        return ZyklusLogik(tage: tage, einstellung: ZyklusEinstellung(), heute: heute)
    }

    func testOhneFreigabeNichts() {
        XCTAssertNil(KiZyklus.fuerKi(freigabe: false, nurLesen: false, logik: logik(heute: plus(start, 1)), heute: plus(start, 1)))
    }

    func testAhmedsGeraetSendetNichts() {
        XCTAssertNil(KiZyklus.fuerKi(freigabe: true, nurLesen: true, logik: logik(heute: plus(start, 1)), heute: plus(start, 1)))
    }

    func testMitFreigabeTagUndPhase() {
        let heute = plus(start, 1)
        let r = KiZyklus.fuerKi(freigabe: true, nurLesen: false, logik: logik(heute: heute), heute: heute)
        XCTAssertEqual(r?.tag, 2)
        XCTAssertEqual(r?.phase, "menstruation")
    }

    func testPhasenNamenWieImServer() {
        XCTAssertEqual(KiZyklus.name(.periode), "menstruation")
        XCTAssertEqual(KiZyklus.name(.follikel), "follikel")
        XCTAssertEqual(KiZyklus.name(.fruchtbar), "follikel")
        XCTAssertEqual(KiZyklus.name(.eisprung), "ovulation")
        XCTAssertEqual(KiZyklus.name(.luteal), "luteal")
    }

    func testProfilOhneZyklusHatDieFelderNicht() throws {
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(KiProfil(ziel: "cut", kcal: 2000, protein: 160)), encoding: .utf8))
        XCTAssertFalse(json.contains("zyklus"))
    }

    func testProfilSchickZyklusInServerNamen() throws {
        let p = KiProfil(ziel: "cut", kcal: 2000, protein: 160, zyklusTag: 12, zyklusPhase: "follikel")
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(p), encoding: .utf8))
        XCTAssertTrue(json.contains("\"zyklus_tag\":12"), json)
        XCTAssertTrue(json.contains("\"zyklus_phase\":\"follikel\""), json)
    }
}
