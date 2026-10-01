import XCTest
@testable import Lovea

/// Build 78: zwei getrennte Mechanismen in `StartProtokoll`.
/// 1. `neuerStart()` entscheidet NUR, ob der Absturz-Bericht gezeigt wird (vorige Szene erreicht,
///    nie `sauber()`).
/// 2. `unsauberZaehlen()`/`sauber()`/`zaehlerZuruecksetzenNachSichtbar()` steuern den
///    Sicherheitsmodus-Zähler direkt — unabhängig davon, ob je eine Szene erreicht wurde (Ahmed:
///    die App stirbt oft VOR jeder UI).
final class StartProtokollTests: XCTestCase {
    private let schluessel = ["start.breadcrumbs", "start.vorher", "start.sauber", "start.szeneErreicht", "start.unsauber.zaehler", "start.stufe"]

    override func setUp() {
        super.setUp()
        schluessel.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        ["start-breadcrumbs.txt", "start-vorher.txt"].forEach { try? FileManager.default.removeItem(at: StartProtokoll.datei($0)) }
    }

    override func tearDown() {
        schluessel.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        ["start-breadcrumbs.txt", "start-vorher.txt"].forEach { try? FileManager.default.removeItem(at: StartProtokoll.datei($0)) }
        super.tearDown()
    }

    func testErsterLaufJeZeigtKeinenBericht() {
        XCTAssertFalse(StartProtokoll.neuerStart())
    }

    func testSzeneOhneSauberLoestBerichtAus() {
        _ = StartProtokoll.neuerStart()
        StartProtokoll.szeneErreicht()
        // Prozess "stirbt" hier, ohne `sauber()` — nächster Start erkennt das.
        XCTAssertTrue(StartProtokoll.neuerStart())
    }

    func testUnsauberZaehlenErhoehtNurEinmalProProzess() {
        StartProtokoll.unsauberZaehlen()
        StartProtokoll.unsauberZaehlen() // zweiter Aufruf im selben Prozess: no-op
        XCTAssertFalse(StartProtokoll.abgesichert) // 1 reicht nicht
        _ = StartProtokoll.neuerStart() // neuer Prozess-"Start": Flag zurück
        StartProtokoll.unsauberZaehlen()
        XCTAssertTrue(StartProtokoll.abgesichert) // 2 in Folge -> Sicherheitsmodus
    }

    func testSaubererLaufSetztZaehlerZurueck() {
        StartProtokoll.unsauberZaehlen()
        _ = StartProtokoll.neuerStart()
        StartProtokoll.unsauberZaehlen()
        XCTAssertTrue(StartProtokoll.abgesichert)
        StartProtokoll.sauber()
        XCTAssertFalse(StartProtokoll.abgesichert)
    }

    func testFuenfSekundenSichtbarSetztZaehlerZurueck() {
        StartProtokoll.unsauberZaehlen()
        _ = StartProtokoll.neuerStart()
        StartProtokoll.unsauberZaehlen()
        XCTAssertTrue(StartProtokoll.abgesichert)
        StartProtokoll.zaehlerZuruecksetzenNachSichtbar()
        XCTAssertFalse(StartProtokoll.abgesichert)
    }

    func testMarkeSchreibtListeUndRotiertNachVorher() {
        _ = StartProtokoll.neuerStart()
        StartProtokoll.marke("test.stufe")
        XCTAssertTrue((try? String(contentsOf: StartProtokoll.datei("start-breadcrumbs.txt"), encoding: .utf8))?.contains("test.stufe") ?? false)
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
