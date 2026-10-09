import SwiftUI
import XCTest
@testable import Lovea

/// Render-Tafel "gym-zeit": Zeitkarte passt, mit Supersatz-Tipp, mit Streich-Tipp, ohne Slot, dunkel.
@MainActor
final class ZeitRenderTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private func zelle(_ schema: ColorScheme, titel: String, _ inhalt: some View) -> Zelle {
        let ansicht = inhalt
            .padding(18)
            .frame(width: 393, alignment: .top)
            .background(schema == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, schema)
        return (titel: titel, ansicht: AnyView(ansicht))
    }

    private func tag(_ n: Int, saetze: Int) -> TrainingsTag {
        let namen = ["Bankdrücken", "Rudern", "Schulterdrücken", "Latzug", "Seitheben", "Bizepscurls", "Trizepsdrücken"]
        return TrainingsTag(id: "t", name: "Push", wochentage: [1], uebungen: (0..<n).map {
            PlanUebung(id: "u\($0)", uebung: "EIeI8Vf", name: namen[$0],
                       saetze: Array(repeating: PlanSatz(wdh: 10, kg: nil, failure: false), count: saetze), minuten: nil)
        })
    }

    func testZeitTafel() {
        let passt = ZeitSchaetzung.urteil(tag(5, saetze: 3), slotMinuten: 45)
        let supersatz = ZeitSchaetzung.urteil(tag(6, saetze: 3), slotMinuten: 33)
        let streichen = ZeitSchaetzung.urteil(tag(7, saetze: 4), slotMinuten: 45)
        let ohneSlot = ZeitSchaetzung.urteil(tag(7, saetze: 4), slotMinuten: nil)

        XCTAssertFalse(passt.warnt)
        XCTAssertNotNil(supersatz.tipp)
        XCTAssertNotNil(streichen.tipp)

        RenderTafel.speichern("gym-zeit", spalten: 2, zellen: [
            zelle(.light, titel: "Passt in 45 min, hell", ZeitKarte(urteil: passt)),
            zelle(.light, titel: "Über dem Slot, Supersatz-Tipp, hell", ZeitKarte(urteil: supersatz)),
            zelle(.light, titel: "Weit drüber, Streich-Tipp, hell", ZeitKarte(urteil: streichen)),
            zelle(.light, titel: "Ohne Slot, hell", ZeitKarte(urteil: ohneSlot)),
            zelle(.dark, titel: "Weit drüber, dunkel", ZeitKarte(urteil: streichen)),
            zelle(.dark, titel: "Passt, dunkel", ZeitKarte(urteil: passt)),
        ])
    }
}
