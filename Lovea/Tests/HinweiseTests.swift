import XCTest
@testable import Lovea

final class HinweiseTests: XCTestCase {
    private let heute = "2026-09-25"

    private func u(_ id: String, _ muskel: String) -> Uebung {
        Uebung(id: id, name: id, en: id, muskel: muskel, koerper: "", geraet: "", neben: [])
    }

    private func katalog(_ liste: Uebung...) -> (String) -> Uebung? {
        let nachId = Dictionary(uniqueKeysWithValues: liste.map { ($0.id, $0) })
        return { nachId[$0] }
    }

    /// One session at 18:00 on `tag` with one finished set of `wdh` × `kg`.
    private func session(_ tag: String, _ uebung: String = "bank", kg: Double, wdh: Int = 8) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(18 * 3600)
        let lauf = UebungsLauf(plan: "p", uebung: uebung, start: nil, ende: start, fertig: true,
                               saetze: [PlanSatz(wdh: wdh, kg: kg, failure: false)])
        return GymSession(id: tag, tag: nil, start: start, ende: nil, laeufe: [lauf])
    }

    /// Sessions every other day from 2026-09-01, one per entry of `kgs`.
    private func reihe(_ kgs: [Double]) -> [GymSession] {
        kgs.enumerated().map { session(Datum.addTage("2026-09-01", $0.offset * 2), kg: $0.element) }
    }

    private func eingabe(sessions: [GymSession] = [], schlaf: [String: Int] = [:], wasser: [String: Int] = [:],
                         gym: Set<String> = [], stimmung: Int = 0, koffein: Int = 0,
                         prio: [MuskelGruppe] = []) -> HinweisEingabe {
        HinweisEingabe(sessions: sessions, schlafMinuten: schlaf, wasser: wasser, gymTage: gym,
                       stimmungTage: stimmung, koffeinTage: koffein, prio: prio, heute: heute)
    }

    private func arten(_ e: HinweisEingabe) -> [Hinweis.Art] {
        HinweisLogik.alle(e, katalog: katalog(u("bank", "Brust"))).map(\.art)
    }

    // MARK: - Stillstand

    func testStillstandNachDreiOhnePlus() {
        let h = HinweisLogik.alle(eingabe(sessions: reihe([65, 60, 62.5, 65])), katalog: katalog(u("bank", "Brust")))
        let still = h.first { $0.art == .stillstand }
        XCTAssertEqual(still?.titel, "bank steht still")
    }

    func testKeinStillstandBeiPlus() {
        XCTAssertFalse(arten(eingabe(sessions: reihe([65, 60, 62.5, 67.5]))).contains(.stillstand))
    }

    func testKeinStillstandUnterVierEinheiten() {
        XCTAssertFalse(arten(eingabe(sessions: reihe([65, 60, 62.5]))).contains(.stillstand))
    }

    func testEigeneUebungenMischenSichNicht() {
        let s = reihe([65, 60, 62.5, 65]).map { s -> GymSession in
            var s = s
            s.laeufe[0].uebung = PlanUebung.eigen
            return s
        }
        XCTAssertFalse(arten(eingabe(sessions: s)).contains(.stillstand))
    }

    // MARK: - Schlaf

    func testSchlafGegenLeistung() {
        // Even nights short (90 kg), odd nights long (100 kg): 10 points apart.
        let s = reihe([90, 100, 90, 100, 90, 100, 90, 100])
        let schlaf = Dictionary(uniqueKeysWithValues: s.enumerated().map {
            (Datum.text($0.element.start), $0.offset % 2 == 0 ? 300 : 450)
        })
        let h = HinweisLogik.alle(eingabe(sessions: s, schlaf: schlaf), katalog: katalog(u("bank", "Brust")))
        XCTAssertEqual(h.first { $0.art == .schlaf }?.zahl, "10 %")
    }

    func testSchlafMitZuWenigDatenIstGesperrt() {
        let h = HinweisLogik.alle(eingabe(sessions: reihe([90, 100])), katalog: katalog(u("bank", "Brust")))
        let gesperrt = h.first { $0.id == "gesperrt.schlaf" }
        XCTAssertEqual(gesperrt?.fortschritt, 0)
        XCTAssertFalse(h.contains { $0.art == .schlaf })
    }

    // MARK: - Wasser

    func testWasserAnGymTagenWeniger() {
        let tage = (0..<10).map { Datum.addTage("2026-09-10", $0) }
        let gym = Set(tage.prefix(5))
        let wasser = Dictionary(uniqueKeysWithValues: tage.map { ($0, gym.contains($0) ? 4 : 8) })
        XCTAssertTrue(arten(eingabe(wasser: wasser, gym: gym)).contains(.wasser))
    }

    func testWasserBraeuchtFuenfTageProGruppe() {
        let tage = (0..<9).map { Datum.addTage("2026-09-10", $0) }
        let gym = Set(tage.prefix(4))
        let wasser = Dictionary(uniqueKeysWithValues: tage.map { ($0, gym.contains($0) ? 4 : 8) })
        XCTAssertFalse(arten(eingabe(wasser: wasser, gym: gym)).contains(.wasser))
    }

    func testWasserUnterschiedUnterEinemGlas() {
        let tage = (0..<10).map { Datum.addTage("2026-09-10", $0) }
        let gym = Set(tage.prefix(5))
        let wasser = Dictionary(uniqueKeysWithValues: tage.map { ($0, gym.contains($0) ? 7 : 8) })
        XCTAssertTrue(arten(eingabe(wasser: wasser, gym: gym)).contains(.wasser)) // exactly 1 Glas
        let gleich = Dictionary(uniqueKeysWithValues: tage.map { ($0, 8) })
        XCTAssertFalse(arten(eingabe(wasser: gleich, gym: gym)).contains(.wasser))
    }

    // MARK: - Vergessen

    func testVergessenNachAchtTagen() {
        let s = [session("2026-09-17", kg: 60)] // 8 days before heute
        XCTAssertTrue(arten(eingabe(sessions: s, prio: [.brust])).contains(.vergessen))
    }

    func testNichtVergessenNachSiebenTagen() {
        let s = [session("2026-09-18", kg: 60)]
        XCTAssertFalse(arten(eingabe(sessions: s, prio: [.brust])).contains(.vergessen))
    }

    func testVergessenNurFuerPrioGruppen() {
        let s = [session("2026-09-01", kg: 60)]
        XCTAssertFalse(arten(eingabe(sessions: s, prio: [.beine])).contains(.vergessen))
    }

    // MARK: - Gesperrt und leer

    func testLeereEingabeNurGesperrte() {
        let h = HinweisLogik.alle(eingabe(), katalog: katalog())
        XCTAssertEqual(h.map(\.id), ["gesperrt.stimmung", "gesperrt.koffein"])
        XCTAssertTrue(h.allSatisfy { $0.art == .gesperrt && $0.fortschritt == 0 })
    }

    func testGesperrtZeigtFortschrittUndVerschwindetBei14Tagen() {
        let halb = HinweisLogik.alle(eingabe(stimmung: 7, koffein: 14), katalog: katalog())
        XCTAssertEqual(halb.map(\.id), ["gesperrt.stimmung"])
        XCTAssertEqual(halb.first?.fortschritt, 0.5)
        XCTAssertTrue(halb.first?.text.contains("Noch 7 Tage") == true)
    }

    func testReihenfolge() {
        let s = reihe([65, 60, 62.5, 65])
        let h = HinweisLogik.alle(eingabe(sessions: s, prio: [.brust, .beine]), katalog: katalog(u("bank", "Brust")))
        // beine never trained: no hint. brust last trained 2026-09-07 = 18 days ago.
        XCTAssertEqual(h.map(\.art), [.stillstand, .vergessen, .gesperrt, .gesperrt, .gesperrt])
    }
}
