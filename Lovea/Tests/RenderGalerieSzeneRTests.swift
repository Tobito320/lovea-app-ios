import SwiftUI
import XCTest
@testable import Lovea

/// Brief R render boards: office and classroom by day and by night (before Brief R they never
/// darkened, compare with the day cells).
@MainActor
final class RenderGalerieSzeneRTests: XCTestCase {
    private func kopf(_ szene: ProfilSzene, zimmer: Zimmer, nacht: Bool) -> AnyView {
        AnyView(
            ZStack(alignment: .bottom) {
                ProfilSzeneHintergrund(szene: szene, zimmer: zimmer, nacht: nacht, animiert: false)
                FigurView(.standard(for: .annika), zustand: szene.figur(.ruhig), groesse: 340, animiert: false, ganzkoerper: true, tisch: zimmer.tisch)
                    .brightness(szene.dunkel(nacht: nacht) ? -0.1 : 0)
            }
            .frame(width: 390, height: 430)
            .clipped()
        )
    }

    func testNachtImBueroUndKlassenzimmer() {
        let buero = Zimmer(wand: 5, boden: 1, deko: ["buecherregal", "stehlampe", "kaffeemaschine", "kaktus", "wanduhr", "ledWeiss", "teppich"], poster: 8, tisch: 3)
        let schule = Zimmer(wand: 3, boden: 3, deko: ["globus", "pinnwand", "lichterkette", "blumen", "stehlampe", "teppichRund"], poster: 4, tisch: 1)
        let zellen: [(titel: String, ansicht: AnyView)] = [
            (titel: "Büro Tag", ansicht: kopf(.arbeit, zimmer: Zimmer(ort: .arbeit), nacht: false)),
            (titel: "Büro Nacht", ansicht: kopf(.arbeit, zimmer: Zimmer(ort: .arbeit), nacht: true)),
            (titel: "Büro eingerichtet Nacht", ansicht: kopf(.arbeit, zimmer: buero, nacht: true)),
            (titel: "Klassenzimmer Tag", ansicht: kopf(.schule, zimmer: Zimmer(ort: .schule), nacht: false)),
            (titel: "Klassenzimmer Nacht", ansicht: kopf(.schule, zimmer: Zimmer(ort: .schule), nacht: true)),
            (titel: "Klassenzimmer eingerichtet Nacht", ansicht: kopf(.schule, zimmer: schule, nacht: true)),
        ]
        RenderTafel.speichern("profil-nacht-raeume", spalten: 3, zellen: zellen)
    }
}
