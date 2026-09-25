import XCTest
@testable import Lovea

final class SchritteLogikTests: XCTestCase {
    private let heute = "2026-09-24" // Donnerstag

    // MARK: - Tag / Woche / Monat

    func testTageJeZeitraum() {
        XCTAssertEqual(SchritteLogik.tage(.tag, anker: "2026-09-19"), ["2026-09-19"])
        XCTAssertEqual(SchritteLogik.tage(.woche, anker: heute).first, "2026-09-21")
        XCTAssertEqual(SchritteLogik.tage(.woche, anker: heute).last, "2026-09-27")
        let monat = SchritteLogik.tage(.monat, anker: "2026-02-10")
        XCTAssertEqual(monat.count, 28)
        XCTAssertEqual(monat.first, "2026-02-01")
    }

    func testSummeNurBisHeuteUndNilOhneWerte() {
        let werte = ["2026-09-21": 8000, "2026-09-22": 12_000, "2026-09-24": 3000, "2026-09-25": 99_999]
        let woche = SchritteLogik.tage(.woche, anker: heute)
        XCTAssertEqual(SchritteLogik.summe(werte, tage: woche, heute: heute), 23_000, "kein Wert aus der Zukunft")
        XCTAssertNil(SchritteLogik.summe(werte, tage: ["2026-09-23"], heute: heute))
    }

    func testVerschiebenNieInDieZukunft() {
        XCTAssertEqual(SchritteLogik.verschoben("2026-09-23", .tag, um: 1, heute: heute), heute)
        XCTAssertNil(SchritteLogik.verschoben(heute, .tag, um: 1, heute: heute))
        XCTAssertEqual(SchritteLogik.verschoben(heute, .woche, um: -1, heute: heute), "2026-09-17")
        XCTAssertEqual(SchritteLogik.verschoben("2026-09-17", .woche, um: 1, heute: heute), heute, "laufende Woche, Anker bleibt bei heute")
        XCTAssertNil(SchritteLogik.verschoben(heute, .woche, um: 1, heute: heute))
        XCTAssertEqual(SchritteLogik.verschoben(heute, .monat, um: -1, heute: heute), "2026-08-01")
        XCTAssertNil(SchritteLogik.verschoben(heute, .monat, um: 1, heute: heute))
    }

    /// 25.10.2026, Zeitumstellung: ein Tag zurück bleibt ein Kalendertag.
    func testVerschiebenUeberDieZeitumstellung() {
        XCTAssertEqual(SchritteLogik.verschoben("2026-10-26", .tag, um: -1, heute: "2026-11-01"), "2026-10-25")
        XCTAssertEqual(SchritteLogik.verschoben("2026-10-26", .woche, um: -1, heute: "2026-11-01"), "2026-10-19")
    }

    // MARK: - Diagramm

    func testFensterBleibtBeimTippenStehen() {
        let fenster = SchritteLogik.fensterTage(anker: heute, heute: heute)
        XCTAssertEqual(fenster.first, "2026-09-18")
        XCTAssertEqual(fenster.last, heute)
        XCTAssertEqual(SchritteLogik.fensterTage(anker: "2026-09-19", heute: heute), fenster, "Tag im selben Fenster")
        let davor = SchritteLogik.fensterTage(anker: "2026-09-17", heute: heute)
        XCTAssertEqual(davor.last, "2026-09-17")
        XCTAssertEqual(davor.count, 7)
    }

    func testLinienPunkteOhneZukunftUndLueckenAlsNull() {
        let tage = SchritteLogik.tage(.woche, anker: heute)
        let punkte = SchritteLogik.linienPunkte(tage: tage, werte: ["2026-09-21": 8000, "2026-09-23": 11_955], heute: heute)
        XCTAssertEqual(punkte.map { $0.tag }, ["2026-09-21", "2026-09-22", "2026-09-23", "2026-09-24"])
        XCTAssertEqual(punkte.map { $0.schritte }, [8000, 0, 11_955, 0])
    }

    // MARK: - Rangliste

    func testRanglisteMeisteSchritteZuerst() {
        let liste = SchritteLogik.rangliste([.ahmed: 157_773, .annika: 181_395])
        XCTAssertEqual(liste.map(\.person), [.annika, .ahmed])
        XCTAssertEqual(liste.map(\.rang), [1, 2])
    }

    func testRanglisteGleichstandTeiltDenRang() {
        let liste = SchritteLogik.rangliste([.annika: 5000, .ahmed: 5000])
        XCTAssertEqual(liste.map(\.rang), [1, 1])
        XCTAssertEqual(liste.map(\.person), [.ahmed, .annika], "bei Gleichstand nach Name")
    }
}
