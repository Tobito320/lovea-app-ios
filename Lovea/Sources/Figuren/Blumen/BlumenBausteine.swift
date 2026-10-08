import SwiftUI

/// p59: vector building blocks for the five bouquets (`Strauss*.swift`). Everything is `Path` and
/// `GraphicsContext` in a 200 x 240 design box, static, no raster images. `fein` switches the
/// fine detail (petal veins, rose spirals, glitter, gypsophila dots) off for tiny sizes: the shapes
/// stay the same, only the specks go, so a bouquet on the wardrobe costs a fraction of the big one.

/// Fixed pseudo random numbers: a bouquet looks the same on every draw and on both phones.
struct BlumenZufall {
    private var s: UInt64

    init(_ seed: UInt64) { s = seed &* 6364136223846793005 &+ 1442695040888963407 }

    mutating func next() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((s >> 33) & 0xFFFFFF) / 16777216
    }

    mutating func zwischen(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * next() }
}

/// Photo pixels -> design box. Each bouquet writes down where the flowers sit in Ahmed's photo and
/// this maps them (`p` for positions, `r` for radii), so the arrangement follows the photo.
struct FotoAbb {
    let ox: CGFloat
    let oy: CGFloat
    let sx: CGFloat
    let sy: CGFloat
    let sr: CGFloat
    let dx: CGFloat
    let dy: CGFloat

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { P((x - ox) * sx + dx, (y - oy) * sy + dy) }
    func r(_ v: CGFloat) -> CGFloat { v * sr }
    func pfad(_ punkte: [(CGFloat, CGFloat)]) -> [CGPoint] { punkte.map { p($0.0, $0.1) } }
}

func blWeg(_ c: CGPoint, _ w: CGFloat, _ l: CGFloat) -> CGPoint { P(c.x + cos(w) * l, c.y + sin(w) * l) }

/// A petal or leaf from `a` (base) to `b` (tip), `w` wide. `rund` 0 = pointed tip, 1 = round tip.
func blumenBlatt(_ a: CGPoint, _ b: CGPoint, breite w: CGFloat, rund: CGFloat = 0.3) -> Path {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let l = max((dx * dx + dy * dy).squareRoot(), 0.001)
    let ux = dx / l
    let uy = dy / l
    func q(_ t: CGFloat, _ k: CGFloat) -> CGPoint {
        P(a.x + ux * l * t - uy * w * k, a.y + uy * l * t + ux * w * k)
    }
    let t2 = 0.72 + 0.26 * rund
    let k2 = 0.55 + 0.35 * rund
    return Path { p in
        p.move(to: a)
        p.addCurve(to: b, control1: q(0.18, 1.25), control2: q(t2, k2))
        p.addCurve(to: a, control1: q(t2, -k2), control2: q(0.18, -1.25))
        p.closeSubpath()
    }
}

/// `n` petals around `c`, each with a gradient from its base (`von`) to its tip (`bis`).
func blumenKranz(_ g: GraphicsContext, _ c: CGPoint, n: Int, innen: CGFloat, aussen: CGFloat, breite: CGFloat, start: CGFloat,
                 rund: CGFloat, von: FigurFarbe, bis: FigurFarbe, rand: Color?, randBreite: CGFloat = 0.4) {
    for i in 0..<n {
        let w = start + CGFloat(i) * 2 * CGFloat.pi / CGFloat(n)
        let a = blWeg(c, w, innen)
        let b = blWeg(c, w, aussen)
        let pf = blumenBlatt(a, b, breite: breite, rund: rund)
        g.fill(pf, with: .linearGradient(Gradient(colors: [von.farbe, bis.farbe]), startPoint: a, endPoint: b))
        if let rand { g.stroke(pf, with: .color(rand), style: StrokeStyle(lineWidth: randBreite, lineJoin: .round)) }
    }
}

