import SwiftUI

/// Vector watches for the "uhr" shop category (Z-23.3) and the free everyday watches (Z-39.3), drawn on the wrist.
enum UhrenStil: Sendable { case rund, eckig, smart, digital, fitness, taucher, pepsi }

let uhrenKatalog: [String: (stil: UhrenStil, band: FigurFarbe, gehaeuse: FigurFarbe)] = [
    "uhr.guess": (.rund, FigurFarbe(0x2B2830), Pal.silber),
    "uhr.fossil": (.rund, FigurFarbe(0x7A5234), Pal.gold),
    "uhr.rolex": (.rund, FigurFarbe(0x8E8C93), Pal.gold),
    "uhr.rolex-submariner": (.taucher, Pal.dunkel, Pal.gold),
    "uhr.cartier": (.eckig, Pal.silber, Pal.silber),
    "uhr.cartier-tank": (.eckig, FigurFarbe(0x2B2830), Pal.gold),
    "uhr.apple-style": (.smart, FigurFarbe(0x2B2830), Pal.dunkel),
    "uhr.smart-sport": (.smart, FigurFarbe(0x3F7D52), Pal.dunkel),
    // Z-39.2 Luxus
    "uhr.rolex-gmt": (.pepsi, Pal.silber, Pal.silber),
]

/// Z-39.3: free everyday watches. Index + 1 = the stored `uhrAlltag` value (0 = none).
let alltagsUhren: [(name: String, stil: UhrenStil, band: FigurFarbe, gehaeuse: FigurFarbe)] = [
    ("Digitaluhr", .digital, FigurFarbe(0x2B2830), FigurFarbe(0x3B3A44)),
    ("Fitnessband", .fitness, FigurFarbe(0x2B2830), FigurFarbe(0x2B2830)),
    ("Stoffband-Uhr", .rund, FigurFarbe(0x2C3E6B), Pal.silber),
]

/// `an`: the wrist point (the drawing hand near the free arm). `groesse` scales the whole watch.
func zeichneUhr(_ g: GraphicsContext, id: String, an punkt: CGPoint, groesse: CGFloat = 1) {
    guard let e = uhrenKatalog[id] else { return }
    zeichneUhr(g, e.stil, band: e.band, gehaeuse: e.gehaeuse, an: punkt, groesse: groesse)
}

func zeichneUhr(_ g: GraphicsContext, _ stil: UhrenStil, band: FigurFarbe, gehaeuse: FigurFarbe, an punkt: CGPoint, groesse: CGFloat = 1) {
    var h = g
    h.translateBy(x: punkt.x, y: punkt.y)
    h.scaleBy(x: groesse, y: groesse)
    let breit: CGFloat = stil == .fitness ? 3.5 : 5
    linie(h, strich(P(-10, -26), P(0, -7)), band.farbe, breit)
    linie(h, strich(P(10, -26), P(0, -7)), band.farbe, breit)
    let tinte = Pal.tinte.farbe
    switch stil {
    case .rund:
        teil(h, kreis(.zero, 11), gehaeuse, 2.5)
        linie(h, strich(.zero, P(0, -7)), tinte, 2)
        linie(h, strich(.zero, P(5, 2)), tinte, 2)
    case .eckig:
        teil(h, box(-9, -9, 18, 18, 3), gehaeuse, 2.5)
        linie(h, strich(P(0, -6), P(0, 6)), tinte, 1.5)
    case .smart:
        teil(h, box(-9, -9, 18, 18, 5), gehaeuse, 2.5)
        h.fill(box(-6, -6, 12, 12, 2), with: .color(Pal.himmel.farbe.opacity(0.6)))
    case .digital:
        teil(h, box(-10, -8, 20, 16, 3), gehaeuse, 2.5)
        h.fill(box(-6.5, -4.5, 13, 9, 1.5), with: .color(FigurFarbe(0xB9C4A8).farbe))
        for x in [CGFloat(-3.5), -1, 1.5, 4] { linie(h, strich(P(x, -2.5), P(x, 2.5)), tinte.opacity(0.7), 1.1) }
    case .fitness:
        teil(h, oval(.zero, 6.5, 9), gehaeuse, 2)
        linie(h, strich(P(-2.5, 1), P(2.5, -1.5)), Pal.gruen.farbe, 1.6)
    case .taucher, .pepsi:
        // Rolex: steel/gold case, rotating bezel (black, or red-blue "Pepsi"), dark dial, luminous hands.
        teil(h, kreis(.zero, 12), gehaeuse, 2.2)
        if stil == .pepsi {
            let oben = Path { p in p.addArc(center: .zero, radius: 9.2, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false) }
            let unten = Path { p in p.addArc(center: .zero, radius: 9.2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false) }
            linie(h, oben, FigurFarbe(0xC8283F).farbe, 3.6)
            linie(h, unten, FigurFarbe(0x2C3E9B).farbe, 3.6)
        } else {
            linie(h, kreis(.zero, 9.2), Pal.dunkel.farbe, 3.6)
        }
        h.fill(kreis(.zero, 7), with: .color(Pal.dunkel.mal(0.8).farbe))
        h.fill(kreis(P(0, -9.2), 1.2), with: .color(.white))
        linie(h, strich(.zero, P(0, -5.5)), .white, 1.6)
        linie(h, strich(.zero, P(4, 1.5)), .white, 1.6)
    }
}
