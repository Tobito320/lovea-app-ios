import XCTest
@testable import Lovea

/// Frischer eigener Split (1 bis 6 Tage), Plantag-Karte und schnelles Bearbeiten einer Übung.
final class SplitFreiTests: XCTestCase {
    // 2026-10-05 ist ein Montag.
    private func tag(_ name: String, _ wochentage: [Int], uebungen: Int = 0) -> TrainingsTag {
        TrainingsTag(id: name, name: name, wochentage: wochentage, uebungen: (0..<uebungen).map {
            PlanUebung(id: "\(name)\($0)", uebung: "x", name: "U", saetze: [], minuten: nil)
        })
    }

    private func uebung(saetze: [PlanSatz]) -> PlanUebung {
        PlanUebung(id: "u", uebung: "x", name: "U", saetze: saetze, minuten: nil)
    }

    func testFreshSplitHasOneToSixNamedDays() {
        for n in 1...6 {
            let plan = SplitFrei.anlegen(name: "Mein", tage: (1...n).map { "T\($0)" })
            XCTAssertEqual(plan.tage.map(\.name), (1...n).map { "T\($0)" })
            let wochentage = plan.tage.flatMap(\.wochentage)
            XCTAssertEqual(wochentage.count, n, "ein Wochentag je Tag")
            XCTAssertEqual(Set(wochentage).count, n, "keiner doppelt")
            XCTAssertEqual(Set(wochentage).union(plan.ruhetage ?? []), Set(1...7), "Rest sind Ruhetage")
            XCTAssertEqual(Set(plan.tage.map(\.id)).count, n)
        }
    }

    func testFreshSplitClampsAndFillsNames() {
        XCTAssertEqual(SplitFrei.anlegen(name: "", tage: []).tage.map(\.name), ["Tag 1"], "mindestens ein Tag")
        let sieben = SplitFrei.anlegen(name: "  Push Pull  ", tage: ["A", "  ", "C", "D", "E", "F", "G"])
        XCTAssertEqual(sieben.tage.map(\.name), ["A", "Tag 2", "C", "D", "E", "F"], "höchstens sechs, leere Namen werden Tag N")
        XCTAssertEqual(sieben.splitName, "Push Pull")
        XCTAssertEqual(SplitFrei.anlegen(name: " ", tage: ["A"]).splitName, "Mein Split")
        XCTAssertEqual(SplitFrei.wochentage(fuer: 3), [1, 3, 5])
        XCTAssertEqual(SplitFrei.wochentage(fuer: 0), [1])
    }

    func testPlantagCountsTrainingDaysOfTheWeek() {
        let plan = TrainingsPlan(tage: [tag("Push", [1], uebungen: 4), tag("Pull", [3], uebungen: 1), tag("Upper", [5], uebungen: 6)])
        let montag = SplitFrei.plantag(plan, datum: "2026-10-05")
        XCTAssertEqual(montag?.titel, "Tag 1 diese Woche: Push")
        XCTAssertEqual(montag?.unter, "4 Übungen · 3 Trainingstage pro Woche")
        XCTAssertEqual(montag?.heute, true)
        let freitag = SplitFrei.plantag(plan, datum: "2026-10-09")
        XCTAssertEqual(freitag?.titel, "Tag 3 diese Woche: Upper")
        XCTAssertEqual(freitag?.tagId, "Upper")
        XCTAssertEqual(SplitFrei.plantag(plan, datum: "2026-10-07")?.unter, "1 Übung · 3 Trainingstage pro Woche")
    }

    func testPlantagOnRestDayPointsToNextDay() {
        let plan = TrainingsPlan(tage: [tag("Push", [1]), tag("Upper", [5])])
        let dienstag = SplitFrei.plantag(plan, datum: "2026-10-06")
        XCTAssertEqual(dienstag?.titel, "Heute frei")
        XCTAssertEqual(dienstag?.unter, "Als Nächstes Tag 2: Upper, Freitag")
        XCTAssertEqual(dienstag?.heute, false)
        let sonntag = SplitFrei.plantag(plan, datum: "2026-10-11")
        XCTAssertEqual(sonntag?.unter, "Als Nächstes Tag 1: Push, nächste Woche Montag", "nach dem letzten Tag wieder der erste")
    }

    func testPlantagNeedsFixedWeekdays() {
        XCTAssertNil(SplitFrei.plantag(.leer, datum: "2026-10-05"))
        XCTAssertNil(SplitFrei.plantag(TrainingsPlan(tage: [tag("Flexibel", [])]), datum: "2026-10-05"))
        XCTAssertEqual(SplitFrei.plantag(TrainingsPlan(tage: [tag("", [1])]), datum: "2026-10-05")?.titel, "Tag 1 diese Woche: Training")
    }

    func testQuickEditSetsRepsAndWeight() {
        let u = uebung(saetze: [PlanSatz(wdh: 8, kg: 40, failure: false), PlanSatz(wdh: 6, kg: 45, failure: true)])
        XCTAssertEqual(SplitFrei.saetzeAnzahl(u, 4).saetze.count, 4)
        XCTAssertEqual(SplitFrei.saetzeAnzahl(u, 4).saetze.last, u.saetze.last, "neuer Satz kopiert den letzten")
        XCTAssertEqual(SplitFrei.saetzeAnzahl(u, 1).saetze, [u.saetze[0]])
        XCTAssertEqual(SplitFrei.saetzeAnzahl(u, 0).saetze.count, 1, "mindestens ein Satz")
        XCTAssertEqual(SplitFrei.saetzeAnzahl(u, 99).saetze.count, SplitFrei.maxSaetze)
        XCTAssertEqual(SplitFrei.saetzeAnzahl(uebung(saetze: []), 3).saetze, Array(repeating: PlanSatz(wdh: 10, kg: nil, failure: false), count: 3))
        XCTAssertEqual(SplitFrei.alleWdh(u, 12).saetze.map(\.wdh), [12, 12])
        XCTAssertEqual(SplitFrei.alleWdh(u, 0).saetze.map(\.wdh), [1, 1])
        XCTAssertEqual(SplitFrei.alleKg(u, 52.5).saetze.map(\.kg), [52.5, 52.5])
        XCTAssertEqual(SplitFrei.alleKg(u, 0).saetze.map(\.kg), [nil, nil])
        XCTAssertEqual(SplitFrei.alleKg(u, 900).saetze.first?.kg, 500)
        XCTAssertEqual(SplitFrei.alleWdh(u, 12).saetze.map(\.failure), [false, true], "Rest bleibt")
    }

    func testCardioDurationIsClamped() {
        var u = uebung(saetze: [])
        u.minuten = 20
        XCTAssertEqual(SplitFrei.dauer(u, 25).minuten, 25)
        XCTAssertEqual(SplitFrei.dauer(u, 1).minuten, 5)
        XCTAssertEqual(SplitFrei.dauer(u, 500).minuten, 180)
    }
}
