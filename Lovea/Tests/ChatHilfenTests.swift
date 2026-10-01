import XCTest
@testable import Lovea

/// R7: interactive keyboard dismiss must not fight the list's own re-pin-to-bottom logic.
final class ChatHilfenTests: XCTestCase {
    func testSpringtNurBeiEchterGroessenaenderung() {
        XCTAssertFalse(ListenAutoScroll.sollNachUntenSpringen(sichtbarGeaendert: false, warAmEnde: true, nutzerZiehtGerade: false))
    }

    func testSpringtNurWennAmEnde() {
        XCTAssertFalse(ListenAutoScroll.sollNachUntenSpringen(sichtbarGeaendert: true, warAmEnde: false, nutzerZiehtGerade: false))
    }

    func testSpringtNichtWaehrendDerNutzerZieht() {
        // Interaktives Tastatur-Einklappen aendert die sichtbare Hoehe bei jedem Frame — das darf
        // nicht gegen die eigene Wisch-Geste des Nutzers anspringen.
        XCTAssertFalse(ListenAutoScroll.sollNachUntenSpringen(sichtbarGeaendert: true, warAmEnde: true, nutzerZiehtGerade: true))
    }

    func testSpringtBeiEchterAenderungAmEndeOhneZiehen() {
        // z. B. Antwort-Leiste oder Tastatur oeffnet sich nicht-interaktiv, waehrend man unten war.
        XCTAssertTrue(ListenAutoScroll.sollNachUntenSpringen(sichtbarGeaendert: true, warAmEnde: true, nutzerZiehtGerade: false))
    }
}
