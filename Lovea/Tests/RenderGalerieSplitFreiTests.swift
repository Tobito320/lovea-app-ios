import SwiftUI
import XCTest
@testable import Lovea

/// Render-Tafel: Plantag-Karte oben in Health und der Split-Tag mit den Schnell-Steppern.
@MainActor
final class RenderGalerieSplitFreiTests: XCTestCase {
    private func zelle(_ schema: ColorScheme, titel: String, _ inhalt: some View) -> (titel: String, ansicht: AnyView) {
        let ansicht = inhalt
            .padding(18)
            .frame(width: 393, alignment: .top)
            .background(schema == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, schema)
        return (titel: titel, ansicht: AnyView(ansicht))
    }

    func testSplitFrei() throws {
        var n = 0
        let plan = SplitFrei.anlegen(name: "Mein Split", tage: ["Push", "Pull", "Beine", "Upper"]) { n += 1; return "t\(n)" }
        var tag = plan.tage[0]
        tag.uebungen = [
            PlanUebung(id: "u1", uebung: "EIeI8Vf", name: "Bankdrücken", saetze: Array(repeating: PlanSatz(wdh: 8, kg: 60, failure: false), count: 3), minuten: nil),
            PlanUebung(id: "u2", uebung: "j9Q5crt", name: "Laufband", saetze: [], minuten: 20),
        ]
        let gefuellt = TrainingLogik.tagSetzen(plan, tag)
        let heute = try XCTUnwrap(SplitFrei.plantag(gefuellt, datum: "2026-10-05"))
        let frei = try XCTUnwrap(SplitFrei.plantag(gefuellt, datum: "2026-10-03"))
        XCTAssertEqual(heute.titel, "Tag 1 diese Woche: Push")
        XCTAssertEqual(frei.titel, "Heute frei")
        RenderTafel.speichern("split-frei", spalten: 2, zellen: [
            zelle(.light, titel: "Plantag, Trainingstag", PlantagKarteInhalt(stand: heute)),
            zelle(.dark, titel: "Plantag, frei", PlantagKarteInhalt(stand: frei)),
            zelle(.light, titel: "Split-Tag, Schnell-Stepper", SplitEditorInhalt(plan: gefuellt, tagId: "t1", offen: "u1")),
            zelle(.dark, titel: "Split-Tag, Cardio", SplitEditorInhalt(plan: gefuellt, tagId: "t1", offen: "u2")),
        ])
    }
}
