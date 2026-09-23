import XCTest
@testable import Lovea

/// Brief G: scene decision (every branch) and the tolerant `profil.zimmer` reading.
final class ProfilSzeneTests: XCTestCase {
    private func szene(schlaeft: Bool = false, partner: Bool = false, ort: String? = nil, code: Int? = nil, tag: Bool? = nil, stunde: Int = 12) -> ProfilSzene {
        ProfilSzene.fuer(schlaeft: schlaeft, partnerSchlaeft: partner, ort: ort, wetterCode: code, tag: tag, stunde: stunde)
    }

    func testSchlafenAlleinUndZusammen() {
        XCTAssertEqual(szene(schlaeft: true, ort: "zuhause"), .schlafen(zusammen: false))
        XCTAssertEqual(szene(schlaeft: true, partner: true, ort: "zuhause"), .schlafen(zusammen: true))
        // Only the partner asleep: the profile person is still in their room.
        XCTAssertEqual(szene(partner: true, ort: "zuhause"), .zimmer)
    }

    func testSchlafenSchlaegtOrt() {
        XCTAssertEqual(szene(schlaeft: true, ort: "gym"), .schlafen(zusammen: false))
    }

    func testGymUndZimmer() {
        XCTAssertEqual(szene(ort: "gym", code: 61), .gym)
        XCTAssertEqual(szene(ort: "zuhause", code: 61, tag: false), .zimmer)
    }

    func testDraussenWetter() {
        XCTAssertEqual(szene(ort: nil, code: 61, tag: true), .draussen(wetter: .regen, nacht: false))
        XCTAssertEqual(szene(ort: "arbeit", code: 0, tag: true), .draussen(wetter: .sonne, nacht: false))
        XCTAssertEqual(szene(ort: "sonstiges", code: 3, tag: true), .draussen(wetter: .wolken, nacht: false))
        XCTAssertEqual(szene(code: 73, tag: true), .draussen(wetter: .schnee, nacht: false))
        XCTAssertEqual(szene(code: nil, tag: true), .draussen(wetter: .wolken, nacht: false))
    }

    func testDraussenNacht() {
        // Clear at night stays "sonne" (clear sky): the view draws moon and stars instead.
        XCTAssertEqual(szene(code: 0, tag: false, stunde: 12), .draussen(wetter: .sonne, nacht: true))
        XCTAssertEqual(szene(code: 61, tag: false), .draussen(wetter: .regen, nacht: true))
        // Unknown daylight: 20-6 Uhr is night.
        XCTAssertEqual(szene(code: 0, tag: nil, stunde: 20), .draussen(wetter: .sonne, nacht: true))
        XCTAssertEqual(szene(code: 0, tag: nil, stunde: 5), .draussen(wetter: .sonne, nacht: true))
        XCTAssertEqual(szene(code: 0, tag: nil, stunde: 6), .draussen(wetter: .sonne, nacht: false))
        XCTAssertEqual(szene(code: 0, tag: nil, stunde: 19), .draussen(wetter: .sonne, nacht: false))
        // Real daylight wins over the clock.
        XCTAssertEqual(szene(code: 0, tag: true, stunde: 21), .draussen(wetter: .sonne, nacht: false))
    }

    func testSchlaeft() {
        XCTAssertTrue(ProfilSzene.schlaeft(anzeige: .schlaeft, zuletzt: nil, stunde: 14))
        XCTAssertTrue(ProfilSzene.schlaeft(anzeige: .offline, zuletzt: .schlaeft, stunde: 23))
        XCTAssertTrue(ProfilSzene.schlaeft(anzeige: .offline, zuletzt: .schlaeft, stunde: 6))
        XCTAssertFalse(ProfilSzene.schlaeft(anzeige: .offline, zuletzt: .schlaeft, stunde: 15))
        XCTAssertFalse(ProfilSzene.schlaeft(anzeige: .offline, zuletzt: .zuhause, stunde: 23))
        XCTAssertFalse(ProfilSzene.schlaeft(anzeige: .imChat, zuletzt: .schlaeft, stunde: 23))
    }

