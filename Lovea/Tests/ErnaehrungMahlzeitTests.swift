import XCTest
@testable import Lovea

/// Gespeicherte Mahlzeit (Cornflakes, Milch, Honig): Summe und Auffalten in Tagebuch-Einträge.
final class ErnaehrungMahlzeitTests: XCTestCase {
    private let cornflakes = Lebensmittel(id: "off-1", name: "Cornflakes", pro100: Naehrwerte(kcal: 380, protein: 7, kohlenhydrate: 84, fett: 1))
    private let milch = Lebensmittel(id: "off-2", name: "Milch", fluessig: true, pro100: Naehrwerte(kcal: 64, protein: 3.4, kohlenhydrate: 4.8, fett: 3.5))
    private let honig = Lebensmittel(id: "off-3", name: "Honig", pro100: Naehrwerte(kcal: 300, protein: 0.4, kohlenhydrate: 75, fett: 0))

    private var mahlzeit: Rezept {
        Rezept(id: "m1", name: "Frühstück Standard", portionen: 1, zutaten: [
            Zutat(id: "z1", lebensmittel: cornflakes, menge: 40, einheit: .g),
            Zutat(id: "z2", lebensmittel: milch, menge: 200, einheit: .ml),
            Zutat(id: "z3", lebensmittel: honig, menge: 10, einheit: .g),
        ], art: .mahlzeit)
    }

    func testSummeIstSummeDerZutaten() {
        let s = ErnaehrungLogik.summe(mahlzeit)
        XCTAssertEqual(s.kcal, 152 + 128 + 30, accuracy: 0.001)
        XCTAssertEqual(s.protein, 2.8 + 6.8 + 0.04, accuracy: 0.001)
    }

    func testLeereMahlzeitHatKeineWerteUndKeineEintraege() {
        let leer = Rezept(id: "m0", name: "Leer", portionen: 1, zutaten: [], art: .mahlzeit)
        XCTAssertEqual(ErnaehrungLogik.summe(leer).kcal, 0)
        XCTAssertTrue(ErnaehrungLogik.eintraege(leer, mahlzeit: .snack, datum: "2026-10-08").isEmpty)
    }

    func testEintraegeEinerJeZutatMitEigenerId() {
        var n = 0
        let liste = ErnaehrungLogik.eintraege(mahlzeit, mahlzeit: .mittag, datum: "2026-10-08") { n += 1; return "e\(n)" }
        XCTAssertEqual(liste.map(\.id), ["e1", "e2", "e3"])
        XCTAssertEqual(liste.map(\.lebensmittel.name), ["Cornflakes", "Milch", "Honig"])
        XCTAssertEqual(liste.map(\.menge), [40, 200, 10])
        XCTAssertEqual(liste.map(\.einheit), [.g, .ml, .g])
        XCTAssertTrue(liste.allSatisfy { $0.mahlzeit == .mittag && $0.datum == "2026-10-08" && $0.geloescht == nil })
        XCTAssertEqual(ErnaehrungLogik.summe(liste).kcal, ErnaehrungLogik.summe(mahlzeit).kcal, accuracy: 0.001)
    }

    func testEintragAendernLaesstVorlageUnberuehrt() {
        let vorher = mahlzeit
        var liste = ErnaehrungLogik.eintraege(vorher, mahlzeit: .fruehstueck, datum: "2026-10-08")
        liste[0].menge = 80
        XCTAssertEqual(vorher.zutaten[0].menge, 40)
        XCTAssertEqual(vorher, mahlzeit)
    }

    func testAltesRezeptOhneArtBleibtLesbar() throws {
        let alt = Rezept(id: "r9", name: "Suppe", portionen: 4, zutaten: [Zutat(id: "z", lebensmittel: honig, menge: 5, einheit: .g)])
        let neu = try JSONDecoder().decode(Rezept.self, from: JSONEncoder().encode(alt))
        XCTAssertNil(neu.art)
        XCTAssertFalse(neu.istMahlzeit)
        XCTAssertEqual(neu.zutaten.count, 1)
    }

    func testMahlzeitRoundtrip() throws {
        let neu = try JSONDecoder().decode(Rezept.self, from: JSONEncoder().encode(mahlzeit))
        XCTAssertEqual(neu, mahlzeit)
        XCTAssertTrue(neu.istMahlzeit)
    }
}
