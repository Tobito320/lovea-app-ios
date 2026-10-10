import XCTest
@testable import Lovea

/// Satz kopieren, Anstrengung nach RIR und Pausenziel (Gym nach openGym).
final class WorkoutBedienungTests: XCTestCase {
    func testCopyInsertsBelowWithoutTicksAndKeepsTypeAndValues() {
        var erster = PlanSatz(wdh: 8, kg: 60, failure: false, typ: "d", rpe: 9)
        erster.ok = true
        erster.sek = 40
        erster.pause = 90
        let zweiter = PlanSatz(wdh: 6, kg: 70, failure: true)
        let neu = WorkoutLogik.kopieren([erster, zweiter], 0)
        XCTAssertEqual(neu.count, 3)
        XCTAssertEqual(neu[1], PlanSatz(wdh: 8, kg: 60, failure: false, typ: "d"))
        XCTAssertNil(neu[1].ok)
        XCTAssertEqual(neu[2], zweiter)
        XCTAssertEqual(WorkoutLogik.kopieren([zweiter], 5), [zweiter])
    }

    func testEffortBandsFollowRirAndRpeIsTenMinusRir() {
        XCTAssertEqual(Anstrengung.allCases.map(\.rpe), [10, 9.5, 9, 8, 7, 6])
        for stufe in Anstrengung.allCases {
            XCTAssertEqual(Anstrengung.stufe(rpe: stufe.rpe), stufe)
        }
        XCTAssertEqual(Anstrengung.stufe(rpe: 8.5), .zweiNoch)
        XCTAssertEqual(Anstrengung.stufe(rpe: 10), .versagen)
        XCTAssertEqual(Anstrengung.stufe(rpe: 3), .leicht)
        XCTAssertEqual(Anstrengung.leicht.rirText, "4+")
        XCTAssertEqual(Anstrengung.fastVersagen.rirText, "0,5")
    }

    func testRestTargetStepsByFifteenAndNeverDropsBelowFifteen() {
        XCTAssertEqual(WorkoutLogik.pauseZiel(120, um: 15), 135)
        XCTAssertEqual(WorkoutLogik.pauseZiel(120, um: -15), 105)
        XCTAssertEqual(WorkoutLogik.pauseZiel(20, um: -15), 15)
    }
}