private func blumenSchatten(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, _ deckung: Double = 0.16) {
    g.fill(kreis(P(c.x + r * 0.07, c.y + r * 0.12), r * 0.93), with: .color(.black.opacity(deckung)))
}

private func blumenPunkt(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, _ f: Color) {
    g.fill(kreis(c, max(r, 0.12)), with: .color(f))
}

// MARK: - Flowers

/// Rose seen from the front: rings of rounded petals, a spiral in the heart. `rand` tints the edge
/// of the two outer rings (two-tone roses).
func blumeRose(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, hell: FigurFarbe, dunkel: FigurFarbe, rand: FigurFarbe? = nil,
               winkel: CGFloat = 0, fein: Bool = true) {
    blumenSchatten(g, c, r, 0.2)
    let ringe: [(n: Int, bis: CGFloat, w: CGFloat, rund: CGFloat)] = fein
        ? [(6, 1.0, 0.52, 0.9), (5, 0.8, 0.46, 0.85), (4, 0.6, 0.4, 0.8), (3, 0.4, 0.32, 0.7)]
        : [(5, 1.0, 0.55, 0.9), (4, 0.62, 0.42, 0.8)]
    for (k, e) in ringe.enumerated() {
        let t = CGFloat(k) / CGFloat(max(ringe.count - 1, 1))
        let ton = hell.mix(dunkel, 0.15 + 0.6 * t)
        var kante = ton.mal(0.72).farbe.opacity(0.75)
        if k < 2, let rand { kante = rand.farbe }
        blumenKranz(g, c, n: e.n, innen: r * 0.04, aussen: r * e.bis, breite: r * e.w, start: winkel + CGFloat(k) * 0.9 + 0.3,
                    rund: e.rund, von: ton.mix(dunkel, 0.45), bis: ton.mix(Pal.weiss, 0.16), rand: kante, randBreite: max(r * 0.035, 0.3))
    }
    guard fein else {
        blumenPunkt(g, c, r * 0.12, dunkel.mal(0.8).farbe)
        return
    }
    let m = P(c.x + r * 0.03, c.y - r * 0.02)
    for k in 0..<3 {
        let a0 = Double(winkel) + Double(k) * 1.9
        var sp = Path()
        sp.addArc(center: m, radius: r * (0.24 - 0.06 * CGFloat(k)), startAngle: .radians(a0), endAngle: .radians(a0 + 4.2), clockwise: false)
        g.stroke(sp, with: .color(dunkel.mal(0.6).farbe.opacity(0.85)), style: StrokeStyle(lineWidth: max(r * 0.045, 0.3), lineCap: .round))
    }
    var licht = Path()
    licht.addArc(center: c, radius: r * 0.9, startAngle: .radians(Double(winkel) + 3.6), endAngle: .radians(Double(winkel) + 4.5), clockwise: false)
    g.stroke(licht, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: max(r * 0.04, 0.3), lineCap: .round))
}

/// Closed rose bud with its green sepals.
func blumeKnospe(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, hell: FigurFarbe, dunkel: FigurFarbe, winkel: CGFloat = 0) {
    var h = g
    h.translateBy(x: c.x, y: c.y)
    h.rotate(by: .radians(Double(winkel)))
    let gruen = FigurFarbe(0x6E9A4E)
    for dx in [CGFloat(-0.55), 0.55, 0] {
        let pf = blumenBlatt(P(0, r * 0.6), P(dx * r, r * 1.25), breite: r * 0.22, rund: 0.1)
        h.fill(pf, with: .color(gruen.farbe))
        h.stroke(pf, with: .color(gruen.kontur), style: StrokeStyle(lineWidth: max(r * 0.05, 0.3)))
    }
    let koerper = oval(P(0, 0), r * 0.72, r)
    h.fill(koerper, with: .linearGradient(Gradient(colors: [hell.farbe, dunkel.farbe]), startPoint: P(-r * 0.5, -r), endPoint: P(r * 0.5, r)))
    h.stroke(koerper, with: .color(dunkel.mal(0.6).farbe), style: StrokeStyle(lineWidth: max(r * 0.07, 0.3)))
    let wickel = Path { p in
        p.move(to: P(-r * 0.7, -r * 0.1))
        p.addQuadCurve(to: P(r * 0.15, r * 0.9), control: P(-r * 0.1, r * 0.3))
        p.move(to: P(r * 0.7, -r * 0.3))
        p.addQuadCurve(to: P(-r * 0.1, -r * 0.2), control: P(r * 0.3, r * 0.2))
    }
    h.stroke(wickel, with: .color(dunkel.mal(0.55).farbe.opacity(0.8)), style: StrokeStyle(lineWidth: max(r * 0.06, 0.3), lineCap: .round))
}

