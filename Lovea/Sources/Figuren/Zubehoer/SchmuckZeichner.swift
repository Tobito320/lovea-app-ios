import SwiftUI

/// Vector jewelry for the "schmuck" shop category (Z-23.3).
/// ponytail: every schmuck item draws as a necklace at the collar (the figure's most visible
/// jewelry spot) rather than a per-subtype anchor (ring/bracelet); add a wrist anchor if a
/// bracelet-only item is ever needed.
enum SchmuckStil: Sendable { case kette, ketteHerz, kettePerlen, ketteEdelstein }

let schmuckKatalog: [String: (stil: SchmuckStil, farbe: FigurFarbe)] = [
    "schmuck.kette-silber": (.kette, Pal.silber),
    "schmuck.kette-gold": (.kette, Pal.gold),
    "schmuck.cartier-kette": (.ketteHerz, Pal.gold),
    "schmuck.perlenkette": (.kettePerlen, FigurFarbe(0xF4F1EE)),
    "schmuck.tiffany-kette": (.ketteEdelstein, Pal.himmel),
    "schmuck.gold-kette": (.ketteEdelstein, Pal.gold),
]

/// `hals`: the collar point below the chin. `groesse` scales the whole necklace.
func zeichneSchmuck(_ g: GraphicsContext, id: String, hals punkt: CGPoint, groesse: CGFloat = 1) {
    guard let e = schmuckKatalog[id] else { return }
    var h = g
    h.translateBy(x: punkt.x, y: punkt.y)
    h.scaleBy(x: groesse, y: groesse)
    h.translateBy(x: -punkt.x, y: -punkt.y)
    let kette = bogen(P(punkt.x - 14, punkt.y), P(punkt.x + 14, punkt.y), P(punkt.x, punkt.y + 14))
    linie(h, kette, e.farbe.farbe, 2)
    switch e.stil {
    case .kette:
        teil(h, kreis(P(punkt.x, punkt.y + 14), 3), e.farbe, 1)
    case .ketteHerz:
        teil(h, herzPfad(P(punkt.x, punkt.y + 16), 4), Pal.rose, 1)
    case .kettePerlen:
        for dx in stride(from: CGFloat(-14), through: 14, by: 5) {
            teil(h, kreis(P(punkt.x + dx, punkt.y + 10 - abs(dx) * 0.3), 2.2), e.farbe, 1)
        }
    case .ketteEdelstein:
        teil(h, oval(P(punkt.x, punkt.y + 15), 3.5, 4.5), e.farbe, 1)
        h.fill(kreis(P(punkt.x - 1, punkt.y + 13), 1), with: .color(.white.opacity(0.8)))
    }
}
