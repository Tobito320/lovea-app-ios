import XCTest
@testable import Lovea

final class AusweichTests: XCTestCase {
    private let t0 = Datum.datum("2026-09-23").addingTimeInterval(18 * 3600)
    private let eintraege = AusweichLogik.laden(Bundle(for: TrainingModell.self))

    private func katalog(_ id: String) throws -> Uebung { try XCTUnwrap(UebungsKatalog.nachId[id], id) }

    func testAusweichDateiIstImBundleUndAlleIdsGibtEs() {
        XCTAssertGreaterThanOrEqual(eintraege.count, 15)
        for e in eintraege {
            for id in e.alternativen { XCTAssertNotNil(UebungsKatalog.nachId[id], "\(e.muster): \(id)") }
        }
    }

    func testAlternativenHabenGleicheMuskelgruppeHoechstensZweiUndNieSichSelbst() {
        for u in UebungsKatalog.alle {
            let alt = AusweichLogik.alternativen(fuer: u, eintraege: eintraege)
            XCTAssertLessThanOrEqual(alt.count, 2, u.name)
            XCTAssertEqual(Set(alt.map(\.id)).count, alt.count, u.name)
            for a in alt {
                XCTAssertEqual(a.muskel, u.muskel, "\(u.name) -> \(a.name)")
                XCTAssertNotEqual(a.id, u.id)
                XCTAssertFalse(a.istCardio)
            }
        }
    }

    func testSmithMachineBekommtKurzhantelAlsErsteAlternative() throws {
        let smith = try katalog("903mzG8")
        XCTAssertEqual(smith.geraet, "Multipresse")
        let alt = AusweichLogik.alternativen(fuer: smith, eintraege: eintraege)
        XCTAssertEqual(alt.first?.geraet, "Kurzhantel")
        XCTAssertTrue(alt.allSatisfy { $0.geraet != "Multipresse" })
    }

    func testBankdrueckenLanghantelBekommtAnderesGeraet() throws {
        let alt = AusweichLogik.alternativen(fuer: try katalog("EIeI8Vf"), eintraege: eintraege)
        XCTAssertFalse(alt.isEmpty)
        XCTAssertTrue(alt.allSatisfy { $0.geraet != "Langhantel" && $0.muskel == "Brust" })
    }