/// Pompon chrysanthemum: dense rings of narrow, frilled petals, the tips lighter.
func blumeChrysantheme(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, hell: FigurFarbe, dunkel: FigurFarbe, winkel: CGFloat = 0, fein: Bool = true) {
    blumenSchatten(g, c, r)
    let ringe: [(n: Int, bis: CGFloat, w: CGFloat)] = fein
        ? [(15, 1.0, 0.2), (12, 0.84, 0.19), (10, 0.68, 0.18), (8, 0.52, 0.17), (6, 0.36, 0.15)]
        : [(11, 1.0, 0.26), (8, 0.7, 0.22), (5, 0.4, 0.2)]
    for (k, e) in ringe.enumerated() {
        let t = CGFloat(k) / CGFloat(max(ringe.count - 1, 1))
        blumenKranz(g, c, n: e.n, innen: r * 0.05, aussen: r * e.bis, breite: r * e.w, start: winkel + CGFloat(k) * 0.37, rund: 0.55,
                    von: dunkel.mix(hell, 0.2 * t), bis: hell.mix(Pal.weiss, 0.25 - 0.1 * t),
                    rand: dunkel.mal(0.85).farbe.opacity(0.5), randBreite: max(r * 0.025, 0.25))
    }
    blumenPunkt(g, c, r * 0.1, dunkel.mal(0.8).farbe)
}

/// Daisy-like flower: two rings of thin petals around a round disc (aster, daisy, marguerite).
func blumeAster(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, blatt hell: FigurFarbe, grund dunkel: FigurFarbe,
                mitte: FigurFarbe, mitteRand: FigurFarbe, n: Int = 16, breite: CGFloat = 0.1, mittel: CGFloat = 0.24,
                winkel: CGFloat = 0, fein: Bool = true) {
    blumenSchatten(g, c, r, 0.12)
    let rand = dunkel.mal(0.85).farbe.opacity(0.45)
    blumenKranz(g, c, n: n, innen: r * mittel * 0.6, aussen: r, breite: r * breite, start: winkel, rund: 0.25,
                von: dunkel, bis: hell, rand: rand, randBreite: max(r * 0.02, 0.2))
    blumenKranz(g, c, n: n, innen: r * mittel * 0.6, aussen: r * 0.86, breite: r * breite * 1.1,
                start: winkel + CGFloat.pi / CGFloat(n), rund: 0.25, von: dunkel.mix(hell, 0.3), bis: hell, rand: rand,
                randBreite: max(r * 0.02, 0.2))
    let mr = r * mittel
    g.fill(kreis(c, mr), with: .radialGradient(Gradient(colors: [mitte.mix(Pal.weiss, 0.35).farbe, mitte.farbe]), center: P(c.x - mr * 0.2, c.y - mr * 0.2), startRadius: 0, endRadius: mr))
    g.stroke(kreis(c, mr), with: .color(mitteRand.farbe), style: StrokeStyle(lineWidth: max(r * 0.05, 0.3)))
    guard fein else { return }
    for i in 0..<7 {
        let w = CGFloat(i) * 0.9 + winkel
        blumenPunkt(g, blWeg(c, w, mr * 0.5), r * 0.03, mitteRand.mal(0.7).farbe)
    }
}

