import SwiftUI

/// Vector bags for the "tasche" shop category (Z-23.3), drawn near the free hand.
enum TaschenStil: Sendable { case shopper, rucksack, clutch, koffer, klappe, speedy }

/// Z-39.2: brand cues on the bag body. `web` Gucci green-red-green, `monogramm` LV, `oblique` Dior,
/// `dreieck` Prada, `gesteppt` Chanel quilting with CC, `guess` the Guess wordmark plate.
/// Fix round 5: `guess` was `.keins` — on Annika's standard black jacket/shoes the all-black bag
/// had no cue at all and was invisible against them (p5 bug report).
enum TaschenMuster: Sendable, Equatable { case keins, web, monogramm, oblique, dreieck, gesteppt, guess }

/// Maps a purchased bag's shop id to a drawn silhouette + color. New catalog ids need one line
/// here (`ShopKatalogTests.testAlleTeileHabenEineZeichnung` catches a missing entry).
let taschenKatalog: [String: (stil: TaschenStil, farbe: FigurFarbe, muster: TaschenMuster)] = [
    "tasche.stoffbeutel": (.shopper, FigurFarbe(0xD8C3A0), .keins),
    "tasche.canvas-tote": (.shopper, FigurFarbe(0xEFC09B), .keins),
    "tasche.guess-tasche": (.shopper, FigurFarbe(0x2B2830), .guess),
    "tasche.rucksack": (.rucksack, FigurFarbe(0x4B6C98), .keins),
    "tasche.prada-rucksack": (.rucksack, FigurFarbe(0x2B2830), .dreieck),
    "tasche.gucci-tasche": (.shopper, FigurFarbe(0xCDB68C), .web),
    "tasche.dior-clutch": (.clutch, FigurFarbe(0x27355F), .oblique),
    "tasche.lv-koffer": (.koffer, FigurFarbe(0x7A5234), .monogramm),
    "tasche.chanel-classic": (.klappe, FigurFarbe(0x2B2830), .gesteppt),
    "tasche.lv-speedy": (.speedy, FigurFarbe(0x6B4630), .monogramm),
]

/// p48: the six kept bags have their own detailed drawing (body top at y -12, handle above it);
/// every other id still uses the simple silhouettes at the bottom of this file.
func taschenNeu(id: String) -> Bool {
    switch id {
    case "tasche.guess-tasche", "tasche.chanel-classic", "tasche.lv-speedy",
         "tasche.gucci-tasche", "tasche.dior-clutch", "tasche.canvas-tote":
        return true
    default:
        return false
    }
}

/// How far above the bag's centre the handle meets the hand, in bag units (times `groesse`).
func taschenGriff(id: String) -> CGFloat {
    switch id {
    case "tasche.guess-tasche": return 30
    case "tasche.chanel-classic": return 31
    case "tasche.lv-speedy": return 32
    case "tasche.gucci-tasche": return 29
    case "tasche.dior-clutch": return 27
    case "tasche.canvas-tote": return 30
    default: return 20
    }
}

/// p48: the new bags are drawn about 1.5 times larger than before (a dot in the 44 pt bar).
func taschenGroesse(id: String, ganz: Bool) -> CGFloat {
    if taschenNeu(id: id) { return ganz ? 1.35 : 1.45 }
    return ganz ? 1.15 : 1.3
}

/// `an`: the bag's centre. The handle reaches up to `taschenGriff(id:) * groesse` above it, so
/// callers hang a bag from a hand at `hand.y + taschenGriff * groesse`.
/// `groesse` scales the whole drawing. `henkel: false` leaves the handle off (shoulder strap drawn by the caller).
func zeichneTasche(_ g: GraphicsContext, id: String, an punkt: CGPoint, groesse: CGFloat = 1, henkel: Bool = true) {
    guard let e = taschenKatalog[id] else { return }
    var h = g
    h.translateBy(x: punkt.x, y: punkt.y)
    h.scaleBy(x: groesse, y: groesse)
    switch id {
    case "tasche.guess-tasche": guessTasche(h, e.farbe, henkel: henkel)
    case "tasche.chanel-classic": chanelTasche(h, e.farbe, henkel: henkel)
    case "tasche.lv-speedy": speedyTasche(h, e.farbe, henkel: henkel)
    case "tasche.gucci-tasche": gucciTasche(h, e.farbe, henkel: henkel)
    case "tasche.dior-clutch": diorClutch(h, e.farbe, henkel: henkel)
    case "tasche.canvas-tote": canvasTote(h, e.farbe, henkel: henkel)
    default: einfacheTasche(h, e)
    }
}

