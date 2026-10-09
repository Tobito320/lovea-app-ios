import SwiftUI
import XCTest
@testable import Lovea

/// p65 B2: every pose of the whole-body figure, for both people, as one still picture each (CI
/// uploads `render-galerie`). The sofa here is a stand-in built from the same numbers as the pose
/// logic (`FigurPoseLogik.sitzFlaecheY`), so the picture shows where the body rests.
@MainActor
final class RenderGalerieFigurPosenTests: XCTestCase {
    private let hoehe: CGFloat = 200
    private let zelleGroesse: CGFloat = 210

    private func figur(_ person: Person, _ pose: FigurPose, schlaeft: Bool = false) -> FigurView {
        FigurView(.standard(for: person), zustand: FigurPoseLogik.zustand(pose, schlaeft: schlaeft),
                  groesse: hoehe, animiert: false, ganzkoerper: true, pose: pose)
    }

    private func zelle(_ person: Person, _ pose: FigurPose, schlaeft: Bool = false) -> AnyView {
        AnyView(
            figur(person, pose, schlaeft: schlaeft)
                .frame(width: zelleGroesse, height: zelleGroesse, alignment: .bottom)
                .background(Color(white: 0.93))
        )
    }

    /// Stand-in sofa: back behind the figure, base behind the lower legs, armrests in front of the hips.
    private func sofa(_ person: Person, stufe: Int) -> AnyView {
        let faktor = hoehe / FigurPoseLogik.leinwand.height
        let boden = zelleGroesse
        let sitz = boden - (FigurPoseLogik.bodenY - FigurPoseLogik.sitzFlaecheY(stufe: stufe)) * faktor
        let breite: CGFloat = 190
        let lehne = Color(red: 0.62, green: 0.46, blue: 0.70)
        let figurX = (breite - hoehe / 2) / 2
        return AnyView(
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.55, green: 0.40, blue: 0.62))
                    .frame(width: breite, height: 92).offset(y: sitz - 84)
                RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.45, green: 0.32, blue: 0.52))
                    .frame(width: breite, height: boden - sitz).offset(y: sitz)
                FigurView(.standard(for: person), zustand: .ruhig, groesse: hoehe, animiert: false, ganzkoerper: true, pose: .sitzenSofa)
                    .offset(x: figurX, y: boden - FigurPoseLogik.bodenY * faktor)
                RoundedRectangle(cornerRadius: 10).fill(lehne)
                    .frame(width: 30, height: boden - sitz + 30).offset(y: sitz - 30)
                RoundedRectangle(cornerRadius: 10).fill(lehne)
                    .frame(width: 30, height: boden - sitz + 30).offset(x: breite - 30, y: sitz - 30)
            }
            .frame(width: breite, height: zelleGroesse, alignment: .topLeading)
            .frame(width: zelleGroesse, height: zelleGroesse)
            .background(Color(white: 0.93))
        )
    }

    func testPosenAhmed() {
        RenderTafel.speichern("figur-posen-ahmed", spalten: 4, zellen: zellenFuer(.ahmed))
    }

    func testPosenAnnika() {
        RenderTafel.speichern("figur-posen-annika", spalten: 4, zellen: zellenFuer(.annika))
    }

    func testSofa() {
        let zellen: [(titel: String, ansicht: AnyView)] = [
            (titel: "Ahmed klein", ansicht: sofa(.ahmed, stufe: 0)),
            (titel: "Ahmed mittel", ansicht: sofa(.ahmed, stufe: 1)),
            (titel: "Ahmed gross", ansicht: sofa(.ahmed, stufe: 2)),
            (titel: "Annika mittel", ansicht: sofa(.annika, stufe: 1)),
        ]
        RenderTafel.speichern("figur-sofa", spalten: 4, zellen: zellen)
    }

    private func zellenFuer(_ person: Person) -> [(titel: String, ansicht: AnyView)] {
        [
            (titel: "stehen", ansicht: zelle(person, .stehen)),
            (titel: "gehen", ansicht: zelle(person, .gehen)),
            (titel: "winken", ansicht: zelle(person, .winken)),
            (titel: "sitzen Sofa", ansicht: zelle(person, .sitzenSofa)),
            (titel: "sitzen Bettkante", ansicht: zelle(person, .sitzenBettkante)),
            (titel: "liegen", ansicht: zelle(person, .liegen)),
            (titel: "liegen, schläft", ansicht: zelle(person, .liegen, schlaeft: true)),
        ]
    }
}
