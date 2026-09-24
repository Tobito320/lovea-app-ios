import SwiftUI
import XCTest
@testable import Lovea

/// Brief Z render board: the drawing scene in the own room (still frame, mid-doodle), alone,
/// together and at night, plus two close-ups of the tablet.
@MainActor
final class RenderGalerieZeichnenTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private func figur(_ p: Person, _ szene: ProfilSzene, groesse: CGFloat = 340) -> FigurView {
        let z = szene.figur(.zeichnet)
        return FigurView(.standard(for: p), zustand: z, groesse: groesse, animiert: false, ganzkoerper: true, extras: szene.extras(z, wetterCode: nil, temperatur: nil))
    }

    /// Like the header: the room of the first person, both figures as the pair stands (Annika left).
    private func kopf(_ szene: ProfilSzene, _ personen: [Person], nacht: Bool = false) -> AnyView {
        AnyView(
            ZStack(alignment: .bottom) {
                ProfilSzeneHintergrund(szene: szene, zimmer: Zimmer(ort: .zuhause, person: personen[0]), nacht: nacht, animiert: false)
                HStack(alignment: .bottom, spacing: -64) {
                    ForEach(personen, id: \.self) { figur($0, szene) }
                }
                .brightness(szene.dunkel(nacht: nacht) ? -0.1 : 0)
            }
            .frame(width: 390, height: 430)
            .clipped()
        )
    }

    /// The tablet large: an 800-pt figure, cut to its lap.
    private func nah(_ p: Person, _ szene: ProfilSzene) -> AnyView {
        AnyView(
            figur(p, szene, groesse: 800)
                .offset(y: -44)
                .frame(width: 390, height: 430)
                .clipped()
                .background(Color(white: 0.93))
        )
    }

    func testZeichnen() {
        let allein = ProfilSzene.zeichnen(zusammen: false)
        let zusammen = ProfilSzene.zeichnen(zusammen: true)
        let zellen: [Zelle] = [
            (titel: "Annika zeichnet", ansicht: kopf(allein, [.annika])),
            (titel: "Ahmed zeichnet", ansicht: kopf(allein, [.ahmed])),
            (titel: "Zusammen zeichnen", ansicht: kopf(zusammen, [.annika, .ahmed])),
            (titel: "Annika zeichnet bei Nacht", ansicht: kopf(allein, [.annika], nacht: true)),
            (titel: "Ahmed zeichnet bei Nacht", ansicht: kopf(allein, [.ahmed], nacht: true)),
            (titel: "Tablett nah (allein)", ansicht: nah(.annika, allein)),
            (titel: "Tablett nah (zusammen, Ahmed)", ansicht: nah(.ahmed, zusammen)),
        ]
        RenderTafel.speichern("profil-zeichnen", spalten: 4, zellen: zellen)
    }
}
