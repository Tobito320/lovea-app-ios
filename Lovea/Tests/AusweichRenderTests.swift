import SwiftUI
import XCTest
@testable import Lovea

/// Render-Tafel "gym-ausweich": Karte "Gerät besetzt?" vor und nach dem Tausch.
@MainActor
final class AusweichRenderTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private func zelle(_ schema: ColorScheme, titel: String, _ inhalt: some View) -> Zelle {
        let ansicht = inhalt
            .padding(18)
            .frame(width: 393, alignment: .top)
            .background(schema == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, schema)
        return (titel: titel, ansicht: AnyView(ansicht))
    }

    func testAusweichTafel() throws {
        let eintraege = AusweichLogik.laden(Bundle(for: TrainingModell.self))
        let smith = try XCTUnwrap(UebungsKatalog.nachId["903mzG8"])
        let alt = AusweichLogik.alternativen(fuer: smith, eintraege: eintraege)
        XCTAssertFalse(alt.isEmpty)
        let lang = try XCTUnwrap(UebungsKatalog.nachId["EIeI8Vf"])

        RenderTafel.speichern("gym-ausweich", spalten: 3, zellen: [
            zelle(.light, titel: "Multipresse, hell", AusweichKarte(muskel: smith.muskel, alternativen: alt)),
            zelle(.light, titel: "Nach Tausch, hell", AusweichKarte(muskel: smith.muskel, alternativen: Array(alt.dropFirst()), ursprung: smith)),
            zelle(.dark, titel: "Langhantel, dunkel", AusweichKarte(muskel: lang.muskel, alternativen: AusweichLogik.alternativen(fuer: lang, eintraege: eintraege))),
        ])
    }
}
