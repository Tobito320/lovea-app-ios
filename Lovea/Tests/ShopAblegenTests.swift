import XCTest
@testable import Lovea

/// p47: Wer ein entferntes Teil trägt, legt es sauber ab; die Figur bleibt gültig.
final class ShopAblegenTests: XCTestCase {
    private func annika() -> FigurAussehen { .standard(for: .annika) }

    func testEntfernteTascheUhrUndSchmuckWerdenAbgelegt() {
        var a = annika()
        a.tasche = "tasche.prada-rucksack"
        a.uhr = "uhr.rolex"
        a.schmuck = "schmuck.perlenkette"
        let b = a.ohneEntfernteTeile()
        XCTAssertNil(b.tasche)
        XCTAssertNil(b.uhr)
        XCTAssertNil(b.schmuck)
    }

    /// p56: die neuen `juwel.*` bleiben beim Aufräumen, der alte `schmuck.*` im selben Feld geht.
    func testNeueJuwelenBleibenAlterSchmuckGeht() {
        var a = annika()
        a.schmuck = "schmuck.perlenkette,juwel.herzkette,juwel.cartier-love"
        XCTAssertEqual(a.ohneEntfernteTeile().schmuckListe, ["juwel.herzkette", "juwel.cartier-love"])
        a.schmuck = "schmuck.perlenkette"
        XCTAssertNil(a.ohneEntfernteTeile().schmuck)
    }

    func testBehaltenesBleibtAngezogen() {
        var a = annika()
        a.tasche = "tasche.guess-tasche"
        a.tier = "tier.hund-braun"
        a.anziehen("mode.nike-hoodie")
        XCTAssertEqual(a.ohneEntfernteTeile(), a)
    }

    func testEntfernteKleidungKehrtZumStandardZurueck() {
        let basis = annika()
        for id in ["mode.balenciaga-hoodie", "mode.dior-cape", "mode.glitzerhose", "mode.balenciaga-triple-s", "brille.cartier-sonnenbrille",
                   "mode.cargohose", "mode.seidenbluse", "mode.moncler-jacke", "mode.nike-sneaker"] {
            var a = basis
            a.anziehen(id)
            XCTAssertNotEqual(a, basis, id)
            XCTAssertEqual(a.ohneEntfernteTeile(), basis, "\(id) bleibt hängen")
        }
    }

    /// Indizes, die auch der freie Editor wählen kann, sind kein Shop-Teil: die bleiben.
    func testFreieEditorWahlBleibt() {
        for id in ["mode.bomberjacke", "brille.sport", "brille.guess"] {
            var a = annika()
            a.anziehen(id)
            XCTAssertEqual(a.ohneEntfernteTeile(), a, id)
        }
    }

    func testAblegenIstStabil() {
        var a = annika()
        a.tasche = "tasche.lv-koffer"
        a.anziehen("mode.gucci-ace")
        let einmal = a.ohneEntfernteTeile()
        XCTAssertEqual(einmal.ohneEntfernteTeile(), einmal)
    }

    func testAltesAussehenMitPoseFeldLaesstSichLesen() throws {
        let json = #"{"haut":1,"frisur":0,"haarfarbe":0,"augen":0,"brille":0,"bart":0,"oberteil":0,"oberteilfarbe":0,"pose":"pose.tanz1","uhr":"uhr.rolex"}"#
        let a = try JSONDecoder().decode(FigurAussehen.self, from: Data(json.utf8))
        XCTAssertEqual(a.haut, 1)
        XCTAssertNil(a.ohneEntfernteTeile().uhr)
    }

    func testGesteAuswahlHatKeinenTanz() {
        XCTAssertFalse(FigurZustand.mimik.contains(.tanzt))
    }
}