/// Shoulder strap of a bag worn at the hip (half figure): gold chain for Chanel and Dior, leather otherwise.
func zeichneTaschenRiemen(_ g: GraphicsContext, id: String, von a: CGPoint, nach b: CGPoint, kontrolle c: CGPoint) {
    guard let e = taschenKatalog[id] else { return }
    let pfad = bogen(a, b, c)
    if id == "tasche.chanel-classic" || id == "tasche.dior-clutch" {
        linie(g, pfad, messingDunkel.farbe, 4)
        g.stroke(pfad, with: .color(messing.farbe), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2.4, 0.9]))
        g.stroke(pfad, with: .color(e.farbe.farbe), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [1.1, 2.2], dashPhase: 1.1))
        return
    }
    let leder: FigurFarbe
    switch id {
    case "tasche.lv-speedy": leder = FigurFarbe(0xC9A27B)
    case "tasche.gucci-tasche": leder = FigurFarbe(0x6B3F25)
    case "tasche.canvas-tote": leder = e.farbe.mix(Pal.weiss, 0.3)
    default: leder = e.farbe.mix(Pal.weiss, 0.12)
    }
    linie(g, pfad, leder.kontur, 5.4)
    linie(g, pfad, leder.farbe, 3.6)
    steppnaht(g, pfad, leder.mal(0.6).farbe, 0.6)
}

// MARK: - Shared parts

private let messing = FigurFarbe(0xD9B25A)
private let messingDunkel = FigurFarbe(0x7A5C1E)

/// Dashed topstitch along `p`.
func steppnaht(_ g: GraphicsContext, _ p: Path, _ c: Color, _ breite: CGFloat = 0.7) {
    g.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round, dash: [1.6, 1.5]))
}

/// Soft drop shadow: the body path shifted down-right.
private func taschenSchatten(_ g: GraphicsContext, _ body: Path) {
    var s = g
    s.translateBy(x: 1.2, y: 1.8)
    s.fill(body, with: .color(.black.opacity(0.16)))
}

/// Rolled leather handle from `a` to `b`, `hoch` above the chord, with a highlight along the top.
private func henkelBogen(_ g: GraphicsContext, _ a: CGPoint, _ b: CGPoint, hoch: CGFloat, _ f: FigurFarbe, breite: CGFloat = 3.2) {
    let mitte = P((a.x + b.x) / 2, (a.y + b.y) / 2 - 2 * hoch)
    let pfad = bogen(a, b, mitte)
    linie(g, pfad, f.kontur, breite + 1.8)
    linie(g, pfad, f.farbe, breite)
    linie(g, pfad, f.mix(Pal.weiss, 0.4).farbe.opacity(0.55), breite * 0.28)
}

/// Gold chain strap: brass links with a leather thread woven through (Chanel, Dior).
private func kettenBogen(_ g: GraphicsContext, _ a: CGPoint, _ b: CGPoint, hoch: CGFloat, leder: FigurFarbe) {
    let pfad = bogen(a, b, P((a.x + b.x) / 2, (a.y + b.y) / 2 - 2 * hoch))
    linie(g, pfad, messingDunkel.farbe, 3.6)
    g.stroke(pfad, with: .color(messing.farbe), style: StrokeStyle(lineWidth: 2.7, lineCap: .round, dash: [2.4, 0.9]))
    g.stroke(pfad, with: .color(leder.farbe), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [1.1, 2.2], dashPhase: 1.1))
}

private func ring(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat = 1.9) {
    teil(g, kreis(c, r), messing, 0.8)
    g.fill(kreis(c, r * 0.4), with: .color(messingDunkel.farbe))
}

