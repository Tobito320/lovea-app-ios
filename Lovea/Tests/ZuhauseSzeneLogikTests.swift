import XCTest
@testable import Lovea

/// p70: Leerlauf der Figuren, schlafender Offline-Partner, Herz auf die Stimmungsblase, Zonen-Haptik.
final class ZuhauseSzeneLogikTests: XCTestCase {
    func testLeerlaufNurWennAktiv() {
        let still = ZuhauseSzeneLogik.bewegung(geht: false, geste: false, aktiv: false)
        XCTAssertFalse(still.animiert)
        let leer = ZuhauseSzeneLogik.bewegung(geht: false, geste: false, aktiv: true)
        XCTAssertTrue(leer.animiert)
        XCTAssertEqual(leer.bildrate, ZuhauseSzeneLogik.leerlaufRate)
        XCTAssertLessThan(leer.bildrate, ZuhauseSzeneLogik.bewegtRate)
    }

    func testGehenUndGesteBleibenSchnell() {
        for aktiv in [true, false] {
            let geht = ZuhauseSzeneLogik.bewegung(geht: true, geste: false, aktiv: aktiv)
            XCTAssertTrue(geht.animiert)
            XCTAssertEqual(geht.bildrate, ZuhauseSzeneLogik.bewegtRate)
            let geste = ZuhauseSzeneLogik.bewegung(geht: false, geste: true, aktiv: aktiv)
            XCTAssertTrue(geste.animiert)
            XCTAssertEqual(geste.bildrate, ZuhauseSzeneLogik.bewegtRate)
        }
    }

    func testNurDerPartnerSchlaeftWennOffline() {
        XCTAssertTrue(ZuhauseSzeneLogik.schlaeftOffline(.annika, ich: .ahmed, verbunden: true, partnerDa: false))
        XCTAssertFalse(ZuhauseSzeneLogik.schlaeftOffline(.ahmed, ich: .ahmed, verbunden: true, partnerDa: false))
        XCTAssertTrue(ZuhauseSzeneLogik.schlaeftOffline(.ahmed, ich: .annika, verbunden: true, partnerDa: false))
        XCTAssertFalse(ZuhauseSzeneLogik.schlaeftOffline(.annika, ich: .ahmed, verbunden: true, partnerDa: true))
    }

    func testOhneVerbindungOderPersonSchlaeftNiemand() {
        for p in Person.allCases {
            XCTAssertFalse(ZuhauseSzeneLogik.schlaeftOffline(p, ich: .ahmed, verbunden: false, partnerDa: false))
            XCTAssertFalse(ZuhauseSzeneLogik.schlaeftOffline(p, ich: nil, verbunden: true, partnerDa: false))
        }
    }

    func testLiegendeImBett() {
        XCTAssertEqual(ZuhauseSzeneLogik.liegende(beide: true, schlaefer: nil), [.annika, .ahmed])
        XCTAssertEqual(ZuhauseSzeneLogik.liegende(beide: true, schlaefer: .annika), [.annika, .ahmed])
        XCTAssertEqual(ZuhauseSzeneLogik.liegende(beide: false, schlaefer: .annika), [.annika])
        XCTAssertEqual(ZuhauseSzeneLogik.liegende(beide: false, schlaefer: .ahmed), [.ahmed])
        XCTAssertEqual(ZuhauseSzeneLogik.liegende(beide: false, schlaefer: nil), [])
    }

    func testLeereKissen() {
        XCTAssertEqual(ZuhauseSzeneLogik.leereKissen(schlafende: []), [112, 188])
        XCTAssertEqual(ZuhauseSzeneLogik.leereKissen(schlafende: [.annika]), [188])
        XCTAssertEqual(ZuhauseSzeneLogik.leereKissen(schlafende: [.ahmed]), [112])
        XCTAssertEqual(ZuhauseSzeneLogik.leereKissen(schlafende: [.annika, .ahmed]), [])
    }

    func testHerzNurAlleZehnSekunden() {
        let t = Date(timeIntervalSince1970: 1_791_500_000)
        XCTAssertTrue(ZuhauseSzeneLogik.herzErlaubt(letztes: nil, jetzt: t))
        XCTAssertFalse(ZuhauseSzeneLogik.herzErlaubt(letztes: t, jetzt: t.addingTimeInterval(3)))
        XCTAssertTrue(ZuhauseSzeneLogik.herzErlaubt(letztes: t, jetzt: t.addingTimeInterval(ZuhauseSzeneLogik.herzPause)))
    }

    func testZonenHaptikNichtDirektNachTabTipp() {
        XCTAssertFalse(ZuhauseSzeneLogik.zonenHaptik(sekundenSeitTab: 0.4))
        XCTAssertTrue(ZuhauseSzeneLogik.zonenHaptik(sekundenSeitTab: 5))
        XCTAssertTrue(ZuhauseSzeneLogik.zonenHaptik(sekundenSeitTab: Date().timeIntervalSince(.distantPast)))
    }
}
