import SwiftUI

/// Vector pets for the "tier" shop category (Z-23.3): at least 4 species, standing next to the figure.
/// p48: each species is drawn in detail in its own local space (feet on y 0, facing right), then placed
/// and mirrored by `zeichneHaustier`. The full body shows it beside the feet, the half figure in its lower corner.
enum HaustierArt: Sendable { case hund, katze, hase, vogel }

let haustierKatalog: [String: (art: HaustierArt, farbe: FigurFarbe)] = [
    "tier.hund-braun": (.hund, FigurFarbe(0xA96F45)),
    "tier.hund-schwarz": (.hund, FigurFarbe(0x2B2830)),
    "tier.katze-grau": (.katze, FigurFarbe(0x8E8C93)),
    "tier.katze-orange": (.katze, FigurFarbe(0xF08A4B)),
    "tier.hase-weiss": (.hase, FigurFarbe(0xF4F1EE)),
    "tier.vogel-blau": (.vogel, Pal.blau),
]

/// `boden`: where the pet's feet touch the ground. `groesse` scales the whole pet (the bird is drawn
/// smaller than the rest, so it gets a bit extra). `nachLinks`: the pet looks to the left (towards the figure
/// when it stands on the right); `false` looks right.
func zeichneHaustier(_ g: GraphicsContext, id: String, boden punkt: CGPoint, groesse: CGFloat = 1, nachLinks: Bool = true) {
    guard let e = haustierKatalog[id] else { return }
    var h = g
    let k = groesse * (e.art == .vogel ? 1.25 : 1)
    h.translateBy(x: punkt.x, y: punkt.y)
    h.scaleBy(x: nachLinks ? -k : k, y: k)
    let schattenBreite: CGFloat
    switch e.art {
    case .hund: schattenBreite = 31
    case .katze, .hase: schattenBreite = 19
    case .vogel: schattenBreite = 12
    }
    h.fill(oval(P(0, 0.5), schattenBreite, 3.4), with: .color(.black.opacity(0.15)))
    switch e.art {
    case .hund: hund(h, e.farbe)
    case .katze: katze(h, e.farbe)
    case .hase: hase(h, e.farbe)
    case .vogel: vogel(h, e.farbe)
    }
}

/// `p` rotated by `grad` degrees around `c`.
private func kippe(_ p: Path, um c: CGPoint, grad: Double) -> Path {
    let t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: grad * .pi / 180).translatedBy(x: -c.x, y: -c.y)
    return p.applying(t)
}

private func augenPunkt(_ h: GraphicsContext, _ c: CGPoint, _ r: CGFloat) {
    h.fill(kreis(c, r), with: .color(Pal.tinte.farbe))
    h.fill(kreis(P(c.x + r * 0.35, c.y - r * 0.4), r * 0.36), with: .color(.white))
}

// MARK: - Dog