private func glanz(_ g: GraphicsContext, _ p: Path, _ deckkraft: Double = 0.08) {
    g.fill(p, with: .color(.white.opacity(deckkraft)))
}

/// A "G" with its opening to the right; `sp` -1 mirrors it. `c` is its centre, `s` its scale.
private func buchstabeG(_ p: inout Path, _ c: CGPoint, _ s: CGFloat, _ sp: CGFloat) {
    p.move(to: P(c.x + sp * 2.2 * s, c.y - 1.7 * s))
    p.addQuadCurve(to: P(c.x - sp * 2.3 * s, c.y), control: P(c.x - sp * 0.4 * s, c.y - 4.4 * s))
    p.addQuadCurve(to: P(c.x + sp * 2.2 * s, c.y + 1.5 * s), control: P(c.x - sp * 0.4 * s, c.y + 4.4 * s))
    p.addLine(to: P(c.x + sp * 2.2 * s, c.y))
    p.addLine(to: P(c.x + sp * 0.5 * s, c.y))
}

// MARK: - Guess

/// Guess satchel: black structured body, 4G monogram tone on tone, gold hardware, red triangle plaque.
private func guessTasche(_ g: GraphicsContext, _ f: FigurFarbe, henkel: Bool) {
    let koerper = Path { p in
        p.move(to: P(-22, -12))
        p.addLine(to: P(22, -12))
        p.addQuadCurve(to: P(26, 12), control: P(25, -1))
        p.addQuadCurve(to: P(21, 18), control: P(26, 18))
        p.addLine(to: P(-21, 18))
        p.addQuadCurve(to: P(-26, 12), control: P(-26, 18))
        p.addQuadCurve(to: P(-22, -12), control: P(-25, -1))
        p.closeSubpath()
    }
    if henkel {
        henkelBogen(g, P(-9, -12), P(9, -12), hoch: 15, f.mal(0.85), breite: 2.8)
        henkelBogen(g, P(-14, -12), P(14, -12), hoch: 18, f)
    }
    taschenSchatten(g, koerper)
    teil(g, koerper, f, 2.2)
    var innen = g
    innen.clip(to: koerper)
    var muster = Path()
    var reihe = 0
    for y in stride(from: CGFloat(-8), through: 18, by: 6.5) {
        let versatz: CGFloat = reihe % 2 == 0 ? 0 : 6
        for x in stride(from: CGFloat(-24), through: 26, by: 12) {
            muster.addPath(vierG(P(x + versatz, y)))
        }
        reihe += 1
    }
    innen.stroke(muster, with: .color(messing.farbe.opacity(0.5)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round))
    glanz(innen, Path { p in
        p.move(to: P(-22, -12))
        p.addLine(to: P(-6, -12))
        p.addLine(to: P(-16, 18))
        p.addLine(to: P(-26, 18))
        p.closeSubpath()
    })
    linie(innen, strich(P(-24, -8.2), P(24, -8.2)), f.mal(0.5).farbe, 0.8)
    steppnaht(innen, strich(P(-24, -9.6), P(24, -9.6)), messing.farbe.opacity(0.85))
    // Triangle plaque: red, gold rim, the wordmark across the wide top.
    let dreieck = Path { p in
        p.move(to: P(-7, -5))
        p.addLine(to: P(7, -5))
        p.addLine(to: P(0, 7))
        p.closeSubpath()
    }
    var plakette = g
    plakette.translateBy(x: 0, y: 3)
    plakette.fill(dreieck, with: .color(FigurFarbe(0xC8283F).farbe))
    plakette.stroke(dreieck, with: .color(messing.farbe), style: StrokeStyle(lineWidth: 1.3, lineJoin: .round))
    plakette.draw(Text("GUESS").font(.system(size: 3.4, weight: .heavy)).foregroundStyle(Color.white), at: P(0, -2.8))
    ring(g, P(-14, -11))
    ring(g, P(14, -11))
    for x in [CGFloat(-16), 16] { g.fill(kreis(P(x, 18.4), 1.4), with: .color(messing.farbe)) }
}

