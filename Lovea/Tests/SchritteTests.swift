import XCTest
@testable import Lovea

final class SchritteTests: XCTestCase {

    // MARK: - sollSenden

    func testErsteZahlDesTagesWirdImmerGesendet() {
        let ergebnis = SchritteLogik.sollSenden(anzahl: 120, zuletzt: nil, heutigerTag: "2026-09-23", vergangen: 0)
        XCTAssertTrue(ergebnis)
    }

    func testNeuerTagWirdSofortGesendet() {
        let zuletzt = (datum: "2026-09-22", anzahl: 9000)
        let ergebnis = SchritteLogik.sollSenden(anzahl: 10, zuletzt: zuletzt, heutigerTag: "2026-09-23", vergangen: 5)
        XCTAssertTrue(ergebnis, "erster Wert eines neuen Tages zählt als Sprung, egal wie klein")
    }

    func testKleinerSprungInnerhalbVonFuenfzehnMinutenWirdNichtGesendet() {
        let zuletzt = (datum: "2026-09-23", anzahl: 1000)
        let ergebnis = SchritteLogik.sollSenden(anzahl: 1030, zuletzt: zuletzt, heutigerTag: "2026-09-23", vergangen: 60)
        XCTAssertFalse(ergebnis)
    }

    func testSprungAbFuenfzigWirdSofortGesendet() {
        let zuletzt = (datum: "2026-09-23", anzahl: 1000)
        let ergebnis = SchritteLogik.sollSenden(anzahl: 1050, zuletzt: zuletzt, heutigerTag: "2026-09-23", vergangen: 5)
        XCTAssertTrue(ergebnis)
    }

    func testNachFuenfzehnMinutenWirdAuchOhneSprungGesendet() {
        let zuletzt = (datum: "2026-09-23", anzahl: 1000)
        let ergebnis = SchritteLogik.sollSenden(anzahl: 1005, zuletzt: zuletzt, heutigerTag: "2026-09-23", vergangen: 15 * 60)
        XCTAssertTrue(ergebnis)
    }

    // MARK: - falten

    func testFaltenSetztDieZahlDerPerson() {
        var heute: [Person: Int] = [:]
        SchritteLogik.falten(&heute, von: .annika, datum: "2026-09-23", anzahl: 4321, heutigerTag: "2026-09-23")
        XCTAssertEqual(heute[.annika], 4321)
    }

    func testFaltenVerwirftOpsFuerEinenAnderenTag() {
        var heute: [Person: Int] = [.annika: 100]
        SchritteLogik.falten(&heute, von: .annika, datum: "2026-09-22", anzahl: 9999, heutigerTag: "2026-09-23")
        XCTAssertEqual(heute[.annika], 100, "gestrige Op darf die heutige Zahl nicht überschreiben")
    }

    func testFaltenUeberschreibtDenVorherigenWertDerselbenPerson() {
        var heute: [Person: Int] = [.ahmed: 500]
        SchritteLogik.falten(&heute, von: .ahmed, datum: "2026-09-23", anzahl: 650, heutigerTag: "2026-09-23")
        XCTAssertEqual(heute[.ahmed], 650)
    }

    func testFaltenLaesstDieAndereFigurInRuhe() {
        var heute: [Person: Int] = [.ahmed: 500]
        SchritteLogik.falten(&heute, von: .annika, datum: "2026-09-23", anzahl: 300, heutigerTag: "2026-09-23")
        XCTAssertEqual(heute[.ahmed], 500)
        XCTAssertEqual(heute[.annika], 300)
    }
}
