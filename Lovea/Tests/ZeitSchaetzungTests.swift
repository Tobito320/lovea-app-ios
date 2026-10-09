import XCTest
@testable import Lovea

/// Zeitschätzung je Trainingstag (Sätze, Pausen, Wechsel), Warnung über dem Studio-Slot, 45-Minuten-Pläne.
final class ZeitSchaetzungTests: XCTestCase {
    private func uebung(_ name: String, saetze: Int = 3, pause: Int? = nil, supersatz: Bool? = nil) -> PlanUebung {
        PlanUebung(id: name, uebung: "EIeI8Vf", name: name,
                   saetze: Array(repeating: PlanSatz(wdh: 10, kg: nil, failure: false), count: saetze),
                   minuten: nil, pause: pause, supersatz: supersatz)
    }

    private func tag(_ uebungen: [PlanUebung]) -> TrainingsTag {
        TrainingsTag(id: "t", name: "Test", wochentage: [1], uebungen: uebungen)
    }

    private func namen(_ n: Int, saetze: Int = 3) -> [PlanUebung] {
        (0..<n).map { uebung(String(Character(UnicodeScalar(UInt8(65 + $0)))), saetze: saetze) }
    }

    func testLeererTagIstNullMinutenOhneWarnung() {
        XCTAssertEqual(ZeitSchaetzung.minuten(tag([])), 0)
        let u = ZeitSchaetzung.urteil(tag([]), slotMinuten: 45)
        XCTAssertEqual(u.minuten, 0)
        XCTAssertFalse(u.warnt)
        XCTAssertNil(u.tipp)
    }

    func testFuenfUebungenDreiSaetzeStandardPause() {
        // je Übung 3 × 40 s + 2 × 90 s Pause + 60 s Wechsel = 360 s
        XCTAssertEqual(ZeitSchaetzung.sekunden(tag(namen(1))), 360)
        XCTAssertEqual(ZeitSchaetzung.minuten(tag(namen(5))), 30)
    }

    func testPauseAusDemPlanUndNullIstStandard() {
        XCTAssertEqual(ZeitSchaetzung.sekunden(tag([uebung("A", pause: 60)])), 3 * 40 + 2 * 60 + 60)
        XCTAssertEqual(ZeitSchaetzung.sekunden(tag([uebung("A", pause: 0)])), 360)
    }

    func testCardioZaehltNachPlanMinuten() {
        let cardio = PlanUebung(id: "c", uebung: "j9Q5crt", name: nil, saetze: [], minuten: 20)
        XCTAssertEqual(ZeitSchaetzung.sekunden(tag([cardio])), 20 * 60 + 60)
    }

    func testSupersatzSpartEinePausePlusEinenWechsel() {
        // Paar: 6 Sätze × 40 s + 2 Pausen × 90 s + 1 Wechsel = 480 s statt 720 s
        XCTAssertEqual(ZeitSchaetzung.sekunden(tag([uebung("A", supersatz: true), uebung("B")])), 480)
        let mitPaar = tag([uebung("A", supersatz: true), uebung("B"), uebung("C"), uebung("D"), uebung("E")])
        XCTAssertEqual(ZeitSchaetzung.sekunden(mitPaar), 480 + 3 * 360)
        XCTAssertEqual(ZeitSchaetzung.minuten(mitPaar), 26)
    }

    func testSupersatzAnLetzterUebungOderCardioWirdIgnoriert() {
        XCTAssertEqual(ZeitSchaetzung.sekunden(tag([uebung("A", supersatz: true)])), 360)
        let cardio = PlanUebung(id: "c", uebung: "j9Q5crt", name: nil, saetze: [], minuten: 10)
        XCTAssertEqual(ZeitSchaetzung.sekunden(tag([uebung("A", supersatz: true), cardio])), 360 + 660)
    }

    func testWarnungErstUeberDerGrenze() {
        let fuenf = tag(namen(5))
        XCTAssertFalse(ZeitSchaetzung.urteil(fuenf, slotMinuten: 30).warnt, "genau 30 von 30 passt")
        let knapp = ZeitSchaetzung.urteil(fuenf, slotMinuten: 29)
        XCTAssertTrue(knapp.warnt)
        XCTAssertEqual(knapp.ueber, 1)
        XCTAssertEqual(knapp.titel, "ca. 30 min, 1 min über deinem Slot (29 min)")
        XCTAssertEqual(ZeitSchaetzung.urteil(fuenf, slotMinuten: 45).titel, "ca. 30 min, passt in deinen Slot (45 min)")
    }

    func testTippSupersatzWennEinPaarReicht() {
        // 6 × 360 s = 36 min, Slot 33: ein Paar spart 240 s und reicht
        let u = ZeitSchaetzung.urteil(tag(namen(6)), slotMinuten: 33)
        XCTAssertEqual(u.minuten, 36)
        XCTAssertEqual(u.tipp, .supersatz(erste: "A", zweite: "B", spart: 4))
        XCTAssertEqual(u.tipp?.text, "Tipp: A und B als Supersatz, spart ca. 4 min.")
    }

