import XCTest
@testable import Lovea

/// Z-7.1: pure mapping tests for `AnwesenheitEingabe` (motion/focus/time -> `FigurEingabe` inputs).
/// `FigurZustand.bestimmen` itself (the merge/priority function) is already covered by `FigurenTests`.
final class AnwesenheitTests: XCTestCase {
    func testFokusNachtsErgibtSchlafen() {
        XCTAssertEqual(AnwesenheitEingabe.fokus(isFocused: true, stunde: 23), "schlafen")
        XCTAssertEqual(AnwesenheitEingabe.fokus(isFocused: true, stunde: 3), "schlafen")
        XCTAssertEqual(AnwesenheitEingabe.fokus(isFocused: true, stunde: 6), "schlafen")
    }

    func testFokusTagsueberErgibtNichtStoeren() {
        XCTAssertEqual(AnwesenheitEingabe.fokus(isFocused: true, stunde: 7), "nichtStoeren")
        XCTAssertEqual(AnwesenheitEingabe.fokus(isFocused: true, stunde: 14), "nichtStoeren")
        XCTAssertEqual(AnwesenheitEingabe.fokus(isFocused: true, stunde: 21), "nichtStoeren")
    }

    func testFokusAusIstNil() {
        XCTAssertNil(AnwesenheitEingabe.fokus(isFocused: false, stunde: 23))
    }

    func testBewegungPrioritaetWieStandort() {
        XCTAssertEqual(AnwesenheitEingabe.bewegung(automotive: true, cycling: true, running: true, walking: true), .faehrt)
        XCTAssertEqual(AnwesenheitEingabe.bewegung(automotive: false, cycling: true, running: true, walking: true), .rad)
        XCTAssertEqual(AnwesenheitEingabe.bewegung(automotive: false, cycling: false, running: true, walking: true), .rennt)
        XCTAssertEqual(AnwesenheitEingabe.bewegung(automotive: false, cycling: false, running: false, walking: true), .laeuft)
        XCTAssertNil(AnwesenheitEingabe.bewegung(automotive: false, cycling: false, running: false, walking: false))
    }

    func testMorgenFenster5Bis11() {
        XCTAssertTrue(AnwesenheitEingabe.istMorgenFenster(5))
        XCTAssertTrue(AnwesenheitEingabe.istMorgenFenster(10))
        XCTAssertFalse(AnwesenheitEingabe.istMorgenFenster(11))
        XCTAssertFalse(AnwesenheitEingabe.istMorgenFenster(4))
    }
}
