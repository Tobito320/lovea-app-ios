import XCTest
@testable import Lovea

/// p63: Datum -> Anlässe -> Deko.
final class ZimmerAnlassTests: XCTestCase {
    private func aktive(_ tag: String, jahrestag: String? = nil) -> [ZimmerAnlass] {
        ZimmerAnlass.aktive(am: Datum.datum(tag), jahrestag: jahrestag.map(Datum.datum))
    }

    func testGeburtstagAhmedAm27FebruarUndTagDavor() {
        XCTAssertEqual(aktive("2026-02-27").first, .geburtstagAhmed)
        XCTAssertTrue(aktive("2026-02-26").contains(.geburtstagAhmed))
        XCTAssertFalse(aktive("2026-02-28").contains(.geburtstagAhmed))
        XCTAssertFalse(aktive("2026-02-25").contains(.geburtstagAhmed))
    }

    func testGeburtstagAnnikaAus06Juni() {
        XCTAssertTrue(aktive("2026-06-06").contains(.geburtstagAnnika))
        XCTAssertTrue(aktive("2026-06-05").contains(.geburtstagAnnika))
        XCTAssertFalse(aktive("2026-06-07").contains(.geburtstagAnnika))
        XCTAssertFalse(aktive("2026-06-06").contains(.geburtstagAhmed))
    }

    func testJahrestagNurInSpaeterenJahren() {
        XCTAssertTrue(aktive("2026-03-14", jahrestag: "2025-03-14").contains(.jahrestag))
        XCTAssertFalse(aktive("2025-03-14", jahrestag: "2025-03-14").contains(.jahrestag))
        XCTAssertFalse(aktive("2026-03-14").contains(.jahrestag))
    }

    func testMonatstagJedenMonatAberNichtAmJahrestag() {
        XCTAssertTrue(aktive("2026-04-14", jahrestag: "2025-03-14").contains(.monatstag))
        XCTAssertFalse(aktive("2026-03-14", jahrestag: "2025-03-14").contains(.monatstag))
        XCTAssertFalse(aktive("2026-04-15", jahrestag: "2025-03-14").contains(.monatstag))
        XCTAssertFalse(aktive("2025-03-10", jahrestag: "2025-03-14").contains(.monatstag))
    }

    func testMonatstagDerEinunddreissigstenRutschtAufMonatsende() {
        XCTAssertTrue(aktive("2026-02-28", jahrestag: "2025-01-31").contains(.monatstag))
        XCTAssertTrue(aktive("2026-04-30", jahrestag: "2025-01-31").contains(.monatstag))
    }

    func testValentinstag() {
        XCTAssertTrue(aktive("2026-02-14").contains(.valentinstag))
        XCTAssertFalse(aktive("2026-02-16").contains(.valentinstag))
    }

    func testOsternOstersonntag2026IstDer5April() {
        for tag in ["2026-03-30", "2026-04-03", "2026-04-05", "2026-04-06"] {
            XCTAssertTrue(aktive(tag).contains(.ostern), tag)
        }
        for tag in ["2026-03-29", "2026-04-07"] {
            XCTAssertFalse(aktive(tag).contains(.ostern), tag)
        }
    }

    func testAdventskerzen2026() {
        // Heiligabend 2026 ist ein Donnerstag: 4. Advent 20.12., 1. Advent 29.11.
        let erwartet = [("2026-11-28", 0), ("2026-11-29", 1), ("2026-12-05", 1), ("2026-12-06", 2), ("2026-12-13", 3),
                        ("2026-12-20", 4), ("2026-12-23", 4), ("2026-12-24", 0)]
        for (tag, kerzen) in erwartet {
            XCTAssertEqual(ZimmerAnlass.adventskerzen(am: Datum.datum(tag)), kerzen, tag)
        }
        XCTAssertTrue(aktive("2026-12-10").contains(.advent))
        XCTAssertFalse(aktive("2026-12-24").contains(.advent))
    }

