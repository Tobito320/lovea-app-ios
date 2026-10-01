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
}
