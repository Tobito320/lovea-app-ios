import XCTest
@testable import Lovea

/// p70 (33, 34, 37, 38): wilting bouquets, a bouquet as a gift, love letters in the album, the live hint.
final class ZimmerBlumenTests: XCTestCase {
    // MARK: 33 wilting

    func testStufenNachTagen() {
        XCTAssertEqual(StraussFrische.stufe(tage: 0), .frisch)
        XCTAssertEqual(StraussFrische.stufe(tage: StraussFrische.muedeNachTagen - 1), .frisch)
        XCTAssertEqual(StraussFrische.stufe(tage: StraussFrische.muedeNachTagen), .muede)
        XCTAssertEqual(StraussFrische.stufe(tage: StraussFrische.welkNachTagen - 1), .muede)
        XCTAssertEqual(StraussFrische.stufe(tage: StraussFrische.welkNachTagen), .welk)
    }

    func testTageZaehlenGanzeKalendertage() {
        XCTAssertEqual(StraussFrische.tage(seit: "2026-10-01", bis: "2026-10-08"), 7)
        XCTAssertEqual(StraussFrische.tage(seit: "2026-10-08", bis: "2026-10-08"), 0)
        // Over the end of daylight saving time (25 Oct 2026) a day is still a day.
        XCTAssertEqual(StraussFrische.tage(seit: "2026-10-24", bis: "2026-10-26"), 2)
    }

    func testKaputtesDatumIstFrisch() {
        for kaputt in [nil, "", "heute", "2026-10", "2026-10-xx"] {
            XCTAssertNil(StraussFrische.tage(seit: kaputt, bis: "2026-10-08"))
            XCTAssertEqual(StraussFrische.von(gestellt: kaputt, heute: "2026-10-08"), .frisch)
        }
        XCTAssertEqual(StraussFrische.von(gestellt: "2026-10-20", heute: "2026-10-08"), .frisch, "a date in the future is not old")
    }

    func testWenigerFarbeJeAelter() {
        XCTAssertGreaterThan(StraussFrische.frisch.saettigung, StraussFrische.muede.saettigung)
        XCTAssertGreaterThan(StraussFrische.muede.saettigung, StraussFrische.welk.saettigung)
        XCTAssertLessThan(StraussFrische.muede.neigung, StraussFrische.welk.neigung)
        XCTAssertEqual(StraussFrische.frisch.neigung, 0)
    }

    func testAuswahlStempeltTagUndVergisstWasWeg() {
        var z = ZimmerStraeusse()
        z.schrankUmschalten(.lila, heute: "2026-10-01")
        z.vaseUmschalten(.rotBunt, heute: "2026-10-02")
        XCTAssertEqual(z.frisch, ["lila": "2026-10-01", "rotBunt": "2026-10-02"])
        z.schrankUmschalten(.lila, heute: "2026-10-05")
        XCTAssertEqual(z.frisch, ["rotBunt": "2026-10-02"], "taken off: its date falls away")
        z.vaseUmschalten(.rotBunt, heute: "2026-10-05")
        XCTAssertTrue(z.frisch.isEmpty)
    }

    func testSelbeArtInSchrankUndVaseBehaeltDenAltenTag() {
        var z = ZimmerStraeusse()
        z.schrankUmschalten(.lila, heute: "2026-10-01")
        z.vaseUmschalten(.lila, heute: "2026-10-04")
        XCTAssertEqual(z.frisch["lila"], "2026-10-01")
    }

    func testFuerBuehneNurMuedeUndWelke() {
        var z = ZimmerStraeusse()
        z.schrankUmschalten(.lila, heute: "2026-10-01")
        z.schrankUmschalten(.rotBunt, heute: "2026-10-06")
        z.vaseUmschalten(.pinkCreme, heute: "2026-09-20")
        let b = z.fuerBuehne(heute: "2026-10-08")
        XCTAssertEqual(b.frische, ["lila": .muede, "pinkCreme": .welk])
        XCTAssertNil(b.frische["rotBunt"])
        XCTAssertTrue(z.welkt(heute: "2026-10-08"))
        var frischer = ZimmerStraeusse()
        frischer.schrankUmschalten(.lila, heute: "2026-10-06")
        XCTAssertFalse(frischer.welkt(heute: "2026-10-08"))
    }

    func testAuffrischenMachtAllesFrisch() {
        var z = ZimmerStraeusse()
        z.schrankUmschalten(.lila, heute: "2026-09-01")
        z.vaseUmschalten(.pinkCreme, heute: "2026-09-02")
        z.auffrischen(heute: "2026-10-08")
        XCTAssertEqual(z.frisch, ["lila": "2026-10-08", "pinkCreme": "2026-10-08"])
        XCTAssertFalse(z.welkt(heute: "2026-10-08"))
    }

