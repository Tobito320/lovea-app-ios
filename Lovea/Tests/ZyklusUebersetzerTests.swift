import XCTest
@testable import Lovea

final class ZyklusUebersetzerTests: XCTestCase {
    func testOhnePhaseKeineBotschaft() {
        XCTAssertNil(ZyklusUebersetzer.fuer(phase: nil, tag: nil))
    }

    func testJedePhaseHatWunschUndTipps() {
        for p in Phase.allCases {
            let b = ZyklusUebersetzer.fuer(phase: p, tag: nil)
            XCTAssertNotNil(b)
            XCTAssertFalse(b!.wunsch.isEmpty)
            XCTAssertEqual(b!.tipps.count, 3)
        }
    }

    func testTraurigGehtVorPhase() {
        let tag = ZyklusTag(id: "2026-10-08", stimmung: [.traurig])
        let b = ZyklusUebersetzer.fuer(phase: .follikel, tag: tag)!
        XCTAssertEqual(b.wunsch, "Sicherheit und Nähe")
        XCTAssertEqual(b.tipps.first, "Sag ihr klar: Ich bin da und ich bleibe")
    }

    func testSchmerzenGebenWaermeTipp() {
        let tag = ZyklusTag(id: "2026-10-08", symptome: [.kraempfe])
        let b = ZyklusUebersetzer.fuer(phase: .periode, tag: tag)!
        XCTAssertEqual(b.wunsch, "Wärme und Fürsorge")
        XCTAssertTrue(b.tipps.contains("Sie hat Schmerzen: Wärmflasche, Tee, Ruhe"))
        XCTAssertLessThanOrEqual(b.tipps.count, 3)
    }
}
