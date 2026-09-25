import SwiftUI

/// Vector bags for the "tasche" shop category (Z-23.3), drawn near the free hand.
enum TaschenStil: Sendable { case shopper, rucksack, clutch, koffer, klappe, speedy }

/// Z-39.2: brand cues on the bag body. `web` Gucci green-red-green, `monogramm` LV, `oblique` Dior,
/// `dreieck` Prada, `gesteppt` Chanel quilting with CC.
enum TaschenMuster: Sendable { case keins, web, monogramm, oblique, dreieck, gesteppt }

/// Maps a purchased bag's shop id to a drawn silhouette + color. New catalog ids need one line
/// here (`ShopKatalogTests.testAlleTeileHabenEineZeichnung` catches a missing entry).
let taschenKatalog: [String: (stil: TaschenStil, farbe: FigurFarbe, muster: TaschenMuster)] = [
    "tasche.stoffbeutel": (.shopper, FigurFarbe(0xD8C3A0), .keins),
    "tasche.canvas-tote": (.shopper, FigurFarbe(0xEFC09B), .keins),
    "tasche.guess-tasche": (.shopper, FigurFarbe(0x2B2830), .keins),
    "tasche.rucksack": (.rucksack, FigurFarbe(0x4B6C98), .keins),
    "tasche.prada-rucksack": (.rucksack, FigurFarbe(0x2B2830), .dreieck),
    "tasche.gucci-tasche": (.shopper, FigurFarbe(0xB5552B), .web),
    "tasche.dior-clutch": (.clutch, FigurFarbe(0xF4F1EE), .oblique),
    "tasche.lv-koffer": (.koffer, FigurFarbe(0x7A5234), .monogramm),
    "tasche.chanel-classic": (.klappe, FigurFarbe(0x2B2830), .gesteppt),
    "tasche.lv-speedy": (.speedy, FigurFarbe(0x6B4630), .monogramm),
]

/// `an`: where the bag hangs from — the free hand in the half figure, the same hand full-body.
/// `groesse` scales the whole drawing (1 in the half figure, ~0.66 mapped onto the full-body torso).
func zeichneTasche(_ g: GraphicsContext, id: String, an punkt: CGPoint, groesse: CGFloat = 1) {
    guard let e = taschenKatalog[id] else { return }
    var h = g
    h.translateBy(x: punkt.x, y: punkt.y)
    h.scaleBy(x: groesse, y: groesse)
    let f = e.farbe
    let koerper: Path
    switch e.stil {
    case .shopper:
        linie(h, bogen(P(-6, -8), P(6, -8), P(0, -20)), f.kontur, 3)
        koerper = box(-11, -8, 22, 20, 5)
    case .rucksack:
        koerper = box(-10, -16, 20, 28, 7)
    case .clutch:
        koerper = box(-12, -6, 24, 14, 4)
    case .koffer:
        koerper = box(-10, -12, 20, 24, 4)
    case .klappe:
        linie(h, bogen(P(-9, -6), P(9, -6), P(0, -24)), Pal.gold.farbe, 1.6)
        koerper = box(-11, -6, 22, 16, 3)
    case .speedy:
        linie(h, bogen(P(-7, -6), P(7, -6), P(0, -18)), f.kontur, 3)
        koerper = box(-13, -6, 26, 17, 8)
    }
    teil(h, koerper, f, 2.5)
    var innen = h
    innen.clip(to: koerper)
    muster(innen, e.muster, f)
    switch e.stil {
    case .rucksack:
        teil(h, box(-5, -11, 10, 9, 3), f.mal(0.85), 1.5)
    case .clutch:
        teil(h, kreis(P(0, -6), 1.8), Pal.gold, 1)
    case .koffer:
        linie(h, strich(P(-10, -2), P(10, -2)), f.kontur, 1.5)
    case .klappe:
        linie(h, bogen(P(-11, 0), P(11, 0), P(0, 4)), f.kontur, 1.5)
        chanelCC(h, P(0, 2), 2.2)
    default:
        break
    }
}

/// Brand pattern inside the bag body (`h` is clipped to it).
private func muster(_ h: GraphicsContext, _ m: TaschenMuster, _ f: FigurFarbe) {
    switch m {
    case .keins:
        break
    case .web:
        h.fill(box(-20, -1, 40, 6), with: .color(FigurFarbe(0x1F7A45).farbe))
        h.fill(box(-20, 1, 40, 2), with: .color(FigurFarbe(0xC8283F).farbe))
    case .monogramm:
        let gold = FigurFarbe(0xD8B46A).farbe
        for y in stride(from: CGFloat(-16), through: 12, by: 6) {
            for x in stride(from: CGFloat(-12), through: 12, by: 6) {
                let versatz: CGFloat = Int((y + 16) / 6) % 2 == 0 ? 0 : 3
                h.fill(funkelKlein(P(x + versatz, y)), with: .color(gold))
            }
        }
    case .oblique:
        for x in stride(from: CGFloat(-24), through: 16, by: 5) {
            linie(h, strich(P(x, 12), P(x + 12, -12)), f.kontur.opacity(0.35), 1.2)
        }
    case .dreieck:
        let d = Path { p in
            p.move(to: P(-4, -4))
            p.addLine(to: P(4, -4))
            p.addLine(to: P(0, 2))
            p.closeSubpath()
        }
        teil(h, d, Pal.silber, 0.8)
    case .gesteppt:
        for x in stride(from: CGFloat(-24), through: 16, by: 5) {
            linie(h, strich(P(x, 12), P(x + 10, -8)), f.mix(Pal.weiss, 0.25).farbe, 0.9)
            linie(h, strich(P(x + 10, 12), P(x, -8)), f.mix(Pal.weiss, 0.25).farbe, 0.9)
        }
    }
}

/// Four-pointed LV flower, tiny.
private func funkelKlein(_ c: CGPoint) -> Path {
    Path { p in
        p.move(to: P(c.x, c.y - 1.8))
        p.addQuadCurve(to: P(c.x + 1.8, c.y), control: c)
        p.addQuadCurve(to: P(c.x, c.y + 1.8), control: c)
        p.addQuadCurve(to: P(c.x - 1.8, c.y), control: c)
        p.addQuadCurve(to: P(c.x, c.y - 1.8), control: c)
        p.closeSubpath()
    }
}

/// Chanel's two interlocking C's (back to back), gold, radius `r`.
func chanelCC(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, farbe: FigurFarbe = Pal.gold) {
    let links = Path { p in p.addArc(center: P(c.x - r * 0.45, c.y), radius: r, startAngle: .degrees(230), endAngle: .degrees(130), clockwise: false) }
    let rechts = Path { p in p.addArc(center: P(c.x + r * 0.45, c.y), radius: r, startAngle: .degrees(50), endAngle: .degrees(310), clockwise: false) }
    for bogenC in [links, rechts] { linie(g, bogenC, farbe.farbe, max(1, r * 0.45)) }
}
