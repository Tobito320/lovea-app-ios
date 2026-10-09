import XCTest
@testable import Lovea

final class ZimmerSammlungLogikTests: XCTestCase {
    typealias L = ZimmerSammlungLogik

    func testDankeZaehlen() {
        let texte: [String?] = ["Danke dir!", "DANKESCHÖN", "dank", nil, "", "nix", "ich danke dir"]
        XCTAssertEqual(L.dankeZaehlen(texte), 3)
    }

    func testHerbstUndHaufen() {
        let sommer = L.tagDatum("2026-07-10")!
        let oktober = L.tagDatum("2026-10-09")!
        XCTAssertFalse(L.istHerbst(sommer))
        XCTAssertTrue(L.istHerbst(oktober))
        XCTAssertTrue(L.blaetter(gesamt: 9, herbst: false) == (9, 0))
        XCTAssertTrue(L.blaetter(gesamt: 9, herbst: true) == (6, 3))
        XCTAssertTrue(L.blaetter(gesamt: -2, herbst: true) == (0, 0))
        XCTAssertEqual(L.sichtbar(99, maximal: 24), 24)
    }

    func testWoche() {
        XCTAssertEqual(L.woche(L.tagDatum("2026-10-09")!), "2026-W41")
        XCTAssertEqual(L.woche(L.tagDatum("2026-01-01")!), "2026-W01")
        XCTAssertEqual(L.woche(L.tagDatum("2027-01-01")!), "2026-W53")
    }

    func testSpotifyURL() {
        XCTAssertNotNil(L.spotifyURL("https://open.spotify.com/track/abc"))
        XCTAssertNotNil(L.spotifyURL("spotify:track:abc"))
        XCTAssertNil(L.spotifyURL("https://evil.com/open.spotify.com"))
        XCTAssertNil(L.spotifyURL("http://open.spotify.com/track/abc"))
        XCTAssertNil(L.spotifyURL("javascript:alert(1)"))
        XCTAssertNil(L.spotifyURL("  "))
    }

    func testKassetteEinlegen() {
        var liste: [L.Kassette] = []
        for w in 1...10 { liste = L.kassetteEinlegen(liste, neu: .init(woche: "2026-W\(String(format: "%02d", w))", url: "u", titel: "t")) }
        XCTAssertEqual(liste.count, L.kassettenMaximum)
        XCTAssertEqual(liste.last?.woche, "2026-W10")
        let ersetzt = L.kassetteEinlegen(liste, neu: .init(woche: "2026-W10", url: "neu", titel: "t"))
        XCTAssertEqual(ersetzt.count, L.kassettenMaximum)
        XCTAssertEqual(ersetzt.last?.url, "neu")
    }

    func testSterne() {
        var g = L.gekocht([], rezeptId: "a", tag: "2026-10-01")
        g = L.gekocht(g, rezeptId: "a", tag: "2026-10-01")
        g = L.gekocht(g, rezeptId: "a", tag: "2026-10-05")
        g = L.gekocht(g, rezeptId: "ab", tag: "2026-10-05")
        XCTAssertEqual(L.sterne(rezeptId: "a", gekocht: g), 2)
        XCTAssertEqual(L.sterne(rezeptId: "ab", gekocht: g), 1)
    }

    func testWunschrolle() {
        XCTAssertEqual(L.gemeinsamErledigt(["1", "2"], ["2", "3"]), ["2"])
        XCTAssertEqual(L.umschalten(["1"], id: "1"), [])
        XCTAssertEqual(L.umschalten(["1"], id: "2"), ["1", "2"])
        XCTAssertEqual(L.aufkleber(erledigt: 40), 6)
    }

    func testRegenbogen() {
        let tage = L.letzteTage(heute: "2026-10-09")
        XCTAssertEqual(tage.count, 7)
        XCTAssertEqual(tage.first, "2026-10-03")
        XCTAssertEqual(tage.last, "2026-10-09")
        XCTAssertEqual(L.letzteTage(heute: "2026-03-02", anzahl: 3), ["2026-02-28", "2026-03-01", "2026-03-02"])
        let v = L.verlaufEintragen(["2026-10-08": "muede"], tag: "2026-10-09", art: "verliebt")
        XCTAssertEqual(L.bogen(v, tage: ["2026-10-07", "2026-10-08", "2026-10-09"]), [nil, "muede", "verliebt"])
        var lang: [String: String] = [:]
        for i in 1...20 { lang[String(format: "2026-09-%02d", i)] = "muede" }
        XCTAssertEqual(L.verlaufEintragen(lang, tag: "2026-10-01", art: "krank").count, 14)
        XCTAssertEqual(L.verlaufEintragen(["a": "b"], tag: "x", art: nil), ["a": "b"])
    }

    func testMarken() {
        let eigene = [L.EigeneMarke(titel: "Eingezogen", tag: "2026-09-15")]
        let m = L.marken(heute: "2026-10-09", start: "2026-08-26", eigene: eigene)
        XCTAssertEqual(m.map(\.titel), ["Zusammen", "Eingezogen", "100 Tage"])
        XCTAssertEqual(m.map(\.erreicht), [true, true, false])
        let spaet = L.marken(heute: "2028-01-01", start: "2026-08-26", eigene: eigene)
        XCTAssertLessThanOrEqual(spaet.count, L.markenMaximum)
        XCTAssertTrue(spaet.dropLast().allSatisfy(\.erreicht))
        XCTAssertTrue(L.marken(heute: "2026-10-09", start: "kaputt", eigene: []).isEmpty)
    }

    func testBereinigt() {
        XCTAssertNil(L.bereinigt("   ", maximal: 5))
        XCTAssertEqual(L.bereinigt(" abcdefgh ", maximal: 5), "abcde")
    }
}