/// The "4" and the "G" of Guess's 4G monogram, centred at `c`.
private func vierG(_ c: CGPoint) -> Path {
    var p = Path()
    p.move(to: P(c.x - 1.4, c.y - 2.3))
    p.addLine(to: P(c.x - 4.6, c.y + 0.9))
    p.addLine(to: P(c.x - 1, c.y + 0.9))
    p.move(to: P(c.x - 1.6, c.y - 1.6))
    p.addLine(to: P(c.x - 1.6, c.y + 2.4))
    buchstabeG(&p, P(c.x + 2.8, c.y), 1, 1)
    return p
}

// MARK: - Chanel

/// Chanel Classic Flap: diamond-quilted black leather, chain strap, flap with the CC turn-lock.
private func chanelTasche(_ g: GraphicsContext, _ f: FigurFarbe, henkel: Bool) {
    let koerper = box(-24, -12, 48, 31, 5)
    if henkel {
        kettenBogen(g, P(-19, -11), P(19, -11), hoch: 19, leder: f)
        kettenBogen(g, P(-15, -11), P(15, -11), hoch: 15, leder: f)
    }
    taschenSchatten(g, koerper)
    teil(g, koerper, f, 2.2)
    var innen = g
    innen.clip(to: koerper)
    var raute = Path()
    for x in stride(from: CGFloat(-60), through: 40, by: 8) {
        raute.move(to: P(x, -14))
        raute.addLine(to: P(x + 36, 22))
        raute.move(to: P(x + 36, -14))
        raute.addLine(to: P(x, 22))
    }
    var tief = innen
    tief.translateBy(x: 0.7, y: 0.9)
    tief.stroke(raute, with: .color(f.mal(0.4).farbe.opacity(0.8)), lineWidth: 0.8)
    innen.stroke(raute, with: .color(f.mix(Pal.weiss, 0.24).farbe.opacity(0.85)), lineWidth: 0.8)
    innen.fill(box(17, -14, 9, 36), with: .color(.black.opacity(0.10)))
    glanz(innen, Path { p in
        p.move(to: P(-24, -12))
        p.addLine(to: P(-8, -12))
        p.addLine(to: P(-18, 19))
        p.addLine(to: P(-24, 19))
        p.closeSubpath()
    }, 0.07)
    // Flap with a curved lower edge, a bright edge line below it.
    let klappe = Path { p in
        p.move(to: P(-24, -12))
        p.addLine(to: P(24, -12))
        p.addLine(to: P(24, 4))
        p.addQuadCurve(to: P(-24, 4), control: P(0, 12))
        p.closeSubpath()
    }
    let klappenKante = bogen(P(-24, 4), P(24, 4), P(0, 12))
    linie(innen, klappenKante, f.mal(0.35).farbe, 1.7)
    var kante = innen
    kante.translateBy(x: 0, y: 1.3)
    linie(kante, klappenKante, f.mix(Pal.weiss, 0.3).farbe.opacity(0.55), 0.7)
    innen.stroke(klappe, with: .color(f.mal(0.4).farbe), lineWidth: 1)
    // Turn-lock: brass plate with the interlocking CC.
    teil(g, box(-5.4, 4.2, 10.8, 8, 2.4), messing, 0.9)
    chanelCC(g, P(0, 8.2), 2.4, farbe: messingDunkel)
    ring(g, P(-19, -11), 1.6)
    ring(g, P(19, -11), 1.6)
}

/// Chanel's two interlocking C's (back to back), gold, radius `r`.
func chanelCC(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, farbe: FigurFarbe = Pal.gold) {
    let links = Path { p in p.addArc(center: P(c.x - r * 0.45, c.y), radius: r, startAngle: .degrees(230), endAngle: .degrees(130), clockwise: false) }
    let rechts = Path { p in p.addArc(center: P(c.x + r * 0.45, c.y), radius: r, startAngle: .degrees(50), endAngle: .degrees(310), clockwise: false) }
    for bogenC in [links, rechts] { linie(g, bogenC, farbe.farbe, max(1, r * 0.45)) }
}

// MARK: - Louis Vuitton

