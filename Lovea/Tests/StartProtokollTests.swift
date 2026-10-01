import XCTest
@testable import Lovea

/// Build 78: Absturz-Zähler-Logik ohne echten Prozess-Neustart testbar — `neuerStart()` muss einen
/// Lauf nur dann als Absturz zählen, wenn er eine Szene erreichte und nie `sauber()` wurde (sonst
/// zählt ein reiner Hintergrund-Start durch Silent-Push/HealthKit fälschlich als Absturz).
final class StartProtokollTests: XCTestCase {
    private let schluessel = ["start.breadcrumbs", "start.vorher", "start.sauber", "start.szeneErreicht", "start.unsauber.zaehler", "start.stufe"]

    override func setUp() {
        super.setUp()
        schluessel.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        schluessel.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    func testErsterLaufJeZaehltNichtAlsAbsturz() {
        XCTAssertFalse(StartProtokoll.neuerStart())
        XCTAssertFalse(StartProtokoll.abgesichert)
    }

    func testSzeneOhneSauberZaehltAlsAbsturz() {
        _ = StartProtokoll.neuerStart()
        StartProtokoll.szeneErreicht()
        // Prozess "stirbt" hier, ohne `sauber()` — nächster Start erkennt das.
        XCTAssertTrue(StartProtokoll.neuerStart())
    }

    func testHintergrundLaufOhneSzeneAendertZaehlerNicht() {
        _ = StartProtokoll.neuerStart()
        StartProtokoll.szeneErreicht()
        XCTAssertTrue(StartProtokoll.neuerStart()) // 1. Absturz
        XCTAssertFalse(StartProtokoll.neuerStart()) // 2. reiner Hintergrund-Start: keine Szene
        XCTAssertFalse(StartProtokoll.abgesichert) // Zähler blieb bei 1, kein Absturz gezählt
    }

    func testZweiAbstuerzeInFolgeSichern() {
        for _ in 0..<2 {
            _ = StartProtokoll.neuerStart()
            StartProtokoll.szeneErreicht()
        }
        XCTAssertTrue(StartProtokoll.neuerStart())
        XCTAssertTrue(StartProtokoll.abgesichert)
    }

    func testSaubererLaufSetztZaehlerZurueck() {
        _ = StartProtokoll.neuerStart()
        StartProtokoll.szeneErreicht()
        _ = StartProtokoll.neuerStart() // 1 Absturz
        StartProtokoll.szeneErreicht()
        StartProtokoll.sauber()
        XCTAssertFalse(StartProtokoll.neuerStart())
        XCTAssertFalse(StartProtokoll.abgesichert)
    }

    func testMarkeSchreibtListeUndRotiertNachVorher() {
        _ = StartProtokoll.neuerStart()
        StartProtokoll.marke("test.stufe")
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "start.breadcrumbs")?.count, 1)
        _ = StartProtokoll.neuerStart()
        XCTAssertEqual(StartProtokoll.vorherigeListe().count, 1)
        XCTAssertTrue(StartProtokoll.vorherigeListe().first?.contains("test.stufe") ?? false)
    }

    func testAlteStufeEinmalLesenLoeschtSieWieder() {
        UserDefaults.standard.set("gym.abgleichen.start", forKey: "start.stufe")
        XCTAssertEqual(StartProtokoll.alteStufeEinmalLesen(), "gym.abgleichen.start")
        XCTAssertNil(StartProtokoll.alteStufeEinmalLesen())
    }
}
