import XCTest
@testable import Lovea

/// Reine Ernährungslogik: Mengen, Ziele, Rezepte, Open-Food-Facts-Parser, Faltung.
final class ErnaehrungTests: XCTestCase {
    private let skyr = Lebensmittel(id: "off-1", name: "Skyr", pro100: Naehrwerte(kcal: 62, protein: 11, kohlenhydrate: 4, fett: 0.2),
                                    portionMenge: 150, packungMenge: 450)

    // MARK: - Mengen

    func testGrammUndPortion() {
        XCTAssertEqual(ErnaehrungLogik.naehrwerte(skyr, menge: 200, einheit: .g).kcal, 124, accuracy: 0.001)
        XCTAssertEqual(ErnaehrungLogik.naehrwerte(skyr, menge: 250, einheit: .ml).protein, 27.5, accuracy: 0.001)
        XCTAssertEqual(ErnaehrungLogik.naehrwerte(skyr, menge: 1, einheit: .portion).kcal, 93, accuracy: 0.001)
        XCTAssertEqual(ErnaehrungLogik.naehrwerte(skyr, menge: 0.5, einheit: .packung).protein, 24.75, accuracy: 0.001)
    }

    func testSummeUndOptionaleWerte() {
        let a = Naehrwerte(kcal: 100, protein: 10, kohlenhydrate: 5, fett: 1, zucker: 2)
        let b = Naehrwerte(kcal: 50, protein: 1, kohlenhydrate: 1, fett: 1)
        let s = a + b
        XCTAssertEqual(s.kcal, 150)
        XCTAssertEqual(s.zucker, 2)
        XCTAssertNil(s.salz)
    }

    func testMengeText() {
        XCTAssertEqual(ErnaehrungLogik.mengeText(1, .portion, skyr), "1 Portion (150 g)")
        XCTAssertEqual(ErnaehrungLogik.mengeText(250, .ml, skyr), "250 ml")
        XCTAssertEqual(ErnaehrungLogik.zahl(12.25), "12,3")
        XCTAssertEqual(ErnaehrungLogik.eingabe("12,5"), 12.5)
        XCTAssertNil(ErnaehrungLogik.eingabe("abc"))
    }

    // MARK: - Ziele

    func testKalorienzielHaltenUndAbnehmen() {
        var z = ErnaehrungsZiele()
        z.geschlecht = 0
        z.alter = 30
        z.groesseCm = 180
        z.aktivitaet = 2
        z.richtung = 1
        // 10*80 + 6,25*180 - 5*30 + 5 = 1780, mal 1,55 = 2759
        XCTAssertEqual(ErnaehrungLogik.kalorienziel(z, kg: 80), 2760)
        z.richtung = 0
        z.tempo = 500
        XCTAssertEqual(ErnaehrungLogik.kalorienziel(z, kg: 80), 2210)
    }

    func testKalorienzielNieUnterMinimum() {
        var z = ErnaehrungsZiele()
        z.geschlecht = 1
        z.alter = 60
        z.groesseCm = 150
        z.aktivitaet = 0
        z.richtung = 0
        z.tempo = 1000
        XCTAssertEqual(ErnaehrungLogik.kalorienziel(z, kg: 45), 1200)
    }

    func testMakrosProteinreich() {
        let m = ErnaehrungLogik.makros(kcal: 2000, kg: 90, profil: 1)
        XCTAssertEqual(m.protein, 180)
        XCTAssertEqual(m.fett, 67)
        XCTAssertEqual(m.kohlenhydrate, 170)
    }

    // MARK: - Rezepte

    func testRezeptAlsLebensmittel() {
        let hafer = Lebensmittel(id: "h", name: "Hafer", pro100: Naehrwerte(kcal: 370, protein: 13, kohlenhydrate: 59, fett: 7))
        let r = Rezept(id: "r", name: "Porridge", portionen: 2, zutaten: [
            Zutat(id: "1", lebensmittel: hafer, menge: 100, einheit: .g),
            Zutat(id: "2", lebensmittel: skyr, menge: 300, einheit: .g),
        ], geloescht: nil)
        let l = ErnaehrungLogik.alsLebensmittel(r)
        XCTAssertEqual(l.id, "rezept-r")
        XCTAssertEqual(l.portionMenge ?? 0, 200, accuracy: 0.001)
        // (370 + 186) kcal auf 400 g
        XCTAssertEqual(ErnaehrungLogik.naehrwerte(l, menge: 1, einheit: .portion).kcal, 278, accuracy: 0.01)
    }

    // MARK: - Open Food Facts

