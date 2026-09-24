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

    func testSchuleUndArbeit() {
        XCTAssertEqual(szene(ort: "schule", code: 0, tag: true), .schule)
        XCTAssertEqual(szene(ort: "arbeit", code: 61, tag: false), .arbeit)
        XCTAssertEqual(ProfilSzene.schule.figur(.imChat), .schule)
        XCTAssertEqual(ProfilSzene.arbeit.figur(.tippt), .arbeit)
        XCTAssertEqual(ProfilSzene.arbeit.figur(.kuss), .kuss)
        XCTAssertEqual(ProfilSzene.schule.extras(.schule, wetterCode: 61, temperatur: 2), [])
    }

    func testGymUndZimmer() {
        XCTAssertEqual(szene(ort: "gym", code: 61), .gym)
        XCTAssertEqual(szene(ort: "zuhause", code: 61, tag: false), .zimmer)
    }

    func testDraussenWetter() {
        XCTAssertEqual(szene(ort: nil, code: 61, tag: true), .draussen(wetter: .regen, nacht: false))
        XCTAssertEqual(szene(ort: nil, code: 0, tag: true), .draussen(wetter: .sonne, nacht: false))
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

    // MARK: - Sleep (Brief G fixes)

    private func berlin(_ tag: Int, _ stunde: Int, _ minute: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal.date(from: DateComponents(year: 2026, month: 9, day: tag, hour: stunde, minute: minute))!
    }

    func testGuteNachtImZustand() {
        var e = FigurEingabe(person: .annika, jetzt: berlin(25, 2, 35))
        e.guteNacht = berlin(25, 0, 10)
        e.zuhauseBekannt = false
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .schlaeft)
        e.zuhauseBekannt = true
        e.ort = .zuhause
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .schlaeft)
        e.ort = .arbeit
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .arbeit)
        e.ort = .zuhause
        e.app = .imChat
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .imChat)
    }

    func testSchlafAusSichtDesPartners() {
        // Online: their own phone decided. Offline: their last shared state, no local guess.
        XCTAssertEqual(ProfilSzene.schlaf(anzeige: .schlaeft, zuletzt: nil), .schlaeft)
        XCTAssertEqual(ProfilSzene.schlaf(anzeige: .sitztImBett, zuletzt: nil), .sitzt)
        XCTAssertEqual(ProfilSzene.schlaf(anzeige: .imChat, zuletzt: .schlaeft), .wach)
        XCTAssertEqual(ProfilSzene.schlaf(anzeige: .offline, zuletzt: .schlaeft), .schlaeft)
        XCTAssertEqual(ProfilSzene.schlaf(anzeige: .offline, zuletzt: .ruhig), .wach)
        XCTAssertEqual(ProfilSzene.schlaf(anzeige: .offline, zuletzt: nil), .wach)
    }
    func testSpaet() {
        XCTAssertFalse(ProfilSzene.spaet(stunde: 21))
        XCTAssertTrue(ProfilSzene.spaet(stunde: 22))
        XCTAssertTrue(ProfilSzene.spaet(stunde: 2))
        XCTAssertFalse(ProfilSzene.spaet(stunde: 6))
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
        XCTAssertEqual(ProfilSzene.gym.extras(.gym, wetterCode: 61, temperatur: 2), [.hanteln])
        // A gesture or expression in the gym keeps its own arms and props.
        XCTAssertEqual(ProfilSzene.gym.extras(.kuss, wetterCode: nil, temperatur: nil), [])
        XCTAssertEqual(ProfilSzene.gym.extras(.daumen, wetterCode: nil, temperatur: nil), [])
        XCTAssertEqual(ProfilSzene.zimmer.extras(.laedt, wetterCode: 61, temperatur: 2), [])
        XCTAssertEqual(ProfilSzene.draussen(wetter: .regen, nacht: false).extras(.ruhig, wetterCode: 61, temperatur: 12), [.schirm])
        XCTAssertEqual(ProfilSzene.draussen(wetter: .regen, nacht: false).extras(.laedt, wetterCode: 61, temperatur: 12), [.schirm, .handyKabel])
        // Clear sky: sunglasses by day, none at night (same rule as the map figure).
        XCTAssertEqual(ProfilSzene.draussen(wetter: .sonne, nacht: false).extras(.ruhig, wetterCode: 0, temperatur: 20), [.sonnenbrille])
        XCTAssertEqual(ProfilSzene.draussen(wetter: .sonne, nacht: true).extras(.ruhig, wetterCode: 0, temperatur: 20), [])
    }

    // MARK: - profil.zimmer

    func testZimmerFehlt() {
        XCTAssertEqual(Zimmer.lesen(nil), Zimmer())
        XCTAssertEqual(Zimmer.lesen(.string("kaputt")), Zimmer())
        XCTAssertEqual(Zimmer().deko, Zimmer.standardDeko)
    }

    func testZimmerRundreise() {
        let z = Zimmer(bett: 2, wand: 5, boden: 1, deko: ["lichterkette", "neonHerz"], rahmen: [.init(slot: 2, medienId: "m1"), .init(slot: 0, medienId: "m2")], poster: 3, tisch: 1)
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

    // MARK: - profil.raeume (one room per place)

    func testRaeumeProOrt() {
        let buero = Zimmer(wand: 4, deko: ["gaming", "kaffeemaschine"], poster: 6, tisch: 3)
        let karte: JSONValue = .object(["arbeit": buero.json, "quatsch": .string("x")])
        XCTAssertEqual(Zimmer.lesen(raeume: karte, altesZimmer: nil, ort: .arbeit), buero)
        // Missing places get their own defaults.
        XCTAssertEqual(Zimmer.lesen(raeume: karte, altesZimmer: nil, ort: .schule), Zimmer(ort: .schule))
        XCTAssertEqual(Zimmer.lesen(raeume: karte, altesZimmer: nil, ort: .zuhause), Zimmer())
        XCTAssertEqual(Zimmer.lesen(raeume: .string("kaputt"), altesZimmer: nil, ort: .arbeit), Zimmer(ort: .arbeit))
    }

    func testAltesZimmerWirdZuhause() {
        let alt = Zimmer(bett: 3, wand: 1, deko: ["fenster", "regal"])
        XCTAssertEqual(Zimmer.lesen(raeume: nil, altesZimmer: alt.json, ort: .zuhause), alt)
        // The old room never leaks into office or classroom.
        XCTAssertEqual(Zimmer.lesen(raeume: nil, altesZimmer: alt.json, ort: .arbeit), Zimmer(ort: .arbeit))
        // Once the map has home, the old key no longer counts.
        let neu = Zimmer(bett: 1)
        XCTAssertEqual(Zimmer.lesen(raeume: .object(["zuhause": neu.json]), altesZimmer: alt.json, ort: .zuhause), neu)
    }

    func testAltesPosterWirdPosterTab() {
        let z = Zimmer.lesen(.object(["deko": .array([.string("poster"), .string("teppich")])]))
        XCTAssertEqual(z.poster, 1)
        XCTAssertEqual(z.deko, ["teppich"])
        XCTAssertEqual(Zimmer.lesen(.object(["poster": .number(99), "tisch": .number(-2)])).poster, 0)
    }

    func testBueroOhneBettzimmerDeko() {
        let z = Zimmer.lesen(.object(["deko": .array([.string("fenster"), .string("lampe"), .string("globus")])]), ort: .schule)
        XCTAssertEqual(z.deko, ["globus"])
        XCTAssertGreaterThanOrEqual(Zimmer.dekoArten.count, 25)
        XCTAssertEqual(Set(Zimmer.dekoArten.map { $0.id }).count, Zimmer.dekoArten.count, "ids are unique")
    }

    // MARK: - Per-person defaults and clean spots

    func testAhmedsZuhauseOhneRosa() {
        let z = Zimmer(ort: .zuhause, person: .ahmed)
        XCTAssertEqual(z.bett, 5, "black bed")
        XCTAssertEqual(z.wand, 6, "charcoal wall")
        XCTAssertEqual(z.boden, 5, "concrete floor")
        for rosa in ["neonHerz", "ledStreifen", "sitzsack", "teppichRund", "blumen", "kerze"] { XCTAssertFalse(z.hat(rosa), rosa) }
        for teil in ["sneakerRegal", "gaming", "lautsprecher", "teppichSchwarz", "bargeld", "jordanBox", "ledWeiss"] { XCTAssertTrue(z.hat(teil), teil) }
        XCTAssertEqual([z.posterLinks, z.posterBett, z.poster].map { Zimmer.posterArten[$0] }, ["ICEMAN", "Meet the Woo 2", "SVJ"])
        XCTAssertFalse(z.hat("fenster"), "the left posters need the wall")
        // Annika's default stays as it was.
        XCTAssertEqual(Zimmer(ort: .zuhause, person: .annika), Zimmer())
        // Nothing saved yet: Ahmed gets his default, from either key.
        XCTAssertEqual(Zimmer.lesen(raeume: nil, altesZimmer: nil, ort: .zuhause, person: .ahmed), z)
    }

    func testStandardsOhneUeberschneidung() {
        for p in [Person.ahmed, .annika] {
            for ort in RaumOrt.allCases {
                XCTAssertEqual(Zimmer(ort: ort, person: p).konflikte, [], "\(p.name) \(ort.rawValue)")
            }
        }
    }

    func testDekoAnSchaltetNachbarnAus() {
        var z = Zimmer(deko: ["teppich", "pflanze", "gaming"])
        z.dekoAn("teppichSchwarz")
        z.dekoAn("monstera")
        z.dekoAn("buecherregal")
        XCTAssertEqual(Set(z.deko), ["teppichSchwarz", "monstera", "buecherregal"])
        XCTAssertEqual(z.konflikte, [])
    }

    func testDreiPosterRundreise() {
        let z = Zimmer(deko: ["ledRot", "goldkette", "tresor"], poster: 17, posterLinks: 14, posterBett: 15)
        XCTAssertEqual(Zimmer.lesen(z.json), z)
        XCTAssertEqual(Zimmer.posterArten.count, 18)
    }
}