/// LV Speedy: domed monogram canvas, vachetta handles, brass zip, padlock.
private func speedyTasche(_ g: GraphicsContext, _ f: FigurFarbe, henkel: Bool) {
    let vachetta = FigurFarbe(0xC9A27B)
    let koerper = Path { p in
        p.move(to: P(-22, 18))
        p.addQuadCurve(to: P(-27, 12), control: P(-27, 18))
        p.addCurve(to: P(-13, -11), control1: P(-27, -2), control2: P(-22, -11))
        p.addQuadCurve(to: P(13, -11), control: P(0, -15))
        p.addCurve(to: P(27, 12), control1: P(22, -11), control2: P(27, -2))
        p.addQuadCurve(to: P(22, 18), control: P(27, 18))
        p.closeSubpath()
    }
    if henkel {
        henkelBogen(g, P(-13, -10), P(13, -10), hoch: 18, vachetta.mal(0.82), breite: 3.4)
        henkelBogen(g, P(-15, -9), P(15, -9), hoch: 20, vachetta, breite: 3.6)
    }
    taschenSchatten(g, koerper)
    teil(g, koerper, f, 2.2)
    var innen = g
    innen.clip(to: koerper)
    let gold = FigurFarbe(0xC9A55A).farbe
    var buchstaben = Path()
    var blumen = Path()
    var sterne = Path()
    var reihe = 0
    for y in stride(from: CGFloat(-9), through: 20, by: 6.4) {
        let versatz: CGFloat = reihe % 2 == 0 ? 0 : 5
        var spalte = 0
        for x in stride(from: CGFloat(-26), through: 30, by: 10) {
            let c = P(x + versatz, y)
            switch (reihe + spalte) % 3 {
            case 0: buchstaben.addPath(lvZeichen(c))
            case 1: sterne.addPath(funkelKlein(c))
            default: blumen.addPath(blume(c))
            }
            spalte += 1
        }
        reihe += 1
    }
    let strichStil = StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round)
    innen.stroke(buchstaben, with: .color(gold), style: strichStil)
    innen.stroke(blumen, with: .color(gold), style: strichStil)
    innen.fill(sterne, with: .color(gold))
    // Vachetta base band with stitching, brass zip along the dome.
    innen.fill(box(-30, 13, 60, 8), with: .color(vachetta.farbe))
    linie(innen, strich(P(-30, 13), P(30, 13)), vachetta.kontur, 1)
    steppnaht(innen, strich(P(-30, 15.6), P(30, 15.6)), vachetta.mal(0.55).farbe)
    glanz(innen, Path { p in
        p.move(to: P(-27, 0))
        p.addLine(to: P(-14, -12))
        p.addLine(to: P(-7, -12))
        p.addLine(to: P(-18, 18))
        p.addLine(to: P(-27, 18))
        p.closeSubpath()
    }, 0.07)
    let zip = Path { p in
        p.move(to: P(-24, 3))
        p.addCurve(to: P(-11, -8.5), control1: P(-24, -4), control2: P(-19, -8.5))
        p.addQuadCurve(to: P(11, -8.5), control: P(0, -12.5))
        p.addCurve(to: P(24, 3), control1: P(19, -8.5), control2: P(24, -4))
    }
    linie(g, zip, messingDunkel.farbe, 2)
    g.stroke(zip, with: .color(messing.farbe), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [1.1, 0.8]))
    // Padlock hangs from the front.
    let buegel = Path { p in
        p.move(to: P(-1.9, 4.2))
        p.addQuadCurve(to: P(1.9, 4.2), control: P(0, -1.4))
    }
    linie(g, buegel, messingDunkel.farbe, 1.6)
    linie(g, buegel, messing.farbe, 0.8)
    teil(g, box(-3.2, 4, 6.4, 5.6, 1.2), messing, 0.8)
    g.fill(kreis(P(0, 6.4), 0.8), with: .color(messingDunkel.farbe))
    g.fill(box(-0.35, 6.6, 0.7, 1.8), with: .color(messingDunkel.farbe))
    for x in [CGFloat(-15), 15] { g.fill(kreis(P(x, 18.6), 1.4), with: .color(messing.farbe)) }
}

