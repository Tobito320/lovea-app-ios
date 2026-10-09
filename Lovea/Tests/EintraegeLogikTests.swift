import XCTest
@testable import Lovea

/// "Schreib, was war": Antwort des Servers lesen, Abbildung auf Gläser/Stimmung, Erkennung von "trag das ein".
final class EintraegeLogikTests: XCTestCase {

    private func lesen(_ json: String) -> [KIEintrag]? {
        EintraegeLogik.lesen(Data(json.utf8), tag: "2026-10-09")
    }

    func testEssenWirdGelesenMitMahlzeit() {
        let e = lesen(#"{"eintraege":[{"typ":"essen","datum":"2026-10-09","name":"Skyr","mahlzeit":"fruehstueck","menge":250,"einheit":"g","kcal":160,"protein":27,"kohlenhydrate":10,"fett":1}]}"#)
        XCTAssertEqual(e?.count, 1)
        guard case .essen(let datum, let name, let menge, let fluessig, let mahlzeit, let n)? = e?.first else { return XCTFail() }
        XCTAssertEqual(datum, "2026-10-09")
        XCTAssertEqual(name, "Skyr")
        XCTAssertEqual(menge, 250)
        XCTAssertFalse(fluessig)
        XCTAssertEqual(mahlzeit, .fruehstueck)
        XCTAssertEqual(n.kcal, 160)
        XCTAssertEqual(n.protein, 27)
    }

    func testFehlendesDatumNimmtStandardTag() {
        let e = lesen(#"{"eintraege":[{"typ":"wasser","ml":500}]}"#)
        XCTAssertEqual(e, [.wasser(datum: "2026-10-09", ml: 500)])
    }

    func testUnvollstaendigesUndUnbekanntesFaelltWeg() {
        let e = lesen(#"{"eintraege":[{"typ":"essen","name":"Brot"},{"typ":"magie"},{"typ":"stimmung","stimmung":9},{"typ":"training","name":"Laufen","minuten":30}]}"#)
        XCTAssertEqual(e, [.training(datum: "2026-10-09", name: "Laufen", minuten: 30)])
    }

    func testKaputteAntwortIstNil() {
        XCTAssertNil(lesen("kein json"))
        XCTAssertNil(lesen(#"{"x":1}"#))
    }

    func testSchlafBekommtDatenUeberNacht() {
        let e = lesen(#"{"eintraege":[{"typ":"schlaf","datum":"2026-10-09","bett":"23:30","auf":"06:30"}]}"#)
        guard case .schlaf(_, let bett, let auf)? = e?.first else { return XCTFail() }
        XCTAssertEqual(auf.timeIntervalSince(bett), 7 * 3600, accuracy: 1)
    }

    func testGlaeserRundenMitMindestensEinem() {
        XCTAssertEqual(EintraegeLogik.glaeser(ml: 500), 2)
        XCTAssertEqual(EintraegeLogik.glaeser(ml: 100), 1)
        XCTAssertEqual(EintraegeLogik.glaeser(ml: 1000), 4)
    }

    func testStimmungStufen() {
        XCTAssertEqual(EintraegeLogik.stimmungText(1), "schlecht")
        XCTAssertEqual(EintraegeLogik.stimmungText(2), "schlecht")
        XCTAssertEqual(EintraegeLogik.stimmungText(3), "mittel")
        XCTAssertEqual(EintraegeLogik.stimmungText(5), "gut")
    }

    func testLebensmittelRechnetAufHundertUm() {
        let n = Naehrwerte(kcal: 400, protein: 20, kohlenhydrate: 40, fett: 10)
        let l = EintraegeLogik.lebensmittel(name: "Pasta", menge: 200, fluessig: false, summe: n)
        XCTAssertEqual(l.pro100.kcal, 200, accuracy: 0.001)
        XCTAssertEqual(l.pro100.protein, 10, accuracy: 0.001)
        XCTAssertTrue(l.id.hasPrefix("schnell-"))
        XCTAssertEqual(ErnaehrungLogik.naehrwerte(l, menge: 200, einheit: .g).kcal, 400, accuracy: 0.001)
    }

    func testTragDasEinErkennung() {
        XCTAssertTrue(EintraegeLogik.klingtNachEintragen("Trag das ein"))
        XCTAssertTrue(EintraegeLogik.klingtNachEintragen("Ich habe gerade eine Pizza gegessen"))
        XCTAssertTrue(EintraegeLogik.klingtNachEintragen("heute 2 Liter getrunken und 30 min Gym"))
        XCTAssertFalse(EintraegeLogik.klingtNachEintragen("Wie viel Eiweiß hat Quark?"))
        XCTAssertFalse(EintraegeLogik.klingtNachEintragen("Wie war mein Schlaf?"))
        XCTAssertFalse(EintraegeLogik.klingtNachEintragen("Danke dir"))
    }

    func testBeschreibungOhneEmojis() {
        let s = EintraegeLogik.beschreibung(.wasser(datum: "2026-10-09", ml: 500))
        XCTAssertEqual(s, "Wasser +500 ml")
        XCTAssertTrue(EintraegeLogik.beschreibung(.stimmung(datum: "2026-10-09", stufe: 4)).contains("gut"))
    }
}
