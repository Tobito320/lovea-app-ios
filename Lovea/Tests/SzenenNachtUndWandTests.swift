import CoreGraphics
import XCTest
@testable import Lovea

/// Brief R: which rooms darken at night, and wall posters never cover a photo frame.
final class SzenenNachtUndWandTests: XCTestCase {
    /// Every poster shape in every spot, with all three frames hung: no poster (with room for its
    /// ±2° tilt, tape strip and shadow) touches a frame (with its nail string above and shadow).
    func testPosterUeberdeckenKeineRahmen() {
        let rahmen = (0..<Zimmer.rahmenPlaetze).map { Zimmer.Rahmen(slot: $0, medienId: "f\($0)") }
        let rahmenFlaechen = SzenenZeichnung.rahmenRects.map { r in
            CGRect(x: r.minX, y: r.minY - 10, width: r.width + 2, height: r.height + 13)
        }
        let poster = Array(1..<Zimmer.posterArten.count)
        for rechts in poster {
            for links in [0] + poster {
                for bett in [0, 8, 11, 2, rechts] {
                    let z = Zimmer(deko: [], rahmen: rahmen, poster: rechts, posterLinks: links, posterBett: bett)
                    for p in SzenenZeichnung.posterPlaetze(z) {
                        let s = SzenenZeichnung.posterGroesse(p.i)
                        let flaeche = CGRect(x: p.mitte.x - s.width * p.skala / 2, y: p.mitte.y - s.height * p.skala / 2,
                                             width: s.width * p.skala, height: s.height * p.skala).insetBy(dx: -6, dy: -7)
                        for (slot, r) in rahmenFlaechen.enumerated() {
                            XCTAssertFalse(flaeche.intersects(r), "poster \(p.i) (right \(rechts), left \(links), bed \(bett)) covers frame \(slot)")
                        }
                    }
                }
            }
        }
    }

    /// Without frames the posters keep their old spots.
    func testOhneRahmenBleibtAllesWoEsWar() {
        let z = Zimmer(deko: [], poster: 13, posterLinks: 18, posterBett: 19)
        let plaetze = SzenenZeichnung.posterPlaetze(z)
        XCTAssertEqual(plaetze.map { $0.i }, [13, 18, 19])
        XCTAssertEqual(plaetze[0].mitte, CGPoint(x: 320, y: 150))
        XCTAssertEqual(plaetze[2].mitte.x, 18 + 86 + 43, accuracy: 0.01)
    }

    func testRaeumeWerdenNachtsDunkel() {
        for szene in [ProfilSzene.zimmer, .schule, .arbeit] {
            XCTAssertTrue(szene.dunkel(nacht: true), "\(szene) at night")
            XCTAssertFalse(szene.dunkel(nacht: false), "\(szene) by day")
        }
        XCTAssertTrue(ProfilSzene.schlafen(zusammen: false).dunkel(nacht: false), "the bed is always night")
        let hell: [ProfilSzene] = [
            .gym, .draussen(wetter: .sonne, nacht: true), .unterwegs(wetter: .regen, nacht: true), .abteil(wetter: .regen, nacht: true),
        ]
        for szene in hell { XCTAssertFalse(szene.dunkel(nacht: true), "\(szene) has its own light") }
    }
}
