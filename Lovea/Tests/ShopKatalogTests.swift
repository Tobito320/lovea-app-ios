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

    func testKatalogHatMindestens80EindeutigeArtikel() throws {
        let alle = try geladenerKatalog()
        XCTAssertGreaterThanOrEqual(alle.count, 80)
        XCTAssertEqual(Set(alle.map(\.id)).count, alle.count, "doppelte ids")
    }

    func testKatalogDecktAlleKategorienAb() throws {
        let alle = try geladenerKatalog()
        let erwartet: Set<String> = ["mode", "tasche", "uhr", "schmuck", "brille", "backdrop", "pose", "tier"]
        // Z-39.2: Flammen und Chat-Themes sind raus, gekaufte werden erstattet (kein Katalog-Preis mehr).
        XCTAssertEqual(Set(alle.map(\.kategorie)), erwartet)
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

    func testKatalogMindestzahlenProKategorie() throws {
        let alle = try geladenerKatalog()
        func anzahl(_ k: String) -> Int { alle.filter { $0.kategorie == k }.count }
        XCTAssertGreaterThanOrEqual(anzahl("pose"), 4)
        XCTAssertGreaterThanOrEqual(anzahl("tier"), 4)
    }

    /// Every wearable id needs a drawing (or, for mode/brille, a `FigurAussehen.shopTeile` mapping) —
    /// otherwise a purchase renders as nothing.
    func testAlleTeileHabenEineZeichnungOderZuordnung() throws {
        let alle = try geladenerKatalog()
        let posenIds: Set<String> = ["pose.tanz1", "pose.tanz2", "pose.tanz3", "pose.tanz4", "pose.model"]
        for a in alle {
            switch a.kategorie {
            case "tasche": XCTAssertNotNil(taschenKatalog[a.id], a.id)
            case "uhr": XCTAssertNotNil(uhrenKatalog[a.id], a.id)
            case "schmuck": XCTAssertNotNil(schmuckKatalog[a.id], a.id)
            case "tier": XCTAssertNotNil(haustierKatalog[a.id], a.id)
            case "pose": XCTAssertTrue(posenIds.contains(a.id), a.id)
            case "mode", "brille": XCTAssertNotNil(FigurAussehen.shopTeile[a.id], a.id)
            case "backdrop": XCTAssertNotNil(BackdropKatalog.eintrag(a.id), a.id)
            default: XCTFail("unbekannte Kategorie \(a.kategorie)")
            }
        }
    }

    /// Z-39.2: every luxury house has at least one piece; flames and chat themes are gone.
    func testLuxusMarkenImShop() throws {
        let alle = try geladenerKatalog()
        let marken = Set(alle.compactMap(\.marke))
        for m in ["Gucci", "Dior", "Louis Vuitton", "Prada", "Balenciaga", "Moncler", "Chanel", "Rolex", "Cartier"] {
            XCTAssertTrue(marken.contains(m), m)
        }
        XCTAssertFalse(alle.contains { $0.kategorie == "chatTheme" || $0.kategorie == "flamme" })
    }

    /// Luxury mode pieces are shop-only: their index must be hidden from the free editor.
    func testLuxusModeNurImShop() {
        typealias A = FigurAussehen
        for (id, e) in A.shopTeile {
            switch e.feld {
            case .oberteil: XCTAssertTrue(A.oberteileShop.contains(e.index) || e.index < 14, id)
            case .jacke: XCTAssertTrue(A.jackenShop.contains(e.index) || e.index < 6, id)
            case .hose: XCTAssertTrue(A.hosenShop.contains(e.index) || e.index < 10, id)
            case .schuhe: XCTAssertTrue(A.schuheShop.contains(e.index) || e.index < 8, id)
            case .brille: break
            }
        }
    }
}
