import XCTest
@testable import Lovea

/// p65 C2: the figure (Einstellungen, "Meine Figur") and the wardrobe (Profil, "Kleidung") are two halves of
/// one editor. No tab is in both, the wardrobe has the five clothing groups, and its shop row lists only
/// pieces the person may wear.
final class GarderobeTests: XCTestCase {
    private func artikel(_ id: String, preis: Int, geschlecht: String = "n", exklusiv: Bool = false) -> ShopArtikel {
        ShopArtikel(id: id, name: id, marke: nil, kategorie: "mode", preis: preis, geschlecht: geschlecht, exklusiv: exklusiv)
    }

    // MARK: Tabs

    func testFigurHatGesichtHaareAugenBartKoerper() {
        XCTAssertEqual(FigurEditor.tabs(fuer: .ahmed, bereich: .figur), ["Gesicht", "Haare", "Augen", "Bart", "Körper"])
    }

    func testAnnikaHatKeinenBart() {
        XCTAssertEqual(FigurEditor.tabs(fuer: .annika, bereich: .figur), ["Gesicht", "Haare", "Augen", "Körper"])
    }

    func testGarderobeHatDieFuenfGruppen() {
        for p in Person.allCases {
            let tabs = FigurEditor.tabs(fuer: p, bereich: .kleidung)
            for gruppe in ["Oberteile", "Hosen", "Schuhe", "Jacken", "Accessoires"] {
                XCTAssertTrue(tabs.contains(gruppe), "\(p): \(gruppe) fehlt")
            }
            XCTAssertEqual(tabs.first, "Outfits", "\(p)")
        }
    }

    func testKeinTabIstInBeidenHaelften() {
        for p in Person.allCases {
            let figur = Set(FigurEditor.tabs(fuer: p, bereich: .figur))
            let kleidung = Set(FigurEditor.tabs(fuer: p, bereich: .kleidung))
            XCTAssertTrue(figur.isDisjoint(with: kleidung), "\(p)")
        }
    }

    func testGarderobeHatKeinenBart() {
        XCTAssertFalse(FigurEditor.tabs(fuer: .ahmed, bereich: .kleidung).contains("Bart"))
    }

    // MARK: Shop row

    func testShopStueckeGehoerenZumFeld() {
        for feld in [ShopFeld.oberteil, .jacke, .hose, .schuhe, .brille] {
            for s in GarderobeLogik.shopStuecke(feld: feld, person: .annika, besitzt: { _ in false }) {
                XCTAssertEqual(FigurAussehen.shopTeile[s.artikel.id]?.feld, feld, s.artikel.id)
            }
        }
    }

    func testAhmedBekommtKeinenFrauenArtikelImShop() {
        for feld in [ShopFeld.oberteil, .jacke, .hose, .schuhe, .brille] {
            for s in GarderobeLogik.shopStuecke(feld: feld, person: .ahmed, besitzt: { _ in true }) {
                XCTAssertNotEqual(s.artikel.geschlecht, "w", s.artikel.id)
            }
        }
    }

    func testAnnikaBekommtKeinenMaennerArtikelImShop() {
        for feld in [ShopFeld.oberteil, .jacke, .hose, .schuhe, .brille] {
            for s in GarderobeLogik.shopStuecke(feld: feld, person: .annika, besitzt: { _ in true }) {
                XCTAssertNotEqual(s.artikel.geschlecht, "m", s.artikel.id)
            }
        }
    }

    func testBesitzZuerstDannNachPreis() {
        let katalog = [
            artikel("mode.tshirt-logo", preis: 300),
            artikel("mode.guess-hoodie", preis: 100),
            artikel("mode.nike-hoodie", preis: 200),
        ]
        let liste = GarderobeLogik.shopStuecke(feld: .oberteil, person: .ahmed, katalog: katalog, besitzt: { $0 == "mode.tshirt-logo" })
        XCTAssertEqual(liste.map(\.artikel.id), ["mode.tshirt-logo", "mode.guess-hoodie", "mode.nike-hoodie"])
        XCTAssertEqual(liste.map(\.besitzt), [true, false, false])
    }

    func testBelohnungenNurWennBesessen() {
        let katalog = [artikel("mode.tshirt-logo", preis: 0, exklusiv: true), artikel("mode.guess-hoodie", preis: 100)]
        let ohne = GarderobeLogik.shopStuecke(feld: .oberteil, person: .ahmed, katalog: katalog, besitzt: { _ in false })
        XCTAssertEqual(ohne.map(\.artikel.id), ["mode.guess-hoodie"])
        let mit = GarderobeLogik.shopStuecke(feld: .oberteil, person: .ahmed, katalog: katalog, besitzt: { _ in true })
        XCTAssertEqual(Set(mit.map(\.artikel.id)), ["mode.tshirt-logo", "mode.guess-hoodie"])
    }

    func testArtikelOhneFigurFeldFehlen() {
        let katalog = [artikel("mode.gibt-es-nicht", preis: 10), artikel("mode.guess-hoodie", preis: 100)]
        let liste = GarderobeLogik.shopStuecke(feld: .oberteil, person: .ahmed, katalog: katalog, besitzt: { _ in false })
        XCTAssertEqual(liste.map(\.artikel.id), ["mode.guess-hoodie"])
    }
}