    func testTippStreichenWennKeinPaarReicht() {
        // 7 × 490 s (4 Sätze) = 58 min, Slot 45: kein Paar reicht, die letzten zwei fallen weg (41 min)
        let u = ZeitSchaetzung.urteil(tag(namen(7, saetze: 4)), slotMinuten: 45)
        XCTAssertEqual(u.minuten, 58)
        XCTAssertEqual(u.titel, "ca. 58 min, 13 min über deinem Slot (45 min)")
        XCTAssertEqual(u.tipp, .streichen(namen: ["F", "G"], spart: 17))
        XCTAssertEqual(u.tipp?.text, "Tipp: F, G weglassen, spart ca. 17 min.")
    }

    func testKeinTippUnterDerGrenze() {
        XCTAssertNil(ZeitSchaetzung.urteil(tag(namen(5)), slotMinuten: 45).tipp)
    }

    func testOhneSlotKeineWarnung() {
        let u = ZeitSchaetzung.urteil(tag(namen(7, saetze: 4)), slotMinuten: nil)
        XCTAssertFalse(u.warnt)
        XCTAssertNil(u.tipp)
        XCTAssertEqual(u.titel, "ca. 58 min")
        XCTAssertFalse(ZeitSchaetzung.urteil(tag(namen(7, saetze: 4)), slotMinuten: 0).warnt)
    }

    func testSlotNurMitFesterUhrzeit() {
        XCTAssertEqual(ZeitSchaetzung.slot(.standard(.ahmed)), 45)
        XCTAssertNil(ZeitSchaetzung.slot(.standard(.annika)))
        XCTAssertEqual(ZeitSchaetzung.slot(StudioProfil(studio: .absolutFit, slotStart: 18 * 60, dauer: 60)), 60)
        XCTAssertNil(ZeitSchaetzung.slot(StudioProfil(studio: .fitxHagenMitte, slotStart: 300, dauer: 0)))
    }

    func testSupersatzBleibtImPlanDerVorlage() {
        let v = SplitVorlage(id: "x", name: "X", gruppe: "m", level: "mittel", ziel: "muskeln", geraet: "studio", tage: 1, einheiten: [
            .init(name: "A", wochentage: [1], uebungen: [.init(uebung: "EIeI8Vf", saetze: 3, von: 8, bis: 12, supersatz: true), .init(uebung: "qXTaZnJ", saetze: 3, von: 8, bis: 12)]),
        ])
        let plan = SplitLogik.alsPlan(v)
        XCTAssertEqual(plan.tage[0].uebungen.map(\.supersatz), [true, nil])
    }

    func testKurzplaeneSindDa() {
        XCTAssertEqual(SplitLogik.treffer(SplitLogik.fuer(.ahmed), art: SplitLogik.kurzArt, tage: nil, suche: "").count, 3)
        XCTAssertGreaterThanOrEqual(SplitLogik.treffer(SplitLogik.fuer(.annika), art: SplitLogik.kurzArt, tage: nil, suche: "").count, 1)
        XCTAssertFalse(SplitLogik.fuer(.ahmed).filter(SplitLogik.istKurzplan).contains(where: SplitLogik.istEigen), "Für dich bleibt bei den 15 Eigenen")
    }

    func testKurzplaenePassenInDenSlot() {
        let kurz = SplitKatalog.alle.filter(SplitLogik.istKurzplan)
        XCTAssertFalse(kurz.isEmpty)
        for v in kurz {
            let plan = SplitLogik.alsPlan(v)
            XCTAssertFalse(plan.tage.isEmpty, v.id)
            for t in plan.tage {
                let u = ZeitSchaetzung.urteil(t, slotMinuten: 45)
                XCTAssertFalse(u.warnt, "\(v.id) \(t.name): \(u.titel)")
                XCTAssertGreaterThanOrEqual(u.minuten, 30, "\(v.id) \(t.name): zu kurz für einen Slot")
                XCTAssertTrue(t.uebungen.contains { $0.supersatz == true }, "\(v.id) \(t.name): ohne Supersatz")
            }
        }
        let fuenf = SplitKatalog.alle.first { $0.id == "m-kurz45-3" }
        XCTAssertEqual(fuenf?.einheiten.map(\.uebungen.count), [5, 5, 5], "Kurzplan mit fünf Übungen")
    }

    func testUmfangNutztDieSchaetzung() {
        let t = tag([uebung("A", saetze: 4), PlanUebung(id: "b", uebung: "rjiM4L3", name: nil, saetze: [], minuten: 20)])
        XCTAssertEqual(GymStartLogik.umfang(t), "2 Übungen · etwa 30 min")
    }
}
