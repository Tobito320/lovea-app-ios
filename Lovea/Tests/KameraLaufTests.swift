import XCTest
@testable import Lovea

/// p66: run state of the camera session. Bug: `bildBereit()` only checked "running", so
/// start -> stop -> start let the FIRST run's late callback show the preview before the second
/// `startRunning` had returned (black or half-started image). Each run now has a number.
final class KameraLaufTests: XCTestCase {
    func testErsterStartBekommtNummer() {
        var lauf = KameraLauf()
        XCTAssertEqual(lauf.starten(), 1)
        XCTAssertTrue(lauf.laeuft)
        XCTAssertFalse(lauf.bildDa)
    }

    func testZweiterStartWaehrendLaufNichts() {
        var lauf = KameraLauf()
        _ = lauf.starten()
        XCTAssertNil(lauf.starten())
        XCTAssertEqual(lauf.nummer, 1)
    }

    func testBildBereitDesAktuellenLaufs() {
        var lauf = KameraLauf()
        let nummer = lauf.starten()!
        XCTAssertTrue(lauf.bildBereit(nummer: nummer))
        XCTAssertTrue(lauf.bildDa)
    }

    func testVeralteterCallbackNachSchnellemNeustartZaehltNicht() {
        var lauf = KameraLauf()
        let erste = lauf.starten()!
        XCTAssertTrue(lauf.stoppen())
        let zweite = lauf.starten()!
        XCTAssertNotEqual(erste, zweite)
        XCTAssertFalse(lauf.bildBereit(nummer: erste), "late callback of the first run")
        XCTAssertFalse(lauf.bildDa)
        XCTAssertTrue(lauf.bildBereit(nummer: zweite))
        XCTAssertTrue(lauf.bildDa)
    }

    func testBildBereitNachStoppZaehltNicht() {
        var lauf = KameraLauf()
        let nummer = lauf.starten()!
        _ = lauf.stoppen()
        XCTAssertFalse(lauf.bildBereit(nummer: nummer))
        XCTAssertFalse(lauf.bildDa)
    }

    func testStoppSetztBildZurueckUndMeldetNurEinmal() {
        var lauf = KameraLauf()
        let nummer = lauf.starten()!
        lauf.bildBereit(nummer: nummer)
        XCTAssertTrue(lauf.stoppen())
        XCTAssertFalse(lauf.laeuft)
        XCTAssertFalse(lauf.bildDa)
        XCTAssertFalse(lauf.stoppen(), "second stop is a no-op")
    }
}
