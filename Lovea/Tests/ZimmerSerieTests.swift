import XCTest
@testable import Lovea

/// p70 (40, 41, 44): the day's goals, the streak candle, looking after the cat.
final class ZimmerSerieTests: XCTestCase {
    private let heute = "2026-10-08"

    // MARK: 40 day goals

    func testZieleZaehlenUndHebenDiePflanze() {
        var z = ZimmerTagesZiele()
        XCTAssertEqual(z.anzahl, 0)
        XCTAssertEqual(z.pflanzenStufe, 0)
        XCTAssertEqual(z.lampenFaktor, 1, accuracy: 0.0001)
        z.gym = true
        XCTAssertEqual(z.pflanzenStufe, 1)
        z.wasser = true
        XCTAssertEqual(z.pflanzenStufe, 2)
        z.brief = true
        XCTAssertEqual(z.anzahl, 3)
        XCTAssertEqual(z.pflanzenStufe, 4, "all three: in bloom")
        XCTAssertEqual(z.lampenFaktor, 1.45, accuracy: 0.0001)
    }

    func testZielTextNenntJedesZiel() {
        XCTAssertEqual(ZimmerTagesZiele(gym: true, wasser: false, brief: true).text, "Heute: Gym geschafft, Wasser offen, Brief geschafft")
    }

    func testWasserBrauchtEinZiel() {
        XCTAssertTrue(ZimmerTagesZiele.wasserErreicht(anzahl: 8, ziel: 8))
        XCTAssertTrue(ZimmerTagesZiele.wasserErreicht(anzahl: 9, ziel: 8))
        XCTAssertFalse(ZimmerTagesZiele.wasserErreicht(anzahl: 7, ziel: 8))
        XCTAssertFalse(ZimmerTagesZiele.wasserErreicht(anzahl: 0, ziel: 0), "no goal set is not a goal reached")
    }

    func testBriefZaehltNurEigenenVonHeute() {
        let jetzt = Date(timeIntervalSince1970: 1_800_000_000)
        func brief(_ id: String, von: Person, zeit: Date) -> Brief {
            Brief(id: id, titel: "Öffne, wenn ...", text: "Hallo", von: von, zeit: zeit)
        }
        let tag: (Date) -> String = { $0 == jetzt ? "2026-10-08" : "2026-10-07" }
        let gestern = jetzt.addingTimeInterval(-86_400)
        XCTAssertFalse(ZimmerTagesZiele.briefGeschrieben([], von: .ahmed, heute: heute, tag: tag))
        XCTAssertTrue(ZimmerTagesZiele.briefGeschrieben([brief("a", von: .ahmed, zeit: jetzt)], von: .ahmed, heute: heute, tag: tag))
        XCTAssertFalse(ZimmerTagesZiele.briefGeschrieben([brief("a", von: .annika, zeit: jetzt)], von: .ahmed, heute: heute, tag: tag), "the other one's letter")
        XCTAssertFalse(ZimmerTagesZiele.briefGeschrieben([brief("a", von: .ahmed, zeit: gestern)], von: .ahmed, heute: heute, tag: tag), "yesterday's letter")
    }

    func testPflanzeMitZielenWaechstUndHaengtWeiter() {
        let ziele = ZimmerTagesZiele(gym: true, wasser: true, brief: false)
        let basis = ZimmerPflanzenStand(stufe: 0, haengt: false, serie: 0)
        XCTAssertEqual(basis.mit(ziele).stufe, 2)
        XCTAssertEqual(basis.mit(ZimmerTagesZiele(gym: true, wasser: true, brief: true)).stufe, 4)
        // Never lower than what the shared streak made it.
        XCTAssertEqual(ZimmerPflanzenStand(stufe: 3, haengt: false, serie: 8).mit(ziele).stufe, 3)
        // A dropped streak keeps the leaves down.
        let haengt = ZimmerPflanzenStand(stufe: 1, haengt: true, serie: 0).mit(ZimmerTagesZiele(gym: true, wasser: true, brief: true))
        XCTAssertEqual(haengt.stufe, 1)
        XCTAssertTrue(haengt.haengt)
    }

    func testPflanzenTextNenntDieTagesziele() {
        let s = ZimmerPflanzenStand(stufe: 2, haengt: false, serie: 5).mit(ZimmerTagesZiele(gym: true, wasser: false, brief: false))
        XCTAssertTrue(s.text.hasPrefix("5 Tage gemeinsame Serie"))
        XCTAssertTrue(s.text.hasSuffix("Heute: Gym geschafft, Wasser offen, Brief offen"))
    }

    func testVorhandenePflanzenBleibenGleich() {
        // The old three-field plant equals one with empty goals, so nothing that compared plants breaks.
        XCTAssertEqual(ZimmerPflanzenStand(stufe: 3, haengt: false, serie: 8), ZimmerPflanzenStand(stufe: 3, haengt: false, serie: 8).mit(ZimmerTagesZiele()))
    }

