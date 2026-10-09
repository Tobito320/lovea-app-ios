import SwiftUI
import XCTest
@testable import Lovea

/// Render-Tafel "dates-ansicht": Entwurf A in hell und dunkel, mit Startdaten (Nordpark erledigt).
@MainActor
final class DatesAnsichtRenderTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private func zelle(_ schema: ColorScheme, titel: String, _ inhalt: DatesRenderInhalt) -> Zelle {
        let ansicht = inhalt
            .background(schema == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, schema)
        return (titel: titel, ansicht: AnyView(ansicht))
    }

    func testDatesTafel() {
        let ideen = DateStartdaten.ideen
        var aktivitaetOffen = DateFilter()
        aktivitaetOffen.kategorie = .aktivitaet
        aktivitaetOffen.status = .offen
        let bowling = DatesUndo(ideeID: "start-bowling", titel: "Bowling", beginn: Date())
        let ohneBowling = ideen.map { idee -> DateIdee in
            var kopie = idee
            if idee.id == bowling.ideeID { kopie.geloescht = true }
            return kopie
        }

        RenderTafel.speichern("dates-ansicht", spalten: 2, zellen: [
            zelle(.light, titel: "Liste, hell", DatesRenderInhalt(ideen: ideen)),
            zelle(.dark, titel: "Liste, dunkel", DatesRenderInhalt(ideen: ideen)),
            zelle(.light, titel: "Aktivität + Offen, Undo-Leiste, hell", DatesRenderInhalt(ideen: ohneBowling, filter: aktivitaetOffen, undo: bowling)),
            zelle(.dark, titel: "Aktivität + Offen, Undo-Leiste, dunkel", DatesRenderInhalt(ideen: ohneBowling, filter: aktivitaetOffen, undo: bowling)),
        ])
    }
}
