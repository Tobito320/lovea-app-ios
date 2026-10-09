import XCTest
@testable import Lovea

/// Q-R10 Review-Fix: die reinen Entscheidungsfunktionen hinter dem Palm-Schutz (`resolveSecondTouch`)
/// und dem Mehr-Finger-Undo/Redo-Gating (`allowsAccidentalUndoGesture`) aus `CanvasView`. Beide nehmen
/// Zahlen statt `UITouch`/`CACurrentMediaTime()` entgegen, deshalb ohne MainActor/echte Uhr testbar.
final class CanvasViewGatingTests: XCTestCase {
    // MARK: strichBeiZweiterBeruehrung

    func testPencilAlwaysLandsEvenBrandNew() {
        XCTAssertEqual(CanvasView.strichBeiZweiterBeruehrung(alterMs: 0, laengePunkte: 0, istStift: true), .landen)
    }

    func testFingerDiscardsJustUnderAgeThreshold() {
        XCTAssertEqual(CanvasView.strichBeiZweiterBeruehrung(alterMs: 299, laengePunkte: 100, istStift: false), .verwerfen)
    }

    func testFingerLandsAtAgeThreshold() {
        XCTAssertEqual(CanvasView.strichBeiZweiterBeruehrung(alterMs: 300, laengePunkte: 100, istStift: false), .landen)
    }

    func testFingerDiscardsJustUnderLengthThreshold() {
        XCTAssertEqual(CanvasView.strichBeiZweiterBeruehrung(alterMs: 1000, laengePunkte: 39, istStift: false), .verwerfen)
    }

    func testFingerLandsAtLengthThreshold() {
        XCTAssertEqual(CanvasView.strichBeiZweiterBeruehrung(alterMs: 1000, laengePunkte: 40, istStift: false), .landen)
    }

    func testFingerNeedsBothAgeAndLength() {
        // Alt genug, aber zu kurz (schneller Tupfer) - und umgekehrt lang genug, aber zu jung (sehr schneller Wisch).
        XCTAssertEqual(CanvasView.strichBeiZweiterBeruehrung(alterMs: 1000, laengePunkte: 5, istStift: false), .verwerfen)
        XCTAssertEqual(CanvasView.strichBeiZweiterBeruehrung(alterMs: 10, laengePunkte: 1000, istStift: false), .verwerfen)
    }

    func testFingerLandsWhenBothThresholdsClearedWell() {
        XCTAssertEqual(CanvasView.strichBeiZweiterBeruehrung(alterMs: 500, laengePunkte: 80, istStift: false), .landen)
    }

    // MARK: erlaubtMehrFingerGeste

    private func allGood(
        hadPencilStroke: Bool = false,
        now: CFTimeInterval = 10,
        lastStrokeLandTime: CFTimeInterval = 0,
        groupFirstStart: CFTimeInterval = 9.99,
        groupLastStart: CFTimeInterval = 10,
        groupMaxTravel: CGFloat = 2
    ) -> Bool {
        CanvasView.erlaubtMehrFingerGeste(
            hadPencilStroke: hadPencilStroke, now: now, lastStrokeLandTime: lastStrokeLandTime,
            groupFirstStart: groupFirstStart, groupLastStart: groupLastStart, groupMaxTravel: groupMaxTravel
        )
    }

    func testAllowsWhenEveryRuleIsClear() {
        XCTAssertTrue(allGood())
    }

    func testBlocksWhenAPencilStrokeWasRunning() {
        XCTAssertFalse(allGood(hadPencilStroke: true))
    }

    func testBlocksRightAfterAStrokeLanded() {
        // Strich landete vor 0.1 s - klar innerhalb der 0.3-s-Sperrzeit, kein Grenzfall-Fließkomma-Risiko.
        XCTAssertFalse(allGood(now: 10, lastStrokeLandTime: 9.9))
    }

    func testAllowsOnceSperrzeitPassed() {
        // Strich landete vor 1 s - klar außerhalb der Sperrzeit.
        XCTAssertTrue(allGood(now: 10, lastStrokeLandTime: 9))
    }

    func testBlocksWhenTouchesStartTooFarApart() {
        // 0.2 s auseinander - klar über der 0.1-s-Synchronitätsgrenze.
        XCTAssertFalse(allGood(groupFirstStart: 9.8, groupLastStart: 10))
    }

    func testBlocksWhenAnyTouchTravelsTooFar() {
        XCTAssertFalse(allGood(groupMaxTravel: 10))
    }

    func testAllowsJustUnderTravelThreshold() {
        XCTAssertTrue(allGood(groupMaxTravel: 9.9))
    }
}
