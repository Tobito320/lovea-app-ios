import XCTest
@testable import Lovea

/// p65 A1: the panorama of the profile scene as numbers. Every object has one slot in a world that is
/// about two and a half screens wide; no two slots touch, every tap area is at least 44 pt, and each
/// zone fits on one screen when the view rests on its anchor. Pure rects, no drawing.
final class ProfilSlotsTests: XCTestCase {
    private typealias S = ProfilSlots

    private func abstand(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let dx = max(b.minX - a.maxX, a.minX - b.maxX)
        let dy = max(b.minY - a.maxY, a.minY - b.maxY)
        return max(dx, dy)
    }

    func testWeltIstZweiBisZweiEinhalbBildschirmeBreit() {
        let faktor = S.weltBreite / S.ansichtBreite
        XCTAssertGreaterThanOrEqual(faktor, 2)
        XCTAssertLessThanOrEqual(faktor, 2.5)
    }

    func testKeinDingBerueHrtEinAnderes() {
        let alle = ProfilDing.allCases
        for (i, a) in alle.enumerated() {
            for b in alle[(i + 1)...] {
                let d = abstand(S.welt(a), S.welt(b))
                XCTAssertGreaterThanOrEqual(d, S.mindestAbstand, "\(a) und \(b): Abstand \(d)")
            }
        }
    }

    func testAlleDingeLiegenInDerWelt() {
        for d in ProfilDing.allCases {
            let r = S.welt(d)
            XCTAssertGreaterThanOrEqual(r.minX, 0, "\(d)")
            XCTAssertLessThanOrEqual(r.maxX, S.weltBreite, "\(d)")
            XCTAssertGreaterThanOrEqual(r.minY, 0, "\(d)")
            XCTAssertLessThanOrEqual(r.maxY, S.hoehe, "\(d)")
        }
    }

    func testJedesDingLiegtInSeinerZone() {
        for d in ProfilDing.allCases {
            XCTAssertEqual(S.zone(beiX: S.welt(d).midX), S.zone(d), "\(d)")
        }
        for z in ProfilZone.allCases {
            XCTAssertFalse(ProfilDing.allCases.filter { S.zone($0) == z }.isEmpty, "\(z) ist leer")
        }
    }

    func testJedeZoneIstAmAnkerGanzSichtbar() {
        for z in ProfilZone.allCases {
            let sicht = CGRect(x: S.anker(z), y: 0, width: S.ansichtBreite, height: S.hoehe)
            for d in ProfilDing.allCases where S.zone(d) == z {
                XCTAssertTrue(sicht.contains(S.welt(d)), "\(d) ragt aus der Ansicht der Zone \(z)")
            }
        }
    }

    func testAnkerLiegenImScrollBereich() {
        let anker = ProfilZone.allCases.map(S.anker)
        XCTAssertEqual(anker.first, 0)
        XCTAssertEqual(anker.last, ProfilPanoramaLayout.maxOffset)
        XCTAssertEqual(anker, anker.sorted())
        XCTAssertEqual(ProfilPanoramaLayout.maxOffset, S.weltBreite - S.ansichtBreite)
    }

    func testPlatteLiegtNieUeberBildern() {
        let platte = S.welt(.platte)
        for d in [ProfilDing.rahmen0, .rahmen1, .rahmen2, .kalender, .countdown, .pinnwand, .pokale] {
            XCTAssertFalse(platte.intersects(S.welt(d)), "Plattenspieler ueber \(d)")
            XCTAssertGreaterThanOrEqual(abstand(platte, S.welt(d)), S.mindestAbstand, "\(d)")
        }
    }

