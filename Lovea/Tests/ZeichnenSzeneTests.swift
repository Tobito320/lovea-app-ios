import XCTest
@testable import Lovea

/// Brief Z: drawing in the studio beats every other scene, keeps the room, and together draws one heart.
final class ZeichnenSzeneTests: XCTestCase {
    private func szene(zeichnet: Bool = true, partner: Bool = false, schlaeft: Bool = false, ort: String? = nil, unterwegs: Bool = false) -> ProfilSzene {
        ProfilSzene.fuer(schlaeft: schlaeft, partnerSchlaeft: false, ort: ort, wetterCode: 61, tag: false, stunde: 23, unterwegs: unterwegs,
                         zeichnet: zeichnet, partnerZeichnet: partner)
    }

    func testZeichnenSchlaegtAlles() {
        XCTAssertEqual(szene(ort: "zuhause"), .zeichnen(zusammen: false))
        XCTAssertEqual(szene(schlaeft: true, ort: "zuhause"), .zeichnen(zusammen: false))
        XCTAssertEqual(szene(ort: "gym"), .zeichnen(zusammen: false))
        XCTAssertEqual(szene(ort: "arbeit"), .zeichnen(zusammen: false))
        XCTAssertEqual(szene(unterwegs: true), .zeichnen(zusammen: false))
        XCTAssertEqual(szene(), .zeichnen(zusammen: false))
    }

    func testZusammen() {
        XCTAssertEqual(szene(partner: true), .zeichnen(zusammen: true))
        // Only the partner draws: the profile person keeps their own scene.
        XCTAssertEqual(szene(zeichnet: false, partner: true, ort: "zuhause"), .zimmer)
        XCTAssertEqual(szene(zeichnet: false, ort: "zuhause"), .zimmer)
    }

    func testFigurUndExtras() {
        let allein = ProfilSzene.zeichnen(zusammen: false)
        let zusammen = ProfilSzene.zeichnen(zusammen: true)
        XCTAssertEqual(allein.figur(.zeichnet), .zeichnet)
        XCTAssertEqual(allein.figur(.ruhig), .zeichnet)
        // A gesture plays inside the drawing scene.
        XCTAssertEqual(allein.figur(.kuss), .kuss)
        XCTAssertEqual(zusammen.figur(.zwinkert), .zwinkert)
        XCTAssertEqual(allein.extras(.zeichnet, wetterCode: 61, temperatur: 2), [])
        XCTAssertEqual(zusammen.extras(.zeichnet, wetterCode: 61, temperatur: 2), [.mitzeichnen])
        XCTAssertEqual(zusammen.extras(.kuss, wetterCode: nil, temperatur: nil), [])
    }

    func testRaumUndNacht() {
        let s = ProfilSzene.zeichnen(zusammen: false)
        XCTAssertEqual(s.raumOrt, .zuhause)
        XCTAssertTrue(s.dunkel(nacht: true))
        XCTAssertFalse(s.dunkel(nacht: false))
    }

    func testStricheLaufenImKreis() {
        // Still frame: the first strokes done, the last one under way.
        let still = ZeichenStriche.fortschritt(zeit: ZeichenStriche.stillZeit, anzahl: 4)
        XCTAssertEqual(still.prefix(2), [1, 1])
        XCTAssertLessThan(still[3], 1)
        // The cycle starts empty and repeats.
        XCTAssertEqual(ZeichenStriche.fortschritt(zeit: 0, anzahl: 4), [0, 0, 0, 0])
        XCTAssertEqual(ZeichenStriche.fortschritt(zeit: ZeichenStriche.periode + 1, anzahl: 4), ZeichenStriche.fortschritt(zeit: 1, anzahl: 4))
        // Together each figure only moves its own pencil: Annika the even strokes, Ahmed the odd ones.
        XCTAssertEqual(ZeichenStriche.eigene(person: .annika, zusammen: true, anzahl: 4), [0, 2])
        XCTAssertEqual(ZeichenStriche.eigene(person: .ahmed, zusammen: true, anzahl: 4), [1, 3])
        XCTAssertEqual(ZeichenStriche.eigene(person: .ahmed, zusammen: false, anzahl: 4), [0, 1, 2, 3])
    }
}
