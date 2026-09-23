import SwiftUI

/// Vector watches for the "uhr" shop category (Z-23.3), drawn on the wrist.
enum UhrenStil: Sendable { case rund, eckig, smart }

let uhrenKatalog: [String: (stil: UhrenStil, band: FigurFarbe, gehaeuse: FigurFarbe)] = [
    "uhr.guess": (.rund, FigurFarbe(0x2B2830), Pal.silber),
    "uhr.fossil": (.rund, FigurFarbe(0x7A5234), Pal.gold),
    "uhr.rolex": (.rund, FigurFarbe(0x8E8C93), Pal.gold),
    "uhr.rolex-submariner": (.rund, Pal.dunkel, Pal.gold),
    "uhr.cartier": (.eckig, Pal.silber, Pal.silber),
    "uhr.cartier-tank": (.eckig, FigurFarbe(0x2B2830), Pal.gold),
    "uhr.apple-style": (.smart, FigurFarbe(0x2B2830), Pal.dunkel),
    "uhr.smart-sport": (.smart, FigurFarbe(0x3F7D52), Pal.dunkel),
]

/// `an`: the wrist point (the drawing hand near the free arm). `groesse` scales the whole watch.
func zeichneUhr(_ g: GraphicsContext, id: String, an punkt: CGPoint, groesse: CGFloat = 1) {
    guard let e = uhrenKatalog[id] else { return }
    var h = g
    h.translateBy(x: punkt.x, y: punkt.y)
    h.scaleBy(x: groesse, y: groesse)
    h.translateBy(x: -punkt.x, y: -punkt.y)
    linie(h, strich(P(punkt.x - 10, punkt.y - 26), P(punkt.x, punkt.y - 7)), e.band.farbe, 5)
    linie(h, strich(P(punkt.x + 10, punkt.y - 26), P(punkt.x, punkt.y - 7)), e.band.farbe, 5)
    switch e.stil {
    case .rund:
        teil(h, kreis(P(punkt.x, punkt.y), 11), e.gehaeuse, 2.5)
        linie(h, strich(P(punkt.x, punkt.y), P(punkt.x, punkt.y - 7)), Pal.tinte.farbe, 2)
        linie(h, strich(P(punkt.x, punkt.y), P(punkt.x + 5, punkt.y + 2)), Pal.tinte.farbe, 2)
    case .eckig:
        teil(h, box(punkt.x - 9, punkt.y - 9, 18, 18, 3), e.gehaeuse, 2.5)
        linie(h, strich(P(punkt.x, punkt.y - 6), P(punkt.x, punkt.y + 6)), Pal.tinte.farbe, 1.5)
    case .smart:
        teil(h, box(punkt.x - 9, punkt.y - 9, 18, 18, 5), e.gehaeuse, 2.5)
        h.fill(box(punkt.x - 6, punkt.y - 6, 12, 12, 2), with: .color(Pal.himmel.farbe.opacity(0.6)))
    }
}