    func testTippflaecheMindestens44PtAufZweiGeraeten() {
        for breite in [CGFloat(375), 430] {
            let k = ProfilPanoramaLayout.massstab(breite: breite)
            for d in ProfilDing.allCases where S.tippbar(d) {
                let t = S.tippFlaeche(d, massstab: k)
                XCTAssertGreaterThanOrEqual(t.width * k, S.tippMinimum - 0.001, "\(d) breite \(breite)")
                XCTAssertGreaterThanOrEqual(t.height * k, S.tippMinimum - 0.001, "\(d) breite \(breite)")
                XCTAssertTrue(t.contains(S.welt(d)), "\(d): die Tippflaeche deckt das Ding")
            }
        }
    }

    func testTippflaechenStoerenSichKaum() {
        for breite in [CGFloat(375), 430] {
            let k = ProfilPanoramaLayout.massstab(breite: breite)
            let tippbar = ProfilDing.allCases.filter(S.tippbar)
            for (i, a) in tippbar.enumerated() {
                for b in tippbar[(i + 1)...] {
                    let schnitt = S.tippFlaeche(a, massstab: k).intersection(S.tippFlaeche(b, massstab: k))
                    guard !schnitt.isNull else { continue }
                    XCTAssertLessThanOrEqual(min(schnitt.width, schnitt.height), S.maxTippUeberlapp, "\(a) und \(b) bei \(breite)")
                }
            }
        }
    }

    func testNativeRechteKommenAusDenEchtenKonstanten() {
        XCTAssertEqual(S.nativ(.rahmen0), ZimmerLebenLayout.rahmen[0])
        XCTAssertEqual(S.nativ(.rahmen1), ZimmerLebenLayout.rahmen[1])
        XCTAssertEqual(S.nativ(.rahmen2), ZimmerLebenLayout.rahmen[2])
        XCTAssertEqual(S.nativ(.kalender), ZimmerLebenLayout.kalender)
        XCTAssertEqual(S.nativ(.fernseher), ZimmerLebenLayout.fernseher)
        XCTAssertEqual(S.nativ(.pinnwand), ZimmerLebenLayout.pinnwand)
        XCTAssertEqual(S.nativ(.pokale), ZimmerLebenLayout.pokale)
        XCTAssertEqual(S.nativ(.pflanze), ZimmerLebenLayout.pflanze)
        XCTAssertEqual(S.nativ(.ziel), ZimmerLebenLayout.ziel)
        XCTAssertEqual(S.nativ(.kleiderschrank), ZimmerMoebel.stange.union(ZimmerMoebel.regal))
        XCTAssertEqual(S.nativ(.sofa).minX, ZuhauseZeichnung.sofa.minX)
        XCTAssertEqual(S.nativ(.sofa).minY, ZuhauseZeichnung.sofa.minY)
        XCTAssertEqual(S.nativ(.sofa).height, ZuhauseZeichnung.sofa.height)
        XCTAssertEqual(S.nativ(.bett).minX, ZuhauseZeichnung.bettOrt.x)
        XCTAssertEqual(S.nativ(.bett).minY, ZuhauseZeichnung.bettOrt.y)
    }

    func testSofaIstBreitGenugFuerZweiMitGanzemKoerper() {
        XCTAssertGreaterThanOrEqual(S.nativ(.sofa).width, 2 * 60 + 20)
        XCTAssertGreaterThan(S.nativ(.sofa).width, ZuhauseZeichnung.sofa.width, "breiter als das alte Sofa")
    }

    func testFensterGruppeUmfasstFensterUndVorhaenge() {
        let f = ZuhauseZeichnung.fenster
        XCTAssertTrue(S.nativ(.fenster).contains(f))
        XCTAssertLessThan(S.nativ(.fenster).minX, f.minX, "Vorhang links")
        XCTAssertGreaterThan(S.nativ(.fenster).maxX, f.maxX, "Vorhang rechts")
    }

