import XCTest
@testable import Lovea

final class TrainingTests: XCTestCase {
    /// Wednesday 23.09.2026, 18:00 Berlin.
    private let t0 = Datum.datum("2026-09-23").addingTimeInterval(18 * 3600)

    private func op(_ art: String, _ d: some Encodable, zeit: Date, von: Person = .ahmed, id: String = UUID().uuidString, seq: Int? = nil) -> Op {
        Op(id: id, seq: seq, art: art, von: von, zeit: zeit, d: try! JSONEncoder().encode(d))
    }

    private func satz(_ wdh: Int, _ kg: Double?, failure: Bool = false) -> PlanSatz { PlanSatz(wdh: wdh, kg: kg, failure: failure) }

    private func planUebung(_ id: String, minuten: Int? = nil, saetze: [PlanSatz] = []) -> PlanUebung {
        PlanUebung(id: id, uebung: "x\(id)", name: "Übung \(id)", saetze: saetze, minuten: minuten)
    }

    private func faltung(_ ops: [Op]) -> TrainingFaltung {
        var f = TrainingFaltung()
        for o in ops { f.anwenden(o) }
        return f
    }

    func testSameOpTwiceCountsOnce() {
        let checkin = op("gym.checkin", GymD(session: "s", tag: "push", start: t0), zeit: t0, id: "c1")
        let start = op("gym.uebung", GymD(session: "s", plan: "p1", uebung: "EIeI8Vf", status: "start"), zeit: t0 + 60, id: "u1")
        var confirmed = start
        confirmed.seq = 7
        let sessions = faltung([checkin, start, confirmed]).sessions(.ahmed)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].laeufe.count, 1)
        XCTAssertEqual(sessions[0].aktiv?.uebung, "EIeI8Vf")
        XCTAssertEqual(sessions[0].tag, "push")
    }

    func testStartingAnotherEndsThePreviousWithoutTicking() {
        let s = faltung([
            op("gym.checkin", GymD(session: "s", start: t0), zeit: t0),
            op("gym.uebung", GymD(session: "s", plan: "a", uebung: "A", status: "start"), zeit: t0 + 60),
            op("gym.uebung", GymD(session: "s", plan: "b", uebung: "B", status: "start"), zeit: t0 + 600),
        ]).sessions(.ahmed)[0]
        XCTAssertEqual(s.laeufe.count, 2)
        XCTAssertEqual(s.laeufe[0].ende, t0 + 600)
        XCTAssertFalse(s.laeufe[0].fertig)
        XCTAssertEqual(s.aktiv?.plan, "b")
        XCTAssertFalse(s.erledigt("a"))
    }

    func testFinishWithSetsTickWithoutStartAndUndo() {
        let saetze = [satz(10, 60), satz(8, 62.5)]
        let s = faltung([
            op("gym.checkin", GymD(session: "s", start: t0), zeit: t0),
            op("gym.uebung", GymD(session: "s", plan: "a", uebung: "A", status: "start"), zeit: t0 + 60),
            op("gym.uebung", GymD(session: "s", plan: "a", uebung: "A", status: "fertig", saetze: saetze), zeit: t0 + 400),
            op("gym.uebung", GymD(session: "s", plan: "b", uebung: "B", status: "fertig"), zeit: t0 + 500),
            op("gym.uebung", GymD(session: "s", plan: "b", uebung: "B", status: "offen"), zeit: t0 + 510),
        ]).sessions(.ahmed)[0]
        XCTAssertTrue(s.erledigt("a"))
        XCTAssertEqual(s.laeufe[0].dauer, 340)
        XCTAssertEqual(s.laeufe[0].saetze, saetze)
        XCTAssertNil(s.laeufe[1].start)
        XCTAssertFalse(s.erledigt("b"))
        XCTAssertNil(s.aktiv)
    }

    func testCorrectedTimesNewestWinsAndDeletedIsGone() {
        let f = faltung([
            op("gym.checkin", GymD(session: "s", tag: "push", start: t0), zeit: t0),
            op("gym.checkout", GymD(session: "s", ende: t0 + 5 * 3600), zeit: t0 + 5 * 3600),
            op("gym.checkin", GymD(session: "s", tag: "push", start: t0 - 1800), zeit: t0 + 6 * 3600),
            op("gym.checkout", GymD(session: "s", ende: t0 + 5400), zeit: t0 + 6 * 3600 + 1),
            op("gym.checkin", GymD(session: "weg", start: t0 + 86400), zeit: t0 + 86400),
            op("gym.loeschen", GymD(session: "weg"), zeit: t0 + 86500),
        ])
        let sessions = f.sessions(.ahmed)
        XCTAssertEqual(sessions.map(\.id), ["s"])
        XCTAssertEqual(sessions[0].start, t0 - 1800)
        XCTAssertEqual(sessions[0].ende, t0 + 5400)
        XCTAssertTrue(f.sessions(.annika).isEmpty)
    }

    func testRunningAndForgotten() {
        let s = GymSession(id: "s", tag: nil, start: t0, ende: nil, laeufe: [])
        XCTAssertTrue(TrainingLogik.laufend(s, jetzt: t0 + 2 * 3600))
        XCTAssertNil(TrainingLogik.vergessen([s], jetzt: t0 + 2 * 3600))
        XCTAssertFalse(TrainingLogik.laufend(s, jetzt: t0 + 3.5 * 3600))
        XCTAssertEqual(TrainingLogik.vergessen([s], jetzt: t0 + 3.5 * 3600)?.id, "s")
        XCTAssertEqual(TrainingLogik.vergessen([s], jetzt: t0 + 26 * 3600)?.id, "s")   // Thursday 20:00
        XCTAssertNil(TrainingLogik.vergessen([s], jetzt: t0 + 40 * 3600))              // Friday 10:00
        var fertig = s
        fertig.ende = t0 + 3600
        XCTAssertFalse(TrainingLogik.laufend(fertig, jetzt: t0 + 1800 + 3600))
        XCTAssertNil(TrainingLogik.vergessen([fertig], jetzt: t0 + 4 * 3600))
        XCTAssertTrue(TrainingLogik.zuLang(start: t0, ende: t0 + 3 * 3600 + 60))
        XCTAssertFalse(TrainingLogik.zuLang(start: t0, ende: t0 + 2 * 3600))
    }

    func testNewestPlanWins() {
        let neu = TrainingsPlan(tage: [TrainingsTag(id: "t", name: "Push", wochentage: [1], uebungen: [])])
        let f = faltung([
            op("gym.plan", neu, zeit: t0 + 100),
            op("gym.plan", TrainingsPlan.leer, zeit: t0),
            op("gym.plan", TrainingsPlan.leer, zeit: t0 + 50, von: .annika),
        ])
        XCTAssertEqual(f.plaene[.ahmed], neu)
        XCTAssertEqual(f.plaene[.annika], .leer)
    }

    func testDayForDateNextAndWeekdaysMoveBetweenDays() {
        let push = TrainingsTag(id: "push", name: "Push", wochentage: [1, 3], uebungen: [planUebung("a"), planUebung("b")])
        let beine = TrainingsTag(id: "beine", name: "Beine", wochentage: [2], uebungen: [])
        let plan = TrainingsPlan(tage: [push, beine])
        XCTAssertEqual(TrainingLogik.tag(plan, datum: "2026-09-23")?.id, "push")   // Mittwoch
        XCTAssertEqual(TrainingLogik.tag(plan, datum: "2026-09-22")?.id, "beine")  // Dienstag
        XCTAssertNil(TrainingLogik.tag(plan, datum: "2026-09-24"))                 // Donnerstag: Ruhetag

        var s = GymSession(id: "s", tag: "push", start: t0, ende: nil, laeufe: [])
        XCTAssertEqual(TrainingLogik.naechste(push, s)?.id, "a")
        s.laeufe = [UebungsLauf(plan: "a", uebung: "xa", start: nil, ende: t0, fertig: true, saetze: nil)]
        XCTAssertEqual(TrainingLogik.naechste(push, s)?.id, "b")

        var beineNeu = beine
        beineNeu.wochentage = [2, 3]
        let neu = TrainingLogik.tagSetzen(plan, beineNeu)
        XCTAssertEqual(neu.tage.first { $0.id == "push" }?.wochentage, [1])
        XCTAssertEqual(neu.tage.first { $0.id == "beine" }?.wochentage, [2, 3])
        let mitNeuemTag = TrainingLogik.tagSetzen(plan, TrainingsTag(id: "pull", name: "Pull", wochentage: [5], uebungen: []))
        XCTAssertEqual(mitNeuemTag.tage.map(\.id), ["push", "beine", "pull"])
    }

    func testFinishedSetsBecomePlanValues() {
        let plan = TrainingsPlan(tage: [TrainingsTag(id: "t", name: "Push", wochentage: [1], uebungen: [planUebung("a", saetze: [satz(10, 60)])])])
        let neu = TrainingLogik.uebernehmen(plan, planUebung: "a", saetze: [satz(10, 62.5), satz(8, 62.5, failure: true)])
        XCTAssertEqual(neu.tage[0].uebungen[0].saetze, [satz(10, 62.5), satz(8, 62.5, failure: true)])
        XCTAssertEqual(TrainingLogik.uebernehmen(plan, planUebung: "zz", saetze: []), plan)
    }

    func testNotAtGymOnlyWithSavedGymAndFreshFix() {
        let gym = Ort(id: "g", person: .ahmed, name: "Gym", kategorie: "gym", lat: 52.52, lon: 13.40, radius: 100, melden: "nichts")
        let annikasGym = Ort(id: "h", person: .annika, name: "Gym", kategorie: "gym", lat: 52.52, lon: 13.40, radius: 100, melden: "nichts")
        XCTAssertFalse(TrainingLogik.nichtImGym(orte: [], ich: .ahmed, lat: 52.6, lon: 13.4, alter: 10))
        XCTAssertFalse(TrainingLogik.nichtImGym(orte: [annikasGym], ich: .ahmed, lat: 52.6, lon: 13.4, alter: 10))
        XCTAssertFalse(TrainingLogik.nichtImGym(orte: [gym], ich: .ahmed, lat: nil, lon: nil, alter: nil))
        XCTAssertFalse(TrainingLogik.nichtImGym(orte: [gym], ich: .ahmed, lat: 52.6, lon: 13.4, alter: 600))
        XCTAssertFalse(TrainingLogik.nichtImGym(orte: [gym], ich: .ahmed, lat: 52.5201, lon: 13.4001, alter: 10))
        XCTAssertTrue(TrainingLogik.nichtImGym(orte: [gym], ich: .ahmed, lat: 52.6, lon: 13.4, alter: 10))
    }

    func testTexts() {
        XCTAssertEqual(TrainingLogik.saetzeText(planUebung("a", saetze: [satz(10, 60), satz(10, 60), satz(10, 60)])), "3 × 10 · 60 kg")
        XCTAssertEqual(TrainingLogik.saetzeText(planUebung("a", saetze: [satz(12, 40), satz(10, 45), satz(8, 50, failure: true)])), "3 Sätze · 40–50 kg · F")
        XCTAssertEqual(TrainingLogik.saetzeText(planUebung("a", saetze: [satz(15, nil)])), "1 × 15")
        XCTAssertEqual(TrainingLogik.saetzeText(planUebung("a", minuten: 20)), "20 min")
        XCTAssertEqual(TrainingLogik.kgText(62.5), "62,5")
        XCTAssertEqual(TrainingLogik.dauerText(3900), "1:05 h")
        XCTAssertEqual(TrainingLogik.dauerText(2520), "42 min")
        XCTAssertEqual(TrainingLogik.wochentageText([5, 1, 3]), "Mo, Mi, Fr")
        XCTAssertEqual(TrainingLogik.wochentageText([]), "kein Tag")
        XCTAssertEqual(TrainingLogik.tagText(t0, jetzt: t0 + 3600), "heute")
        XCTAssertEqual(TrainingLogik.tagText(t0, jetzt: t0 + 20 * 3600), "gestern")
    }

    func testCardioDeviceAndNewPlanEntries() {
        let laufband = Uebung(id: "l", name: "Gehen auf dem Laufband", en: "walking on incline treadmill", muskel: "Herz-Kreislauf", koerper: "Cardio", geraet: "Körpergewicht", neben: [])
        let stepper = Uebung(id: "s", name: "Gehen am Stepper", en: "walking on stepmill", muskel: "Herz-Kreislauf", koerper: "Cardio", geraet: "Stepper", neben: [])
        let bank = Uebung(id: "b", name: "Bankdrücken mit Langhantel", en: "barbell bench press", muskel: "Brust", koerper: "Brust", geraet: "Langhantel", neben: [])
        XCTAssertEqual(TrainingLogik.cardioGeraet(laufband), "laufband")
        XCTAssertEqual(TrainingLogik.cardioGeraet(stepper), "stairmaster")
        XCTAssertNil(TrainingLogik.cardioGeraet(bank))
        XCTAssertEqual(PlanUebung.neu(laufband).minuten, 20)
        XCTAssertTrue(PlanUebung.neu(laufband).saetze.isEmpty)
        XCTAssertEqual(PlanUebung.neu(bank).saetze.count, 3)
        XCTAssertEqual(PlanUebung.eigene("Kabelturm").anzeigeName, "Kabelturm")
    }

    func testGymPayloadDecodesWithMissingAndUnknownFields() throws {
        let d = try JSONDecoder().decode(GymD.self, from: Data(#"{"session":"s","neu":"egal"}"#.utf8))
        XCTAssertEqual(d, GymD(session: "s"))
    }
}
