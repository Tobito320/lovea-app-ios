import XCTest
@testable import Lovea

/// Das selbstpflegende Zimmer: Bett aus dem Schlaf, Schuhe aus den Schritten, Pokale aus den Punkten,
/// dazu der Verlauf der getragenen Outfits für die Kleiderstange.
final class ZimmerZustandLogikTests: XCTestCase {
    func testBettOhneDatenIstGemacht() {
        XCTAssertTrue(ZimmerZustandLogik.bettGemacht(schlafMinuten: nil, ziel: 480))
    }

    func testBettGenau75ProzentIstGemacht() {
        XCTAssertTrue(ZimmerZustandLogik.bettGemacht(schlafMinuten: 360, ziel: 480))
        XCTAssertFalse(ZimmerZustandLogik.bettGemacht(schlafMinuten: 359, ziel: 480))
        XCTAssertFalse(ZimmerZustandLogik.bettGemacht(schlafMinuten: 0, ziel: 480))
        XCTAssertTrue(ZimmerZustandLogik.bettGemacht(schlafMinuten: 600, ziel: 480))
    }

    func testSchuheErstAmZiel() {
        XCTAssertFalse(ZimmerZustandLogik.schuheDa(schritte: 9_999, ziel: 10_000))
        XCTAssertTrue(ZimmerZustandLogik.schuheDa(schritte: 10_000, ziel: 10_000))
        XCTAssertTrue(ZimmerZustandLogik.schuheDa(schritte: 10_001, ziel: 10_000))
        XCTAssertFalse(ZimmerZustandLogik.schuheDa(schritte: nil, ziel: 10_000))
        XCTAssertFalse(ZimmerZustandLogik.schuheDa(schritte: 5, ziel: 0))
    }

    func testPokaleAnDenSchwellen() {
        for stufe in [ZimmerPokal.Stufe.bronze, .silber, .gold] {
            let s = ZimmerZustandLogik.schwelle(stufe)
            XCTAssertFalse(ZimmerZustandLogik.pokale(punkte: s - 1).contains(stufe), "\(stufe) bei \(s - 1)")
            XCTAssertTrue(ZimmerZustandLogik.pokale(punkte: s).contains(stufe), "\(stufe) bei \(s)")
            XCTAssertTrue(ZimmerZustandLogik.pokale(punkte: s + 1).contains(stufe), "\(stufe) bei \(s + 1)")
        }
        XCTAssertEqual(ZimmerZustandLogik.pokale(punkte: 0), [])
        XCTAssertEqual(ZimmerZustandLogik.pokale(punkte: 1_000_000), [.gold, .silber, .bronze])
    }

    func testPokaleMischenSpielUndPunkteHoechsteZuerstMaxDrei() {
        XCTAssertEqual(ZimmerZustandLogik.pokale(spiel: [.bronze, .silber], punkte: 0), [.silber, .bronze])
        XCTAssertEqual(ZimmerZustandLogik.pokale(spiel: [.bronze, .bronze], punkte: 5_000), [.gold, .silber, .bronze])
        XCTAssertEqual(ZimmerZustandLogik.pokale(spiel: [], punkte: 0), [])
    }

    private func kleidung(_ n: Int) -> FigurAussehen {
        var a = FigurAussehen.standard(for: .ahmed)
        a.oberteil = n
        return a
    }

    func testVerlaufNeuestesVornUndHoechstensFuenf() {
        var v: [FigurAussehen] = []
        for n in 1...7 { v = ZimmerZustandLogik.verlauf(v, neu: kleidung(n)) }
        XCTAssertEqual(v.count, 5)
        XCTAssertEqual(v.map(\.oberteil), [7, 6, 5, 4, 3])
    }

    func testVerlaufGleicheKleidungRutschtNachVornOhneDoppelt() {
        var v: [FigurAussehen] = []
        for n in 1...3 { v = ZimmerZustandLogik.verlauf(v, neu: kleidung(n)) }
        v = ZimmerZustandLogik.verlauf(v, neu: kleidung(1))
        XCTAssertEqual(v.map(\.oberteil), [1, 3, 2])
    }

    func testVerlaufUnterscheidetNurNachKleidungNichtNachGesicht() {
        var gesicht = kleidung(2)
        gesicht.haut = 3
        let v = ZimmerZustandLogik.verlauf([kleidung(2)], neu: gesicht)
        XCTAssertEqual(v.count, 1)
    }

    func testNeuePaketeNurUngesehenesSortiert() {
        XCTAssertEqual(ZimmerZustandLogik.neuePakete(besitz: ["b", "a", "c"], gesehen: ["c"]), ["a", "b"])
        XCTAssertEqual(ZimmerZustandLogik.neuePakete(besitz: ["a"], gesehen: ["a", "z"]), [])
    }
}