    func testKommodeUmfasstSchrankTischUndStraeusse() {
        let k = S.nativ(.kommode)
        XCTAssertTrue(k.contains(ZuhauseZeichnung.schrank))
        XCTAssertLessThanOrEqual(k.minY, ZuhauseZeichnung.schrankOben + 2 - ZuhauseZeichnung.strauss.height)
        XCTAssertGreaterThanOrEqual(k.maxY, ZuhauseZeichnung.tisch.y + 25)
        XCTAssertTrue(k.contains(CGPoint(x: ZuhauseZeichnung.tisch.x, y: ZuhauseZeichnung.tisch.y)))
    }

    func testWeltEinzelLaesstAllesWieEsWar() {
        for d in ProfilDing.allCases {
            XCTAssertEqual(ProfilWelt.einzel.versatz(d), .zero, "\(d)")
            XCTAssertEqual(ProfilWelt.einzel.rect(d), d == .sofa ? ZuhauseZeichnung.sofa : S.nativ(d), "\(d)")
            XCTAssertEqual(ProfilWelt.panorama.rect(d), S.welt(d), "\(d)")
        }
        XCTAssertEqual(ProfilWelt.einzel.breite, SzenenZeichnung.breite)
        XCTAssertEqual(ProfilWelt.panorama.breite, S.weltBreite)
    }

    // p69: the old test here added up scene, tab bar and a "room below" for three phones, but left the zone
    // strip and the iPad out of the sum; it moved to ProfilLayoutTests with the strip, more devices and a fallback.

    func testSzeneHoeheFolgtDerBreite() {
        XCTAssertEqual(ProfilPanoramaLayout.szeneHoehe(breite: 390), 430, accuracy: 0.001)
        XCTAssertEqual(ProfilPanoramaLayout.massstab(breite: 195), 0.5, accuracy: 0.0001)
    }

    func testNaechsterAnkerRastetEin() {
        let anker = ProfilZone.allCases.map(S.anker)
        XCTAssertEqual(ProfilPanoramaLayout.naechsterAnker(-30), anker[0])
        XCTAssertEqual(ProfilPanoramaLayout.naechsterAnker(60), anker[0])
        XCTAssertEqual(ProfilPanoramaLayout.naechsterAnker(S.anker(.wohn) + 20), S.anker(.wohn))
        XCTAssertEqual(ProfilPanoramaLayout.naechsterAnker(9999), anker.last)
        XCTAssertEqual(ProfilPanoramaLayout.zone(offset: S.anker(.regal) - 10), .regal)
        XCTAssertEqual(ProfilPanoramaLayout.zone(offset: 0), .schlaf)
    }

    func testWandLaeuftLangsamerAlsDieMoebel() {
        let f = ProfilPanoramaLayout.wandFaktor
        XCTAssertLessThan(f, 1)
        XCTAssertGreaterThan(f, 0)
        // On screen the wall moves at f times the scroll; the world moves at 1 times.
        XCTAssertEqual(ProfilPanoramaLayout.wandVersatz(scroll: 100) - 100, -100 * f, accuracy: 0.001)
        // At every offset the wall covers the whole screen and never starts right of it.
        for scroll in stride(from: CGFloat(0), through: ProfilPanoramaLayout.maxOffset, by: 15) {
            let links = ProfilPanoramaLayout.wandVersatz(scroll: scroll)
            XCTAssertLessThanOrEqual(links, scroll + 0.001, "scroll \(scroll)")
            XCTAssertGreaterThanOrEqual(links + ProfilPanoramaLayout.wandBreite, scroll + S.ansichtBreite - 0.001, "scroll \(scroll)")
        }
        // Bouncing past either end changes nothing.
        XCTAssertEqual(ProfilPanoramaLayout.wandVersatz(scroll: -40), 0)
        XCTAssertEqual(ProfilPanoramaLayout.wandVersatz(scroll: 9999), ProfilPanoramaLayout.wandVersatz(scroll: ProfilPanoramaLayout.maxOffset))
    }

    func testZonenHabenTitel() {
        XCTAssertEqual(ProfilZone.allCases.map(\.titel), ["Schlafen", "Wohnen", "Regal"])
    }
}