    func testAdventskerzenWennHeiligabendEinSonntagIst() {
        // 2022: Heiligabend ein Samstag, 4. Advent 18.12. 2023: Heiligabend ein Sonntag, 4. Advent 24.12 (dann Weihnachten).
        XCTAssertEqual(ZimmerAnlass.adventskerzen(am: Datum.datum("2022-12-18")), 4)
        XCTAssertEqual(ZimmerAnlass.adventskerzen(am: Datum.datum("2023-12-23")), 3)
        XCTAssertEqual(ZimmerAnlass.adventskerzen(am: Datum.datum("2023-12-17")), 3)
    }

    func testWinterfeste() {
        XCTAssertTrue(aktive("2026-12-06").contains(.nikolaus))
        XCTAssertTrue(aktive("2026-12-05").contains(.nikolaus))
        XCTAssertFalse(aktive("2026-12-07").contains(.nikolaus))
        for tag in ["2026-12-24", "2026-12-25", "2026-12-26"] { XCTAssertTrue(aktive(tag).contains(.weihnachten), tag) }
        XCTAssertFalse(aktive("2026-12-27").contains(.weihnachten))
        XCTAssertTrue(aktive("2026-12-31").contains(.silvester))
        XCTAssertTrue(aktive("2027-01-01").contains(.neujahr))
        XCTAssertTrue(aktive("2027-01-02").contains(.neujahr))
        XCTAssertFalse(aktive("2027-01-03").contains(.neujahr))
    }

    func testHalloweenEineWocheVorher() {
        XCTAssertTrue(aktive("2026-10-31").contains(.halloween))
        XCTAssertTrue(aktive("2026-10-25").contains(.halloween))
        XCTAssertFalse(aktive("2026-10-24").contains(.halloween))
        XCTAssertFalse(aktive("2026-11-01").contains(.halloween))
    }

    func testJahreszeiten() {
        XCTAssertEqual(aktive("2026-10-08"), [.herbst])
        XCTAssertEqual(aktive("2026-04-20"), [.fruehling])
        XCTAssertEqual(aktive("2026-07-15"), [.sommer])
        XCTAssertEqual(aktive("2026-01-15"), [.schnee])
        XCTAssertEqual(aktive("2026-12-01"), [.advent, .schnee])
    }

    func testJederTagDesJahresHatDekoUndJederAnlassGiltIrgendwann() {
        var gesehen = Set<ZimmerAnlass>()
        var tag = "2026-01-01"
        for _ in 0..<366 {
            let a = aktive(tag, jahrestag: "2024-05-17")
            gesehen.formUnion(a)
            XCTAssertFalse(ZimmerDeko.fuer(a).leer, tag)
            tag = Datum.addTage(tag, 1)
        }
        XCTAssertEqual(gesehen, Set(ZimmerAnlass.allCases))
    }

    func testWichtigsterAnlassGewinntDenPlatz() {
        // Geburtstag im Winter: Konfetti statt Schnee, Torte statt Schneehaube, Wimpel statt Lichter.
        let d = ZimmerDeko.fuer(tag: Datum.datum("2026-02-27"))
        XCTAssertEqual(d.girlande, .wimpel)
        XCTAssertEqual(d.streu, .konfetti)
        XCTAssertEqual(d.fenster, .torte)
        XCTAssertEqual(d.luft, .ballons)
        XCTAssertEqual(d.boden, .geschenke)
    }

    func testWeihnachtenHatBaumUndStern() {
        let d = ZimmerDeko.fuer(tag: Datum.datum("2026-12-24"))
        XCTAssertEqual(d.boden, .tannenbaum)
        XCTAssertEqual(d.fenster, .stern)
        XCTAssertEqual(d.girlande, .lichter)
    }

    func testAdventskranzBringtDieKerzenMit() {
        let d = ZimmerDeko.fuer(tag: Datum.datum("2026-12-08"))
        XCTAssertEqual(d.fenster, .adventskranz)
        XCTAssertEqual(d.kerzen, 2)
    }

    func testAmEinenTagNurEinePassendeJahreszeit() {
        let a = aktive("2026-10-08")
        XCTAssertEqual(a.filter { [.herbst, .fruehling, .sommer, .schnee].contains($0) }.count, 1)
    }
}
