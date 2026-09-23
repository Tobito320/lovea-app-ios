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
        let erwartet = ["mode", "tasche", "uhr", "schmuck", "brille", "backdrop", "chatTheme", "flamme", "pose", "tier"]
        let vorhanden = Set(alle.map(\.kategorie))
        for k in erwartet { XCTAssertTrue(vorhanden.contains(k), k) }
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
        XCTAssertGreaterThanOrEqual(anzahl("chatTheme"), 6)
        XCTAssertGreaterThanOrEqual(anzahl("flamme"), 8)
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
            case "chatTheme": XCTAssertNotNil(ChatThemes.von(a.id), a.id)
            case "flamme": XCTAssertNotNil(Flammen.von(a.id), a.id)
            case "backdrop": XCTAssertNotNil(BackdropKatalog.eintrag(a.id), a.id)
            default: XCTFail("unbekannte Kategorie \(a.kategorie)")
            }
        }
    }

    func testChatThemesUndFlammenMindestzahl() {
        XCTAssertGreaterThanOrEqual(ChatThemes.alle.count, 6)
        XCTAssertGreaterThanOrEqual(Flammen.alle.count, 8)
        XCTAssertEqual(Set(ChatThemes.alle.map(\.id)).count, ChatThemes.alle.count)
        XCTAssertEqual(Set(Flammen.alle.map(\.id)).count, Flammen.alle.count)
    }
}
