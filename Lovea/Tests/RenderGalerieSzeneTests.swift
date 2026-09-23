import SwiftUI
import XCTest
@testable import Lovea

/// Brief G render boards: every profile scene with its figure, drawn like the own header (still,
/// full header size), and every bed with two sleepers. Frame photos can't load here, so the frames
/// show their drawn stand-in.
@MainActor
final class RenderGalerieSzeneTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private let eingerichtet = Zimmer(
        bett: 2, wand: 1, boden: 3, deko: Zimmer.dekoArten.map { $0.id },
        rahmen: [.init(slot: 0, medienId: "a"), .init(slot: 1, medienId: "b"), .init(slot: 2, medienId: "c")]
    )

    private func kopf(_ szene: ProfilSzene, _ p: Person = .annika, zimmer: Zimmer = Zimmer(), nacht: Bool = false, code: Int? = nil, temperatur: Double? = nil) -> AnyView {
        let figuren: AnyView
        if case .schlafen(let zusammen) = szene {
            let schlaefer = zusammen ? [p, p.partner] : [p]
            figuren = AnyView(SchlafendeFiguren(zimmer: zimmer, schlaefer: schlaefer.map { FigurAussehen.standard(for: $0) }, animiert: false))
        } else {
            let extras = szene.extras(wetterCode: code, temperatur: temperatur, laedt: false)
            figuren = AnyView(FigurView(.standard(for: p), zustand: szene.figur(.ruhig), groesse: 340, animiert: false, ganzkoerper: true, extras: extras))
        }
        return AnyView(
            ZStack(alignment: .bottom) {
                ProfilSzeneHintergrund(szene: szene, zimmer: zimmer, nacht: nacht, animiert: false)
                figuren
            }
            .frame(width: 390, height: 430)
            .clipped()
        )
    }

    func testSzenen() {
        let zellen: [Zelle] = [
            (titel: "Zimmer (Standard)", ansicht: kopf(.zimmer)),
            (titel: "Zimmer eingerichtet", ansicht: kopf(.zimmer, .ahmed, zimmer: eingerichtet)),
            (titel: "Zimmer bei Nacht", ansicht: kopf(.zimmer, .ahmed, zimmer: eingerichtet, nacht: true)),
            (titel: "Schlafen allein", ansicht: kopf(.schlafen(zusammen: false))),
            (titel: "Schlafen zusammen", ansicht: kopf(.schlafen(zusammen: true), zimmer: eingerichtet)),
            (titel: "Gym Ahmed", ansicht: kopf(.gym, .ahmed)),
            (titel: "Gym Annika", ansicht: kopf(.gym, .annika)),
            (titel: "Draußen Regen", ansicht: kopf(.draussen(wetter: .regen, nacht: false), code: 61, temperatur: 12)),
            (titel: "Draußen Sonne", ansicht: kopf(.draussen(wetter: .sonne, nacht: false), .ahmed, code: 0, temperatur: 24)),
            (titel: "Draußen Nacht", ansicht: kopf(.draussen(wetter: .sonne, nacht: true), code: 0, temperatur: 14)),
            (titel: "Draußen Wolken", ansicht: kopf(.draussen(wetter: .wolken, nacht: false), .ahmed, code: 3, temperatur: 16)),
            (titel: "Draußen Schnee", ansicht: kopf(.draussen(wetter: .schnee, nacht: false), code: 73, temperatur: -2)),
        ]
        RenderTafel.speichern("profil-szenen", spalten: 4, zellen: zellen)
    }

    func testBetten() {
        let zellen: [Zelle] = Zimmer.betten.indices.map { i in
            var z = Zimmer()
            z.bett = i
            let schlaefer = [FigurAussehen.standard(for: .annika), FigurAussehen.standard(for: .ahmed)]
            return (titel: Zimmer.betten[i], ansicht: AnyView(SchlafendeFiguren(zimmer: z, schlaefer: schlaefer, animiert: false).background(Color(white: 0.93))))
        }
        RenderTafel.speichern("profil-betten", spalten: 5, zellen: zellen)
    }
}
