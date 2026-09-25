import XCTest
@testable import Lovea

final class RuhetageTests: XCTestCase {
    /// Main muscles by day name, so the tests don't need the bundled catalog.
    private let muskeln: [String: Set<String>] = [
        "Push": ["Brust", "Trizeps"], "Push2": ["Brust", "Schultern"], "Pull": ["Latissimus", "Bizeps"],
        "Beine": ["Quadrizeps", "Po"], "Beine2": ["Beinbeuger", "Waden"], "Core": ["Bauch"],
    ]

    private func schwerpunkt(_ t: TrainingsTag) -> Set<String> { muskeln[t.name] ?? [] }

    private func tag(_ name: String, _ tage: [Int]) -> TrainingsTag {
        TrainingsTag(id: name, name: name, wochentage: tage, uebungen: [])
    }

    private func hinweise(_ plan: TrainingsPlan) -> [PlanHinweis] { RuhetagLogik.hinweise(plan, schwerpunkt: schwerpunkt) }
    private func wertung(_ plan: TrainingsPlan) -> Int { RuhetagLogik.wertung(plan, schwerpunkt: schwerpunkt) }

    func testUnplannedDaysAreNamedFirst() {
        let plan = TrainingsPlan(tage: [tag("Push", [1, 3, 5])], ruhetage: [2])
        let h = hinweise(plan)
        XCTAssertEqual(h.map(\.id), ["offen"])
        XCTAssertTrue(h[0].text.contains("Do, Sa, So"))
        XCTAssertEqual(RuhetagLogik.art(plan, 2), .ruhe)
        XCTAssertEqual(RuhetagLogik.art(plan, 4), .offen)
        XCTAssertTrue(hinweise(.leer).isEmpty)
    }

    func testTooFewAndTooManyRestDays() {
        let keinRuhetag = TrainingsPlan(tage: [tag("Push", [1, 4]), tag("Pull", [2, 5]), tag("Beine", [3, 6]), tag("Core", [7])])
        XCTAssertEqual(hinweise(keinRuhetag).map(\.id), ["zuWenig"])
        let zweiTage = TrainingsPlan(tage: [tag("Push", [1]), tag("Beine", [4])], ruhetage: [2, 3, 5, 6, 7])
        XCTAssertEqual(hinweise(zweiTage).map(\.id), ["zuViel"])
    }

    func testGoodWeekHasNoHint() {
        let plan = TrainingsPlan(tage: [tag("Push", [1, 5]), tag("Pull", [2, 6]), tag("Beine", [4])], ruhetage: [3, 7])
        XCTAssertEqual(wertung(plan), 0)
        XCTAssertTrue(hinweise(plan).isEmpty)
    }

    func testSameMusclesOnNeighbouringDaysGetASwapThatFixesIt() throws {
        let plan = TrainingsPlan(tage: [tag("Push", [1]), tag("Push2", [2]), tag("Beine", [4])], ruhetage: [3, 5, 6, 7])
        XCTAssertEqual(wertung(plan), 10)
        let h = hinweise(plan)
        XCTAssertEqual(h.map(\.id), ["verteilung"])
        XCTAssertTrue(h[0].text.contains("Brust"))
        XCTAssertTrue(h[0].text.contains("Vorschlag:"))
        let t = try XCTUnwrap(h[0].tausch)
        XCTAssertEqual(wertung(RuhetagLogik.tauschen(plan, t[0], t[1])), 0)
    }

    func testLongStreakGetsSpreadWhenPossible() throws {
        let plan = TrainingsPlan(tage: [tag("Push", [1]), tag("Pull", [2]), tag("Beine", [3]), tag("Core", [4])], ruhetage: [5, 6, 7])
        XCTAssertEqual(RuhetagLogik.laengsteSerie(plan), 4)
        let h = hinweise(plan)
        XCTAssertEqual(h.map(\.id), ["verteilung"])
        let t = try XCTUnwrap(h[0].tausch)
        XCTAssertLessThanOrEqual(RuhetagLogik.laengsteSerie(RuhetagLogik.tauschen(plan, t[0], t[1])), 3)
    }

    func testNoNaggingWhenNoSwapHelps() {
        // Six training days with pairwise different main muscles and one rest day: every
        // arrangement leaves a run of 6, so no swap lowers the score.
        let plan = TrainingsPlan(
            tage: [tag("Push", [1]), tag("Pull", [2]), tag("Beine", [3]), tag("Core", [4]), tag("Beine2", [5]), tag("Push2", [6])],
            ruhetage: [7]
        )
        XCTAssertEqual(RuhetagLogik.laengsteSerie(plan), 6)
        XCTAssertTrue(hinweise(plan).isEmpty)
    }

    func testSetAndSwapKeepEveryWeekdayInOnePlace() {
        var plan = TrainingsPlan(tage: [tag("Push", [1, 3]), tag("Beine", [5])], ruhetage: [2])
        plan = RuhetagLogik.setzen(plan, 3, tag: nil)
        XCTAssertEqual(plan.tage[0].wochentage, [1])
        XCTAssertEqual(plan.ruhetage, [2, 3])
        plan = RuhetagLogik.setzen(plan, 2, tag: "Beine")
        XCTAssertEqual(plan.tage[1].wochentage, [2, 5])
        XCTAssertEqual(plan.ruhetage, [3])
        plan = RuhetagLogik.tauschen(plan, 1, 3)
        XCTAssertEqual(RuhetagLogik.art(plan, 1), .ruhe)
        XCTAssertEqual(RuhetagLogik.art(plan, 3), .training(plan.tage[0]))
        let mitTag = TrainingLogik.tagSetzen(plan, TrainingsTag(id: "Pull", name: "Pull", wochentage: [1], uebungen: []))
        XCTAssertEqual(RuhetagLogik.art(mitTag, 1), .training(mitTag.tage[2]))
        XCTAssertEqual(mitTag.ruhetage, [])
    }

    func testOldPlanWithoutRestDaysDecodes() throws {
        let plan = try JSONDecoder().decode(TrainingsPlan.self, from: Data(#"{"tage":[]}"#.utf8))
        XCTAssertNil(plan.ruhetage)
    }
}