    func testStempelnNurWoDasDatumFehlt() {
        var z = ZimmerStraeusse(schrank: [.lila, .rotBunt], vase: .pinkCreme)
        z.frisch["lila"] = "2026-10-01"
        XCTAssertTrue(z.stempelnFallsFehlt(heute: "2026-10-08"))
        XCTAssertEqual(z.frisch, ["lila": "2026-10-01", "rotBunt": "2026-10-08", "pinkCreme": "2026-10-08"])
        XCTAssertFalse(z.stempelnFallsFehlt(heute: "2026-10-09"), "second time nothing to write")
        var leer = ZimmerStraeusse()
        XCTAssertFalse(leer.stempelnFallsFehlt(heute: "2026-10-08"))
    }

    func testJsonMitDatenUndAlteWerteOhne() {
        var z = ZimmerStraeusse()
        z.schrankUmschalten(.lila, heute: "2026-10-01")
        z.annehmen(.rosaGerbera, geschenk: "strauss-2026-10-07-annika", heute: "2026-10-07")
        XCTAssertEqual(ZimmerStraeusse.lesen(z.json), z)

        // What the old app wrote has none of the new keys: it reads as before.
        let alt = ZimmerStraeusse.lesen(.object(["schrank": .array([.string("lila")]), "vase": .string("rotBunt")]))
        XCTAssertEqual(alt, ZimmerStraeusse(schrank: [.lila], vase: .rotBunt))
        XCTAssertTrue(alt.frische(heute: "2030-01-01").isEmpty, "no date: never wilts")

        // And what the old app does not know does not hurt the new one.
        let wirr = ZimmerStraeusse.lesen(.object(["frisch": .object(["gibtEsNicht": .string("2026-10-01"), "lila": .number(3)]), "angenommen": .number(1)]))
        XCTAssertEqual(wirr, ZimmerStraeusse())
        XCTAssertNil(ZimmerStraeusse().json.objektWert("frisch"))
    }

    // MARK: 34 gift

    func testGeschenkNurWennIdZuTagUndPersonPasst() {
        let d = StraussGeschenkLogik.D(tag: "2026-10-08", strauss: "lila", text: "  Für dich  ")
        let id = StraussGeschenkLogik.opId(tag: "2026-10-08", von: .annika)
        let g = StraussGeschenkLogik.geschenk(id: id, von: .annika, d: d)
        XCTAssertEqual(g?.strauss, .lila)
        XCTAssertEqual(g?.text, "Für dich")
        XCTAssertNil(StraussGeschenkLogik.geschenk(id: id, von: .ahmed, d: d), "someone else's ID")
        XCTAssertNil(StraussGeschenkLogik.geschenk(id: "irgendwas", von: .annika, d: d))
        XCTAssertNil(StraussGeschenkLogik.geschenk(id: id, von: .annika, d: .init(tag: "2026-10-08", strauss: "gibtEsNicht", text: nil)))
    }

    func testGeschenkGibtDemSchenkerPunkte() {
        let g = StraussGeschenkLogik.Geschenk(id: "x", von: .ahmed, tag: "2026-10-08", strauss: .lila, text: nil)
        let e = StraussGeschenkLogik.eintraege([g])
        XCTAssertEqual(e, [PunkteLogik.Eintrag(datum: "2026-10-08", von: .ahmed, grund: StraussGeschenkLogik.grund, punkte: StraussGeschenkLogik.punkte)])
        XCTAssertGreaterThan(StraussGeschenkLogik.punkte, 0)
    }

    func testOffenIstDasNeuesteVomAnderenUndNochNichtAngenommene() {
        func g(_ tag: String, _ von: Person) -> StraussGeschenkLogik.Geschenk {
            .init(id: StraussGeschenkLogik.opId(tag: tag, von: von), von: von, tag: tag, strauss: .lila, text: nil)
        }
        let alle = [g("2026-10-06", .annika), g("2026-10-07", .annika), g("2026-10-08", .ahmed)]
        XCTAssertEqual(StraussGeschenkLogik.offen(alle, fuer: .ahmed, angenommen: nil)?.tag, "2026-10-07")
        XCTAssertNil(StraussGeschenkLogik.offen(alle, fuer: .ahmed, angenommen: g("2026-10-07", .annika).id), "taken; the older one is not offered again")
        XCTAssertEqual(StraussGeschenkLogik.offen(alle, fuer: .annika, angenommen: nil)?.von, .ahmed)
        XCTAssertNil(StraussGeschenkLogik.offen([], fuer: .ahmed, angenommen: nil))
    }