/// The LV initials: an L and a V side by side.
private func lvZeichen(_ c: CGPoint) -> Path {
    var p = Path()
    p.move(to: P(c.x - 3.4, c.y - 2.4))
    p.addLine(to: P(c.x - 3.4, c.y + 2.4))
    p.addLine(to: P(c.x - 1.2, c.y + 2.4))
    p.move(to: P(c.x - 0.6, c.y - 2.4))
    p.addLine(to: P(c.x + 1.2, c.y + 2.4))
    p.addLine(to: P(c.x + 3, c.y - 2.4))
    return p
}

/// Monogram flower: a ring with four petals.
private func blume(_ c: CGPoint) -> Path {
    var p = Path()
    p.addEllipse(in: CGRect(x: c.x - 1, y: c.y - 1, width: 2, height: 2))
    for (dx, dy) in [(CGFloat(0), CGFloat(-2.6)), (2.6, 0), (0, 2.6), (-2.6, 0)] {
        p.addEllipse(in: CGRect(x: c.x + dx - 0.9, y: c.y + dy - 0.9, width: 1.8, height: 1.8))
    }
    return p
}

/// Four-pointed LV star.
private func funkelKlein(_ c: CGPoint) -> Path {
    Path { p in
        p.move(to: P(c.x, c.y - 2.1))
        p.addQuadCurve(to: P(c.x + 2.1, c.y), control: c)
        p.addQuadCurve(to: P(c.x, c.y + 2.1), control: c)
        p.addQuadCurve(to: P(c.x - 2.1, c.y), control: c)
        p.addQuadCurve(to: P(c.x, c.y - 2.1), control: c)
        p.closeSubpath()
    }
}

// MARK: - Gucci

/// Gucci GG Supreme tote: beige canvas with the brown GG, green-red-green web band, leather trim, GG plate.
private func gucciTasche(_ g: GraphicsContext, _ f: FigurFarbe, henkel: Bool) {
    let leder = FigurFarbe(0x6B3F25)
    let gruen = FigurFarbe(0x1F7A45)
    let rot = FigurFarbe(0xC8283F)
    let koerper = Path { p in
        p.move(to: P(-22, -12))
        p.addLine(to: P(22, -12))
        p.addLine(to: P(25, 14))
        p.addQuadCurve(to: P(21, 18), control: P(25, 18))
        p.addLine(to: P(-21, 18))
        p.addQuadCurve(to: P(-25, 14), control: P(-25, 18))
        p.closeSubpath()
    }
    if henkel {
        henkelBogen(g, P(-12, -12), P(12, -12), hoch: 17, leder, breite: 3.4)
    }
    taschenSchatten(g, koerper)
    teil(g, koerper, f, 2.2)
    var innen = g
    innen.clip(to: koerper)
    var gg = Path()
    var reihe = 0
    for y in stride(from: CGFloat(-8), through: 20, by: 6) {
        let versatz: CGFloat = reihe % 2 == 0 ? 0 : 4.5
        for x in stride(from: CGFloat(-26), through: 28, by: 9) {
            let c = P(x + versatz, y)
            buchstabeG(&gg, P(c.x - 1.2, c.y), 0.95, 1)
            buchstabeG(&gg, P(c.x + 1.2, c.y), 0.95, -1)
        }
        reihe += 1
    }
    innen.stroke(gg, with: .color(FigurFarbe(0x7A5232).farbe.opacity(0.85)), style: StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round))
    // Web band down the middle, leather trim at the rim and the base.
    innen.fill(box(-4.5, -14, 3, 36), with: .color(gruen.farbe))
    innen.fill(box(-1.5, -14, 3, 36), with: .color(rot.farbe))
    innen.fill(box(1.5, -14, 3, 36), with: .color(gruen.farbe))
    innen.fill(box(-30, -12, 60, 5), with: .color(leder.farbe))
    steppnaht(innen, strich(P(-24, -9.5), P(24, -9.5)), FigurFarbe(0xD9B27A).farbe.opacity(0.9))
    innen.fill(box(-30, 14, 60, 8), with: .color(leder.farbe))
    steppnaht(innen, strich(P(-30, 15.6), P(30, 15.6)), FigurFarbe(0xD9B27A).farbe.opacity(0.9))
    glanz(innen, Path { p in
        p.move(to: P(-22, -12))
        p.addLine(to: P(-8, -12))
        p.addLine(to: P(-16, 18))
        p.addLine(to: P(-25, 18))
        p.closeSubpath()
    }, 0.09)
    // GG plate on the band.
    teil(g, kreis(P(0, 3), 4.6), messing, 1)
    var plakette = Path()
    buchstabeG(&plakette, P(-1.1, 3), 1.05, 1)
    buchstabeG(&plakette, P(1.1, 3), 1.05, -1)
    g.stroke(plakette, with: .color(messingDunkel.farbe), style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round))
    ring(g, P(-12, -11), 1.7)
    ring(g, P(12, -11), 1.7)
}