/// White marguerite with a green-yellow heart (photos 2 and 3).
func blumeMargerite(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, winkel: CGFloat = 0, fein: Bool = true) {
    blumeAster(g, c, r, blatt: FigurFarbe(0xFFFFFF), grund: FigurFarbe(0xD3D7E4), mitte: FigurFarbe(0x9DBB3A), mitteRand: FigurFarbe(0xE6D84C),
               n: 13, breite: 0.17, mittel: 0.27, winkel: winkel, fein: fein)
}

/// Geranium: a main floret with two smaller ones next to it, five broad crumpled petals each.
func blumeGeranie(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, hell: FigurFarbe, dunkel: FigurFarbe, winkel: CGFloat = 0, fein: Bool = true) {
    let teile: [(dx: CGFloat, dy: CGFloat, k: CGFloat)] = [(-0.55, 0.5, 0.5), (0.62, -0.34, 0.55), (0, 0, 1)]
    for t in teile {
        let m = P(c.x + t.dx * r, c.y + t.dy * r)
        let rr = r * t.k
        blumenSchatten(g, m, rr, 0.2)
        blumenKranz(g, m, n: 5, innen: rr * 0.05, aussen: rr, breite: rr * 0.58, start: winkel + t.dx, rund: 1,
                    von: dunkel, bis: hell, rand: dunkel.mal(0.7).farbe.opacity(0.8), randBreite: max(rr * 0.04, 0.3))
        blumenKranz(g, m, n: 5, innen: rr * 0.05, aussen: rr * 0.68, breite: rr * 0.42, start: winkel + t.dx + 0.63, rund: 1,
                    von: dunkel.mal(0.85), bis: hell.mix(dunkel, 0.2), rand: dunkel.mal(0.7).farbe.opacity(0.6), randBreite: max(rr * 0.03, 0.25))
        if fein {
            for i in 0..<5 {
                let w = winkel + t.dx + CGFloat(i) * 1.2566
                let ader = strich(blWeg(m, w, rr * 0.1), blWeg(m, w, rr * 0.82))
                linie(g, ader, dunkel.mal(0.75).farbe.opacity(0.5), max(rr * 0.03, 0.2))
            }
        }
        blumenPunkt(g, m, rr * 0.1, dunkel.mal(0.6).farbe)
    }
}

/// Gerbera: long ray petals in three rings with fine veins, dark disc with a ring of stamens.
func blumeGerbera(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, hell: FigurFarbe, dunkel: FigurFarbe, mitte: FigurFarbe,
                  winkel: CGFloat = 0, fein: Bool = true) {
    blumenSchatten(g, c, r, 0.2)
    let ringe: [(n: Int, bis: CGFloat)] = [(22, 1.0), (18, 0.86), (14, 0.7)]
    for (k, e) in ringe.enumerated() {
        let t = CGFloat(k) / 2
        blumenKranz(g, c, n: e.n, innen: r * 0.18, aussen: r * e.bis, breite: r * 0.1, start: winkel + CGFloat(k) * 0.21, rund: 0.6,
                    von: dunkel.mix(hell, 0.1 * t), bis: hell.mix(Pal.weiss, 0.1 + 0.08 * t),
                    rand: dunkel.mal(0.7).farbe.opacity(0.55), randBreite: max(r * 0.02, 0.2))
    }
    if fein {
        for i in 0..<22 {
            let w = winkel + CGFloat(i) * 2 * CGFloat.pi / 22
            linie(g, strich(blWeg(c, w, r * 0.24), blWeg(c, w, r * 0.9)), hell.mix(Pal.weiss, 0.45).farbe.opacity(0.5), max(r * 0.015, 0.2))
        }
    }
    g.fill(kreis(c, r * 0.22), with: .color(mitte.farbe))
    g.stroke(kreis(c, r * 0.22), with: .color(dunkel.mal(0.6).farbe), style: StrokeStyle(lineWidth: max(r * 0.03, 0.25)))
    guard fein else { return }
    for i in 0..<14 {
        let w = CGFloat(i) * 2 * CGFloat.pi / 14
        blumenPunkt(g, blWeg(c, w, r * 0.16), r * 0.03, hell.mix(Pal.weiss, 0.5).farbe)
    }
    blumenPunkt(g, c, r * 0.07, mitte.mal(0.6).farbe)
}

