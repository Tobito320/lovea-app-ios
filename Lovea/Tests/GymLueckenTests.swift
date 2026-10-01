import XCTest
@testable import Lovea

/// Lücken im Gym-Bereich (Nachtschicht 02.10.): reine Logik, ohne Oberfläche.
final class GymLueckenTests: XCTestCase {
    /// Mittwoch 23.09.2026, 18:00 Berlin.
    private let t0 = Datum.datum("2026-09-23").addingTimeInterval(18 * 3600)

    private func satz(_ wdh: Int, _ kg: Double?, ok: Bool = false) -> PlanSatz {
        var s = PlanSatz(wdh: wdh, kg: kg, failure: false)
        if ok { s.ok = true }
        return s
    }

    private func uebung(_ id: String, saetze: [PlanSatz] = [], minuten: Int? = nil) -> PlanUebung {
        PlanUebung(id: id, uebung: "x\(id)", name: "Übung \(id)", saetze: saetze, minuten: minuten)
    }

    private func leereSession(tag: String? = "t", laeufe: [UebungsLauf] = []) -> GymSession {
        GymSession(id: "s", tag: tag, start: t0, ende: nil, laeufe: laeufe)
    }

    func testEarliestStartKeepsSessionRunning() {
        let frueh = TrainingLogik.fruehesterStart(jetzt: t0)
        XCTAssertTrue(TrainingLogik.laufend(GymSession(id: "s", tag: nil, start: frueh, ende: nil, laeufe: []), jetzt: t0))
        let zuFrueh = frueh.addingTimeInterval(-61)
        XCTAssertFalse(TrainingLogik.laufend(GymSession(id: "s", tag: nil, start: zuFrueh, ende: nil, laeufe: []), jetzt: t0))
    }

    func testDayCanOnlyBeSwitchedBeforeAnySetIsTicked() {
        let tag = TrainingsTag(id: "t", name: "Push", wochentage: [], uebungen: [uebung("a", saetze: [satz(10, 50), satz(10, 50)])])
        var liste = WorkoutLogik.uebungen(leereSession(), tag: tag, frueher: [])
        XCTAssertTrue(WorkoutLogik.tagWechselbar(liste))
        liste[0].saetze[0].ok = true
        XCTAssertFalse(WorkoutLogik.tagWechselbar(liste))
    }

    func testSwitchingDayTakesOutOnlyRunsOfTheOldDay() {
        let alt = TrainingsTag(id: "t", name: "Push", wochentage: [], uebungen: [uebung("a"), uebung("b")])
        let s = leereSession(laeufe: [
            UebungsLauf(plan: "a", uebung: "xa", start: t0, ende: nil, fertig: false, saetze: nil),
            UebungsLauf(plan: "z", uebung: "eigen", start: t0, ende: nil, fertig: false, saetze: nil, name: "Dips"),
        ])
        XCTAssertEqual(WorkoutLogik.laeufeDesTages(s, alt).map(\.plan), ["a"])
        XCTAssertTrue(WorkoutLogik.laeufeDesTages(s, nil).isEmpty)
    }
}
