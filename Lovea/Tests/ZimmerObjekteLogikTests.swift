import XCTest
@testable import Lovea

final class ZimmerObjekteLogikTests: XCTestCase {
    func testSchweinStufe() {
        XCTAssertEqual(ZimmerObjekteLogik.schweinStufe(punkte: -5), 0)
        XCTAssertEqual(ZimmerObjekteLogik.schweinStufe(punkte: 0), 0)
        XCTAssertEqual(ZimmerObjekteLogik.schweinStufe(punkte: 1), 1)
        XCTAssertEqual(ZimmerObjekteLogik.schweinStufe(punkte: 24), 1)
        XCTAssertEqual(ZimmerObjekteLogik.schweinStufe(punkte: 25), 2)
        XCTAssertEqual(ZimmerObjekteLogik.schweinStufe(punkte: 99), 2)
        XCTAssertEqual(ZimmerObjekteLogik.schweinStufe(punkte: 100), 3)
        XCTAssertEqual(ZimmerObjekteLogik.schweinStufe(punkte: 250), 4)
        XCTAssertEqual(ZimmerObjekteLogik.schweinStufe(punkte: 500), 5)
        XCTAssertEqual(ZimmerObjekteLogik.schweinStufe(punkte: 99_999), 5)
    }

    func testSchweinFuellung() {
        XCTAssertEqual(ZimmerObjekteLogik.schweinFuellung(punkte: 0), 0)
        XCTAssertEqual(ZimmerObjekteLogik.schweinFuellung(punkte: 100), 0.6, accuracy: 0.0001)
        XCTAssertEqual(ZimmerObjekteLogik.schweinFuellung(punkte: 1000), 1)
    }

    func testBriefStapel() {
        XCTAssertEqual(ZimmerObjekteLogik.briefStapel(ungeoeffnet: 0), .init(sichtbar: 0, ueberlauf: 0))
        XCTAssertEqual(ZimmerObjekteLogik.briefStapel(ungeoeffnet: 3), .init(sichtbar: 3, ueberlauf: 0))
        XCTAssertEqual(ZimmerObjekteLogik.briefStapel(ungeoeffnet: 4), .init(sichtbar: 4, ueberlauf: 0))
        XCTAssertEqual(ZimmerObjekteLogik.briefStapel(ungeoeffnet: 7), .init(sichtbar: 4, ueberlauf: 3))
        XCTAssertEqual(ZimmerObjekteLogik.briefStapel(ungeoeffnet: -2), .init(sichtbar: 0, ueberlauf: 0))
    }

    func testFahne() {
        XCTAssertFalse(ZimmerObjekteLogik.fahneOben(ungeoeffnet: 0))
        XCTAssertTrue(ZimmerObjekteLogik.fahneOben(ungeoeffnet: 1))
    }

    func testZiffern() {
        XCTAssertEqual(ZimmerObjekteLogik.ziffern(ungehoert: 0), "00")
        XCTAssertEqual(ZimmerObjekteLogik.ziffern(ungehoert: 7), "07")
        XCTAssertEqual(ZimmerObjekteLogik.ziffern(ungehoert: 150), "99")
    }

    func testHerzen() {
        let heute: [Person: Int] = [.ahmed: 3, .annika: 5]
        XCTAssertEqual(ZimmerObjekteLogik.herzenErhalten(heute: heute, ich: .ahmed), 5)
        XCTAssertEqual(ZimmerObjekteLogik.herzenErhalten(heute: heute, ich: .annika), 3)
        XCTAssertEqual(ZimmerObjekteLogik.herzenErhalten(heute: [:], ich: .ahmed), 0)
        XCTAssertEqual(ZimmerObjekteLogik.herzenErhalten(heute: heute, ich: nil), 0)
        XCTAssertEqual(ZimmerObjekteLogik.glasHerzen(erhalten: 5), 5)
        XCTAssertEqual(ZimmerObjekteLogik.glasHerzen(erhalten: 40), ZimmerObjekteLogik.glasHoechstens)
    }

    func testTageBisMeilenstein() {
        // Start 2026-08-26, erster Meilenstein nach einem Monat: 2026-09-26.
        XCTAssertEqual(ZimmerObjekteLogik.tageBis(heute: "2026-09-25"), 1)
        XCTAssertEqual(ZimmerObjekteLogik.tageBis(heute: "2026-09-16"), 10)
    }

    func testMeilensteinTag() {
        XCTAssertTrue(ZimmerObjekteLogik.istMeilensteinTag(heute: "2026-09-26"))
        XCTAssertFalse(ZimmerObjekteLogik.istMeilensteinTag(heute: "2026-09-25"))
        XCTAssertFalse(ZimmerObjekteLogik.istMeilensteinTag(heute: "2026-09-27"))
        XCTAssertFalse(ZimmerObjekteLogik.istMeilensteinTag(heute: "2026-08-26"))
        XCTAssertEqual(ZimmerObjekteLogik.meilensteinHeute(heute: "2026-09-26"), "1 Monat")
        XCTAssertNil(ZimmerObjekteLogik.meilensteinHeute(heute: "2026-09-27"))
    }
}