    func testFallbackOhneEintragIstDeterministischUndAndersesGeraet() throws {
        let u = try katalog("DsgkuIt")
        let a = AusweichLogik.alternativen(fuer: u, eintraege: [])
        let b = AusweichLogik.alternativen(fuer: u, eintraege: [])
        let c = AusweichLogik.alternativen(fuer: u, eintraege: [], katalog: UebungsKatalog.alle.reversed())
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, c)
        XCTAssertEqual(a.count, 2)
        XCTAssertTrue(a.allSatisfy { $0.geraet != u.geraet && $0.muskel == u.muskel })
        XCTAssertEqual(Set(a.map(\.geraet)).count, 2)
    }

    func testCardioUndEigeneUebungBekommenKeine() throws {
        let cardio = try XCTUnwrap(UebungsKatalog.alle.first { $0.istCardio })
        XCTAssertTrue(AusweichLogik.alternativen(fuer: cardio, eintraege: eintraege).isEmpty)
        let eigen = Uebung(id: PlanUebung.eigen, name: "Eigene", en: "own", muskel: "Brust", koerper: "Brust", geraet: "Kurzhantel", neben: [])
        XCTAssertTrue(AusweichLogik.alternativen(fuer: eigen, eintraege: eintraege).isEmpty)
    }

    func testSaetzeNachTauschOhneVorgeschichteOhneGewicht() {
        let aktuell = [PlanSatz(wdh: 8, kg: 60, failure: false, typ: "w"), PlanSatz(wdh: 10, kg: 80, failure: false)]
        let neu = AusweichLogik.saetzeNachTausch(aktuell, vorher: [])
        XCTAssertEqual(neu.count, 2)
        XCTAssertEqual(neu.map(\.typ), ["w", nil])
        XCTAssertTrue(neu.allSatisfy { $0.kg == nil && $0.ok == nil })
        let mit = AusweichLogik.saetzeNachTausch(aktuell, vorher: [PlanSatz(wdh: 12, kg: 20, failure: false)])
        XCTAssertEqual(mit[0].kg, 20)
        XCTAssertEqual(mit[0].wdh, 12)
        XCTAssertNil(mit[1].kg)
    }

    func testTauschbarNurVorDemErstenHaken() {
        let plan = PlanUebung(id: "p1", uebung: "903mzG8", name: nil, saetze: [], minuten: nil)
        let u = WorkoutUebung(planUebung: plan, saetze: [], vorher: [], extra: false)
        XCTAssertTrue(AusweichLogik.tauschbar(u, saetze: [PlanSatz(wdh: 10, kg: nil, failure: false)]))
        XCTAssertFalse(AusweichLogik.tauschbar(u, saetze: [PlanSatz(wdh: 10, kg: 40, failure: false, ok: true)]))
        let eigen = WorkoutUebung(planUebung: PlanUebung.eigene("Mein Ding"), saetze: [], vorher: [], extra: false)
        XCTAssertFalse(AusweichLogik.tauschbar(eigen, saetze: []))
    }

    // MARK: - Tausch im Training

    private func op(_ d: GymD, art: String = "gym.uebung", zeit: Date) -> Op {
        Op(id: UUID().uuidString, seq: nil, art: art, von: .ahmed, zeit: zeit, d: try! JSONEncoder().encode(d))
    }

    private func session(_ ops: [Op]) throws -> GymSession {
        var f = TrainingFaltung()
        for o in ops { f.anwenden(o) }
        return try XCTUnwrap(f.sessions(.ahmed).first)
    }

    func testTauschBehaeltPlanIdUndOriginalAmLauf() throws {
        let orig = "903mzG8", alt = "znQUdHY"
        let zeilen = [PlanSatz(wdh: 10, kg: nil, failure: false)]
        let tag = TrainingsTag(id: "t", name: "Push", wochentage: [], uebungen: [PlanUebung(id: "p1", uebung: orig, name: nil, saetze: zeilen, minuten: nil)])
        let checkin = op(GymD(session: "s", start: t0), art: "gym.checkin", zeit: t0)
        let tausch = op(GymD(session: "s", plan: "p1", uebung: alt, status: "satz", saetze: zeilen, ersatzFuer: orig), zeit: t0 + 60)

        var s = try session([checkin, tausch])
        XCTAssertEqual(s.laeufe.count, 1)
        XCTAssertEqual(s.laeufe[0].plan, "p1")
        XCTAssertEqual(s.laeufe[0].uebung, alt)
        XCTAssertEqual(s.laeufe[0].ersatzFuer, orig)
        var liste = WorkoutLogik.uebungen(s, tag: tag, frueher: [])
        XCTAssertEqual(liste.map(\.id), ["p1"])
        XCTAssertEqual(liste[0].planUebung.uebung, alt)
        XCTAssertEqual(liste[0].ersatzFuer, orig)
        XCTAssertNil(WorkoutLogik.neuerTag(tag, liste))

        let haken = op(GymD(session: "s", plan: "p1", uebung: alt, status: "satz", saetze: [PlanSatz(wdh: 10, kg: 22, failure: false, ok: true)]), zeit: t0 + 200)
        s = try session([checkin, tausch, haken])
        XCTAssertEqual(s.laeufe[0].ersatzFuer, orig, "ein normaler Satz-Stand behält die Zuordnung")
        XCTAssertEqual(s.laeufe[0].uebung, alt)
        XCTAssertEqual(RekordLogik.tage(katalogId: alt, in: [s]).count, 1)
        XCTAssertEqual(RekordLogik.tage(katalogId: orig, in: [s]).count, 0)
        XCTAssertTrue(s.erledigt("p1"))
        liste = WorkoutLogik.uebungen(s, tag: tag, frueher: [])
        XCTAssertEqual(liste[0].ersatzFuer, orig)
    }

    func testTauschRueckgaengig() throws {
        let orig = "903mzG8", alt = "znQUdHY"
        let zeilen = [PlanSatz(wdh: 10, kg: nil, failure: false)]
        let tag = TrainingsTag(id: "t", name: "Push", wochentage: [], uebungen: [PlanUebung(id: "p1", uebung: orig, name: nil, saetze: zeilen, minuten: nil)])
        let s = try session([
            op(GymD(session: "s", start: t0), art: "gym.checkin", zeit: t0),
            op(GymD(session: "s", plan: "p1", uebung: alt, status: "satz", saetze: zeilen, ersatzFuer: orig), zeit: t0 + 60),
            op(GymD(session: "s", plan: "p1", uebung: orig, status: "satz", saetze: zeilen), zeit: t0 + 120),
        ])
        XCTAssertEqual(s.laeufe[0].uebung, orig)
        XCTAssertNil(s.laeufe[0].ersatzFuer)
        let u = WorkoutLogik.uebungen(s, tag: tag, frueher: [])[0]
        XCTAssertEqual(u.planUebung.uebung, orig)
        XCTAssertNil(u.ersatzFuer)
    }

    func testAltesDatenformatDekodiertWeiter() throws {
        let alt = #"{"session":"s","plan":"p1","uebung":"903mzG8","status":"satz","saetze":[{"wdh":10,"kg":40,"failure":false,"ok":true}]}"#
        let d = try JSONDecoder().decode(GymD.self, from: Data(alt.utf8))
        XCTAssertNil(d.ersatzFuer)
        XCTAssertEqual(d.uebung, "903mzG8")
        let neu = try JSONEncoder().encode(GymD(session: "s", plan: "p1", uebung: "znQUdHY", status: "satz", ersatzFuer: "903mzG8"))
        let zurueck = try JSONDecoder().decode(GymD.self, from: neu)
        XCTAssertEqual(zurueck.ersatzFuer, "903mzG8")
        let s = try session([
            op(GymD(session: "s", start: t0), art: "gym.checkin", zeit: t0),
            op(d, zeit: t0 + 60),
        ])
        XCTAssertEqual(s.laeufe[0].uebung, "903mzG8")
        XCTAssertNil(s.laeufe[0].ersatzFuer)
        XCTAssertEqual(s.laeufe[0].saetze?.count, 1)
    }
}
