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

    private func op(_ art: String, _ d: some Encodable, zeit: Date, id: String = UUID().uuidString) -> Op {
        Op(id: id, seq: nil, art: art, von: .ahmed, zeit: zeit, d: try! JSONEncoder().encode(d))
    }

    private func session(_ ops: [Op]) -> GymSession {
        var f = TrainingFaltung()
        for o in ops { f.anwenden(o) }
        return f.sessions(.ahmed)[0]
    }

    func testSkippedExerciseIsNotActiveAndDranMovesOn() {
        let tag = TrainingsTag(id: "t", name: "Push", wochentage: [], uebungen: [
            uebung("a", saetze: [satz(10, 50), satz(10, 50)]),
            uebung("b", saetze: [satz(12, 20)]),
        ])
        let s = session([
            op("gym.checkin", GymD(session: "s", tag: "t", start: t0), zeit: t0),
            op("gym.uebung", GymD(session: "s", plan: "a", uebung: "xa", status: "satz", saetze: []), zeit: t0 + 60),
        ])
        XCTAssertNil(s.aktiv) // ausgelassen: die Figur zeigt sie nicht als laufende Übung
        XCTAssertFalse(s.erledigt("a"))
        let liste = WorkoutLogik.uebungen(s, tag: tag, frueher: [])
        XCTAssertTrue(liste[0].ausgelassen)
        XCTAssertFalse(liste[1].ausgelassen)
        XCTAssertEqual(WorkoutLogik.dran(liste)?.uebung, 1)
        // "weg" nimmt die Übung wieder auf: frische Zeilen aus dem Plan.
        let wieder = session([
            op("gym.checkin", GymD(session: "s", tag: "t", start: t0), zeit: t0),
            op("gym.uebung", GymD(session: "s", plan: "a", uebung: "xa", status: "satz", saetze: []), zeit: t0 + 60),
            op("gym.uebung", GymD(session: "s", plan: "a", uebung: "xa", status: "weg"), zeit: t0 + 120),
        ])
        let neu = WorkoutLogik.uebungen(wieder, tag: tag, frueher: [])
        XCTAssertFalse(neu[0].ausgelassen)
        XCTAssertEqual(neu[0].saetze.count, 2)
        XCTAssertEqual(WorkoutLogik.dran(neu)?.uebung, 0)
    }

    func testSkippedCardioDranMovesOn() {
        let tag = TrainingsTag(id: "t", name: "Cardio", wochentage: [], uebungen: [uebung("c", minuten: 20), uebung("b", saetze: [satz(12, 20)])])
        let s = session([
            op("gym.checkin", GymD(session: "s", tag: "t", start: t0), zeit: t0),
            op("gym.uebung", GymD(session: "s", plan: "c", uebung: "xc", status: "satz", saetze: []), zeit: t0 + 60),
        ])
        let liste = WorkoutLogik.uebungen(s, tag: tag, frueher: [])
        XCTAssertTrue(liste[0].ausgelassen)
        XCTAssertEqual(WorkoutLogik.dran(liste)?.uebung, 1)
    }

    func testPlanQuestionKeepsPlanSetsOfSkippedExercise() {
        let tag = TrainingsTag(id: "t", name: "Push", wochentage: [], uebungen: [
            uebung("a", saetze: [satz(10, 50), satz(10, 50)]),
            uebung("b", saetze: [satz(12, 20)]),
        ])
        var liste = WorkoutLogik.uebungen(leereSession(), tag: tag, frueher: [])
        liste[0].saetze = []
        liste[0].ausgelassen = true
        XCTAssertNil(WorkoutLogik.neuerTag(tag, liste)) // nichts anderes geändert: keine Frage
        liste[1].saetze.append(satz(10, 20))
        let neu = WorkoutLogik.neuerTag(tag, liste)
        XCTAssertEqual(neu?.uebungen[0].saetze.count, 2) // der Plan behält die Sätze der ausgelassenen Übung
        XCTAssertEqual(neu?.uebungen[1].saetze.count, 2)
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
