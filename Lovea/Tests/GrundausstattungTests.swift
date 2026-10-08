import XCTest
@testable import Lovea

/// p65 D: about five free pieces per person, everything else costs coins in the shop. Every shop piece has a
/// real short name, fits its person, and a drawing (an index the figure can show).
final class GrundausstattungTests: XCTestCase {
    typealias A = FigurAussehen

    private func katalog() throws -> [ShopArtikel] {
        let bundle = Bundle(for: FigurenModell.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "katalog", withExtension: "json")
                ?? bundle.url(forResource: "katalog", withExtension: "json", subdirectory: "Shop")
        )
        return try JSONDecoder().decode([ShopArtikel].self, from: try Data(contentsOf: url))
    }

    private func modeArtikel() throws -> [ShopArtikel] { try katalog().filter { $0.kategorie == "mode" } }

    private func tags(_ feld: ShopFeld) -> [FigurGeschlecht] {
        switch feld {
        case .oberteil: A.oberteileGeschlecht
        case .jacke: A.jackenGeschlecht
        case .hose: A.hosenGeschlecht
        case .schuhe: A.schuheGeschlecht
        case .brille: A.brillenGeschlecht
        }
    }

    private func anzahl(_ feld: ShopFeld) -> Int {
        switch feld {
        case .oberteil: A.oberteile.count
        case .jacke: A.jacken.count
        case .hose: A.hosen.count
        case .schuhe: A.schuhArten.count
        case .brille: A.brillen.count
        }
    }

    private func shopIndizes(_ feld: ShopFeld) -> Set<Int> {
        switch feld {
        case .oberteil: A.oberteileShop
        case .jacke: A.jackenShop
        case .hose: A.hosenShop
        case .schuhe: A.schuheShop
        case .brille: A.brillenShop
        }
    }

    // MARK: Free kit

    func testKitHatVierBisFuenfTeileJePerson() {
        for p in Person.allCases {
            let kit = A.grundausstattung(fuer: p)
            XCTAssertTrue((4...5).contains(kit.anzahl), "\(p): \(kit.anzahl) Teile")
        }
    }

    func testEditorBietetNurDasKitAn() {
        for p in Person.allCases {
            let kit = A.grundausstattung(fuer: p)
            let oben = Set(A.erlaubt(A.oberteile, geschlecht: A.oberteileGeschlecht, shop: A.oberteileShop, fuer: p))
            let ohneTeil: Set<Int> = A.passt(A.keinOberteil, A.oberteileGeschlecht, fuer: p) ? [A.keinOberteil] : []
            XCTAssertEqual(oben, kit.oberteile.union(ohneTeil), "oberteile \(p)")
            XCTAssertEqual(Set(A.erlaubt(A.hosen, geschlecht: A.hosenGeschlecht, shop: A.hosenShop, fuer: p)), kit.hosen, "hosen \(p)")
            XCTAssertEqual(Set(A.erlaubt(A.schuhArten, geschlecht: A.schuheGeschlecht, shop: A.schuheShop, fuer: p)), kit.schuhe, "schuhe \(p)")
            XCTAssertEqual(Set(A.erlaubt(A.jacken, geschlecht: A.jackenGeschlecht, shop: A.jackenShop, fuer: p)), [0], "jacken \(p)")
        }
    }

    func testStandardLookLiegtImKit() {
        for p in Person.allCases {
            let kit = A.grundausstattung(fuer: p)
            let a = A.standard(for: p)
            XCTAssertTrue(kit.oberteile.contains(a.oberteil), "oberteil \(p)")
            XCTAssertTrue(kit.hosen.contains(a.hose), "hose \(p)")
            XCTAssertTrue(kit.schuhe.contains(a.schuhe), "schuhe \(p)")
            XCTAssertEqual(a.jacke, 0, "jacke \(p)")
        }
    }

    func testOutfitsNutzenNurDasKit() {
        for p in Person.allCases {
            let kit = A.grundausstattung(fuer: p)
            for o in A.outfits(fuer: p) {
                XCTAssertTrue(kit.oberteile.contains(o.oberteil) || o.oberteil == A.keinOberteil, "\(p) \(o.name): oberteil")
                XCTAssertTrue(kit.hosen.contains(o.hose), "\(p) \(o.name): hose")
                XCTAssertTrue(kit.schuhe.contains(o.schuhe), "\(p) \(o.name): schuhe")
                XCTAssertEqual(o.jacke, 0, "\(p) \(o.name): jacke")
                XCTAssertEqual(o.kopfbedeckung, 0, "\(p) \(o.name): kopf")
            }
        }
    }

    func testJederHatMindestensDreiOutfits() {
        for p in Person.allCases { XCTAssertGreaterThanOrEqual(A.outfits(fuer: p).count, 3, "\(p)") }
    }

    func testAhmedsStilIstImKitDa() {
        let namen = A.outfits(fuer: .ahmed).map(\.name)
        for n in ["All Black", "All White", "Pink"] { XCTAssertTrue(namen.contains(n), n) }
    }

    func testKitNamenSindKurzUndEcht() {
        XCTAssertEqual(A.oberteile[32], "T-Shirt schwarz")
        XCTAssertEqual(A.hosen[18], "Baggy Jeans hellgrau")
        XCTAssertEqual(A.schuhArten[15], "Sneaker weiß")
    }

    func testListenUndTagsWachsenGemeinsam() {
        XCTAssertEqual(A.oberteile.count, A.oberteileGeschlecht.count)
        XCTAssertEqual(A.jacken.count, A.jackenGeschlecht.count)
        XCTAssertEqual(A.hosen.count, A.hosenGeschlecht.count)
        XCTAssertEqual(A.schuhArten.count, A.schuheGeschlecht.count)
    }

    func testAlteNamenBleibenAmAltenPlatz() {
        XCTAssertEqual(A.oberteile[19], "Nike Tech Fleece")
        XCTAssertEqual(A.oberteile[38], "Wickelkleid")
        XCTAssertEqual(A.schuhArten[10], "Nike Air Force 1")
        XCTAssertEqual(A.schuhArten[11], "Adidas Samba")
    }

    // MARK: Brand pieces

    func testNeueMarkenTeileSindEingetragen() {
        XCTAssertEqual(A.oberteile[39], "Ralph Lauren Polo")
        XCTAssertEqual(A.oberteile[40], "Adidas T-Shirt")
        XCTAssertEqual(A.oberteile[41], "Carhartt T-Shirt")
        XCTAssertEqual(A.oberteile[42], "The North Face T-Shirt")
        XCTAssertEqual(A.oberteile[43], "Nike Sport-Top")
        XCTAssertEqual(A.schuhArten[16], "Air Jordan 1")
        XCTAssertEqual(A.schuhArten[17], "Nike Dunk Low")
        XCTAssertEqual(A.oberteileGeschlecht[43], .w)
        for i in 39...42 { XCTAssertEqual(A.oberteileGeschlecht[i], .n, A.oberteile[i]) }
        XCTAssertEqual(A.schuheGeschlecht[16], .n)
        XCTAssertEqual(A.schuheGeschlecht[17], .n)
    }

    /// The new tops reuse a drawn base shape; the brand mark is drawn on top (`ModeMarken.swift`).
    func testMarkenOberteileZeigenAufEineGezeichneteBasis() {
        XCTAssertEqual(Set(A.markenBasis.keys), [39, 40, 41, 42, 43])
        for (i, basis) in A.markenBasis {
            XCTAssertTrue(A.oberteile.indices.contains(i))
            XCTAssertLessThan(basis, 39, "Basis von \(A.oberteile[i]) muss ein älterer Index sein")
        }
    }

    // MARK: Catalog

    func testKatalogHatGenugModeFuerBeide() throws {
        let mode = try modeArtikel()
        XCTAssertTrue((50...90).contains(mode.count), "\(mode.count) Mode-Teile")
        for p in Person.allCases {
            XCTAssertGreaterThanOrEqual(mode.filter { $0.sichtbar(fuer: p) }.count, 30, "\(p)")
        }
    }

    func testJederModeArtikelPasstZuSeinemListenIndex() throws {
        for a in try modeArtikel() {
            let e = try XCTUnwrap(A.shopTeile[a.id], a.id)
            XCTAssertTrue((0..<anzahl(e.feld)).contains(e.index), "\(a.id): Index \(e.index)")
            XCTAssertTrue(shopIndizes(e.feld).contains(e.index), "\(a.id): Index \(e.index) ist frei, nicht Shop")
            for p in Person.allCases where a.sichtbar(fuer: p) {
                XCTAssertTrue(A.passt(e.index, tags(e.feld), fuer: p), "\(a.id) wird \(p) gezeigt, passt aber nicht")
            }
        }
    }

    func testAhmedBekommtKeinenFrauenArtikel() throws {
        for a in try modeArtikel() where a.sichtbar(fuer: .ahmed) {
            let e = try XCTUnwrap(A.shopTeile[a.id], a.id)
            XCTAssertNotEqual(tags(e.feld)[e.index], .w, "\(a.id) ist ein Frauenteil")
            XCTAssertNotEqual(a.geschlecht, "w", a.id)
        }
    }

    func testAnnikaBekommtKeinenMaennerArtikel() throws {
        for a in try modeArtikel() where a.sichtbar(fuer: .annika) {
            let e = try XCTUnwrap(A.shopTeile[a.id], a.id)
            XCTAssertNotEqual(tags(e.feld)[e.index], .m, "\(a.id) ist ein Männerteil")
        }
    }

    func testZweiArtikelTragenNichtDasselbe() throws {
        var gesehen: [String: String] = [:]
        for a in try modeArtikel() {
            let e = try XCTUnwrap(A.shopTeile[a.id], a.id)
            let schluessel = "\(e.feld)|\(e.index)|\(e.hex ?? "-")"
            if let anderer = gesehen[schluessel] { XCTFail("\(a.id) und \(anderer) tragen dasselbe Teil") }
            gesehen[schluessel] = a.id
        }
    }

    /// `ohneEntfernteTeile` takes a removed piece off by (field, index, hex); a live article must never look like one.
    func testKeinArtikelGleichtEinemEntferntenTeil() throws {
        func schluessel(_ id: String) -> String? {
            A.shopTeile[id].map { "\($0.feld)|\($0.index)|\($0.hex ?? "-")" }
        }
        let entfernt = Set(ShopErstattung.entfernt.keys.compactMap(schluessel))
        for a in try modeArtikel() {
            let s = try XCTUnwrap(schluessel(a.id), a.id)
            XCTAssertFalse(entfernt.contains(s), "\(a.id) gleicht einem entfernten Teil: \(s)")
        }
    }

    func testMarkenStehenImArtikel() throws {
        let marken = ["Nike", "Adidas", "Jordan", "The North Face", "Ralph Lauren", "Carhartt", "Puma", "New Balance", "Levi's", "Gymshark"]
        var gefunden = Set<String>()
        for a in try modeArtikel() {
            for m in marken where a.name.contains(m) {
                XCTAssertEqual(a.marke, m, "\(a.id): Marke fehlt oder passt nicht zum Namen")
                gefunden.insert(m)
            }
        }
        XCTAssertEqual(gefunden, Set(marken), "Marken ohne Teil im Shop: \(Set(marken).subtracting(gefunden))")
    }

    func testNamenSindKurzUndOhneFantasie() throws {
        for a in try modeArtikel() {
            XCTAssertLessThanOrEqual(a.name.count, 32, a.name)
            XCTAssertFalse(a.name.contains("Cargo Jeans"), a.name)
        }
        let namen = Set(try modeArtikel().map(\.name))
        for n in ["Baggy Jeans schwarz", "Slim Fit Hemd weiß", "Denim Jacke", "Strickpullover creme"] {
            XCTAssertTrue(namen.contains(n), n)
        }
    }

    func testSchuheAusDemAuftragSindDa() throws {
        let namen = try modeArtikel().map(\.name)
        for n in ["Nike Air Force 1 weiß", "Adidas Samba", "Nike Dunk Low Panda"] { XCTAssertTrue(namen.contains(n), n) }
        XCTAssertTrue(namen.contains { $0.hasPrefix("Air Jordan 1") })
    }

    func testAnnikaHatEinenEigenenKatalog() throws {
        let nurFrau = try modeArtikel().filter { $0.geschlecht == "w" }
        XCTAssertGreaterThanOrEqual(nurFrau.count, 14)
        let felder = Set(nurFrau.compactMap { A.shopTeile[$0.id]?.feld })
        XCTAssertTrue(felder.isSuperset(of: [.oberteil, .hose, .schuhe, .jacke]))
        XCTAssertTrue(nurFrau.contains { $0.name.contains("Kleid") })
        XCTAssertTrue(nurFrau.contains { $0.name.lowercased().contains("rock") })
        XCTAssertTrue(nurFrau.contains { $0.marke == "Nike" })
    }
}
