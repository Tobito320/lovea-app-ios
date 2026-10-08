import XCTest
@testable import Lovea

final class ZimmerRitualeLogikTests: XCTestCase {
    private typealias L = ZimmerRitualeLogik

    func testMarkeRoundTrip() {
        let z = Date(timeIntervalSince1970: 1_760_000_000)
        let m = L.marke(tag: "2026-10-09", zeit: z)
        XCTAssertEqual(L.zerlegt(m)?.tag, "2026-10-09")
        XCTAssertEqual(L.zerlegt(m)?.zeit, z)
        XCTAssertNil(L.zerlegt("kaputt"))
        XCTAssertNil(L.zerlegt(nil))
    }

    func testErsterGewinntNurHeute() {
        let frueh = L.marke(tag: "2026-10-09", zeit: Date(timeIntervalSince1970: 100))
        let spaet = L.marke(tag: "2026-10-09", zeit: Date(timeIntervalSince1970: 200))
        let gestern = L.marke(tag: "2026-10-08", zeit: Date(timeIntervalSince1970: 50))
        XCTAssertEqual(L.erster([.ahmed: spaet, .annika: frueh], tag: "2026-10-09"), .annika)
        XCTAssertEqual(L.erster([.ahmed: gestern, .annika: spaet], tag: "2026-10-09"), .annika)
        XCTAssertNil(L.erster([.ahmed: gestern], tag: "2026-10-09"))
    }

    func testTexte() {
        XCTAssertEqual(L.vorhangText(oeffner: .annika, ich: .ahmed), "Annika hat die Vorhänge aufgemacht")
        XCTAssertEqual(L.teeText(macher: .ahmed, ich: .annika), "Ahmed hat dir Tee gemacht")
        XCTAssertNil(L.teeText(macher: nil, ich: .annika))
    }

    func testVorhangNurMorgensZu() {
        XCTAssertTrue(L.vorhangZu(offenHeute: false, stunde: 8))
        XCTAssertFalse(L.vorhangZu(offenHeute: true, stunde: 8))
        XCTAssertFalse(L.vorhangZu(offenHeute: false, stunde: 15))
        XCTAssertFalse(L.vorhangZu(offenHeute: false, stunde: 2))
    }

    func testKussZaehltImFenster() {
        let t = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(L.kussZaehlt(meinHalt: t, partnerHalt: t.addingTimeInterval(-9), schonGezaehlt: nil))
        XCTAssertFalse(L.kussZaehlt(meinHalt: t, partnerHalt: t.addingTimeInterval(-11), schonGezaehlt: nil))
        XCTAssertFalse(L.kussZaehlt(meinHalt: t, partnerHalt: nil, schonGezaehlt: nil))
    }

    func testKussZaehltNichtDoppelt() {
        let t = Date(timeIntervalSince1970: 1000)
        let p = t.addingTimeInterval(-3)
        XCTAssertFalse(L.kussZaehlt(meinHalt: t.addingTimeInterval(2), partnerHalt: p, schonGezaehlt: p))
        XCTAssertTrue(L.kussZaehlt(meinHalt: t.addingTimeInterval(2), partnerHalt: p, schonGezaehlt: p.addingTimeInterval(-60)))
    }

    func testHaeltGerade() {
        let t = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(L.haeltGerade(halt: t, jetzt: t.addingTimeInterval(5)))
        XCTAssertFalse(L.haeltGerade(halt: t, jetzt: t.addingTimeInterval(11)))
        XCTAssertFalse(L.haeltGerade(halt: nil, jetzt: t))
    }

    func testGlasHerzenGedeckelt() {
        XCTAssertEqual(L.glasHerzen(-3), 0)
        XCTAssertEqual(L.glasHerzen(5), 5)
        XCTAssertEqual(L.glasHerzen(500), L.glasMaximum)
    }

    func testFrageProTagGleichUndWechselnd() {
        let a = L.fragenIndex(tag: "2026-10-09", anzahl: 60)
        XCTAssertEqual(a, L.fragenIndex(tag: "2026-10-09", anzahl: 60))
        XCTAssertEqual((a + 1) % 60, L.fragenIndex(tag: "2026-10-10", anzahl: 60))
        XCTAssertEqual(L.fragenIndex(tag: "kaputt", anzahl: 60), 0)
        XCTAssertEqual(L.fragenIndex(tag: "2026-10-09", anzahl: 0), 0)
    }

    func testFragenListe() {
        XCTAssertGreaterThanOrEqual(ZimmerRitualeFragen.alle.count, 60)
        XCTAssertEqual(Set(ZimmerRitualeFragen.alle).count, ZimmerRitualeFragen.alle.count)
        XCTAssertFalse(ZimmerRitualeFragen.frage(tag: "2026-10-09").isEmpty)
    }

    func testAntwortenVerdecktBisBeide() {
        XCTAssertFalse(L.antwortenOffen(meine: "ja", partner: nil))
        XCTAssertFalse(L.antwortenOffen(meine: nil, partner: "ja"))
        XCTAssertFalse(L.antwortenOffen(meine: "", partner: "ja"))
        XCTAssertTrue(L.antwortenOffen(meine: "a", partner: "b"))
    }

    func testBereinigt() {
        XCTAssertNil(L.bereinigt("   \n", maximal: 10))
        XCTAssertEqual(L.bereinigt("  hallo  ", maximal: 10), "hallo")
        XCTAssertEqual(L.bereinigt("abcdefgh", maximal: 3), "abc")
    }

    func testWunschHinzuUndGold() {
        var liste = L.wunschHinzu([], text: "  Kino  ", id: "a")
        liste = L.wunschHinzu(liste, text: "Meer", id: "b")
        liste = L.wunschHinzu(liste, text: "   ", id: "c")
        XCTAssertEqual(liste.map(\.id), ["a", "b"])
        XCTAssertEqual(liste.first?.text, "Kino")
        XCTAssertEqual(L.gold(liste, erfuellt: ["b", "zzz"]), 1)
        XCTAssertEqual(L.gold(liste, erfuellt: []), 0)
    }

    func testWunschGlasVoll() {
        var liste: [L.Wunsch] = []
        for i in 0..<30 { liste = L.wunschHinzu(liste, text: "w\(i)", id: "\(i)") }
        XCTAssertEqual(liste.count, L.wuenscheMaximum)
    }

    func testUmschalten() {
        XCTAssertEqual(L.umschalten([], id: "a"), ["a"])
        XCTAssertEqual(L.umschalten(["a", "b"], id: "a"), ["b"])
    }

    func testUmarmt() {
        let t = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(L.umarmt(ichDa: true, partnerBis: t.addingTimeInterval(5), jetzt: t))
        XCTAssertFalse(L.umarmt(ichDa: true, partnerBis: t.addingTimeInterval(-5), jetzt: t))
        XCTAssertFalse(L.umarmt(ichDa: false, partnerBis: t.addingTimeInterval(5), jetzt: t))
    }
}
