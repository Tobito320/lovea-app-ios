import SwiftUI

/// Vector bags for the "tasche" shop category (Z-23.3), drawn near the free hand.
enum TaschenStil: Sendable { case shopper, rucksack, clutch, koffer }

/// Maps a purchased bag's shop id to a drawn silhouette + color. New catalog ids need one line
/// here (`ShopKatalogTests.testAlleTeileHabenEineZeichnung` catches a missing entry).
let taschenKatalog: [String: (stil: TaschenStil, farbe: FigurFarbe)] = [
    "tasche.stoffbeutel": (.shopper, FigurFarbe(0xD8C3A0)),
    "tasche.canvas-tote": (.shopper, FigurFarbe(0xEFC09B)),
    "tasche.guess-tasche": (.shopper, FigurFarbe(0x2B2830)),
    "tasche.rucksack": (.rucksack, FigurFarbe(0x4B6C98)),
    "tasche.prada-rucksack": (.rucksack, FigurFarbe(0x2B2830)),
    "tasche.gucci-tasche": (.shopper, FigurFarbe(0xB5552B)),
    "tasche.dior-clutch": (.clutch, FigurFarbe(0xF4F1EE)),
    "tasche.lv-koffer": (.koffer, FigurFarbe(0x7A5234)),
]

/// `an`: where the bag hangs from — the free hand in the half figure, the same hand full-body.
/// `groesse` scales the whole drawing (1 in the half figure, ~0.66 mapped onto the full-body torso).
func zeichneTasche(_ g: GraphicsContext, id: String, an punkt: CGPoint, groesse: CGFloat = 1) {
    guard let e = taschenKatalog[id] else { return }
    var h = g
    h.translateBy(x: punkt.x, y: punkt.y)
    h.scaleBy(x: groesse, y: groesse)
    h.translateBy(x: -punkt.x, y: -punkt.y)
    let f = e.farbe
    switch e.stil {
    case .shopper:
        let henkel = bogen(P(punkt.x - 6, punkt.y - 8), P(punkt.x + 6, punkt.y - 8), P(punkt.x, punkt.y - 20))
        linie(h, henkel, f.kontur, 3)
        teil(h, box(punkt.x - 11, punkt.y - 8, 22, 20, 5), f, 2.5)
    case .rucksack:
        teil(h, box(punkt.x - 10, punkt.y - 16, 20, 28, 7), f, 2.5)
        teil(h, box(punkt.x - 5, punkt.y - 11, 10, 9, 3), f.mal(0.85), 1.5)
    case .clutch:
        teil(h, box(punkt.x - 12, punkt.y - 6, 24, 14, 4), f, 2.5)
        teil(h, kreis(P(punkt.x, punkt.y - 6), 1.8), Pal.gold, 1)
    case .koffer:
        teil(h, box(punkt.x - 10, punkt.y - 12, 20, 24, 4), f, 2.5)
        linie(h, strich(P(punkt.x - 10, punkt.y - 2), P(punkt.x + 10, punkt.y - 2)), f.kontur, 1.5)
    }
}