// MARK: - Dior

/// Dior clutch: navy Oblique jacquard with the CD monogram, V flap with a CD charm, chain loop.
private func diorClutch(_ g: GraphicsContext, _ f: FigurFarbe, henkel: Bool) {
    let hell = FigurFarbe(0x7E92C4)
    let koerper = box(-26, -12, 52, 31, 4)
    if henkel {
        kettenBogen(g, P(-22, -11), P(22, -11), hoch: 15, leder: f)
    }
    taschenSchatten(g, koerper)
    teil(g, koerper, f, 2.2)
    var innen = g
    innen.clip(to: koerper)
    var schraeg = Path()
    for x in stride(from: CGFloat(-50), through: 30, by: 6) {
        schraeg.move(to: P(x, 20))
        schraeg.addLine(to: P(x + 32, -14))
    }
    innen.stroke(schraeg, with: .color(hell.farbe.opacity(0.28)), lineWidth: 0.6)
    var cd = Path()
    var reihe = 0
    for y in stride(from: CGFloat(-8), through: 20, by: 7) {
        let versatz: CGFloat = reihe % 2 == 0 ? 0 : 6
        for x in stride(from: CGFloat(-26), through: 28, by: 12) {
            cd.addPath(cdZeichen(P(x + versatz, y)))
        }
        reihe += 1
    }
    innen.stroke(cd, with: .color(hell.farbe.opacity(0.7)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round, lineJoin: .round))
    glanz(innen, Path { p in
        p.move(to: P(-26, -12))
        p.addLine(to: P(-10, -12))
        p.addLine(to: P(-20, 19))
        p.addLine(to: P(-26, 19))
        p.closeSubpath()
    }, 0.08)
    // V flap.
    let klappe = Path { p in
        p.move(to: P(-26, -12))
        p.addLine(to: P(26, -12))
        p.addLine(to: P(26, 1))
        p.addQuadCurve(to: P(0, 12), control: P(18, 9))
        p.addQuadCurve(to: P(-26, 1), control: P(-18, 9))
        p.closeSubpath()
    }
    var klappeInnen = innen
    klappeInnen.translateBy(x: 0, y: 1.2)
    klappeInnen.stroke(klappe, with: .color(hell.farbe.opacity(0.4)), lineWidth: 0.8)
    innen.stroke(klappe, with: .color(f.mal(0.45).farbe), lineWidth: 1.5)
    steppnaht(innen, strich(P(-22, -8), P(22, -8)), hell.farbe.opacity(0.8))
    // CD charm at the tip.
    teil(g, kreis(P(0, 10.6), 3.6), messing, 0.9)
    g.draw(Text("CD").font(.system(size: 3.6, weight: .heavy, design: .serif)).foregroundStyle(messingDunkel.farbe), at: P(0, 10.7))
    ring(g, P(-22, -11), 1.6)
    ring(g, P(22, -11), 1.6)
}

/// The interlocked C and D of Dior's monogram.
private func cdZeichen(_ c: CGPoint) -> Path {
    var p = Path()
    p.move(to: P(c.x - 0.2, c.y - 1.9))
    p.addQuadCurve(to: P(c.x - 0.2, c.y + 1.9), control: P(c.x - 3.8, c.y))
    p.move(to: P(c.x + 0.8, c.y - 1.9))
    p.addLine(to: P(c.x + 0.8, c.y + 1.9))
    p.addQuadCurve(to: P(c.x + 3.6, c.y), control: P(c.x + 4.4, c.y + 1.9))
    p.addQuadCurve(to: P(c.x + 0.8, c.y - 1.9), control: P(c.x + 4.4, c.y - 1.9))
    return p
}

