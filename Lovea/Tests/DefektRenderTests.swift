import SwiftUI
import XCTest
@testable import Lovea

/// Render-Tafel "gym-defekt": Karte frisch, mit Ausweich-Vorschlag, veraltet, und der Melden-Knopf.
@MainActor
final class DefektRenderTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private func zelle(_ schema: ColorScheme, titel: String, _ inhalt: some View) -> Zelle {
        let ansicht = inhalt
            .padding(18)
            .frame(width: 393, alignment: .top)
            .background(schema == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, schema)
        return (titel: titel, ansicht: AnyView(ansicht))
    }

    func testDefektTafel() throws {
        let smith = try XCTUnwrap(UebungsKatalog.nachId["903mzG8"])
        let vorschlag = try XCTUnwrap(AusweichLogik.alternativen(fuer: smith).first)
        let heute = "2026-10-05"

        RenderTafel.speichern("gym-defekt", spalten: 3, zellen: [
            zelle(.light, titel: "Vor 3 Tagen, mit Vorschlag, hell",
                  DefektKarte(notiz: DefektNotiz(text: "Sitz wackelt", gemeldetAm: "2026-10-02"), heute: heute, vorschlag: vorschlag)),
            zelle(.light, titel: "Älter als 30 Tage, hell",
                  DefektKarte(notiz: DefektNotiz(text: nil, gemeldetAm: "2026-08-20"), heute: heute, vorschlag: vorschlag)),
            zelle(.dark, titel: "Gestern, ohne Vorschlag, dunkel",
                  DefektKarte(notiz: DefektNotiz(text: "Seil gerissen", gemeldetAm: "2026-10-04"), heute: heute)),
            zelle(.light, titel: "Melden-Knopf, hell", DefektMeldenKnopf()),
        ])
    }
}
