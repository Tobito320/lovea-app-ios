import SwiftUI
import XCTest
@testable import Lovea

/// Render-Tafel "gym-einstellung": So geht's (Schrägbank, FitX und Absolut Fit) und Meine Einstellung.
@MainActor
final class EinstellungRenderTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private let liste = EinstellHinweise.laden(Bundle(for: EinstellGedaechtnis.self))

    private func zelle(_ schema: ColorScheme, titel: String, _ inhalt: some View) -> Zelle {
        let ansicht = inhalt
            .padding(18)
            .frame(width: 393, alignment: .top)
            .background(schema == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, schema)
        return (titel: titel, ansicht: AnyView(ansicht))
    }

    func testEinstellTafel() throws {
        let schraeg = try XCTUnwrap(EinstellHinweise.finden(name: "Schrägbankdrücken mit Kurzhanteln", in: liste))
        let beinpresse = try XCTUnwrap(EinstellHinweise.finden(name: "Beinpresse 45°", in: liste))
        let werte = EinstellWerte(bankstufe: 3, sitzhoehe: nil, polster: 2, notiz: "Lehne mit Wasserwaage geprüft, ca. 25 Grad")

        let fitx = VStack(spacing: 12) {
            SoGehtsKarte(hinweis: schraeg, studio: .fitxHagenMitte, offen: true)
            MeineEinstellungKarte(werte: werte, studio: .fitxHagenMitte)
        }
        let annika = VStack(spacing: 12) {
            SoGehtsKarte(hinweis: schraeg, studio: .absolutFit, offen: true)
            MeineEinstellungKarte(werte: nil, studio: .absolutFit)
        }
        let geraet = VStack(spacing: 12) {
            SoGehtsKarte(hinweis: beinpresse, studio: .fitxHagenMitte, offen: true)
            SoGehtsKarte(hinweis: schraeg, studio: .fitxHagenMitte, offen: false)
        }
        RenderTafel.speichern("gym-einstellung", spalten: 3, zellen: [
            zelle(.light, titel: "Schrägbank, FitX, hell", fitx),
            zelle(.light, titel: "Schrägbank, Absolut Fit, hell", annika),
            zelle(.dark, titel: "Beinpresse und zu, dunkel", geraet),
        ])
    }
}
