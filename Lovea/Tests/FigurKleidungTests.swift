import XCTest
@testable import Lovea

/// p65 C1: clothing is per person. Ahmed is offered no women's piece, Annika no men's piece, and a saved
/// look that wears a piece its person may not wear is reset to the person's default for that part.
final class FigurKleidungTests: XCTestCase {
    typealias A = FigurAussehen

    private struct Teil {
        let feld: String
        let namen: [String]
        let erlaubt: [Int]
    }

    /// What the editor offers `p`, per clothing part.
    private func frei(_ p: Person) -> [Teil] {
        [
            Teil(feld: "oberteil", namen: A.oberteile, erlaubt: A.erlaubt(A.oberteile, geschlecht: A.oberteileGeschlecht, shop: A.oberteileShop, fuer: p)),
            Teil(feld: "jacke", namen: A.jacken, erlaubt: A.erlaubt(A.jacken, geschlecht: A.jackenGeschlecht, shop: A.jackenShop, fuer: p)),
            Teil(feld: "hose", namen: A.hosen, erlaubt: A.erlaubt(A.hosen, geschlecht: A.hosenGeschlecht, shop: A.hosenShop, fuer: p)),
            Teil(feld: "schuhe", namen: A.schuhArten, erlaubt: A.erlaubt(A.schuhArten, geschlecht: A.schuheGeschlecht, shop: A.schuheShop, fuer: p)),
            Teil(feld: "brille", namen: A.brillen, erlaubt: A.erlaubt(A.brillen, geschlecht: A.brillenGeschlecht, shop: A.brillenShop, fuer: p)),
            Teil(feld: "kopf", namen: A.kopfbedeckungen, erlaubt: A.erlaubt(A.kopfbedeckungen, geschlecht: A.kopfbedeckungenGeschlecht, fuer: p)),
        ]
    }

    func testGeschlechtTagsPassenZuListen() {
        XCTAssertEqual(A.jacken.count, A.jackenGeschlecht.count)
        XCTAssertEqual(A.schuhArten.count, A.schuheGeschlecht.count)
        XCTAssertEqual(A.brillen.count, A.brillenGeschlecht.count)
        XCTAssertEqual(A.kopfbedeckungen.count, A.kopfbedeckungenGeschlecht.count)
    }

    func testAhmedBekommtKeineFrauenteile() {
        let frauen = ["Top", "Trägertop", "Crop-Top", "Kleid", "Rock", "Minirock", "Leggings", "Puma Leggings",
                      "Zara Rippstrick-Top", "Ballerinas", "Cat-Eye", "Herz-Sonnenbrille", "Haarreif"]
        for teil in frei(.ahmed) {
            for i in teil.erlaubt { XCTAssertFalse(frauen.contains(teil.namen[i]), "\(teil.feld): \(teil.namen[i]) wird Ahmed angeboten") }
        }
    }

    func testAhmedHatNurMaennlicheOderNeutraleTags() {
        let tags: [(String, [FigurGeschlecht])] = [
            ("oberteil", A.oberteileGeschlecht), ("jacke", A.jackenGeschlecht), ("hose", A.hosenGeschlecht),
            ("schuhe", A.schuheGeschlecht), ("brille", A.brillenGeschlecht), ("kopf", A.kopfbedeckungenGeschlecht),
        ]
        let angeboten = frei(.ahmed)
        for (feld, liste) in tags {
            let erlaubt = angeboten.first { $0.feld == feld }!.erlaubt
            for i in erlaubt { XCTAssertNotEqual(liste[i], .w, "\(feld) \(i) ist ein Frauenteil") }
        }
    }

    func testAnnikaBehaeltFrauenteileUndBekommtKeineMaennerteile() {
        let angeboten = frei(.annika)
        let oberteile = angeboten.first { $0.feld == "oberteil" }!
        let top = A.oberteile.firstIndex(of: "Top")!, crop = A.oberteile.firstIndex(of: "Crop-Top")!
        XCTAssertTrue(oberteile.erlaubt.contains(top))
        XCTAssertTrue(oberteile.erlaubt.contains(crop))
        let schuhe = angeboten.first { $0.feld == "schuhe" }!
        XCTAssertTrue(schuhe.erlaubt.contains(A.schuhArten.firstIndex(of: "Ballerinas")!))
        for i in oberteile.erlaubt { XCTAssertNotEqual(A.oberteileGeschlecht[i], .m, A.oberteile[i]) }
    }