    func testOffProduktMitTextZahlenUndMarkeAlsText() throws {
        let json = """
        {"code":"4000417025005","status":1,"product":{"product_name":"Schokolade","product_name_de":"Voll-Nuss","brands":"Ritter Sport, Alfred Ritter",
        "serving_quantity":"16.7","product_quantity":100,"product_quantity_unit":"g","nutriscore_grade":"E",
        "nutriments":{"energy-kcal_100g":"496","proteins_100g":6.3,"carbohydrates_100g":52,"fat_100g":27,"sugars_100g":49,"salt_100g":"0,1"}}}
        """
        let l = try XCTUnwrap(ErnaehrungLogik.offProdukt(Data(json.utf8)))
        XCTAssertEqual(l.id, "off-4000417025005")
        XCTAssertEqual(l.name, "Voll-Nuss")
        XCTAssertEqual(l.marke, "Ritter Sport")
        XCTAssertEqual(l.pro100.kcal, 496)
        XCTAssertEqual(l.pro100.salz ?? 0, 0.1, accuracy: 0.0001)
        XCTAssertEqual(l.portionMenge ?? 0, 16.7, accuracy: 0.0001)
        XCTAssertEqual(l.nutriscore, "e")
        XCTAssertFalse(l.fluessig)
    }

    func testOffProduktNurKilojouleUndFluessig() throws {
        let json = """
        {"code":"1","status":1,"product":{"product_name":"Milch","product_quantity_unit":"ml","product_quantity":"1000",
        "nutriments":{"energy-kj_100g":2092,"proteins_100g":3.4}}}
        """
        let l = try XCTUnwrap(ErnaehrungLogik.offProdukt(Data(json.utf8)))
        XCTAssertEqual(l.pro100.kcal, 500, accuracy: 0.01)
        XCTAssertTrue(l.fluessig)
        XCTAssertEqual(l.packungMenge, 1000)
    }

    func testOffProduktUnbekannt() {
        XCTAssertNil(ErnaehrungLogik.offProdukt(Data(#"{"code":"1","status":0,"status_verbose":"product not found"}"#.utf8)))
        XCTAssertNil(ErnaehrungLogik.offProdukt(Data(#"{"code":"1","product":{"code":"1"},"status":1}"#.utf8)))
    }

    func testOffSucheMarkeAlsListe() {
        let json = """
        {"hits":[{"code":"8710624358174","brands":["Skyr"],"product_name":"Skyr naturel","nutriments":{"energy-kcal_100g":62,"proteins_100g":11}},
        {"code":"2","product_name":"Ohne Werte","nutriments":{}}]}
        """
        let treffer = ErnaehrungLogik.offSuche(Data(json.utf8))
        XCTAssertEqual(treffer.count, 1)
        XCTAssertEqual(treffer.first?.marke, "Skyr")
        XCTAssertEqual(treffer.first?.barcode, "8710624358174")
    }

    // MARK: - Faltung

    private func op(_ art: String, _ d: some Encodable, von: Person = .ahmed, sekunde: Double) throws -> Op {
        Op(id: UUID().uuidString, seq: nil, art: art, von: von, zeit: Date(timeIntervalSince1970: sekunde), d: try JSONEncoder().encode(d))
    }

    func testNeuesteGewinntUndLoeschen() throws {
        var f = ErnaehrungFaltung()
        let e = EssenEintrag(id: "e", datum: "2026-09-26", mahlzeit: .fruehstueck, menge: 200, einheit: .g, lebensmittel: skyr, geloescht: nil)
        var geaendert = e
        geaendert.menge = 300
        var weg = e
        weg.geloescht = true
        f.anwenden(try op("essen.setzen", geaendert, sekunde: 20))
        f.anwenden(try op("essen.setzen", e, sekunde: 10))
        XCTAssertEqual(f.eintraege(.ahmed, "2026-09-26").first?.menge, 300)
        XCTAssertTrue(f.eintraege(.annika, "2026-09-26").isEmpty)
        f.anwenden(try op("essen.setzen", weg, sekunde: 30))
        XCTAssertTrue(f.eintraege(.ahmed, "2026-09-26").isEmpty)
    }

    func testZuletztOhneDoppelteUndBarcodeOffline() throws {
        var f = ErnaehrungFaltung()
        var mitCode = skyr
        mitCode.barcode = "8710624358174"
        for (i, tag) in ["2026-09-24", "2026-09-25"].enumerated() {
            let e = EssenEintrag(id: "e\(i)", datum: tag, mahlzeit: .snack, menge: 1, einheit: .portion, lebensmittel: mitCode, geloescht: nil)
            f.anwenden(try op("essen.setzen", e, sekunde: Double(i)))
        }
        XCTAssertEqual(f.zuletzt(.ahmed).count, 1)
        XCTAssertEqual(f.lebensmittel(barcode: "8710624358174", .annika)?.name, "Skyr")
        XCTAssertEqual(f.letzteMenge(.ahmed, skyr.id)?.einheit, .portion)
    }
}
