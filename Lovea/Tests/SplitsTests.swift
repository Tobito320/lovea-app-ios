import XCTest
@testable import Lovea

/// Fertige Splits (`splits.json`) und die reinen Texte der neuen Gym-Seite.
final class SplitsTests: XCTestCase {
    private let t0 = Datum.datum("2026-10-02").addingTimeInterval(15 * 3600)

    private func vorlage(_ id: String, gruppe: String = "m", tage: Int, ziel: String = "muskeln", geraet: String = "studio") -> SplitVorlage {
        SplitVorlage(id: id, name: id, gruppe: gruppe, level: "mittel", ziel: ziel, geraet: geraet, tage: tage, einheiten: [])
    }

    func testEverySplitResolvesAgainstTheCatalog() {
        let alle = SplitKatalog.alle
        XCTAssertGreaterThanOrEqual(alle.count, 30)
        XCTAssertEqual(Set(alle.map(\.id)).count, alle.count, "ids eindeutig")
        for v in alle {
            XCTAssertTrue(["m", "w"].contains(v.gruppe), v.id)
            let wochentage = v.einheiten.flatMap(\.wochentage)
            XCTAssertEqual(Set(wochentage).count, wochentage.count, "\(v.id): Wochentag doppelt")
            XCTAssertEqual(Set(wochentage).count, v.tage, "\(v.id): tage passt nicht zu den Wochentagen")
            XCTAssertTrue(wochentage.allSatisfy { (1...7).contains($0) }, v.id)
            for e in v.einheiten {
                XCTAssertFalse(e.uebungen.isEmpty, "\(v.id) \(e.name)")
                for z in e.uebungen {
                    XCTAssertNotNil(UebungsKatalog.nachId[z.uebung], "\(v.id) \(e.name): \(z.uebung) fehlt im Katalog")
                    XCTAssertTrue(z.saetze >= 1 && z.von >= 1 && z.bis >= z.von, "\(v.id) \(e.name)")
                }
            }
        }
    }

    func testEachPersonSeesOnlyTheirGroup() {
        let liste = [vorlage("a", gruppe: "m", tage: 3), vorlage("b", gruppe: "w", tage: 3), vorlage("c", gruppe: "m", tage: 4)]
        XCTAssertEqual(SplitLogik.fuer(.ahmed, in: liste).map(\.id), ["a", "c"])
        XCTAssertEqual(SplitLogik.fuer(.annika, in: liste).map(\.id), ["b"])
        XCTAssertEqual(SplitLogik.fuer(.ahmed, tage: 4, in: liste).map(\.id), ["c"])
        XCTAssertTrue(SplitLogik.fuer(.annika, tage: 6, in: liste).isEmpty)
        XCTAssertGreaterThanOrEqual(SplitLogik.fuer(.ahmed).count, 12)
        XCTAssertGreaterThanOrEqual(SplitLogik.fuer(.annika).count, 12)
    }

    func testCardioLineBecomesMinutesInPlan() {
        let z = SplitVorlage.Zeile(uebung: "j9Q5crt", saetze: 1, von: 1, bis: 1, minuten: 30)
        XCTAssertEqual(SplitLogik.wdhText(z), "30 min")
        let v = SplitVorlage(id: "c", name: "Cardio", gruppe: "m", level: "mittel", ziel: "definieren", geraet: "studio", tage: 1, einheiten: [
            .init(name: "A", wochentage: [6], uebungen: [z, .init(uebung: "EIeI8Vf", saetze: 3, von: 8, bis: 12)]),
        ])
        let plan = SplitLogik.alsPlan(v)
        let cardio = plan.tage[0].uebungen[0], kraft = plan.tage[0].uebungen[1]
        XCTAssertTrue(cardio.istCardio)
        XCTAssertEqual(cardio.minuten, 30)
        XCTAssertTrue(cardio.saetze.isEmpty)
        XCTAssertFalse(kraft.istCardio)
        XCTAssertEqual(kraft.saetze.count, 3)
        XCTAssertEqual(SplitKatalog.alle.first { $0.id == "m-ahmed01" }?.einheiten.flatMap(\.uebungen).filter { $0.minuten != nil }.count, 3, "Split 01: Cardio an drei Tagen")
    }

    func testSplitBecomesAPlanWithRestDays() {
        let v = SplitVorlage(id: "x", name: "Test", gruppe: "m", level: "einsteiger", ziel: "kraft", geraet: "studio", tage: 3, einheiten: [
            .init(name: "A", wochentage: [5, 1], uebungen: [.init(uebung: "EIeI8Vf", saetze: 4, von: 6, bis: 8)]),
            .init(name: "B", wochentage: [3], uebungen: [.init(uebung: "qXTaZnJ", saetze: 5, von: 5, bis: 5)]),
        ])
        var n = 0
        let plan = SplitLogik.alsPlan(v) { n += 1; return "id\(n)" }
        XCTAssertEqual(plan.splitName, "Test")
        XCTAssertEqual(plan.tage.map(\.name), ["A", "B"])
        XCTAssertEqual(plan.tage[0].wochentage, [1, 5])
        XCTAssertEqual(plan.ruhetage, [2, 4, 6, 7])
        XCTAssertEqual(plan.tage[0].uebungen[0].saetze, Array(repeating: PlanSatz(wdh: 6, kg: nil, failure: false), count: 4))
        XCTAssertEqual(Set(plan.tage.map(\.id) + plan.tage.flatMap { $0.uebungen.map(\.id) }).count, 4, "alle ids frisch")
        XCTAssertEqual(TrainingLogik.tag(plan, datum: "2026-10-02")?.name, "A") // Freitag
        XCTAssertEqual(SplitLogik.wochenbild(v), [true, false, true, false, true, false, false])
        XCTAssertEqual(SplitLogik.wdhText(v.einheiten[0].uebungen[0]), "4 × 6–8")
        XCTAssertEqual(SplitLogik.wdhText(v.einheiten[1].uebungen[0]), "5 × 5")
        XCTAssertEqual(SplitLogik.unterzeile(v), "3 Tage · Einsteiger")
    }

