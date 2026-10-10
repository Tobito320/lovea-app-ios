import XCTest
@testable import Lovea

/// Coach-Chat, Vorschläge und Zeichenzähler (`CoachVorschlaege.swift`). Reine Logik.
final class CoachVorschlagTests: XCTestCase {

    func testSymbolLeerFragenUndZaehler() {
        // Symbole: die bekannten Fragen, alles andere bekommt den Funken.
        XCTAssertEqual(CoachVorschlag.symbol(fuer: CoachLokal.wochenrueckblick), "calendar")
        XCTAssertEqual(CoachVorschlag.symbol(fuer: CoachLokal.luecken), "checklist")
        XCTAssertEqual(CoachVorschlag.symbol(fuer: "Wie läuft mein Training?"), "figure.strengthtraining.traditional")
        XCTAssertEqual(CoachVorschlag.symbol(fuer: "Was soll ich heute essen?"), "fork.knife")
        XCTAssertEqual(CoachVorschlag.symbol(fuer: "Tagesbericht"), "doc.text.magnifyingglass")
        XCTAssertEqual(CoachVorschlag.symbol(fuer: "Irgendwas"), "sparkles")

        // Leerer Chat: die Fragen der Tageszeit bleiben vorn, der Rest kommt ohne Doppelte dazu, höchstens sechs.
        let vier = CoachLokal.schnellfragen(stunde: 9, wochentag: 2, schonGefragt: [])
        let leer = CoachVorschlag.leerFragen(vier)
        XCTAssertEqual(Array(leer.prefix(vier.count)), vier)
        XCTAssertEqual(Set(leer).count, leer.count)
        XCTAssertTrue((4...6).contains(leer.count))
        XCTAssertEqual(CoachVorschlag.leerFragen([]).count, 5)

        // Zähler: sichtbar ab 80 Prozent, gefärbt in den letzten 50 Zeichen.
        XCTAssertFalse(CoachVorschlag.zaehlerSichtbar(anzahl: 799, maximal: 1000))
        XCTAssertTrue(CoachVorschlag.zaehlerSichtbar(anzahl: 800, maximal: 1000))
        XCTAssertTrue(CoachVorschlag.zaehlerSichtbar(anzahl: 1000, maximal: 1000))
        XCTAssertFalse(CoachVorschlag.zaehlerWarnt(anzahl: 949, maximal: 1000))
        XCTAssertTrue(CoachVorschlag.zaehlerWarnt(anzahl: 950, maximal: 1000))
    }
}
