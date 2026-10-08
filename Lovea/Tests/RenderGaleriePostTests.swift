import SwiftUI
import XCTest
@testable import Lovea

/// p67 B: Profil-Szene mit Briefkasten und Telefon, ohne und mit rotem Punkt.
@MainActor
final class RenderGaleriePostTests: XCTestCase {
    private func szene(briefe: Bool, sprache: Bool) -> AnyView {
        AnyView(
            ZStack {
                ProfilSzeneHintergrund(szene: .zimmer, zimmer: Zimmer(), nacht: false, animiert: false)
                PostObjektLeiste(briefeNeu: briefe, sprachNeu: sprache)
            }
            .frame(width: 390, height: 430)
            .clipped()
        )
    }

    func testPostObjekte() {
        RenderTafel.speichern("profil-post", spalten: 3, zellen: [
            (titel: "keine neue Post", ansicht: szene(briefe: false, sprache: false)),
            (titel: "neuer Brief", ansicht: szene(briefe: true, sprache: false)),
            (titel: "Brief und Sprachpost", ansicht: szene(briefe: true, sprache: true)),
        ])
    }
}