// MARK: - Canvas tote

/// Plain canvas tote: woven fabric, cotton webbing handles with stitched patches, a heart print.
private func canvasTote(_ g: GraphicsContext, _ f: FigurFarbe, henkel: Bool) {
    let gurt = f.mix(Pal.weiss, 0.3)
    let koerper = Path { p in
        p.move(to: P(-22, -12))
        p.addLine(to: P(22, -12))
        p.addLine(to: P(23, 16))
        p.addQuadCurve(to: P(19, 18.5), control: P(23, 18.5))
        p.addLine(to: P(-19, 18.5))
        p.addQuadCurve(to: P(-23, 16), control: P(-23, 18.5))
        p.closeSubpath()
    }
    if henkel {
        henkelBogen(g, P(-11, -12), P(11, -12), hoch: 15, gurt.mal(0.85), breite: 3.6)
        henkelBogen(g, P(-14, -12), P(14, -12), hoch: 18, gurt, breite: 3.8)
    }
    taschenSchatten(g, koerper)
    teil(g, koerper, f, 2.2)
    var innen = g
    innen.clip(to: koerper)
    var gewebe = Path()
    for y in stride(from: CGFloat(-12), through: 19, by: 2.2) {
        gewebe.move(to: P(-24, y))
        gewebe.addLine(to: P(24, y))
    }
    for x in stride(from: CGFloat(-24), through: 24, by: 2.2) {
        gewebe.move(to: P(x, -12))
        gewebe.addLine(to: P(x, 19))
    }
    innen.stroke(gewebe, with: .color(f.kontur.opacity(0.13)), lineWidth: 0.4)
    innen.fill(box(-30, -12, 60, 4.5), with: .color(f.mal(0.93).farbe))
    steppnaht(innen, strich(P(-24, -7.2), P(24, -7.2)), f.mal(0.6).farbe)
    innen.fill(box(-30, 13, 60, 8), with: .color(f.mal(0.88).farbe))
    steppnaht(innen, strich(P(-24, 13), P(24, 13)), f.mal(0.6).farbe)
    // Where the straps are sewn on: patches with a crossed stitch.
    for x in [CGFloat(-12.5), 12.5] {
        teil(innen, box(x - 5, -12, 10, 11, 1), f.mal(0.9), 1)
        var kreuz = Path()
        kreuz.move(to: P(x - 3, -10))
        kreuz.addLine(to: P(x + 3, -3.5))
        kreuz.move(to: P(x + 3, -10))
        kreuz.addLine(to: P(x - 3, -3.5))
        innen.stroke(kreuz, with: .color(f.mal(0.55).farbe), lineWidth: 0.7)
    }
    g.fill(herzPfad(P(0, 3.5), 5), with: .color(FigurFarbe(0xE0586E).farbe))
    var herzGlanz = g
    herzGlanz.translateBy(x: -1.6, y: 2)
    herzGlanz.fill(kreis(P(0, 0), 0.9), with: .color(.white.opacity(0.5)))
    glanz(innen, Path { p in
        p.move(to: P(-22, -12))
        p.addLine(to: P(-9, -12))
        p.addLine(to: P(-16, 18))
        p.addLine(to: P(-23, 18))
        p.closeSubpath()
    }, 0.1)
}

// MARK: - Simple silhouettes (ids without a detailed drawing)

private func einfacheTasche(_ h: GraphicsContext, _ e: (stil: TaschenStil, farbe: FigurFarbe, muster: TaschenMuster)) {
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
    // Fix round 5: a thin gold rim so the silhouette reads against equally dark clothing (p5).
    if e.muster == .guess { h.stroke(koerper, with: .color(Pal.gold.farbe), lineWidth: 1.2) }
    var innen = h
    innen.clip(to: koerper)
    einfachesMuster(innen, e.muster, f)
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

/// Brand pattern inside a simple bag body (`h` is clipped to it).
private func einfachesMuster(_ h: GraphicsContext, _ m: TaschenMuster, _ f: FigurFarbe) {
    switch m {
    case .keins, .guess:
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
