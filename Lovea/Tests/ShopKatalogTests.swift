import XCTest
@testable import Lovea

/// `ShopKatalog.alle` itself reads `Bundle.main`, which is the app bundle only at real app
/// runtime — inside XCTest it is empty (see `SpieleTests.testWortlisteImBundleHatGut300...`), so
/// these tests load the bundled JSON the same way: `Bundle(for:)` an app-target class.
final class ShopKatalogTests: XCTestCase {
    private func geladenerKatalog() throws -> [ShopArtikel] {
        let bundle = Bundle(for: FigurenModell.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "katalog", withExtension: "json")
                ?? bundle.url(forResource: "katalog", withExtension: "json", subdirectory: "Shop")
        )
        return try JSONDecoder().decode([ShopArtikel].self, from: try Data(contentsOf: url))
    }

    func testShopArtikelDekodiertMitUndOhneMarke() throws {
        let json = #"[{"id":"a","name":"A","marke":"Gucci","kategorie":"mode","preis":300,"geschlecht":"n","exklusiv":false},{"id":"b","name":"B","marke":null,"kategorie":"tasche","preis":200,"geschlecht":"w","exklusiv":true}]"#
        let liste = try JSONDecoder().decode([ShopArtikel].self, from: Data(json.utf8))
        XCTAssertEqual(liste[0].marke, "Gucci")
        XCTAssertNil(liste[1].marke)
        XCTAssertTrue(liste[1].exklusiv)
    }

    func testKatalogHatEindeutigeArtikel() throws {
        let alle = try geladenerKatalog()
        XCTAssertEqual(Set(alle.map(\.id)).count, alle.count, "doppelte ids")
    }

    /// p47: nur Taschen, Haustiere und Mode, keine Pose und kein Tanz; p56 bringt den Schmuck zurück. p61: dazu das Zimmer.
    func testKatalogHatNurVierGruppen() throws {
        let alle = try geladenerKatalog()
        XCTAssertEqual(Set(alle.map(\.kategorie)), ["mode", "schmuck", "tasche", "tier", "zimmer"])
        XCTAssertFalse(alle.contains { $0.id.hasPrefix("pose.") || $0.name.contains("Tanz") || $0.name.contains("Pose") })
        for k in ["mode", "schmuck", "tasche", "tier", "zimmer"] {
            let n = alle.filter { $0.kategorie == k }.count
            // p65 D: Mode ist der große Kleiderschrank (nur ca. 5 Teile je Person sind frei), der Rest bleibt klein.
            let erlaubt = k == "mode" ? 50...90 : 4...10
            XCTAssertTrue(erlaubt.contains(n), "\(k): \(n) Teile, erwartet \(erlaubt)")
        }
    }

    /// Kein entferntes Teil im Katalog, jedes entfernte Teil in der Erstattungstabelle (ShopErstattungTests).
    func testEntfernteTeileSindWegUndNichtDoppelt() throws {
        let ids = Set(try geladenerKatalog().map(\.id))
        XCTAssertTrue(ids.isDisjoint(with: ShopErstattung.entfernt.keys), "\(ids.intersection(ShopErstattung.entfernt.keys))")
        for praefix in ["uhr.", "schmuck.", "brille.", "backdrop.", "pose."] {
            XCTAssertFalse(ids.contains { $0.hasPrefix(praefix) }, praefix)
        }
    }

    func testGuessTascheBleibtFuerAnnika() throws {
        let guess = try XCTUnwrap(try geladenerKatalog().first { $0.id == "tasche.guess-tasche" })
        XCTAssertTrue(guess.sichtbar(fuer: .annika))
        let taschen = try geladenerKatalog().filter { $0.kategorie == "tasche" }
        XCTAssertGreaterThanOrEqual(taschen.filter { $0.sichtbar(fuer: .annika) }.count, 5, "Fokus Annika")
    }

    func testKatalogPreiseInDenStufenAusSpec() throws {
        let alle = try geladenerKatalog()
        let stufen = [150...400, 800...2000, 3000...6000, 8000...15000]
        for a in alle {
            XCTAssertTrue(stufen.contains { $0.contains(a.preis) }, "\(a.id): \(a.preis) außerhalb der Preisstufen")
        }
    }

    func testKatalogGeschlechtUndExklusiv() throws {
        let alle = try geladenerKatalog()
        for a in alle { XCTAssertTrue(["w", "m", "n"].contains(a.geschlecht), a.id) }
        let exklusiv = alle.filter(\.exklusiv)
        XCTAssertGreaterThanOrEqual(exklusiv.count, 1)
        XCTAssertLessThanOrEqual(exklusiv.count, 2)
    }

    /// Every wearable id needs a drawing (or, for mode/brille, a `FigurAussehen.shopTeile` mapping) —
    /// otherwise a purchase renders as nothing.
    func testAlleTeileHabenEineZeichnungOderZuordnung() throws {
        let alle = try geladenerKatalog()
        for a in alle {
            switch a.kategorie {
            case "tasche": XCTAssertNotNil(taschenKatalog[a.id], a.id)
            case "tier": XCTAssertNotNil(haustierKatalog[a.id], a.id)
            case "mode": XCTAssertNotNil(FigurAussehen.shopTeile[a.id], a.id)
            case "zimmer": XCTAssertNotNil(ZimmerTeile.alle[a.id], a.id)
            case "schmuck": XCTAssertNotNil(schmuckKatalog[a.id], a.id)
            default: XCTFail("unbekannte Kategorie \(a.kategorie)")
            }
        }
    }

    /// Flammen und Chat-Themes sind raus, die Marken der Taschen bleiben.
    func testMarkenDerTaschen() throws {
        let alle = try geladenerKatalog()
        let marken = Set(alle.filter { $0.kategorie == "tasche" }.compactMap(\.marke))
        for m in ["Guess", "Louis Vuitton", "Chanel", "Gucci", "Dior"] { XCTAssertTrue(marken.contains(m), m) }
        XCTAssertFalse(alle.contains { $0.kategorie == "chatTheme" || $0.kategorie == "flamme" })
    }

    /// p65 D: every mode piece is shop-only (only the free kit is outside the shop sets), so its index must be
    /// hidden from the free editor.
    func testLuxusModeNurImShop() {
        typealias A = FigurAussehen
        for (id, e) in A.shopTeile {
            switch e.feld {
            case .oberteil: XCTAssertTrue(A.oberteileShop.contains(e.index), id)
            case .jacke: XCTAssertTrue(A.jackenShop.contains(e.index), id)
            case .hose: XCTAssertTrue(A.hosenShop.contains(e.index), id)
            case .schuhe: XCTAssertTrue(A.schuheShop.contains(e.index), id)
            case .brille: break
            }
        }
    }
}