    func testFigurInDerSzene() {
        XCTAssertEqual(ProfilSzene.gym.figur(.imChat), .gym)
        XCTAssertEqual(ProfilSzene.gym.figur(.kuss), .kuss)
        XCTAssertEqual(ProfilSzene.gym.figur(.zwinkert), .zwinkert)
        XCTAssertEqual(ProfilSzene.zimmer.figur(.zuhause), .ruhig)
        XCTAssertEqual(ProfilSzene.zimmer.figur(.tippt), .tippt)
        XCTAssertEqual(ProfilSzene.schlafen(zusammen: true).figur(.offline), .schlaeft)
        XCTAssertEqual(ProfilSzene.draussen(wetter: .regen, nacht: false).figur(.laeuft), .laeuft)
    }

    func testExtrasInDerSzene() {
        XCTAssertEqual(ProfilSzene.gym.extras(wetterCode: 61, temperatur: 2, laedt: false), [.hanteln])
        XCTAssertEqual(ProfilSzene.zimmer.extras(wetterCode: 61, temperatur: 2, laedt: true), [])
        XCTAssertEqual(ProfilSzene.draussen(wetter: .regen, nacht: false).extras(wetterCode: 61, temperatur: 12, laedt: false), [.schirm])
        // Clear sky: sunglasses by day, none at night (same rule as the map figure).
        XCTAssertEqual(ProfilSzene.draussen(wetter: .sonne, nacht: false).extras(wetterCode: 0, temperatur: 20, laedt: false), [.sonnenbrille])
        XCTAssertEqual(ProfilSzene.draussen(wetter: .sonne, nacht: true).extras(wetterCode: 0, temperatur: 20, laedt: false), [])
    }

    // MARK: - profil.zimmer

    func testZimmerFehlt() {
        XCTAssertEqual(Zimmer.lesen(nil), Zimmer())
        XCTAssertEqual(Zimmer.lesen(.string("kaputt")), Zimmer())
        XCTAssertEqual(Zimmer().deko, Zimmer.standardDeko)
    }

    func testZimmerRundreise() {
        let z = Zimmer(bett: 2, wand: 5, boden: 1, deko: ["lichterkette", "poster"], rahmen: [.init(slot: 2, medienId: "m1"), .init(slot: 0, medienId: "m2")])
        XCTAssertEqual(Zimmer.lesen(z.json), z)
    }

    func testZimmerTolerant() {
        let wert: JSONValue = .object([
            "bett": .number(99), "wand": .string("rot"), "boden": .number(-1),
            "deko": .array([.string("lampe"), .string("einhorn"), .number(3), .string("lampe")]),
            "rahmen": .array([
                .object(["slot": .number(1), "medienId": .string("a")]),
                .object(["slot": .number(1), "medienId": .string("doppelt")]),
                .object(["slot": .number(7), "medienId": .string("weg")]),
                .object(["slot": .number(0), "medienId": .string("")]),
                .object(["slot": .number(2)]),
                .string("quatsch"),
            ]),
            "neuesFeld": .bool(true),
        ])
        let z = Zimmer.lesen(wert)
        XCTAssertEqual(z.bett, 0)
        XCTAssertEqual(z.wand, 0)
        XCTAssertEqual(z.boden, 0)
        XCTAssertEqual(z.deko, ["lampe"])
        XCTAssertEqual(z.rahmen, [.init(slot: 1, medienId: "a")])
        XCTAssertEqual(z.medien(1), "a")
        XCTAssertNil(z.medien(0))
    }

    func testZimmerRiesigeZahlStuerztNicht() {
        let z = Zimmer.lesen(.object(["bett": .number(1e300), "wand": .number(.nan), "boden": .number(4.7)]))
        XCTAssertEqual(z.bett, 0)
        XCTAssertEqual(z.wand, 0)
        XCTAssertEqual(z.boden, 4)
    }

    func testZimmerLeereDekoBleibtLeer() {
        XCTAssertEqual(Zimmer.lesen(.object(["deko": .array([])])).deko, [])
    }
}