    func testOldPlanJsonWithoutSplitNameStillDecodes() throws {
        let alt = try JSONDecoder().decode(TrainingsPlan.self, from: Data(#"{"tage":[]}"#.utf8))
        XCTAssertNil(alt.splitName)
        XCTAssertNil(alt.ruhetage)
    }

    func testGuidedSuggestionPrefersDeviceThenDaysThenGoal() {
        let liste = [
            vorlage("studio6", tage: 6), vorlage("studio4kraft", tage: 4, ziel: "kraft"), vorlage("studio4", tage: 4),
            vorlage("kh3", tage: 3, geraet: "kurzhantel"), vorlage("w4", gruppe: "w", tage: 4),
        ]
        XCTAssertEqual(SplitLogik.vorschlag(.ahmed, tage: 4, ziel: "kraft", geraet: "studio", in: liste)?.id, "studio4kraft")
        XCTAssertEqual(SplitLogik.vorschlag(.ahmed, tage: 5, ziel: "muskeln", geraet: "studio", in: liste)?.id, "studio6")
        XCTAssertEqual(SplitLogik.vorschlag(.ahmed, tage: 6, ziel: "muskeln", geraet: "kurzhantel", in: liste)?.id, "kh3")
        XCTAssertEqual(SplitLogik.vorschlag(.annika, tage: 3, ziel: "fit", geraet: "studio", in: liste)?.id, "w4")
        XCTAssertNil(SplitLogik.vorschlag(.annika, tage: 3, ziel: "fit", geraet: "zuhause", in: liste))
        for p in Person.allCases {
            for g in SplitLogik.geraete { XCTAssertNotNil(SplitLogik.vorschlag(p, tage: 4, ziel: "muskeln", geraet: g.id), "\(p) \(g.id)") }
        }
    }

    func testStatusAndTitleTexts() {
        let saetze = Array(repeating: PlanSatz(wdh: 10, kg: 20, failure: false), count: 3)
        let lauf = UebungsLauf(plan: "p", uebung: "u", start: t0, ende: t0 + 600, fertig: true, saetze: saetze)
        let fertig = GymSession(id: "s", tag: nil, start: t0, ende: t0 + 54 * 60, laeufe: [lauf])
        let heute = "2026-10-02"
        XCTAssertEqual(GymStartLogik.status([fertig], datum: heute, heute: heute, geplant: nil, jetzt: t0 + 3600), "54 min · 3 Sätze")
        let offen = GymSession(id: "o", tag: nil, start: t0, ende: nil, laeufe: [])
        XCTAssertEqual(GymStartLogik.status([offen], datum: heute, heute: heute, geplant: nil, jetzt: t0 + 600), "gerade im Gym")
        XCTAssertEqual(GymStartLogik.status([], datum: heute, heute: heute, geplant: "Push", jetzt: t0), "noch nicht")
        XCTAssertEqual(GymStartLogik.status([], datum: "2026-10-01", heute: heute, geplant: "Push", jetzt: t0), "nicht im Gym")
        XCTAssertEqual(GymStartLogik.status([], datum: "2026-10-03", heute: heute, geplant: "Pull", jetzt: t0), "geplant: Pull")
        XCTAssertEqual(GymStartLogik.status([], datum: "2026-10-04", heute: heute, geplant: nil, jetzt: t0), "Ruhetag")

        let tag = TrainingsTag(id: "t", name: "Push", wochentage: [5], uebungen: [
            PlanUebung(id: "a", uebung: "EIeI8Vf", name: nil, saetze: Array(repeating: PlanSatz(wdh: 8, kg: nil, failure: false), count: 4), minuten: nil),
            PlanUebung(id: "b", uebung: "rjiM4L3", name: nil, saetze: [], minuten: 20),
        ])
        XCTAssertEqual(GymStartLogik.titel(datum: heute, heute: heute, tag: tag), "Heute · Push")
        XCTAssertEqual(GymStartLogik.titel(datum: "2026-09-30", heute: heute, tag: nil), "Mittwoch · Ruhetag")
        XCTAssertEqual(GymStartLogik.umfang(tag), "2 Übungen · etwa 30 min")
    }

    func testSwitchDefaultsToOn() {
        let defaults = UserDefaults(suiteName: "lovea.test.gymNeu")!
        defaults.removePersistentDomain(forName: "lovea.test.gymNeu")
        XCTAssertTrue(GymNeu.an(defaults))
        defaults.set(false, forKey: GymNeu.schluessel)
        XCTAssertFalse(GymNeu.an(defaults))
        defaults.removePersistentDomain(forName: "lovea.test.gymNeu")
    }
}
