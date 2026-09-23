import SwiftUI

/// Vector pets for the "tier" shop category (Z-23.3): at least 4 species, standing at the figure's feet.
/// ponytail: full-body only — a peeking half-figure version (e.g. an ear/paw in a corner) is a
/// nice-to-have, add it if the half figure ever needs the pet too.
enum HaustierArt: Sendable { case hund, katze, hase, vogel }

let haustierKatalog: [String: (art: HaustierArt, farbe: FigurFarbe)] = [
    "tier.hund-braun": (.hund, FigurFarbe(0xA96F45)),
    "tier.hund-schwarz": (.hund, FigurFarbe(0x2B2830)),
    "tier.katze-grau": (.katze, FigurFarbe(0x8E8C93)),
    "tier.katze-orange": (.katze, FigurFarbe(0xF08A4B)),
    "tier.hase-weiss": (.hase, FigurFarbe(0xF4F1EE)),
    "tier.vogel-blau": (.vogel, Pal.blau),
]

/// `boden`: where the pet's feet touch the ground. `groesse` scales the whole pet.
func zeichneHaustier(_ g: GraphicsContext, id: String, boden punkt: CGPoint, groesse: CGFloat = 1) {
    guard let e = haustierKatalog[id] else { return }
    var h = g
    h.translateBy(x: punkt.x, y: punkt.y)
    h.scaleBy(x: groesse, y: groesse)
    h.translateBy(x: -punkt.x, y: -punkt.y)
    let f = e.farbe
    for dx in [CGFloat(-8), -2, 6, 12] { linie(h, strich(P(punkt.x + dx, punkt.y - 2), P(punkt.x + dx, punkt.y + 4)), f.kontur, 3) }
    teil(h, oval(P(punkt.x, punkt.y - 12), 16, 12), f)
    teil(h, kreis(P(punkt.x + 14, punkt.y - 24), 10), f)
    switch e.art {
    case .hund:
        for seite in [CGFloat(-1), 1] { teil(h, oval(P(punkt.x + 14 + seite * 9, punkt.y - 32), 3, 6), f.mal(0.8), 1) }
        linie(h, bogen(P(punkt.x - 16, punkt.y - 14), P(punkt.x - 24, punkt.y - 6), P(punkt.x - 22, punkt.y - 16)), f.kontur, 3)
    case .katze:
        for seite in [CGFloat(-1), 1] {
            let ohr = Path { p in
                p.move(to: P(punkt.x + 14 + seite * 7, punkt.y - 32))
                p.addLine(to: P(punkt.x + 14 + seite * 11, punkt.y - 40))
                p.addLine(to: P(punkt.x + 14 + seite * 3, punkt.y - 34))
                p.closeSubpath()
            }
            teil(h, ohr, f, 1)
        }
        linie(h, bogen(P(punkt.x - 16, punkt.y - 10), P(punkt.x - 24, punkt.y - 20), P(punkt.x - 22, punkt.y - 10)), f.kontur, 2.5)
    case .hase:
        for seite in [CGFloat(-1), 1] { teil(h, oval(P(punkt.x + 14 + seite * 4, punkt.y - 42), 3, 10), f.mix(Pal.weiss, 0.2), 1) }
        teil(h, kreis(P(punkt.x - 2, punkt.y - 8), 3), Pal.weiss, 1)
    case .vogel:
        teil(h, oval(P(punkt.x + 22, punkt.y - 25), 3, 2), Pal.gelb, 1)
        linie(h, bogen(P(punkt.x - 4, punkt.y - 16), P(punkt.x - 16, punkt.y - 8), P(punkt.x - 14, punkt.y - 18)), f.kontur, 3)
    }
    h.fill(kreis(P(punkt.x + 18, punkt.y - 25), 1.3), with: .color(Pal.tinte.farbe))
}
