import SwiftUI
import XCTest
@testable import Lovea

/// Brief R render boards: office and classroom by day and by night (before Brief R they never
/// darkened, compare with the day cells), posters next to photo frames.
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

    /// The moving scene is four stacked canvases, the still one a single canvas with the same four
    /// layers. Left the still picture, right the live stack (its clock is "now", so rain, clouds
    /// and twinkle differ; everything else must match).
    func testEbenenGleichEinerLeinwand() {
        let zimmer = Zimmer(bett: 2, wand: 1, boden: 3, deko: Zimmer.dekoArten.map { $0.id },
                            rahmen: [.init(slot: 0, medienId: "a"), .init(slot: 1, medienId: "b"), .init(slot: 2, medienId: "c")])
        let faelle: [(String, ProfilSzene, Zimmer, Bool)] = [
            ("Zimmer Nacht", .zimmer, zimmer, true),
            ("Klassenzimmer Nacht", .schule, Zimmer(ort: .schule), true),
            ("Draußen Regen Nacht", .draussen(wetter: .regen, nacht: true), Zimmer(), false),
            ("Unterwegs Schnee", .unterwegs(wetter: .schnee, nacht: false), Zimmer(), false),
            ("Abteil Regen", .abteil(wetter: .regen, nacht: false), Zimmer(), false),
        ]
        var zellen: [(titel: String, ansicht: AnyView)] = []
        for (titel, szene, z, nacht) in faelle {
            for animiert in [false, true] {
                let ansicht = ProfilSzeneHintergrund(szene: szene, zimmer: z, nacht: nacht, animiert: animiert).frame(width: 390, height: 430).clipped()
                zellen.append((titel: "\(titel), \(animiert ? "vier Ebenen" : "eine Leinwand")", ansicht: AnyView(ansicht)))
            }
        }
        RenderTafel.speichern("profil-ebenen", spalten: 4, zellen: zellen)
    }

    /// Posters and photo frames on one wall (before Brief R big posters covered frames 1 and 2,
    /// and two wide left posters frame 0). The last cell has no frames: posters stay where they were.
    func testPosterUndRahmen() {
        let rahmen = (0..<Zimmer.rahmenPlaetze).map { Zimmer.Rahmen(slot: $0, medienId: "r\($0)") }
        func wand(_ titel: String, rechts: Int, links: Int = 0, bett: Int = 0, mitRahmen: Bool = true) -> (titel: String, ansicht: AnyView) {
            let z = Zimmer(bett: 5, wand: 6, boden: 5, deko: ["ledWeiss", "teppichSchwarz"], rahmen: mitRahmen ? rahmen : [],
                           poster: rechts, posterLinks: links, posterBett: bett)
            return (titel: titel, ansicht: AnyView(ProfilSzeneHintergrund(szene: .zimmer, zimmer: z, nacht: false, animiert: false).frame(width: 390, height: 430)))
        }
        let buero = Zimmer(wand: 5, boden: 1, deko: ["buecherregal", "stehlampe", "kaffeemaschine"], rahmen: rahmen, poster: 8, tisch: 3)
        let bueroZelle = (titel: "Büro, Rahmen + Porsche über dem Regal",
                          ansicht: AnyView(ProfilSzeneHintergrund(szene: .arbeit, zimmer: buero, nacht: false, animiert: false).frame(width: 390, height: 430)))
        let zellen = [
            bueroZelle,
            wand("Rahmen + SVJ (breit)", rechts: 13),
            wand("Rahmen + Iceman (quadratisch)", rechts: 11),
            wand("Rahmen + Jordan (hoch)", rechts: 3),
            wand("Rahmen + zwei Poster links", rechts: 0, links: 18, bett: 19),
            wand("Rahmen + drei Poster", rechts: 13, links: 18, bett: 19),
            wand("Drei Poster ohne Rahmen", rechts: 13, links: 18, bett: 19, mitRahmen: false),
        ]
        RenderTafel.speichern("profil-poster-rahmen", spalten: 3, zellen: zellen)
    }
}