/// Dark pompon aster with a yellow heart (photo 3).
func blumePompon(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, hell: FigurFarbe, dunkel: FigurFarbe, mitte: FigurFarbe,
                 winkel: CGFloat = 0, fein: Bool = true) {
    blumenSchatten(g, c, r, 0.2)
    let ringe: [(n: Int, bis: CGFloat)] = fein ? [(16, 1.0), (13, 0.82), (10, 0.64)] : [(12, 1.0), (8, 0.7)]
    for (k, e) in ringe.enumerated() {
        blumenKranz(g, c, n: e.n, innen: r * 0.3, aussen: r * e.bis, breite: r * 0.22, start: winkel + CGFloat(k) * 0.4, rund: 0.85,
                    von: dunkel, bis: hell.mix(dunkel, 0.1 * CGFloat(k)), rand: dunkel.mal(0.6).farbe.opacity(0.8), randBreite: max(r * 0.03, 0.25))
    }
    let m = P(c.x + r * 0.04, c.y - r * 0.03)
    g.fill(kreis(m, r * 0.27), with: .color(mitte.farbe))
    g.stroke(kreis(m, r * 0.27), with: .color(dunkel.mal(0.5).farbe), style: StrokeStyle(lineWidth: max(r * 0.05, 0.3)))
    guard fein else { return }
    for i in 0..<6 {
        blumenPunkt(g, blWeg(m, CGFloat(i) * 1.05 + winkel, r * 0.13), r * 0.035, mitte.mal(0.7).farbe)
    }
}

/// Alstroemeria: three broad outer petals, three narrow inner ones with dark streaks, thin stamens.
func blumeAlstroemerie(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, hell: FigurFarbe, dunkel: FigurFarbe, strich farbStrich: FigurFarbe,
                       winkel: CGFloat = 0, fein: Bool = true) {
    blumenSchatten(g, c, r, 0.14)
    blumenKranz(g, c, n: 3, innen: r * 0.05, aussen: r, breite: r * 0.45, start: winkel, rund: 0.4,
                von: dunkel, bis: hell, rand: dunkel.mal(0.75).farbe.opacity(0.7), randBreite: max(r * 0.03, 0.25))
    blumenKranz(g, c, n: 3, innen: r * 0.05, aussen: r * 0.9, breite: r * 0.3, start: winkel + CGFloat.pi / 3, rund: 0.3,
                von: dunkel, bis: hell.mix(Pal.weiss, 0.15), rand: dunkel.mal(0.75).farbe.opacity(0.7), randBreite: max(r * 0.03, 0.25))
    guard fein else { return }
    for k in 0..<3 {
        let w = winkel + CGFloat.pi / 3 + CGFloat(k) * 2 * CGFloat.pi / 3
        for d in [CGFloat(-0.12), 0, 0.12] {
            linie(g, strich(blWeg(c, w + d, r * 0.12), blWeg(c, w + d * 0.5, r * 0.7)), farbStrich.farbe.opacity(0.7), max(r * 0.03, 0.2))
        }
    }
    for i in 0..<5 {
        let w = winkel + CGFloat(i) * 1.3 + 0.4
        let e = blWeg(c, w, r * 0.42)
        linie(g, strich(c, e), farbStrich.mal(0.7).farbe, max(r * 0.02, 0.2))
        blumenPunkt(g, e, r * 0.04, farbStrich.mal(0.55).farbe)
    }
}