    func testFrauenTeileSindMarkiert() {
        for name in ["Top", "Trägertop", "Crop-Top", "Seidenbluse"] {
            XCTAssertEqual(A.oberteileGeschlecht[A.oberteile.firstIndex(of: name)!], .w, name)
        }
        for name in ["Leggings", "Glitzerhose"] {
            XCTAssertEqual(A.hosenGeschlecht[A.hosen.firstIndex(of: name)!], .w, name)
        }
        XCTAssertEqual(A.schuheGeschlecht[A.schuhArten.firstIndex(of: "Ballerinas")!], .w)
        XCTAssertEqual(A.jackenGeschlecht[A.jacken.firstIndex(of: "Cape")!], .w)
    }

    func testStandardLooksBleibenUnveraendert() {
        for p in Person.allCases {
            let a = A.standard(for: p)
            XCTAssertEqual(A.mitGueltigerKleidung(a, p), a, "\(p)")
        }
    }

    func testAlleOutfitsDerPersonSindGueltig() {
        for p in Person.allCases {
            for o in A.outfits(fuer: p) {
                var a = A.standard(for: p)
                a.anziehen(outfit: o)
                XCTAssertEqual(A.mitGueltigerKleidung(a, p), a, "\(p): \(o.name)")
            }
        }
    }

    func testFrauenteileBeiAhmedWerdenZurueckgesetzt() {
        let basis = A.standard(for: .ahmed)
        var a = basis
        a.oberteil = A.oberteile.firstIndex(of: "Crop-Top")!
        a.oberteilfarbe = 12
        a.oberteilfarbeHex = "F7B6C8"
        a.hose = A.hosen.firstIndex(of: "Leggings")!
        a.hosenfarbeHex = "2B2830"
        a.jacke = A.jacken.firstIndex(of: "Cape")!
        a.schuhe = A.schuhArten.firstIndex(of: "Ballerinas")!
        a.brille = A.brillen.firstIndex(of: "Cat-Eye")!
        a.kopfbedeckung = A.kopfbedeckungen.firstIndex(of: "Haarreif")!
        let neu = A.mitGueltigerKleidung(a, .ahmed)
        XCTAssertEqual(neu.oberteil, basis.oberteil)
        XCTAssertEqual(neu.oberteilfarbe, basis.oberteilfarbe)
        XCTAssertNil(neu.oberteilfarbeHex)
        XCTAssertEqual(neu.hose, basis.hose)
        XCTAssertNil(neu.hosenfarbeHex)
        XCTAssertEqual(neu.jacke, basis.jacke)
        XCTAssertEqual(neu.schuhe, basis.schuhe)
        XCTAssertEqual(neu.brille, basis.brille)
        XCTAssertEqual(neu.kopfbedeckung, basis.kopfbedeckung)
    }

    func testGueltigesBleibtUndFaceUndHaareAuch() {
        var a = A.standard(for: .ahmed)
        a.oberteil = A.oberteile.firstIndex(of: "Hoodie")!
        a.oberteilfarbeHex = "F2A9BA"
        a.schuhe = A.schuhArten.firstIndex(of: "Nike Air Force 1")!
        a.frisur = 80
        a.haut = 3
        XCTAssertEqual(A.mitGueltigerKleidung(a, .ahmed), a)
    }

    func testShopTeileBleibenWennGeschlechtPasst() {
        var a = A.standard(for: .ahmed)
        a.oberteil = A.oberteile.firstIndex(of: "Logo-Hoodie")!  // nur im Shop, aber neutral
        XCTAssertEqual(A.mitGueltigerKleidung(a, .ahmed).oberteil, a.oberteil)
    }

    func testUngueltigerIndexWirdZurueckgesetzt() {
        let basis = A.standard(for: .annika)
        var a = basis
        a.oberteil = 999
        a.hose = -1
        a.schuhe = A.schuhArten.count
        let neu = A.mitGueltigerKleidung(a, .annika)
        XCTAssertEqual(neu.oberteil, basis.oberteil)
        XCTAssertEqual(neu.hose, basis.hose)
        XCTAssertEqual(neu.schuhe, basis.schuhe)
    }

    func testMaennerteileBeiAnnikaWerdenZurueckgesetzt() {
        let basis = A.standard(for: .annika)
        var a = basis
        a.oberteil = A.oberteile.firstIndex(of: "Schwarzes Rundhals-Tee")!
        a.hose = A.hosen.firstIndex(of: "Schwarze Gym-Shorts")!
        let neu = A.mitGueltigerKleidung(a, .annika)
        XCTAssertEqual(neu.oberteil, basis.oberteil)
        XCTAssertEqual(neu.hose, basis.hose)
    }
}