    func testKurzSchneidetUndLeertAus() {
        XCTAssertNil(StraussGeschenkLogik.kurz(nil))
        XCTAssertNil(StraussGeschenkLogik.kurz("   \n "))
        XCTAssertEqual(StraussGeschenkLogik.kurz(String(repeating: "a", count: 500))?.count, StraussGeschenkLogik.maxZeichen)
    }

    func testOpTraegtIdUndDaten() throws {
        let op = StraussGeschenkLogik.op(tag: "2026-10-08", von: .annika, strauss: .pinkCreme, text: "Hi")
        XCTAssertEqual(op.id, "strauss-2026-10-08-annika")
        XCTAssertEqual(op.art, StraussGeschenkLogik.art)
        let d = try XCTUnwrap(op.daten(StraussGeschenkLogik.D.self))
        XCTAssertEqual(d.strauss, "pinkCreme")
        XCTAssertEqual(d.text, "Hi")
    }

    // MARK: 37 album

    func testLiebesbriefeKommenInsMonatsblatt() {
        let zeit = Date(timeIntervalSince1970: 1_786_000_000) // 2026-08
        let brief = Brief(id: "b1", titel: SignaleLogik.liebesbriefTitel, text: " Ich denk an dich ", von: .annika, zeit: zeit)
        let monate = ZimmerAlbumLogik.monate(aus: [], ich: .ahmed, briefe: [brief])
        XCTAssertEqual(monate.map(\.id), ["2026-08"])
        XCTAssertEqual(monate.first?.saetze, [AlbumSatz(id: "b1", text: "Ich denk an dich", von: .annika, brief: true)])
        XCTAssertTrue(ZimmerAlbumLogik.monate(aus: [], ich: .ahmed).isEmpty, "without letters nothing changes")
    }

    func testNurGeoeffneteLiebesbriefeSindImAlbum() {
        let zeit = Date(timeIntervalSince1970: 1_786_000_000)
        let lieb = Brief(id: "a", titel: SignaleLogik.liebesbriefTitel, text: "Hallo", von: .annika, zeit: zeit)
        let zu = Brief(id: "b", titel: SignaleLogik.liebesbriefTitel, text: "Noch zu", von: .annika, zeit: zeit)
        let oeffne = Brief(id: "c", titel: "Öffne, wenn du mich vermisst", text: "Ich auch", von: .annika, zeit: zeit)
        var stand = BriefeStand()
        stand.briefe = ["a": lieb, "b": zu, "c": oeffne]
        stand.geoeffnet = ["a": zeit, "c": zeit]
        XCTAssertEqual(ZimmerAlbumLogik.liebesbriefe(stand).map(\.id), ["a"])
    }

    func testBriefeUndSaetzeTeilenSichDieObergrenze() {
        let zeit = Date(timeIntervalSince1970: 1_786_000_000)
        let briefe = (0..<5).map { Brief(id: "b\($0)", titel: SignaleLogik.liebesbriefTitel, text: "t\($0)", von: .ahmed, zeit: zeit.addingTimeInterval(Double($0))) }
        let monat = ZimmerAlbumLogik.monate(aus: [], ich: .ahmed, briefe: briefe).first
        XCTAssertEqual(monat?.saetze.count, ZimmerAlbumLogik.maxSaetze)
        XCTAssertEqual(monat?.saetze.first?.id, "b4", "the newest first")
    }

    // MARK: 38 live hint

    func testFingerabdruckAendertSichNurBeiRaumWerten() {
        let a: [String: JSONValue] = ["profil.raeume": .object(["a": .string("x")]), "flamme": .number(1)]
        var b = a
        b["flamme"] = .number(2)
        XCTAssertEqual(ZimmerHinweisLogik.fingerabdruck(a), ZimmerHinweisLogik.fingerabdruck(b), "other settings do not count")
        b["profil.raeume"] = .object(["a": .string("y")])
        XCTAssertNotEqual(ZimmerHinweisLogik.fingerabdruck(a), ZimmerHinweisLogik.fingerabdruck(b))
        var c = a
        c[ZimmerStraeusse.schluessel] = ZimmerStraeusse(schrank: [.lila]).json
        XCTAssertNotEqual(ZimmerHinweisLogik.fingerabdruck(a), ZimmerHinweisLogik.fingerabdruck(c))
    }

    func testFingerabdruckOhneWerteIstStabil() {
        XCTAssertEqual(ZimmerHinweisLogik.fingerabdruck(nil), "")
        XCTAssertEqual(ZimmerHinweisLogik.fingerabdruck([:]), ZimmerHinweisLogik.fingerabdruck(["x": .null]))
        XCTAssertEqual(ZimmerHinweisLogik.text(partner: .annika), "Annika hat etwas gestellt")
    }
}

private extension JSONValue {
    func objektWert(_ key: String) -> JSONValue? {
        guard case .object(let o) = self else { return nil }
        return o[key]
    }
}
