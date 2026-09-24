import SwiftUI
import XCTest
@testable import Lovea

/// Brief K render board: the profile kiss played by the figures, frame by frame, laid out like
/// the partner profile header (pair at the trailing edge of the 390-pt scene).
@MainActor
final class RenderGalerieKussTests: XCTestCase {
    private func szene(_ stand: KussAblauf.Stand?, nah: Bool = false) -> AnyView {
        let paar = KussPaarBild(vorn: .annika, stand: stand) { p, stand in
            FigurView(.standard(for: p), zustand: stand?.zustand(p) ?? .ruhig, groesse: 340, animiert: false, ganzkoerper: true, umarmung: stand?.umarmung(p))
        }
        return AnyView(
            ZStack(alignment: .bottom) {
                ProfilSzeneHintergrund(szene: .zimmer, zimmer: Zimmer(), nacht: false, animiert: false)
                paar
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, -6)
            }
            .frame(width: 390, height: 430)
            .scaleEffect(nah ? 2.2 : 1, anchor: UnitPoint(x: 0.62, y: 0.3))
            .frame(width: 390, height: 430)
            .clipped()
        )
    }

    func testKuss() {
        let zellen: [(titel: String, ansicht: AnyView)] = [
            (titel: "Vorher", ansicht: szene(nil)),
            (titel: "Ahmed kommt (0,3 s)", ansicht: szene(KussAblauf.stand(0.3))),
            (titel: "Umarmung (1,2 s)", ansicht: szene(KussAblauf.stand(1.2))),
            (titel: "Kuss (2,4 s)", ansicht: szene(KussAblauf.stand(2.4))),
            (titel: "Loslassen (3,5 s)", ansicht: szene(KussAblauf.stand(3.5))),
            (titel: "Reduce Motion (still)", ansicht: szene(KussAblauf.voll)),
            (titel: "Umarmung nah", ansicht: szene(KussAblauf.stand(1.2), nah: true)),
            (titel: "Kuss nah", ansicht: szene(KussAblauf.stand(2.4), nah: true)),
        ]
        RenderTafel.speichern("profil-kuss", spalten: 4, zellen: zellen)
    }
}