/// Open cup flower with a throat: petunia, mallow, cosmos. `staub` adds a ring of coloured stamens.
func blumeKelch(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, n: Int = 5, hell: FigurFarbe, dunkel: FigurFarbe, schlund: FigurFarbe,
                staub: FigurFarbe? = nil, winkel: CGFloat = 0, fein: Bool = true) {
    blumenSchatten(g, c, r, 0.16)
    let rand = dunkel.mal(0.75).farbe.opacity(0.7)
    blumenKranz(g, c, n: n, innen: r * 0.05, aussen: r, breite: r * 0.6, start: winkel, rund: 1, von: dunkel, bis: hell, rand: rand,
                randBreite: max(r * 0.03, 0.25))
    blumenKranz(g, c, n: n, innen: r * 0.05, aussen: r * 0.78, breite: r * 0.45, start: winkel + CGFloat.pi / CGFloat(n), rund: 1,
                von: dunkel, bis: hell.mix(Pal.weiss, 0.12), rand: rand, randBreite: max(r * 0.03, 0.25))
    if fein {
        for i in 0..<n {
            let w = winkel + CGFloat(i) * 2 * CGFloat.pi / CGFloat(n)
            linie(g, strich(blWeg(c, w, r * 0.2), blWeg(c, w, r * 0.85)), dunkel.mal(0.8).farbe.opacity(0.4), max(r * 0.025, 0.2))
        }
    }
    g.fill(kreis(c, r * 0.26), with: .radialGradient(Gradient(colors: [schlund.mix(Pal.weiss, 0.3).farbe, schlund.farbe]), center: c, startRadius: 0, endRadius: r * 0.26))
    if let staub {
        for i in 0..<(fein ? 9 : 4) {
            blumenPunkt(g, blWeg(c, winkel + CGFloat(i) * 0.7, r * 0.2 + CGFloat(i % 3) * r * 0.04), r * 0.05, staub.farbe)
        }
    }
}

/// Gypsophila: fine twigs and many tiny white (or pink) blossoms around `c`.
func blumeSchleier(_ g: GraphicsContext, _ c: CGPoint, spreizung: CGFloat, anzahl: Int, punkt: CGFloat, farbe: FigurFarbe,
                   seed: UInt64, fein: Bool = true) {
    var z = BlumenZufall(seed)
    let n = fein ? anzahl : max(anzahl / 3, 4)
    if fein {
        for _ in 0..<max(n / 4, 3) {
            let w = z.zwischen(0, 2 * CGFloat.pi)
            let l = spreizung * z.zwischen(0.5, 1.0)
            let mitte = blWeg(c, w + 0.3, l * 0.5)
            let zweig = Path { p in
                p.move(to: c)
                p.addQuadCurve(to: blWeg(c, w, l), control: mitte)
            }
            linie(g, zweig, FigurFarbe(0x7F9A6A).farbe.opacity(0.7), max(punkt * 0.25, 0.2))
        }
    }
    for _ in 0..<n {
        let w = z.zwischen(0, 2 * CGFloat.pi)
        let d = z.next().squareRoot() * spreizung
        let m = blWeg(c, w, d)
        let rr = punkt * z.zwischen(0.7, 1.2)
        g.fill(kreis(P(m.x + rr * 0.15, m.y + rr * 0.2), rr), with: .color(.black.opacity(0.1)))
        g.fill(kreis(m, rr), with: .color(farbe.farbe))
        if fein {
            g.stroke(kreis(m, rr), with: .color(farbe.mal(0.8).farbe.opacity(0.6)), style: StrokeStyle(lineWidth: max(rr * 0.2, 0.15)))
            blumenPunkt(g, P(m.x - rr * 0.25, m.y - rr * 0.25), rr * 0.3, .white.opacity(0.9))
            if z.next() > 0.8 { blumenPunkt(g, blWeg(m, w, rr * 1.5), rr * 0.45, FigurFarbe(0xA7B88A).farbe) }
        }
    }
}

// MARK: - Green