/// Standing dog, side view: floppy ear, light snout and chest, collar with a tag, tongue.
private func hund(_ h: GraphicsContext, _ f: FigurFarbe) {
    let dunkel = f.r + f.g + f.b < 0.7
    let hell = dunkel ? FigurFarbe(0xB07A4F) : f.mix(Pal.weiss, 0.55)
    let schwanz = bogen(P(-24, -28), P(-36, -44), P(-38, -31))
    linie(h, schwanz, f.kontur, 7.4)
    linie(h, schwanz, f.farbe, 4.8)
    // Legs sit behind the body so its outline covers their tops; far legs are a shade darker.
    for x in [CGFloat(-16), 12] {
        teil(h, box(x - 3.2, -18, 6.4, 16, 3), f.mal(0.78), 2)
        teil(h, oval(P(x + 0.9, -1.8), 4.6, 2.6), hell.mal(0.85), 1.6)
    }
    for x in [CGFloat(-10), 18] {
        teil(h, box(x - 3.4, -18, 6.8, 16, 3), f, 2)
        teil(h, oval(P(x + 0.9, -1.8), 4.8, 2.7), hell, 1.6)
    }
    let koerper = oval(P(-2, -26), 26, 13)
    teil(h, koerper, f, 2.4)
    var innen = h
    innen.clip(to: koerper)
    innen.fill(oval(P(-2, -12), 29, 7), with: .color(f.mal(0.82).farbe))
    innen.fill(oval(P(17, -22), 10, 9), with: .color(hell.farbe))
    innen.fill(oval(P(-6, -36), 19, 4), with: .color(.white.opacity(0.14)))
    var fell = Path()
    for x in stride(from: CGFloat(-20), through: 8, by: 6) {
        fell.move(to: P(x, -32))
        fell.addLine(to: P(x + 2.4, -28.6))
    }
    innen.stroke(fell, with: .color(f.mal(0.7).farbe.opacity(0.7)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    // Head and snout are one piece.
    let kopf = oval(P(25, -42), 11.5, 10.5)
    let schnauze = oval(P(34.5, -38.5), 8.5, 5.6)
    verbunden(h, [kopf, schnauze], f, 2.4)
    h.fill(schnauze, with: .color(hell.farbe))
    h.fill(oval(P(37, -32.8), 2, 2.9), with: .color(FigurFarbe(0xF08A9B).farbe))
    h.fill(oval(P(42, -41), 2.9, 2.3), with: .color(Pal.tinte.farbe))
    h.fill(oval(P(41.2, -41.8), 0.9, 0.6), with: .color(.white.opacity(0.7)))
    linie(h, bogen(P(41.5, -36.6), P(33.5, -35.4), P(37.8, -33.4)), Pal.tinte.farbe.opacity(0.85), 0.9)
    if dunkel { h.fill(oval(P(28.6, -49), 2.2, 1.4), with: .color(hell.farbe)) }
    augenPunkt(h, P(28.8, -45), 2.1)
    // Collar over the neck, with a round tag.
    let halsband = bogen(P(15.5, -37), P(26.5, -31.5), P(18, -29))
    linie(h, halsband, FigurFarbe(0x8E1C2E).farbe, 4.6)
    linie(h, halsband, FigurFarbe(0xC8283F).farbe, 3.2)
    teil(h, kreis(P(21.8, -28), 2.3), Pal.gold, 1)
    let ohr = Path { p in
        p.move(to: P(19, -50))
        p.addQuadCurve(to: P(13.5, -31), control: P(8, -47))
        p.addQuadCurve(to: P(24, -42), control: P(22, -31))
        p.closeSubpath()
    }
    teil(h, ohr, f.mal(0.8), 2)
}

// MARK: - Cat

/// Sitting cat, front view: pink inner ears, slit pupils, whiskers, tabby stripes, collar with a bell, curled tail.
private func katze(_ h: GraphicsContext, _ f: FigurFarbe) {
    let warm = f.r - f.b > 0.3
    let iris = warm ? FigurFarbe(0x7BC47F) : FigurFarbe(0xE8B93B)
    let streifen = f.mal(0.68).farbe
    let rosa = FigurFarbe(0xF2A6B0)
    let schwanz = Path { p in
        p.move(to: P(10, -3))
        p.addCurve(to: P(30, -32), control1: P(36, -1), control2: P(40, -19))
    }
    linie(h, schwanz, f.kontur, 8.4)
    linie(h, schwanz, f.farbe, 5.8)
    h.stroke(schwanz, with: .color(streifen), style: StrokeStyle(lineWidth: 5.8, dash: [1.4, 5.2], dashPhase: 3))
    let torso = oval(P(0, -19), 13.5, 18)
    verbunden(h, [oval(P(-10.5, -9), 9, 9), oval(P(10.5, -9), 9, 9), torso], f, 2.4)
    var innen = h
    innen.clip(to: torso)
    innen.fill(oval(P(0, -22), 7.5, 12), with: .color(f.mix(Pal.weiss, 0.6).farbe))
    var rippen = Path()
    for y in [CGFloat(-27), -21, -15] {
        rippen.move(to: P(-14, y))
        rippen.addLine(to: P(-8.6, y + 1.6))
        rippen.move(to: P(14, y))
        rippen.addLine(to: P(8.6, y + 1.6))
    }
    innen.stroke(rippen, with: .color(streifen), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
    for s: CGFloat in [-1, 1] {
        linie(h, bogen(P(s * 15, -14), P(s * 9, -5), P(s * 14, -6.5)), streifen, 1.2)
        teil(h, oval(P(s * 5.6, -3), 4.4, 3), f.mix(Pal.weiss, 0.45), 1.6)
    }
    // Ears behind the head, pink inside.
    for s: CGFloat in [-1, 1] {
        let ohr = Path { p in
            p.move(to: P(s * 13.5, -50))
            p.addLine(to: P(s * 11, -64.5))
            p.addLine(to: P(s * 3, -56))
            p.closeSubpath()
        }
        teil(h, ohr, f, 2.2)
        let innenOhr = Path { p in
            p.move(to: P(s * 11.2, -52.5))
            p.addLine(to: P(s * 10.2, -60.5))
            p.addLine(to: P(s * 5.6, -55.5))
            p.closeSubpath()
        }
        h.fill(innenOhr, with: .color(rosa.farbe))
    }
    let kopf = oval(P(0, -45), 14.5, 12.5)
    teil(h, kopf, f, 2.4)
    var gesicht = h
    gesicht.clip(to: kopf)
    for s: CGFloat in [-1, 1] { gesicht.fill(oval(P(s * 8, -40), 6, 4), with: .color(f.mix(Pal.weiss, 0.5).farbe.opacity(0.7))) }
    var stirn = Path()
    for x in [CGFloat(-3.4), 0, 3.4] {
        stirn.move(to: P(x, -58))
        stirn.addLine(to: P(x * 0.8, -52.5))
    }
    gesicht.stroke(stirn, with: .color(streifen), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
    for s: CGFloat in [-1, 1] {
        let c = P(s * 5.6, -46.5)
        h.fill(oval(c, 3, 3.5), with: .color(iris.farbe))
        h.fill(oval(c, 1, 2.9), with: .color(Pal.tinte.farbe))
        h.fill(kreis(P(c.x + 0.8, c.y - 1.5), 0.65), with: .color(.white))
        linie(h, bogen(P(s * 2.6, -41.6), P(s * 5.6, -41.2), P(s * 4, -40.4)), Pal.tinte.farbe.opacity(0.65), 0.7)
        for i in 0..<3 {
            let dy = CGFloat(i) * 1.6
            linie(h, strich(P(s * 7, -41.4 + dy), P(s * 18, -43.6 + dy * 2.2)), Pal.tinte.farbe.opacity(0.5), 0.55)
        }
    }
    let nase = Path { p in
        p.move(to: P(-1.9, -42.6))
        p.addLine(to: P(1.9, -42.6))
        p.addLine(to: P(0, -40.4))
        p.closeSubpath()
    }
    h.fill(nase, with: .color(FigurFarbe(0xE07088).farbe))
    for s: CGFloat in [-1, 1] { linie(h, bogen(P(0, -40.4), P(s * 3.4, -38.6), P(s * 1.4, -37.8)), Pal.tinte.farbe.opacity(0.7), 0.7) }
    // Collar and bell.
    let halsband = bogen(P(-9.5, -34.5), P(9.5, -34.5), P(0, -30))
    linie(h, halsband, FigurFarbe(0x8E1C2E).farbe, 4)
    linie(h, halsband, FigurFarbe(0xC8283F).farbe, 2.8)
    teil(h, kreis(P(0, -29), 2.4), Pal.gold, 1)
    h.fill(box(-1.6, -29.4, 3.2, 0.7), with: .color(Pal.gold.mal(0.5).farbe))
}

// MARK: - Rabbit

/// Sitting rabbit, front view: tall ears with pink inside, round cheeks, cotton tail, long hind feet.
private func hase(_ h: GraphicsContext, _ f: FigurFarbe) {
    let rosa = FigurFarbe(0xF4B6C0)
    let schwanz = kreis(P(14, -9), 5.4)
    teil(h, schwanz, f, 2)
    h.fill(kreis(P(12.4, -10.6), 1.6), with: .color(.white.opacity(0.7)))
    let ohrenGrad: [(CGFloat, Double)] = [(-6, -8), (6, 8)]
    for (x, grad) in ohrenGrad {
        let mitte = P(x, -60)
        teil(h, kippe(oval(mitte, 4, 13.5), um: P(x, -48), grad: grad), f, 2.2)
        h.fill(kippe(oval(P(x, -59.5), 2.2, 10.2), um: P(x, -48), grad: grad), with: .color(rosa.farbe))
    }
    let torso = oval(P(0, -15), 14, 15)
    teil(h, torso, f, 2.4)
    var innen = h
    innen.clip(to: torso)
    innen.fill(oval(P(0, -13), 8.5, 11), with: .color(f.mal(0.94).farbe))
    for s: CGFloat in [-1, 1] {
        teil(h, oval(P(s * 11, -3.4), 6.4, 3.2), f, 1.8)
        teil(h, oval(P(s * 4.6, -3), 3.6, 3.2), f.mix(Pal.weiss, 0.1), 1.6)
    }
    let kopf = oval(P(0, -36), 11.5, 10.5)
    teil(h, kopf, f, 2.4)
    for s: CGFloat in [-1, 1] {
        h.fill(kreis(P(s * 7, -32.4), 2.6), with: .color(rosa.farbe.opacity(0.5)))
        augenPunkt(h, P(s * 4.8, -38), 1.9)
        for i in 0..<3 {
            let dy = CGFloat(i) * 1.5
            linie(h, strich(P(s * 6.6, -33.2 + dy), P(s * 16.5, -35 + dy * 2.4)), Pal.tinte.farbe.opacity(0.4), 0.55)
        }
    }
    h.fill(oval(P(0, -34.2), 1.9, 1.4), with: .color(rosa.mal(0.85).farbe))
    linie(h, strich(P(0, -33), P(0, -31.6)), Pal.tinte.farbe.opacity(0.6), 0.7)
    linie(h, bogen(P(0, -31.6), P(-2.6, -30.4), P(-1.4, -30.6)), Pal.tinte.farbe.opacity(0.6), 0.7)
    linie(h, bogen(P(0, -31.6), P(2.6, -30.4), P(1.4, -30.6)), Pal.tinte.farbe.opacity(0.6), 0.7)
    h.fill(box(-1, -31.4, 2, 2.2, 0.5), with: .color(.white.opacity(0.9)))
}

// MARK: - Bird

/// Budgie standing on the ground: blue body, pale face, orange beak and feet, wing with feather lines.
private func vogel(_ h: GraphicsContext, _ f: FigurFarbe) {
    let orange = FigurFarbe(0xF2A33C)
    for x in [CGFloat(-2), 4] {
        linie(h, strich(P(x, -9), P(x, -1.2)), orange.mal(0.85).farbe, 1.7)
        linie(h, strich(P(x - 2.4, -0.7), P(x + 2.8, -0.7)), orange.mal(0.85).farbe, 1.5)
    }
    let schwanz = Path { p in
        p.move(to: P(-4, -17))
        p.addLine(to: P(-18, -3))
        p.addLine(to: P(-13, -1))
        p.addLine(to: P(0, -10))
        p.closeSubpath()
    }
    teil(h, schwanz, f.mal(0.78), 1.8)
    linie(h, strich(P(-5, -13), P(-14.5, -4)), f.mix(Pal.weiss, 0.4).farbe.opacity(0.8), 0.8)
    let koerper = oval(P(0, -24), 11.5, 15.5)
    let kopf = kreis(P(3.5, -43), 9.5)
    verbunden(h, [koerper, kopf], f, 2.2)
    var innen = h
    innen.clip(to: koerper)
    innen.fill(oval(P(5.5, -22), 7, 11), with: .color(f.mix(Pal.weiss, 0.32).farbe))
    h.fill(oval(P(6, -42.6), 6.4, 6.8), with: .color(f.mix(Pal.weiss, 0.82).farbe))
    h.fill(kreis(P(2.4, -38.6), 1), with: .color(f.mal(0.55).farbe))
    h.fill(kreis(P(5.6, -37.8), 1), with: .color(f.mal(0.55).farbe))
    let auge = P(8, -45)
    h.fill(kreis(auge, 2.7), with: .color(.white))
    h.fill(kreis(auge, 1.7), with: .color(Pal.tinte.farbe))
    h.fill(kreis(P(auge.x + 0.6, auge.y - 0.7), 0.55), with: .color(.white))
    let schnabel = Path { p in
        p.move(to: P(11.4, -46.5))
        p.addQuadCurve(to: P(17.6, -41.6), control: P(17, -46.6))
        p.addQuadCurve(to: P(11.6, -40.6), control: P(15.4, -39.4))
        p.closeSubpath()
    }
    teil(h, schnabel, orange, 1.2)
    let fluegel = kippe(oval(P(-3.5, -24), 6, 12.5), um: P(-3.5, -24), grad: 10)
    teil(h, fluegel, f.mal(0.74), 1.8)
    for dy in [CGFloat(-5), 0, 5] {
        linie(h, bogen(P(-6.5, -25 + dy), P(-0.5, -22.5 + dy), P(-3, -23 + dy)), f.mix(Pal.weiss, 0.45).farbe.opacity(0.7), 0.8)
    }
}
