import XCTest
@testable import Lovea

/// Tracker-Tage (je Viertelstunde das Maximum) und das Zusammenlegen mit Health.
final class TrackerTageTests: XCTestCase {
    private func zeile(_ tag: String = "2026-10-10", slot: Int, schritte: Int, meter: Int = 0, index: Int = 0, anzahl: Int = 1) -> TrackerProtokoll.SchrittSlot {
        .init(tag: tag, slot: slot, index: index, anzahl: anzahl, kcal: 0, schritte: schritte, meter: meter)
    }

    func testTagSummiertDieViertelstunden() {
        var tag = BandTag()
        tag.aufnehmen(zeile(slot: 40, schritte: 100, meter: 70))
        tag.aufnehmen(zeile(slot: 68, schritte: 128, meter: 77))
        XCTAssertEqual(tag.schritte, 228)
        XCTAssertEqual(tag.meter, 147)
        XCTAssertEqual(tag.letzteMinute, 68 * 15)
    }

    func testZweiteAbfrageDesselbenTagesZaehltNichtDoppelt() {
        var tag = BandTag()
        for _ in 0..<3 {
            tag.aufnehmen(zeile(slot: 40, schritte: 100, meter: 70))
            tag.aufnehmen(zeile(slot: 68, schritte: 128, meter: 77))
        }
        XCTAssertEqual(tag.schritte, 228)
    }

    func testAbgebrochenerAbrufVerkleinertDenTagNicht() {
        var tag = BandTag()
        tag.aufnehmen(zeile(slot: 40, schritte: 100))
        tag.aufnehmen(zeile(slot: 68, schritte: 128))
        tag.aufnehmen(zeile(slot: 40, schritte: 60)) // kleinerer Wert für denselben Slot
        XCTAssertEqual(tag.schritte, 228)
    }

    func testWachsenderSlotWirdUebernommen() {
        var tag = BandTag()
        tag.aufnehmen(zeile(slot: 68, schritte: 50))
        tag.aufnehmen(zeile(slot: 68, schritte: 128))
        XCTAssertEqual(tag.schritte, 128)
    }

    func testLeererTagHatKeineLetzteMinute() {
        XCTAssertNil(BandTag().letzteMinute)
        XCTAssertEqual(BandTag().schritte, 0)
    }

    func testTageTrennenNachDatum() {
        var tage = BandTage()
        tage.aufnehmen(zeile("2026-10-09", slot: 10, schritte: 500))
        tage.aufnehmen(zeile("2026-10-10", slot: 10, schritte: 700))
        XCTAssertEqual(tage.schritte("2026-10-09"), 500)
        XCTAssertEqual(tage.schritte("2026-10-10"), 700)
        XCTAssertNil(tage.schritte("2026-10-08"))
        XCTAssertEqual(tage.meter("2026-10-10"), 0)
    }

    func testKuerzenBehaeltNurDasFenster() {
        var tage = BandTage()
        let heute = "2026-10-10"
        tage.aufnehmen(zeile(Datum.addTage(heute, -(BandTage.behalten - 1)), slot: 1, schritte: 1))
        tage.aufnehmen(zeile(Datum.addTage(heute, -BandTage.behalten), slot: 1, schritte: 1))
        tage.aufnehmen(zeile(heute, slot: 1, schritte: 1))
        tage.kuerzen(heute: heute)
        XCTAssertEqual(tage.tage.count, 2)
        XCTAssertNil(tage.schritte(Datum.addTage(heute, -BandTage.behalten)))
    }

    func testTageUeberlebenSpeichernUndLaden() throws {
        var tage = BandTage()
        tage.aufnehmen(zeile(slot: 68, schritte: 128, meter: 77))
        tage.stand = Date(timeIntervalSince1970: 1_700_000_000)
        let daten = try JSONEncoder().encode(tage)
        XCTAssertEqual(try JSONDecoder().decode(BandTage.self, from: daten), tage)
    }

    // MARK: Zusammenlegen mit Health

    func testSchritteNimmtDenGroesserenWertNieDieSumme() {
        XCTAssertEqual(HealthLogik.schritteTag(health: 10_000, band: 15_000), 15_000)
        XCTAssertEqual(HealthLogik.schritteTag(health: 12_000, band: 9_000), 12_000)
        XCTAssertEqual(HealthLogik.schritteTag(health: 500, band: 500), 500)
    }

    func testSchritteMitNurEinerQuelle() {
        XCTAssertEqual(HealthLogik.schritteTag(health: nil, band: 800), 800)
        XCTAssertEqual(HealthLogik.schritteTag(health: 800, band: nil), 800)
        XCTAssertNil(HealthLogik.schritteTag(health: nil, band: nil))
    }

    func testKmFolgtDerQuelleDerSchritte() {
        // Tracker vorn: seine Meter, auf zwei Stellen.
        XCTAssertEqual(HealthLogik.kmTag(health: 7.1, healthSchritte: 10_000, bandSchritte: 15_000, bandMeter: 10_456), 10.46)
        // Health vorn oder gleich: Health-km.
        XCTAssertEqual(HealthLogik.kmTag(health: 7.1, healthSchritte: 10_000, bandSchritte: 10_000, bandMeter: 9_000), 7.1)
        XCTAssertEqual(HealthLogik.kmTag(health: 7.1, healthSchritte: 10_000, bandSchritte: 8_000, bandMeter: 6_000), 7.1)
        // Tracker vorn, aber ohne Meter: nichts erfinden.
        XCTAssertEqual(HealthLogik.kmTag(health: 7.1, healthSchritte: 10_000, bandSchritte: 15_000, bandMeter: 0), 7.1)
        XCTAssertNil(HealthLogik.kmTag(health: nil, healthSchritte: nil, bandSchritte: 15_000, bandMeter: nil))
        // Health ohne Schritte: der Tracker liefert die Strecke.
        XCTAssertEqual(HealthLogik.kmTag(health: nil, healthSchritte: nil, bandSchritte: 3_000, bandMeter: 2_100), 2.1)
    }
}
