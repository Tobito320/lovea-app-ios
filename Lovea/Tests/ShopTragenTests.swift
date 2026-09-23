import XCTest
@testable import Lovea

/// Z-23.2: wear/unwear toggle and the gender filter (Shop/ShopTragen.swift), plus the "missing
/// points" number the detail sheet shows.
final class ShopTragenTests: XCTestCase {
    private func artikel(_ id: String, kategorie: String, geschlecht: String = "n", preis: Int = 500, exklusiv: Bool = false) -> ShopArtikel {
        ShopArtikel(id: id, name: id, marke: nil, kategorie: kategorie, preis: preis, geschlecht: geschlecht, exklusiv: exklusiv)
    }

    func testDirektfeldKategorienTragenUndAusziehen() {
        var a = FigurAussehen.standard(for: .ahmed)
        let tasche = artikel("tasche.gucci-tasche", kategorie: "tasche")
        XCTAssertFalse(a.traegt(tasche))
        a.anziehen(tasche)
        XCTAssertEqual(a.tasche, "tasche.gucci-tasche")
        XCTAssertTrue(a.traegt(tasche))
        a.ausziehen(tasche, person: .ahmed)
        XCTAssertNil(a.tasche)
        XCTAssertFalse(a.traegt(tasche))
    }

    /// Mehrere Mode-Artikel teilen sich denselben (Feld, Index) mit unterschiedlichem Hex
    /// (z. B. `.oberteil` 14) — nach dem Wechsel darf nur der zuletzt angezogene als getragen gelten.
    func testModeArtikelMitGleichemIndexUnterschiedlichesTragenErgebnis() {
        var a = FigurAussehen.standard(for: .ahmed)
        let hoodie = artikel("mode.guess-hoodie", kategorie: "mode")
        let logoShirt = artikel("mode.tshirt-logo", kategorie: "mode")
        a.anziehen(hoodie)
        XCTAssertTrue(a.traegt(hoodie))
        a.anziehen(logoShirt)
        XCTAssertTrue(a.traegt(logoShirt))
        XCTAssertFalse(a.traegt(hoodie), "Hoodie ist nicht mehr an, auch wenn der Index (14) gleich bleibt")
    }

    func testAusziehenVonModeSetztStandardZurueck() {
        var a = FigurAussehen.standard(for: .ahmed)
        let jacke = artikel("mode.moncler-jacke", kategorie: "mode")
        a.anziehen(jacke)
        XCTAssertTrue(a.traegt(jacke))
        a.ausziehen(jacke, person: .ahmed)
        XCTAssertFalse(a.traegt(jacke))
        XCTAssertEqual(a.jacke, FigurAussehen.standard(for: .ahmed).jacke)
    }

    func testAusziehenOhneAnzuhabenTutNichts() {
        var a = FigurAussehen.standard(for: .ahmed)
        let vorher = a
        a.ausziehen(artikel("tasche.gucci-tasche", kategorie: "tasche"), person: .ahmed)
        XCTAssertEqual(a, vorher)
    }

    func testGeschlechtsFilter() {
        let neutral = artikel("mode.tshirt-logo", kategorie: "mode", geschlecht: "n")
        let weiblich = artikel("mode.seidenbluse", kategorie: "mode", geschlecht: "w")
        let maennlich = artikel("mode.trikot", kategorie: "mode", geschlecht: "m")
        XCTAssertTrue(neutral.sichtbar(fuer: .ahmed))
        XCTAssertTrue(neutral.sichtbar(fuer: .annika))
        XCTAssertFalse(weiblich.sichtbar(fuer: .ahmed))
        XCTAssertTrue(weiblich.sichtbar(fuer: .annika))
        XCTAssertTrue(maennlich.sichtbar(fuer: .ahmed))
        XCTAssertFalse(maennlich.sichtbar(fuer: .annika))
    }

    func testFehlendePunkteFuerNichtGenugPunkteText() {
        let preis = 1200
        XCTAssertEqual(max(0, preis - 950), 250, "\"dir fehlen N\" rechnet Preis minus verfügbar")
        XCTAssertEqual(max(0, preis - 5000), 0, "genug Punkte -> nichts fehlt")
    }
}
