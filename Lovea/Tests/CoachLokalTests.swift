import XCTest
@testable import Lovea

/// Health-Coach: Schlüssel, Merklisten, Schnellfragen, Suche, Export (`CoachLokal.swift`). Reine Logik.
final class CoachLokalTests: XCTestCase {

    private var kalender: Calendar {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "UTC")!
        return k
    }

    private func zeit(_ tag: Int, _ stunde: Int = 12) -> Date {
        kalender.date(from: DateComponents(year: 2026, month: 10, day: tag, hour: stunde))!
    }

    private func nachricht(_ id: String, _ rolle: CoachNachricht.Rolle, _ text: String, _ zeit: Date) -> CoachNachricht {
        CoachNachricht(id: id, rolle: rolle, text: text, zeit: zeit)
    }

    // MARK: - Schlüssel

    func testStabilerHashBekannteWerte() {
        XCTAssertEqual(CoachLokal.stabilerHash(""), "cbf29ce484222325")
        XCTAssertEqual(CoachLokal.stabilerHash("a"), "af63dc4c8601ec8c")
        XCTAssertEqual(CoachLokal.stabilerHash("foobar"), "85944171f73967e8")
    }

    func testSchluesselIgnoriertDenRand() {
        XCTAssertEqual(CoachLokal.schluessel("  Hallo \n"), CoachLokal.schluessel("Hallo"))
        XCTAssertNotEqual(CoachLokal.schluessel("Hallo"), CoachLokal.schluessel("hallo"))
    }

    // MARK: - Merklisten

    func testSetzenFuegtAnsEndeUndEntferntDoppelte() {
        XCTAssertEqual(CoachLokal.setzen([], "a", an: true, maximal: 3), ["a"])
        XCTAssertEqual(CoachLokal.setzen(["a", "b"], "a", an: true, maximal: 3), ["b", "a"])
    }

    func testSetzenKuerztAmAnfang() {
        XCTAssertEqual(CoachLokal.setzen(["a", "b", "c"], "d", an: true, maximal: 3), ["b", "c", "d"])
        XCTAssertEqual(CoachLokal.setzen(["a"], "b", an: true, maximal: 0), [])
    }

    func testSetzenAusEntferntNurDenEintrag() {
        XCTAssertEqual(CoachLokal.setzen(["a", "b"], "a", an: false, maximal: 3), ["b"])
        XCTAssertEqual(CoachLokal.setzen(["a"], "x", an: false, maximal: 3), ["a"])
    }

    // MARK: - Fortschritt

    func testAnteil() {
        XCTAssertEqual(CoachLokal.anteil(aktuell: 6200, ziel: 10000), 0.62, accuracy: 0.0001)
        XCTAssertEqual(CoachLokal.anteil(aktuell: 20000, ziel: 10000), 1)
        XCTAssertEqual(CoachLokal.anteil(aktuell: -3, ziel: 10), 0)
        XCTAssertEqual(CoachLokal.anteil(aktuell: 5, ziel: 0), 0)
        XCTAssertEqual(CoachLokal.anteil(aktuell: .infinity, ziel: 10), 0)
    }

    // MARK: - Schnellfragen

    func testHeuteGefragtNimmtNurEigeneFragenVonHeute() {
        let liste = [
            nachricht("1", .du, "Alt", zeit(7)),
            nachricht("2", .du, "Tagesbericht ", zeit(8, 8)),
            nachricht("3", .coach, "Antwort", zeit(8, 9)),
        ]
        XCTAssertEqual(CoachLokal.heuteGefragt(liste, jetzt: zeit(8, 20), kalender: kalender), ["Tagesbericht"])
    }

    func testSchnellfragenMorgens() {
        XCTAssertEqual(CoachLokal.schnellfragen(stunde: 8, wochentag: 4, schonGefragt: []),
                       ["Was soll ich heute essen?", "Wie läuft mein Training?", "Tagesbericht"])
    }

    func testSchnellfragenAbendsMitLuecken() {
        XCTAssertEqual(CoachLokal.schnellfragen(stunde: 20, wochentag: 4, schonGefragt: []),
                       ["Tagesbericht", CoachLokal.luecken, "Wie läuft mein Training?"])
    }

    func testSchnellfragenNachtsSindDieFesten() {
        XCTAssertEqual(CoachLokal.schnellfragen(stunde: 2, wochentag: 4, schonGefragt: []), CoachRegeln.schnellfragen)
    }

    func testSchnellfragenMontagsMitWochenrueckblickZuerst() {
        XCTAssertEqual(CoachLokal.schnellfragen(stunde: 14, wochentag: 2, schonGefragt: []),
                       [CoachLokal.wochenrueckblick, "Tagesbericht", "Was soll ich heute essen?", "Wie läuft mein Training?"])
        XCTAssertEqual(CoachLokal.schnellfragen(stunde: 14, wochentag: 1, schonGefragt: []).first, CoachLokal.wochenrueckblick)
    }

    func testSchnellfragenLassenGefragtesWeg() {
        XCTAssertEqual(CoachLokal.schnellfragen(stunde: 14, wochentag: 4, schonGefragt: ["Tagesbericht"]),
                       ["Was soll ich heute essen?", "Wie läuft mein Training?"])
    }

    func testSchnellfragenZeigenAllesWennAllesGefragtWurde() {
        let alle: Set<String> = ["Tagesbericht", "Was soll ich heute essen?", "Wie läuft mein Training?"]
        XCTAssertEqual(CoachLokal.schnellfragen(stunde: 14, wochentag: 4, schonGefragt: alle),
                       ["Tagesbericht", "Was soll ich heute essen?", "Wie läuft mein Training?"])
    }

    // MARK: - Suche und Sprung

    func testSucheOhneGrossKleinUndAkzent() {
        let liste = [
            nachricht("1", .du, "Wie war mein Café-Besuch?", zeit(5)),
            nachricht("2", .coach, "Gut. Trink mehr Wasser.\n[[weiter: Wie war mein Schlaf?]]", zeit(5, 13)),
        ]
        XCTAssertEqual(CoachLokal.suche(liste, begriff: "cafe").map(\.id), ["1"])
        XCTAssertEqual(CoachLokal.suche(liste, begriff: "WASSER").map(\.id), ["2"])
    }

    func testSucheSiehtDieMarkerNicht() {
        let liste = [nachricht("2", .coach, "Gut.\n[[weiter: Wie war mein Schlaf?]]", zeit(5))]
        XCTAssertTrue(CoachLokal.suche(liste, begriff: "schlaf").isEmpty)
    }

    func testSucheMitLeeremBegriffFindetNichts() {
        let liste = [nachricht("1", .du, "Hallo", zeit(5))]
        XCTAssertTrue(CoachLokal.suche(liste, begriff: "  ").isEmpty)
    }

    func testTageErsteNachrichtJedesTagesNeuesteZuerst() {
        let liste = [
            nachricht("1", .du, "a", zeit(5, 9)),
            nachricht("2", .coach, "b", zeit(5, 18)),
            nachricht("3", .du, "c", zeit(6, 8)),
            nachricht("4", .du, "d", zeit(8, 7)),
        ]
        XCTAssertEqual(CoachLokal.tage(liste, kalender: kalender).map(\.id), ["4", "3", "1"])
        XCTAssertEqual(CoachLokal.tage(liste, kalender: kalender, maximal: 2).map(\.id), ["4", "3"])
        XCTAssertTrue(CoachLokal.tage([], kalender: kalender).isEmpty)
    }

    // MARK: - Export

    func testExportMitNamenUndOhneMarker() {
        let liste = [
            nachricht("1", .du, " Hallo ", zeit(5)),
            nachricht("2", .coach, "Hi.\n[[weiter: A?]]", zeit(5, 13)),
        ]
        XCTAssertEqual(CoachLokal.export(liste, ich: "Ahmed") { _ in "12:00" },
                       "[12:00] Ahmed: Hallo\n\n[12:00] Coach: Hi.")
        XCTAssertEqual(CoachLokal.export([], ich: "Ahmed") { _ in "x" }, "")
    }

    // MARK: - Erinnerungen

    func testErinnerungsKennung() {
        let a = CoachLokal.erinnerungsKennung(stunde: 7, minute: 30, text: "Wasser trinken")
        XCTAssertTrue(a.hasPrefix("coach.erinnerung.7.30."))
        XCTAssertEqual(a, CoachLokal.erinnerungsKennung(stunde: 7, minute: 30, text: " Wasser trinken "))
        XCTAssertNotEqual(a, CoachLokal.erinnerungsKennung(stunde: 7, minute: 30, text: "Dehnen"))
        XCTAssertNotEqual(a, CoachLokal.erinnerungsKennung(stunde: 8, minute: 30, text: "Wasser trinken"))
    }
}
