import SwiftUI
import XCTest
@testable import Lovea

/// p71: Briefkasten und Telefon über einer Wand, ohne und mit rotem Punkt.
@MainActor
final class RenderGaleriePostTests: XCTestCase {
    private func szene(briefe: Int, sprache: Int) -> AnyView {
        AnyView(
            ZStack {
                Color(red: 0.98, green: 0.92, blue: 0.84)
                PostObjektLeiste(briefeNeu: briefe, sprachNeu: sprache)
            }
            .frame(width: 390, height: 430)
            .clipped()
        )
    }

    func testPostObjekte() {
        RenderTafel.speichern("profil-post", spalten: 3, zellen: [
            (titel: "keine neue Post", ansicht: szene(briefe: 0, sprache: 0)),
            (titel: "neuer Brief", ansicht: szene(briefe: 1, sprache: 0)),
            (titel: "Brief und Sprachpost", ansicht: szene(briefe: 2, sprache: 1)),
        ])
    }
}
