import SwiftUI
import XCTest
@testable import Lovea

/// p58: the home scene at the four times of day, at the places the walks end, with bouquets and on
/// the widest phone. The stage runs fixed here (no driver), so every cell is one still picture.
@MainActor
final class ZuhauseRenderTests: XCTestCase {
    private func buehne(_ zeit: Tageszeit, schritt: Int, breite: CGFloat = 390, straeusse: ZuhauseStraeusse = ZuhauseStraeusse()) -> AnyView {
        let stand = ZuhauseSzenenstand(zeit: zeit, ZuhauseAblauf.aufstellung(zeit, schritt: schritt), mitGeste: true)
        let szene = ZuhauseBuehne(straeusse: straeusse, fest: stand) { f in
            FigurView(.standard(for: f.person), zustand: f.zustand, groesse: f.groesse, animiert: false, ganzkoerper: f.ganzkoerper)
        } paar: {
            EmptyView()
        }
        return AnyView(szene.frame(width: breite, height: 430).clipped())
    }

    func testProfilBrett() {
        let viele = ZuhauseStraeusse(schrank: ["rosen", "tulpen", "lavendel"], vase: "sonnenblumen")
        let zellen: [(titel: String, ansicht: AnyView)] = [
            (titel: "Morgen: Annika am Fenster, winkt", ansicht: buehne(.morgen, schritt: 0)),
            (titel: "Mittag: beide auf dem Sofa, Herz", ansicht: buehne(.tag, schritt: 0)),
            (titel: "Abend: beide sitzen im Bett", ansicht: buehne(.abend, schritt: 0)),
            (titel: "Nacht: beide schlafen", ansicht: buehne(.nacht, schritt: 0)),
            (titel: "Mittag: Annika bei den Blumen, winkt", ansicht: buehne(.tag, schritt: 1)),
            (titel: "Mittag: Annika am Bett", ansicht: buehne(.tag, schritt: 3)),
            (titel: "Morgen: beide am Fenster, Herz", ansicht: buehne(.morgen, schritt: 3)),
            (titel: "Morgen: beide auf dem Sofa, Kuss", ansicht: buehne(.morgen, schritt: 2)),
            (titel: "Sträuße: Kommode 3, Vase 1", ansicht: buehne(.tag, schritt: 2, straeusse: viele)),
            (titel: "Sträuße in der Nacht", ansicht: buehne(.nacht, schritt: 0, straeusse: viele)),
            (titel: "Sträuße: nur 2 und keine Vase", ansicht: buehne(.morgen, schritt: 1, straeusse: ZuhauseStraeusse(schrank: ["a", "b"]))),
            (titel: "Breites Handy 430 pt", ansicht: buehne(.tag, schritt: 4, breite: 430)),
        ]
        RenderTafel.speichern("p58-profil", spalten: 4, zellen: zellen)
    }
}
