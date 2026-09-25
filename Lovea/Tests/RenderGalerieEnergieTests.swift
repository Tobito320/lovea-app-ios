import SwiftUI
import XCTest
@testable import Lovea

/// Render board for Teil 5 (common.md): `EnergieAnsicht`, pure and without singletons.
@MainActor
final class RenderGalerieEnergieTests: XCTestCase {
    private func zelle(_ titel: String, _ ansicht: some View, _ schema: ColorScheme = .light) -> (titel: String, ansicht: AnyView) {
        (titel, AnyView(ansicht.padding(12).background(Color(uiColor: .systemBackground)).environment(\.colorScheme, schema)))
    }

    private func eingabe(naechte: [Int?], ruhetag: Bool = false, gymInFolge: Int = 0) -> EnergieEingabe {
        EnergieEingabe(
            naechte: naechte, wasser: 6, wasserZiel: 8, stunde: 16, schritteGestern: 9000,
            trainingstag: true, ruhetag: ruhetag, planLeer: false, gymInFolge: gymInFolge, heuteSchonGym: false
        )
    }

    private func karte(_ ich: Person, _ rat: EnergieRat, _ partner: Person, _ partnerRat: EnergieRat) -> some View {
        EnergieAnsicht(
            ich: ich, rat: rat, partner: partner, partnerRat: partnerRat,
            wasser: 6, wasserZiel: 8, wasserZeiten: [],
            schlafEintragen: {}, wasserPlus: {}
        ).frame(width: 390)
    }

    func testEnergieKarten() {
        let gut = EnergieLogik.rat(eingabe(naechte: [480, 480, 480]))
        let schlecht = EnergieLogik.rat(eingabe(naechte: [330, 360, 390]))
        let ruhe = EnergieLogik.rat(eingabe(naechte: [450, 450, 450], ruhetag: true))

        RenderTafel.speichern("energie", spalten: 3, zellen: [
            zelle("Ahmed, viel Energie", karte(.ahmed, gut, .annika, schlecht)),
            zelle("Annika, wenig Energie", karte(.annika, schlecht, .ahmed, gut)),
            zelle("Ahmed, Ruhetag", karte(.ahmed, ruhe, .annika, gut)),
        ])
    }
}
