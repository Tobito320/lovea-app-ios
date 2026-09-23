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

/// `an`: the wrist point, `winkel`: the forearm's direction (radians, 0 = arm hanging straight
/// down), so the band wraps across the wrist. `groesse` scales the whole watch.
func zeichneUhr(_ g: GraphicsContext, id: String, an punkt: CGPoint, winkel: Double = 0, groesse: CGFloat = 1) {
    guard let e = uhrenKatalog[id] else { return }
    zeichneUhr(g, e.stil, band: e.band, gehaeuse: e.gehaeuse, an: punkt, winkel: winkel, groesse: groesse)
}

/// Fix round 1: a band wrapped around the wrist with a small face on top, instead of a floating icon.
func zeichneUhr(_ g: GraphicsContext, _ stil: UhrenStil, band: FigurFarbe, gehaeuse: FigurFarbe, an punkt: CGPoint, winkel: Double = 0, groesse: CGFloat = 1) {
    var h = g
    h.translateBy(x: punkt.x, y: punkt.y)
    h.rotate(by: .radians(winkel))
    h.scaleBy(x: groesse, y: groesse)
    let tinte = Pal.tinte.farbe
    let breit: CGFloat = stil == .fitness ? 6 : 8
    teil(h, box(-9.5, -breit / 2, 19, breit, breit / 2), band, 1.4)
    if stil == .pepsi || stil == .rund && band == Pal.silber {
        for x in [CGFloat(-7), 7] { linie(h, strich(P(x, -breit / 2 + 1), P(x, breit / 2 - 1)), band.kontur.opacity(0.6), 0.8) }
    }
    switch stil {
    case .rund:
        teil(h, kreis(.zero, 5.8), gehaeuse, 1.4)
        h.fill(kreis(.zero, 4), with: .color(Pal.weiss.farbe))
        linie(h, strich(.zero, P(0, -3)), tinte, 1)
        linie(h, strich(.zero, P(2.2, 0.8)), tinte, 1)
    case .eckig:
        teil(h, box(-4.6, -5.4, 9.2, 10.8, 1.5), gehaeuse, 1.4)
        h.fill(box(-3, -3.8, 6, 7.6, 0.8), with: .color(Pal.weiss.farbe))
        linie(h, strich(P(0, -2.6), P(0, 2.6)), tinte, 0.9)
    case .smart:
        teil(h, box(-5, -6, 10, 12, 3), gehaeuse, 1.4)
        h.fill(box(-3.6, -4.6, 7.2, 9.2, 2), with: .color(Pal.himmel.farbe.opacity(0.7)))
    case .digital:
        teil(h, box(-6, -5, 12, 10, 2), gehaeuse, 1.4)
        h.fill(box(-4, -3, 8, 6, 1), with: .color(FigurFarbe(0xB9C4A8).farbe))
        for x in [CGFloat(-2.4), -0.8, 0.8, 2.4] { linie(h, strich(P(x, -1.6), P(x, 1.6)), tinte.opacity(0.7), 0.7) }
    case .fitness:
        teil(h, oval(.zero, 3.6, 5), gehaeuse, 1.2)
        linie(h, strich(P(-1.4, 0.6), P(1.4, -0.8)), Pal.gruen.farbe, 1)
    case .taucher, .pepsi:
        teil(h, kreis(.zero, 6.6), gehaeuse, 1.3)
        if stil == .pepsi {
            let oben = Path { p in p.addArc(center: .zero, radius: 5.2, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false) }
            let unten = Path { p in p.addArc(center: .zero, radius: 5.2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false) }
            linie(h, oben, FigurFarbe(0xC8283F).farbe, 2)
            linie(h, unten, FigurFarbe(0x2C3E9B).farbe, 2)
        } else {
            linie(h, kreis(.zero, 5.2), Pal.dunkel.farbe, 2)
        }
        h.fill(kreis(.zero, 4), with: .color(Pal.dunkel.mal(0.8).farbe))
        linie(h, strich(.zero, P(0, -3)), .white, 1)
        linie(h, strich(.zero, P(2.2, 0.8)), .white, 1)
    }
}