    // MARK: 41 candle

    func testKerzeWaechstMitDerSerie() {
        XCTAssertEqual(ZimmerKerze.flamme(serie: 0), 0)
        XCTAssertEqual(ZimmerKerze.flamme(serie: -1), 0)
        XCTAssertEqual(ZimmerKerze.flamme(serie: 1), 1)
        XCTAssertEqual(ZimmerKerze.flamme(serie: 2), 1)
        XCTAssertEqual(ZimmerKerze.flamme(serie: 3), 2)
        XCTAssertEqual(ZimmerKerze.flamme(serie: 13), 2)
        XCTAssertEqual(ZimmerKerze.flamme(serie: 14), 3)
        XCTAssertEqual(ZimmerKerze.flamme(serie: 400), 3)
    }

    // MARK: 44 cat

    func testFutterOpIdTraegtTagUndPerson() {
        XCTAssertEqual(KatzePflege.opId(tag: heute, von: .annika), "katze-futter-2026-10-08-annika")
        let op = KatzePflege.op(tag: heute, von: .ahmed)
        XCTAssertEqual(op.id, KatzePflege.opId(tag: heute, von: .ahmed))
        XCTAssertEqual(op.art, KatzePflege.art)
        XCTAssertEqual(op.daten(KatzePflege.D.self)?.tag, heute)
        XCTAssertNotEqual(KatzePflege.opId(tag: heute, von: .ahmed), KatzeLogik.opId(tag: heute, von: .ahmed), "its own ID, not the stroke's")
    }

    func testFutterGibtPunkteEinmalProTagUndPerson() {
        let a = (id: KatzePflege.opId(tag: heute, von: .ahmed), tag: heute, von: Person.ahmed)
        let b = (id: KatzePflege.opId(tag: "2026-10-09", von: .annika), tag: "2026-10-09", von: Person.annika)
        let falsch = (id: "irgendwas", tag: heute, von: Person.annika)
        let e = KatzePflege.eintraege([a, a, b, falsch])
        XCTAssertEqual(e, [
            PunkteLogik.Eintrag(datum: heute, von: .ahmed, grund: KatzePflege.grund, punkte: KatzePflege.punkte),
            PunkteLogik.Eintrag(datum: "2026-10-09", von: .annika, grund: KatzePflege.grund, punkte: KatzePflege.punkte),
        ])
    }

    func testStimmungAusFutterUndStreicheln() {
        XCTAssertEqual(KatzePflege.stimmung(gefuettert: false, gestreichelt: false), .hungrig)
        XCTAssertEqual(KatzePflege.stimmung(gefuettert: true, gestreichelt: false), .zufrieden)
        XCTAssertEqual(KatzePflege.stimmung(gefuettert: false, gestreichelt: true), .zufrieden)
        XCTAssertEqual(KatzePflege.stimmung(gefuettert: true, gestreichelt: true), .schnurrt)
    }

    func testHungerBlaseKommtNachDerHerzblase() {
        XCTAssertTrue(KatzePflege.hungert(.will, gefuettert: false, wuenscht: false))
        XCTAssertFalse(KatzePflege.hungert(.will, gefuettert: false, wuenscht: true), "the heart wish first")
        XCTAssertFalse(KatzePflege.hungert(.will, gefuettert: true, wuenscht: false))
        XCTAssertFalse(KatzePflege.hungert(.schlaeft, gefuettert: false, wuenscht: false), "asleep: no bubble")
    }

    func testTippenStreicheltErstDannFuettert() {
        XCTAssertFalse(KatzePflege.fuettertBeimTippen(gestreichelt: false, gefuettert: false), "first the stroke")
        XCTAssertTrue(KatzePflege.fuettertBeimTippen(gestreichelt: true, gefuettert: false))
        XCTAssertFalse(KatzePflege.fuettertBeimTippen(gestreichelt: true, gefuettert: true), "fed: just strokes")
        XCTAssertFalse(KatzePflege.fuettertBeimTippen(gestreichelt: false, gefuettert: true))
    }

    func testSchnurrenNurWach() {
        XCTAssertTrue(KatzePflege.schnurrt(.will, .schnurrt))
        XCTAssertFalse(KatzePflege.schnurrt(.schlaeft, .schnurrt))
        XCTAssertFalse(KatzePflege.schnurrt(.will, .zufrieden))
    }

    func testKatzenBeschreibung() {
        XCTAssertEqual(KatzePflege.beschreibung(.schlaeft, .schnurrt), "Katze, schläft")
        XCTAssertEqual(KatzePflege.beschreibung(.will, .hungrig), "Katze, hat Hunger")
        XCTAssertEqual(KatzePflege.beschreibung(.folgt, .schnurrt), "Katze, schnurrt")
    }
}
