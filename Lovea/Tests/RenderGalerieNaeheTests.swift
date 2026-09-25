import SwiftUI
import XCTest
@testable import Lovea

@MainActor
final class RenderGalerieNaeheTests: XCTestCase {
    private func figur(_ p: Person, _ pose: NaehePose, _ ebene: PaarEbene) -> some View {
        let partner = FigurAussehen.standard(for: p == .ahmed ? .annika : .ahmed)
        var um = pose.umarmung(p, partnerHaut: NaehePose.haut(partner))
        um.ebene = ebene
        return FigurView(.standard(for: p), zustand: pose.zustand(p), groesse: 340, animiert: false, ganzkoerper: true, umarmung: um)
            .frame(width: 170, height: 340)
            .offset(x: pose.versatz(p))
    }

    /// Both bodies (front figure on top), then both pair arms over everything.
    @ViewBuilder
    private func reihe(_ pose: NaehePose, _ ebene: PaarEbene) -> some View {
        HStack(spacing: -64) {
            ForEach([Person.annika, .ahmed], id: \.self) { p in
                self.figur(p, pose, ebene).zIndex(p == pose.vorn ? 1 : 0)
            }
        }
    }

    private func paar(_ pose: NaehePose) -> AnyView {
        AnyView(ZStack {
            reihe(pose, .ohneArm)
            reihe(pose, .nurArm)
        }.frame(width: 300, height: 360))
    }

    func testNaehePosen() {
        let zellen: [(titel: String, ansicht: AnyView)] = [
            (titel: "Stufe 0", ansicht: paar(.stufe(0, vorn: .annika))),
            (titel: "Stufe 1", ansicht: paar(.stufe(1, vorn: .annika))),
            (titel: "Stufe 2", ansicht: paar(.stufe(2, vorn: .annika))),
            (titel: "Stufe 3", ansicht: paar(.stufe(3, vorn: .annika))),
            (titel: "Kuss", ansicht: paar(.kuss)),
            (titel: "halb zum Kuss", ansicht: paar(.mix(.stufe(1, vorn: .annika), .kuss, 0.5))),
        ]
        RenderTafel.speichern("naehe-posen", spalten: 3, zellen: zellen)
    }
}
