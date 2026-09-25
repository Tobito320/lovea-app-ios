import SwiftUI
import XCTest
@testable import Lovea

/// Teil 2 (Nähe) render board: the profile pair, frame by frame, laid out like the partner
/// profile header (pair at the trailing edge of the 390-pt scene). The kiss glides the level pose
/// into Stufe 3 and back — there is no separate kiss pose in the profile any more.
@MainActor
final class RenderGalerieKussTests: XCTestCase {
    private func figur(_ p: Person, _ pose: NaehePose, _ ebene: PaarEbene) -> some View {
        var um = pose.umarmung(p, partnerHaut: NaehePose.haut(.standard(for: p == .ahmed ? .annika : .ahmed)))
        um.ebene = ebene
        return FigurView(.standard(for: p), zustand: pose.zustand(p), groesse: 340, animiert: false, ganzkoerper: true, umarmung: um)
    }

    private func szene(_ pose: NaehePose, herzen: Bool = false, ahmedHerein: CGFloat = 0, nah: Bool = false) -> AnyView {
        let paar = KussPaarBild(pose: pose, herzen: herzen, ahmedHerein: ahmedHerein) { p, pose, ebene in
            self.figur(p, pose, ebene)
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

    /// Kiss while apart: level 0 gliding into Stufe 3 by the kiss's hug amount, Ahmed walking in.
    private func kussPose(_ t: TimeInterval) -> AnyView {
        let s = KussAblauf.stand(t)
        let pose = NaehePose.mix(.stufe(0, vorn: .annika), .stufe(3, vorn: .annika), s.arme)
        return szene(pose, herzen: s.kuss > 0, ahmedHerein: (1 - s.weg) * 150)
    }

    func testKuss() {
        let zellen: [(titel: String, ansicht: AnyView)] = [
            (titel: "Stufe 0", ansicht: szene(.stufe(0, vorn: .annika))),
            (titel: "Stufe 1", ansicht: szene(.stufe(1, vorn: .annika))),
            (titel: "Stufe 2", ansicht: szene(.stufe(2, vorn: .annika))),
            (titel: "Stufe 3", ansicht: szene(.stufe(3, vorn: .annika))),
            (titel: "Kuss kommt (0,3 s, getrennt)", ansicht: kussPose(0.3)),
            (titel: "Kuss (1,2 s)", ansicht: kussPose(1.2)),
            (titel: "Kuss (2,4 s)", ansicht: kussPose(2.4)),
            (titel: "Reduce Motion", ansicht: szene(.stufe(3, vorn: .annika), herzen: true)),
        ]
        RenderTafel.speichern("profil-kuss", spalten: 4, zellen: zellen)
    }
}