/// A leaf from `a` (base) to `b` (tip) with its midrib; `rand` colours the edge (variegated leaves).
func blumeLaub(_ g: GraphicsContext, _ a: CGPoint, _ b: CGPoint, breite w: CGFloat, _ f: FigurFarbe, rund: CGFloat = 0.15,
               rand: FigurFarbe? = nil, fein: Bool = true) {
    let pf = blumenBlatt(a, b, breite: w, rund: rund)
    g.fill(pf, with: .linearGradient(Gradient(colors: [f.mal(0.68).farbe, f.mix(Pal.weiss, 0.14).farbe]), startPoint: a, endPoint: b))
    if let rand {
        g.stroke(pf, with: .color(rand.farbe), style: StrokeStyle(lineWidth: max(w * 0.25, 0.5), lineJoin: .round))
    } else {
        g.stroke(pf, with: .color(f.mal(0.55).farbe.opacity(0.8)), style: StrokeStyle(lineWidth: max(w * 0.06, 0.3), lineJoin: .round))
    }
    guard fein else { return }
    let ende = P(a.x + (b.x - a.x) * 0.9, a.y + (b.y - a.y) * 0.9)
    linie(g, strich(a, ende), f.mix(Pal.weiss, 0.35).farbe.opacity(0.6), max(w * 0.07, 0.25))
}

/// A thin twig with small oval leaves on both sides (pistachio, ruscus sprigs).
func blumeZweig(_ g: GraphicsContext, _ a: CGPoint, _ b: CGPoint, blatt f: FigurFarbe, anzahl: Int, groesse: CGFloat, fein: Bool = true) {
    linie(g, strich(a, b), f.mal(0.6).farbe, max(groesse * 0.1, 0.4))
    let dx = b.x - a.x
    let dy = b.y - a.y
    let l = max((dx * dx + dy * dy).squareRoot(), 0.001)
    for i in 0..<anzahl {
        let t = CGFloat(i + 1) / CGFloat(anzahl + 1)
        let s: CGFloat = i % 2 == 0 ? 1 : -1
        let fuss = P(a.x + dx * t, a.y + dy * t)
        let spitze = P(fuss.x + dx / l * groesse * 0.5 - dy / l * groesse * s, fuss.y + dy / l * groesse * 0.5 + dx / l * groesse * s)
        blumeLaub(g, fuss, spitze, breite: groesse * 0.38, f.mix(Pal.weiss, 0.06 * CGFloat(i % 3)), rund: 0.7, fein: false)
    }
    blumeLaub(g, b, P(b.x + dx / l * groesse * 0.9, b.y + dy / l * groesse * 0.9), breite: groesse * 0.34, f, rund: 0.7, fein: false)
}

/// Many single leaves scattered over an ellipse, each pointing away from the stem point `fuss`: the
/// green that fills the gaps between the blooms (no flat patch, every leaf keeps its own shape).
func blumeLaubFeld(_ g: GraphicsContext, mitte: CGPoint, rx: CGFloat, ry: CGFloat, fuss: CGPoint, anzahl: Int, laenge: CGFloat, breite: CGFloat,
                   farben: [FigurFarbe], seed: UInt64, fein: Bool = true) {
    guard !farben.isEmpty else { return }
    var z = BlumenZufall(seed)
    for i in 0..<anzahl {
        let w = z.zwischen(0, 2 * CGFloat.pi)
        let d = z.next().squareRoot()
        let a = P(mitte.x + cos(w) * rx * d, mitte.y + sin(w) * ry * d)
        let richtung = atan2(a.y - fuss.y, a.x - fuss.x) + z.zwischen(-0.8, 0.8)
        blumeLaub(g, a, blWeg(a, richtung, laenge * z.zwischen(0.7, 1.2)), breite: breite * z.zwischen(0.8, 1.2), farben[i % farben.count],
                  rund: 0.3, fein: fein)
    }
}

