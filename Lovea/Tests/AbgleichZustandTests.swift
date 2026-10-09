import XCTest
@testable import Lovea

/// Build 78: reine Zustandsmaschine hinter `GymLive`/`EssenLive.abgleichen()` — bei einem laufenden
/// Durchlauf wird kein weiterer Task gequeued, nur "nochmal nötig" gemerkt (verhindert den
/// ActivityKit-Anfragen-Stau beim Op-Replay).
final class AbgleichZustandTests: XCTestCase {
    func testErsterAufrufStartet() {
        let r = AbgleichZustand.aufruf(.leer)
        XCTAssertTrue(r.starten)
        XCTAssertEqual(r.neu, .laeuft)
    }

    func testAufrufWaehrendLaufenQueuedKeinenNeuenStartetAberMerktSchmutzig() {
        let r = AbgleichZustand.aufruf(.laeuft)
        XCTAssertFalse(r.starten)
        XCTAssertEqual(r.neu, .laeuftSchmutzig)
    }

    func testWeitereAufrufeWaehrendSchmutzigBleibenSchmutzig() {
        let r = AbgleichZustand.aufruf(.laeuftSchmutzig)
        XCTAssertFalse(r.starten)
        XCTAssertEqual(r.neu, .laeuftSchmutzig)
    }

    func testFertigAusLeerOderLaeuftOhneWeiterenAufrufGehtAufLeer() {
        XCTAssertEqual(AbgleichZustand.fertig(.laeuft).neu, .leer)
        XCTAssertFalse(AbgleichZustand.fertig(.laeuft).nochmal)
    }

    func testFertigAusSchmutzigLaeuftNochmal() {
        let r = AbgleichZustand.fertig(.laeuftSchmutzig)
        XCTAssertTrue(r.nochmal)
        XCTAssertEqual(r.neu, .laeuft)
    }

    /// Hunderte Aufrufe während eines Durchlaufs kollabieren auf genau einen weiteren.
    func testVieleAufrufeWaehrendLaufenKollabierenAufEinenNachlauf() {
        var zustand = AbgleichZustand.leer
        var gestarteteTasks = 0
        for _ in 0..<500 {
            let (starten, neu) = AbgleichZustand.aufruf(zustand)
            zustand = neu
            if starten { gestarteteTasks += 1 }
        }
        XCTAssertEqual(gestarteteTasks, 1)
        XCTAssertEqual(zustand, .laeuftSchmutzig)
        let (nochmal, neu) = AbgleichZustand.fertig(zustand)
        XCTAssertTrue(nochmal)
        XCTAssertEqual(neu, .laeuft)
        let (nochmal2, neu2) = AbgleichZustand.fertig(neu)
        XCTAssertFalse(nochmal2)
        XCTAssertEqual(neu2, .leer)
    }
}