/// The dense dark mass of leaves and stems under the blooms: in the photos the flowers sit shoulder
/// to shoulder, so the gaps between them show this and not the paper. A smooth blob through `pts`.
func blumenMasse(_ g: GraphicsContext, _ pts: [CGPoint], oben: FigurFarbe, unten: FigurFarbe) {
    let n = pts.count
    guard n > 2 else { return }
    func mitte(_ i: Int) -> CGPoint {
        let p = pts[i % n]
        let q = pts[(i + 1) % n]
        return P((p.x + q.x) / 2, (p.y + q.y) / 2)
    }
    var pf = Path()
    pf.move(to: mitte(n - 1))
    for i in 0..<n { pf.addQuadCurve(to: mitte(i), control: pts[i]) }
    pf.closeSubpath()
    let top = pts.map { $0.y }.min() ?? 0
    let bottom = pts.map { $0.y }.max() ?? 1
    g.fill(pf, with: .linearGradient(Gradient(colors: [oben.farbe, unten.farbe]), startPoint: P(0, top), endPoint: P(0, bottom)))
}

// MARK: - Paper, ribbon, glitter

/// One sheet of wrapping paper: a polygon with a soft shadow, a top-to-bottom tint, a sharp edge
/// and crease lines (each a dark line with a light one beside it).
func blumePapier(_ g: GraphicsContext, _ pts: [CGPoint], oben: FigurFarbe, unten: FigurFarbe, kante: Color, kanteBreite: CGFloat = 0.8,
                 falten: [(CGPoint, CGPoint)] = [], faltenFarbe: Color = .black.opacity(0.14), glanz: Color = .white.opacity(0.35)) {
    guard pts.count > 2 else { return }
    var pf = Path()
    pf.move(to: pts[0])
    for q in pts.dropFirst() { pf.addLine(to: q) }
    pf.closeSubpath()
    var s = g
    s.translateBy(x: 1.2, y: 1.8)
    s.fill(pf, with: .color(.black.opacity(0.14)))
    let hoehen = pts.map { $0.y }
    let top = hoehen.min() ?? 0
    let bottom = hoehen.max() ?? 1
    g.fill(pf, with: .linearGradient(Gradient(colors: [oben.farbe, unten.farbe]), startPoint: P(0, top), endPoint: P(0, bottom)))
    g.stroke(pf, with: .color(kante), style: StrokeStyle(lineWidth: kanteBreite, lineJoin: .miter))
    for f in falten {
        linie(g, strich(f.0, f.1), faltenFarbe, 0.7)
        linie(g, strich(P(f.0.x + 0.8, f.0.y + 0.6), P(f.1.x + 0.8, f.1.y + 0.6)), glanz, 0.6)
    }
}

/// Stems poking out of the bottom of the wrapping.
func blumeStiele(_ g: GraphicsContext, mitteX: CGFloat, unten: CGFloat) {
    let gruen = FigurFarbe(0x5E8F4A)
    for (i, dx) in [CGFloat(-7), -2, 3, 8].enumerated() {
        let a = P(mitteX + dx * 0.5, unten - 26)
        let b = P(mitteX + dx, unten + CGFloat(i % 2) * 2)
        linie(g, strich(a, b), gruen.mal(0.6).farbe, 3.2)
        linie(g, strich(a, b), gruen.farbe, 2.2)
    }
}

/// Fine specks inside a disc: the glitter on the red roses.
func blumeGlitzer(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, anzahl: Int, farben: [Color], punkt: CGFloat, seed: UInt64) {
    guard !farben.isEmpty else { return }
    var z = BlumenZufall(seed)
    for _ in 0..<anzahl {
        let w = z.zwischen(0, 2 * CGFloat.pi)
        let d = z.next().squareRoot() * r
        let col = farben[Int(z.next() * CGFloat(farben.count)) % farben.count]
        g.fill(kreis(blWeg(c, w, d), punkt * z.zwischen(0.5, 1.2)), with: .color(col))
    }
}
