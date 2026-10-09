import SwiftUI

/// Vector pets for the "tier" shop category (Z-23.3): at least 4 species, standing next to the figure.
/// p48: each species is drawn in detail in its own local space (feet on y 0, facing right), then placed
/// and mirrored by `zeichneHaustier`. The full body shows it beside the feet, the half figure in its lower corner.
/// p57: more detail (fur strokes and tufts, eyes with iris and highlight, inner ears, toes, soft shadow), bigger,
/// the black fluffy cat (`KuschelKatzeZeichner.swift`) and a second view "lies / sits" (`HaustierPose.liegt`).
enum HaustierArt: Sendable { case hund, katze, kuschelkatze, hase, vogel }

/// p57: stable interface for the profile ("pets at home"): `.steht` is the old standing view (default, nothing
/// changes for existing callers), `.liegt` is the resting view (dog and cats lie, rabbit sits as a loaf, bird sits
/// with fluffed belly). Same anchor (feet / belly on y 0, facing right), the lying body is a little wider.
enum HaustierPose: Sendable { case steht, liegt }

let haustierKatalog: [String: (art: HaustierArt, farbe: FigurFarbe)] = [
    "tier.hund-braun": (.hund, FigurFarbe(0xA96F45)),
    "tier.hund-schwarz": (.hund, FigurFarbe(0x2B2830)),
    "tier.katze-grau": (.katze, FigurFarbe(0x8E8C93)),
    "tier.katze-orange": (.katze, FigurFarbe(0xF08A4B)),
    "tier.katze-schwarz": (.kuschelkatze, FigurFarbe(0x1E1D24)),
    "tier.hase-weiss": (.hase, FigurFarbe(0xF4F1EE)),
    "tier.vogel-blau": (.vogel, Pal.blau),
]

/// p57: scale of a species in local units (the bird and the rabbit were too small in the profile) and the
/// half width of its soft ground shadow.
private func haustierMass(_ art: HaustierArt) -> (skala: CGFloat, schatten: CGFloat) {
    switch art {
    case .hund: (1.12, 33)
    case .katze: (1.28, 20)
    case .kuschelkatze: (1.25, 26)
    case .hase: (1.45, 20)
    case .vogel: (1.75, 13)
    }
}

/// `boden`: where the pet's feet touch the ground. `groesse` scales the whole pet. `nachLinks`: the pet looks
/// to the left (towards the figure when it stands on the right); `false` looks right. `pose`: standing or lying.
func zeichneHaustier(_ g: GraphicsContext, id: String, boden punkt: CGPoint, groesse: CGFloat = 1, nachLinks: Bool = true, pose: HaustierPose = .steht) {
    guard let e = haustierKatalog[id] else { return }
    var h = g
    let mass = haustierMass(e.art)
    let k = groesse * mass.skala
    h.translateBy(x: punkt.x, y: punkt.y)
    h.scaleBy(x: nachLinks ? -k : k, y: k)
    tierSchatten(h, breite: pose == .liegt ? mass.schatten * 1.25 : mass.schatten)
    switch e.art {
    case .hund: hund(h, e.farbe, pose: pose)
    case .katze: katze(h, e.farbe, pose: pose)
    case .kuschelkatze: kuschelKatze(h, e.farbe, pose: pose)
    case .hase: hase(h, e.farbe, pose: pose)
    case .vogel: vogel(h, e.farbe, pose: pose)
    }
}

// MARK: - Shared building blocks (p57)

/// `p` rotated by `grad` degrees around `c`.
private func kippe(_ p: Path, um c: CGPoint, grad: Double) -> Path {
    let t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: grad * .pi / 180).translatedBy(x: -c.x, y: -c.y)
    return p.applying(t)
}

/// Fur tuft: a pointed, slightly bent leaf from `basis` in direction `grad` (0 = right, 90 = down, y points down).
func tierBuschel(_ basis: CGPoint, laenge l: CGFloat, breite b: CGFloat, grad: Double, biegung: CGFloat = 0.2) -> Path {
    let w = grad * Double.pi / 180
    let r = P(CGFloat(cos(w)), CGFloat(sin(w)))
    let n = P(-r.y, r.x)
    let versatz = l * biegung
    let spitze = P(basis.x + r.x * l + n.x * versatz, basis.y + r.y * l + n.y * versatz)
    let mitte = P(basis.x + r.x * l * 0.55 + n.x * versatz * 0.5, basis.y + r.y * l * 0.55 + n.y * versatz * 0.5)
    return Path { p in
        p.move(to: P(basis.x - n.x * b / 2, basis.y - n.y * b / 2))
        p.addQuadCurve(to: spitze, control: P(mitte.x - n.x * b * 0.6, mitte.y - n.y * b * 0.6))
        p.addQuadCurve(to: P(basis.x + n.x * b / 2, basis.y + n.y * b / 2), control: P(mitte.x + n.x * b * 0.6, mitte.y + n.y * b * 0.6))
        p.closeSubpath()
    }
}

/// Ring of tufts around an ellipse (cheek ruff, cotton tail): one tuft per angle in degrees, drooping a little.
func tierKragen(mitte c: CGPoint, rx: CGFloat, ry: CGFloat, winkel: [Double], laenge: CGFloat, breite: CGFloat) -> [Path] {
    winkel.map { (w: Double) -> Path in
        let r = w * Double.pi / 180
        let rechts = cos(r) >= 0
        let basis = P(c.x + rx * CGFloat(cos(r)) * 0.92, c.y + ry * CGFloat(sin(r)) * 0.92)
        return tierBuschel(basis, laenge: laenge, breite: breite, grad: w + (rechts ? 8 : -8), biegung: rechts ? 0.2 : -0.2)
    }
}

/// Short fur strokes in a grid (every other row shifted, tiny deterministic wiggle), clipped to `flaeche`.
/// One path, one stroke: cheap to draw.
func tierFell(_ h: GraphicsContext, in flaeche: Path, bereich: CGRect, abstand: CGFloat, laenge: CGFloat, grad: Double, farbe: Color, breite: CGFloat = 0.8) {
    var innen = h
    innen.clip(to: flaeche)
    let w = grad * Double.pi / 180
    let dx = CGFloat(cos(w)) * laenge
    let dy = CGFloat(sin(w)) * laenge
    var p = Path()
    var zeile = 0
    var y = bereich.minY
    while y <= bereich.maxY {
        var x = bereich.minX + (zeile % 2 == 0 ? 0 : abstand / 2)
        while x <= bereich.maxX {
            let j = CGFloat(sin(Double(zeile * 7) + Double(x) * 3)) * abstand * 0.2
            p.move(to: P(x + j, y))
            p.addQuadCurve(to: P(x + j + dx, y + dy), control: P(x + j + dx * 0.3 + dy * 0.25, y + dy * 0.6 - dx * 0.25))
            x += abstand
        }
        y += abstand * 0.8
        zeile += 1
    }
    innen.stroke(p, with: .color(farbe), style: StrokeStyle(lineWidth: breite, lineCap: .round))
}

/// Soft ground shadow: flat radial gradient (no blur filter).
func tierSchatten(_ h: GraphicsContext, breite: CGFloat) {
    var s = h
    s.translateBy(x: 0, y: 0.8)
    s.scaleBy(x: 1, y: 0.17)
    s.fill(kreis(.zero, breite), with: verlaufRund(.zero, breite, [
        .init(color: .black.opacity(0.34), location: 0),
        .init(color: .black.opacity(0.16), location: 0.6),
        .init(color: .black.opacity(0), location: 1),
    ]))
}

/// Eye with dark rim, gradient iris, pupil (`schlitz` = pupil width relative to the eye) and two highlights.
func tierAuge(_ h: GraphicsContext, _ c: CGPoint, rx: CGFloat, ry: CGFloat, iris: FigurFarbe, schlitz: CGFloat = 0.5) {
    h.fill(oval(c, rx, ry), with: .color(Pal.tinte.farbe))
    h.fill(oval(c, rx * 0.88, ry * 0.9), with: verlaufY(c.y - ry, c.y + ry, [
        .init(color: iris.mal(0.55).farbe, location: 0),
        .init(color: iris.farbe, location: 0.55),
        .init(color: iris.mix(Pal.weiss, 0.45).farbe, location: 1),
    ]))
    h.fill(oval(c, rx * schlitz, ry * 0.78), with: .color(Pal.tinte.farbe))
    h.fill(kreis(P(c.x + rx * 0.5, c.y - ry * 0.4), rx * 0.26), with: .color(.white))
    h.fill(kreis(P(c.x - rx * 0.3, c.y + ry * 0.35), rx * 0.14), with: .color(.white.opacity(0.8)))
}

/// Toe lines on a paw centred at `c`.
func tierZehen(_ h: GraphicsContext, _ c: CGPoint, farbe: Color, abstand: CGFloat = 2.2) {
    for dx in [-abstand / 2, abstand / 2] {
        linie(h, strich(P(c.x + dx, c.y - 1.2), P(c.x + dx, c.y + 1.5)), farbe, 0.7)
    }
}

// MARK: - Dog

private struct HundFarben {
    let f: FigurFarbe
    let dunkel: Bool
    let hell: FigurFarbe
    /// Colour of the fur strokes: lighter than the fur for the black dog, darker for the others.
    let fell: Color

    init(_ f: FigurFarbe) {
        let d = f.r + f.g + f.b < 0.7
        self.f = f
        dunkel = d
        hell = d ? FigurFarbe(0xB07A4F) : f.mix(Pal.weiss, 0.55)
        fell = d ? f.mix(Pal.weiss, 0.3).farbe.opacity(0.55) : f.mal(0.68).farbe.opacity(0.7)
    }
}

/// Dog, side view: floppy ear with inner shade, light snout and chest with tufts, fur strokes, collar with a tag,
/// tongue, paws with toes. `.liegt`: lying with the head on the front paws.
private func hund(_ h: GraphicsContext, _ f: FigurFarbe, pose: HaustierPose) {
    let c = HundFarben(f)
    if pose == .liegt { hundLiegt(h, c) } else { hundSteht(h, c) }
}

private func hundSteht(_ h: GraphicsContext, _ c: HundFarben) {
    let f = c.f, hell = c.hell
    let schwanz = bogen(P(-24, -28), P(-36, -44), P(-38, -31))
    verbunden(h, [
        tierBuschel(P(-36, -43), laenge: 7, breite: 5, grad: -100),
        tierBuschel(P(-36, -41), laenge: 7, breite: 5, grad: -145, biegung: -0.2),
        tierBuschel(P(-35, -44), laenge: 6.5, breite: 4.5, grad: -55),
    ], f, 1.6)
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
        tierZehen(h, P(x + 1.6, -1.8), farbe: f.kontur.opacity(0.8), abstand: 2.4)
    }
    let koerper = oval(P(-2, -26), 26, 13)
    teil(h, koerper, f, 2.4)
    var innen = h
    innen.clip(to: koerper)
    innen.fill(oval(P(-2, -12), 29, 7), with: .color(f.mal(0.82).farbe))
    innen.fill(oval(P(17, -22), 10, 9), with: .color(hell.farbe))
    innen.fill(oval(P(-6, -36), 19, 4), with: .color(.white.opacity(0.14)))
    tierFell(h, in: koerper, bereich: CGRect(x: -28, y: -39, width: 46, height: 27), abstand: 4.6, laenge: 3.4, grad: 70, farbe: c.fell)
    // Chest tufts hang over the light chest.
    for i in 0..<4 {
        teil(h, tierBuschel(P(22, -31 + CGFloat(i) * 4.2), laenge: 5.5, breite: 4.4, grad: 70 + Double(i) * 8), hell, 1.2)
    }
    hundKopf(h, c)
}

private func hundLiegt(_ h: GraphicsContext, _ c: HundFarben) {
    let f = c.f, hell = c.hell
    let schwanz = bogen(P(-22, -8), P(-37, -3), P(-32, -17))
    verbunden(h, [
        tierBuschel(P(-36, -4), laenge: 6, breite: 4.6, grad: 170),
        tierBuschel(P(-35, -5), laenge: 6, breite: 4.4, grad: 205, biegung: -0.2),
    ], f, 1.6)
    linie(h, schwanz, f.kontur, 7.4)
    linie(h, schwanz, f.farbe, 4.8)
    let koerper = oval(P(-6, -11), 23, 10.5)
    teil(h, koerper, f, 2.4)
    var innen = h
    innen.clip(to: koerper)
    innen.fill(oval(P(-6, -3), 26, 5), with: .color(f.mal(0.82).farbe))
    innen.fill(oval(P(-8, -18), 17, 3.4), with: .color(.white.opacity(0.14)))
    tierFell(h, in: koerper, bereich: CGRect(x: -30, y: -22, width: 48, height: 20), abstand: 4.6, laenge: 3.4, grad: 70, farbe: c.fell)
    let keule = oval(P(-16, -10), 10.5, 9)
    teil(h, keule, f.mal(0.92), 1.8)
    tierFell(h, in: keule, bereich: CGRect(x: -28, y: -19, width: 24, height: 18), abstand: 4.2, laenge: 3, grad: 60, farbe: c.fell)
    teil(h, oval(P(-6, -2.6), 7, 2.8), hell.mal(0.9), 1.6)
    var kopf = h
    kopf.translateBy(x: 6, y: 22)
    hundKopf(kopf, c)
    // Front paws in front of the chin.
    teil(h, oval(P(32, -2.8), 7.5, 3), f.mal(0.85), 1.6)
    teil(h, oval(P(38, -2.4), 7.5, 3), hell, 1.6)
    tierZehen(h, P(42, -2.4), farbe: f.kontur.opacity(0.8), abstand: 2.4)
}

/// Head, snout, eye, collar and ear in the standing frame (head centre 25 / -42); the lying view moves it.
private func hundKopf(_ h: GraphicsContext, _ c: HundFarben) {
    let f = c.f, hell = c.hell
    let kopf = oval(P(25, -42), 11.5, 10.5)
    let schnauze = oval(P(34.5, -38.5), 8.5, 5.6)
    verbunden(h, [kopf, schnauze], f, 2.4)
    h.fill(schnauze, with: .color(hell.farbe))
    var gesicht = h
    gesicht.clip(to: kopf)
    gesicht.fill(oval(P(23, -49), 8, 2.6), with: .color(.white.opacity(0.16)))
    tierFell(h, in: kopf, bereich: CGRect(x: 14, y: -52, width: 22, height: 20), abstand: 3.6, laenge: 2.6, grad: 80, farbe: c.fell)
    h.fill(oval(P(37, -32.8), 2, 2.9), with: .color(FigurFarbe(0xF08A9B).farbe))
    h.fill(oval(P(42, -41), 2.9, 2.3), with: .color(Pal.tinte.farbe))
    h.fill(oval(P(41.2, -41.8), 0.9, 0.6), with: .color(.white.opacity(0.7)))
    linie(h, bogen(P(41.5, -36.6), P(33.5, -35.4), P(37.8, -33.4)), Pal.tinte.farbe.opacity(0.85), 0.9)
    for i in 0..<3 {
        h.fill(kreis(P(35.5 + CGFloat(i) * 2.2, -38 + CGFloat(i % 2) * 1.2), 0.5), with: .color(Pal.tinte.farbe.opacity(0.35)))
    }
    if c.dunkel { h.fill(oval(P(28.6, -49), 2.2, 1.4), with: .color(hell.farbe)) }
    tierAuge(h, P(28.8, -45), rx: 2.7, ry: 2.9, iris: FigurFarbe(0x7A4A22), schlitz: 0.62)
    // Collar over the neck, with a round tag.
    let halsband = bogen(P(15.5, -37), P(26.5, -31.5), P(18, -29))
    linie(h, halsband, FigurFarbe(0x8E1C2E).farbe, 4.6)
    linie(h, halsband, FigurFarbe(0xC8283F).farbe, 3.2)
    teil(h, kreis(P(21.8, -28), 2.3), Pal.gold, 1)
    h.fill(kreis(P(21.2, -28.7), 0.7), with: .color(.white.opacity(0.6)))
    let ohr = Path { p in
        p.move(to: P(19, -50))
        p.addQuadCurve(to: P(13.5, -31), control: P(8, -47))
        p.addQuadCurve(to: P(24, -42), control: P(22, -31))
        p.closeSubpath()
    }
    teil(h, ohr, f.mal(0.8), 2)
    var ohrInnen = h
    ohrInnen.clip(to: ohr)
    ohrInnen.fill(oval(P(17, -39), 4, 8.5), with: .color(f.mal(0.58).farbe))
    tierFell(h, in: ohr, bereich: CGRect(x: 8, y: -50, width: 18, height: 20), abstand: 3.4, laenge: 3, grad: 100, farbe: c.fell)
}

// MARK: - Cat

private struct KatzenFarben {
    let f: FigurFarbe
    let iris: FigurFarbe
    let streifen: Color
    let rosa = FigurFarbe(0xF2A6B0)

    init(_ f: FigurFarbe) {
        self.f = f
        iris = f.r - f.b > 0.3 ? FigurFarbe(0x7BC47F) : FigurFarbe(0xE8B93B)
        streifen = f.mal(0.68).farbe
    }
}

/// Sitting cat, front view: pink inner ears with fluff, big eyes with iris and slit pupils, cheek tufts, whiskers,
/// tabby stripes, chest tufts, paws with toes, collar with a bell, tail with a tufted tip (away from the figure).
/// `.liegt`: loaf with the head on the front paws and the tail around the body.
private func katze(_ h: GraphicsContext, _ f: FigurFarbe, pose: HaustierPose) {
    let c = KatzenFarben(f)
    if pose == .liegt { katzeLiegt(h, c) } else { katzeSteht(h, c) }
}

private func katzeSteht(_ h: GraphicsContext, _ c: KatzenFarben) {
    let f = c.f
    let hell = f.mix(Pal.weiss, 0.45)
    let schwanz = Path { p in
        p.move(to: P(-10, -3))
        p.addCurve(to: P(-24, -32), control1: P(-28, -2), control2: P(-32, -20))
    }
    verbunden(h, [
        tierBuschel(P(-24, -31), laenge: 6, breite: 4.4, grad: -100),
        tierBuschel(P(-24, -30), laenge: 5.5, breite: 4, grad: -140, biegung: -0.2),
        tierBuschel(P(-23, -31), laenge: 5.5, breite: 4, grad: -60),
    ], f, 1.6)
    linie(h, schwanz, f.kontur, 8.4)
    linie(h, schwanz, f.farbe, 5.8)
    h.stroke(schwanz, with: .color(c.streifen), style: StrokeStyle(lineWidth: 5.8, dash: [1.4, 5.2], dashPhase: 3))
    linie(h, schwanz.applying(CGAffineTransform(translationX: -1.4, y: 0)), .white.opacity(0.18), 1.2)
    let torso = oval(P(0, -19), 13.5, 18)
    verbunden(h, [oval(P(-10.5, -9), 9, 9), oval(P(10.5, -9), 9, 9), torso], f, 2.4)
    var innen = h
    innen.clip(to: torso)
    innen.fill(oval(P(0, -22), 7.5, 12), with: .color(hell.farbe))
    var rippen = Path()
    for y in [CGFloat(-27), -21, -15] {
        rippen.move(to: P(-14, y))
        rippen.addLine(to: P(-8.6, y + 1.6))
        rippen.move(to: P(14, y))
        rippen.addLine(to: P(8.6, y + 1.6))
    }
    innen.stroke(rippen, with: .color(c.streifen), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
    tierFell(h, in: torso, bereich: CGRect(x: -14, y: -36, width: 28, height: 34), abstand: 4.2, laenge: 3, grad: 85, farbe: .white.opacity(0.2))
    for s: CGFloat in [-1, 1] {
        linie(h, bogen(P(s * 15, -14), P(s * 9, -5), P(s * 14, -6.5)), c.streifen, 1.2)
        teil(h, oval(P(s * 5.6, -3), 4.4, 3), hell, 1.6)
        tierZehen(h, P(s * 5.6, -3), farbe: f.kontur.opacity(0.8), abstand: 2)
    }
    // Chest tufts under the head.
    for i in 0..<3 {
        let x = CGFloat(i - 1) * 3.6
        teil(h, tierBuschel(P(x, -31), laenge: 6, breite: 4, grad: 90 + Double(i - 1) * 14), hell, 1.2)
    }
    katzeKopf(h, c)
}

private func katzeLiegt(_ h: GraphicsContext, _ c: KatzenFarben) {
    let f = c.f
    let hell = f.mix(Pal.weiss, 0.45)
    let schwanz = Path { p in
        p.move(to: P(-17, -8))
        p.addCurve(to: P(-6, -1.4), control1: P(-38, -9), control2: P(-31, 1))
    }
    linie(h, schwanz, f.kontur, 8.4)
    linie(h, schwanz, f.farbe, 5.8)
    h.stroke(schwanz, with: .color(c.streifen), style: StrokeStyle(lineWidth: 5.8, dash: [1.4, 5.2], dashPhase: 2))
    let koerper = oval(P(0, -10), 20, 10)
    verbunden(h, [koerper, oval(P(-10, -11), 11, 10)], f, 2.4)
    tierFell(h, in: koerper, bereich: CGRect(x: -22, y: -22, width: 44, height: 20), abstand: 4.2, laenge: 3, grad: 75, farbe: c.streifen.opacity(0.7))
    var kopf = h
    kopf.translateBy(x: 9, y: 24)
    katzeKopf(kopf, c)
    for x in [CGFloat(3), 15] {
        teil(h, oval(P(x, -2.6), 5, 3.2), hell, 1.6)
        tierZehen(h, P(x, -2.6), farbe: f.kontur.opacity(0.8), abstand: 2)
    }
}

/// Ears, head, face and collar in the standing frame (head centre 0 / -45); the lying view moves it.
private func katzeKopf(_ h: GraphicsContext, _ c: KatzenFarben) {
    let f = c.f
    // Ears behind the head, pink inside with a few fur strokes.
    for s: CGFloat in [-1, 1] {
        let ohr = Path { p in
            p.move(to: P(s * 13.5, -50))
            p.addLine(to: P(s * 11, -64.5))
            p.addLine(to: P(s * 3, -56))
            p.closeSubpath()
        }
        verbunden(h, [ohr, tierBuschel(P(s * 11, -63.5), laenge: 2, breite: 2.4, grad: -90 + Double(s) * 8)], f, 2.2)
        let innenOhr = Path { p in
            p.move(to: P(s * 11.2, -52.5))
            p.addLine(to: P(s * 10.2, -60.5))
            p.addLine(to: P(s * 5.6, -55.5))
            p.closeSubpath()
        }
        h.fill(innenOhr, with: .color(c.rosa.farbe))
        h.fill(kippe(oval(P(s * 8.6, -55.6), 1.7, 3.6), um: P(s * 8.6, -55.6), grad: Double(s) * 28), with: .color(c.rosa.mal(0.82).farbe))
        for dx: CGFloat in [-1.6, 0, 1.6] {
            linie(h, strich(P(s * (8.4 + dx), -54.6), P(s * (8.6 + dx * 1.3), -58.6)), f.mix(Pal.weiss, 0.5).farbe.opacity(0.7), 0.55)
        }
    }
    let kopf = oval(P(0, -45), 14.5, 12.5)
    let ruff = tierKragen(mitte: P(0, -45), rx: 14.5, ry: 12.5, winkel: [20, 45, 135, 160], laenge: 3.6, breite: 4.4)
    verbunden(h, [kopf] + ruff, f, 2.4)
    var gesicht = h
    gesicht.clip(to: kopf)
    for s: CGFloat in [-1, 1] { gesicht.fill(oval(P(s * 8, -40), 6, 4), with: .color(f.mix(Pal.weiss, 0.5).farbe.opacity(0.7))) }
    gesicht.fill(oval(P(-3, -54), 8, 2.6), with: .color(.white.opacity(0.2)))
    var stirn = Path()
    for x in [CGFloat(-3.4), 0, 3.4] {
        stirn.move(to: P(x, -58))
        stirn.addLine(to: P(x * 0.8, -52.5))
    }
    gesicht.stroke(stirn, with: .color(c.streifen), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
    tierFell(h, in: kopf, bereich: CGRect(x: -14, y: -56, width: 28, height: 22), abstand: 3.6, laenge: 2.6, grad: 90, farbe: .white.opacity(0.18))
    for s: CGFloat in [-1, 1] {
        tierAuge(h, P(s * 5.6, -46.5), rx: 3.7, ry: 4.1, iris: c.iris, schlitz: 0.26)
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
    h.fill(kreis(P(-0.5, -42.2), 0.5), with: .color(.white.opacity(0.55)))
    for s: CGFloat in [-1, 1] { linie(h, bogen(P(0, -40.4), P(s * 3.4, -38.6), P(s * 1.4, -37.8)), Pal.tinte.farbe.opacity(0.7), 0.7) }
    // Collar and bell.
    let halsband = bogen(P(-9.5, -34.5), P(9.5, -34.5), P(0, -30))
    linie(h, halsband, FigurFarbe(0x8E1C2E).farbe, 4)
    linie(h, halsband, FigurFarbe(0xC8283F).farbe, 2.8)
    teil(h, kreis(P(0, -29), 2.4), Pal.gold, 1)
    h.fill(box(-1.6, -29.4, 3.2, 0.7), with: .color(Pal.gold.mal(0.5).farbe))
    h.fill(kreis(P(-0.8, -30), 0.7), with: .color(.white.opacity(0.6)))
}

// MARK: - Rabbit

/// Sitting rabbit, front view: tall ears with pink inside and fur strokes, round cheeks with tufts, eyes with iris,
/// front paws, cotton tail with tufts, long hind feet. `.liegt`: loaf with the head up and the hind feet out.
private func hase(_ h: GraphicsContext, _ f: FigurFarbe, pose: HaustierPose) {
    let rosa = FigurFarbe(0xF4B6C0)
    let fell = f.mal(0.78).farbe.opacity(0.55)
    if pose == .liegt {
        haseSchwanz(h, f, mitte: P(-22, -9))
        let koerper = oval(P(-3, -9.5), 20, 9.5)
        teil(h, koerper, f, 2.4)
        tierFell(h, in: koerper, bereich: CGRect(x: -24, y: -20, width: 42, height: 18), abstand: 4, laenge: 3, grad: 80, farbe: fell)
        teil(h, oval(P(-9, -9), 10, 8), f.mal(0.96), 1.8)
        teil(h, oval(P(-9, -2.6), 11, 3.2), f, 1.8)
        var kopf = h
        kopf.translateBy(x: 13, y: 17)
        haseKopf(kopf, f, rosa: rosa, fell: fell)
        for x in [CGFloat(10), 17] {
            teil(h, oval(P(x, -2.4), 3.6, 2.8), f.mix(Pal.weiss, 0.1), 1.6)
            tierZehen(h, P(x, -2.4), farbe: f.kontur.opacity(0.7), abstand: 1.8)
        }
        return
    }
    haseSchwanz(h, f, mitte: P(14, -9))
    let torso = oval(P(0, -15), 14, 15)
    teil(h, torso, f, 2.4)
    var innen = h
    innen.clip(to: torso)
    innen.fill(oval(P(0, -13), 8.5, 11), with: .color(f.mal(0.94).farbe))
    tierFell(h, in: torso, bereich: CGRect(x: -14, y: -30, width: 28, height: 28), abstand: 4, laenge: 3, grad: 80, farbe: fell)
    for s: CGFloat in [-1, 1] {
        teil(h, oval(P(s * 11, -3.4), 6.4, 3.2), f, 1.8)
        teil(h, oval(P(s * 4.6, -3), 3.6, 3.2), f.mix(Pal.weiss, 0.1), 1.6)
        tierZehen(h, P(s * 4.6, -3), farbe: f.kontur.opacity(0.7), abstand: 1.8)
    }
    haseKopf(h, f, rosa: rosa, fell: fell)
}

private func haseSchwanz(_ h: GraphicsContext, _ f: FigurFarbe, mitte: CGPoint) {
    let schwanz = kreis(mitte, 5.4)
    let flaum = tierKragen(mitte: mitte, rx: 5.4, ry: 5.4, winkel: [0, 45, 90, 135, 180, 225, 270, 315], laenge: 3, breite: 3.4)
    verbunden(h, [schwanz] + flaum, f, 1.8)
    h.fill(kreis(P(mitte.x - 1.6, mitte.y - 1.6), 1.6), with: .color(.white.opacity(0.7)))
}

/// Ears, head and face in the sitting frame (head centre 0 / -36); the lying view moves it.
private func haseKopf(_ h: GraphicsContext, _ f: FigurFarbe, rosa: FigurFarbe, fell: Color) {
    let ohrenGrad: [(CGFloat, Double)] = [(-6, -8), (6, 8)]
    for (x, grad) in ohrenGrad {
        let aussen = kippe(oval(P(x, -60), 4, 13.5), um: P(x, -48), grad: grad)
        teil(h, aussen, f, 2.2)
        h.fill(kippe(oval(P(x, -59.5), 2.4, 10.4), um: P(x, -48), grad: grad), with: .color(rosa.farbe))
        h.fill(kippe(oval(P(x, -54), 1.6, 5), um: P(x, -48), grad: grad), with: .color(rosa.mal(0.88).farbe))
        for dx: CGFloat in [-1, 1] {
            linie(h, kippe(strich(P(x + dx, -66), P(x + dx * 0.6, -58)), um: P(x, -48), grad: grad), f.mix(Pal.weiss, 0.6).farbe.opacity(0.6), 0.5)
        }
    }
    let kopf = oval(P(0, -36), 11.5, 10.5)
    let backen = tierKragen(mitte: P(0, -34), rx: 11.5, ry: 8, winkel: [15, 40, 140, 165], laenge: 3.2, breite: 4)
    verbunden(h, [kopf] + backen, f, 2.4)
    var gesicht = h
    gesicht.clip(to: kopf)
    gesicht.fill(oval(P(-2, -43), 6.5, 2.3), with: .color(.white.opacity(0.35)))
    tierFell(h, in: kopf, bereich: CGRect(x: -11, y: -46, width: 22, height: 20), abstand: 3.4, laenge: 2.4, grad: 90, farbe: fell)
    for s: CGFloat in [-1, 1] {
        h.fill(kreis(P(s * 7, -32.4), 2.6), with: .color(rosa.farbe.opacity(0.5)))
        tierAuge(h, P(s * 4.8, -38), rx: 2.3, ry: 2.6, iris: FigurFarbe(0x6B3A2A), schlitz: 0.62)
        for i in 0..<3 {
            let dy = CGFloat(i) * 1.5
            linie(h, strich(P(s * 6.6, -33.2 + dy), P(s * 16.5, -35 + dy * 2.4)), Pal.tinte.farbe.opacity(0.4), 0.55)
        }
    }
    h.fill(oval(P(0, -34.2), 1.9, 1.4), with: .color(rosa.mal(0.85).farbe))
    h.fill(kreis(P(-0.5, -34.5), 0.5), with: .color(.white.opacity(0.55)))
    linie(h, strich(P(0, -33), P(0, -31.6)), Pal.tinte.farbe.opacity(0.6), 0.7)
    linie(h, bogen(P(0, -31.6), P(-2.6, -30.4), P(-1.4, -30.6)), Pal.tinte.farbe.opacity(0.6), 0.7)
    linie(h, bogen(P(0, -31.6), P(2.6, -30.4), P(1.4, -30.6)), Pal.tinte.farbe.opacity(0.6), 0.7)
    h.fill(box(-1, -31.4, 2, 2.2, 0.5), with: .color(.white.opacity(0.9)))
}

// MARK: - Bird

/// Budgie: blue body with scale rows, pale face with a violet cheek patch and throat spots, orange beak and feet,
/// wing with layered feathers, long tail feathers. `.liegt`: sitting with a rounder, lower body and a fluffed
/// belly, no feet.
private func vogel(_ h: GraphicsContext, _ f: FigurFarbe, pose: HaustierPose) {
    let sitzt = pose == .liegt
    let orange = FigurFarbe(0xF2A33C)
    var b = h
    if sitzt { b.scaleBy(x: 1.06, y: 0.9) }
    if !sitzt {
        for x in [CGFloat(-2), 4] {
            linie(b, strich(P(x, -9), P(x, -1.2)), orange.mal(0.85).farbe, 1.7)
            linie(b, strich(P(x - 2.4, -0.7), P(x + 2.8, -0.7)), orange.mal(0.85).farbe, 1.5)
            linie(b, strich(P(x + 2.8, -0.7), P(x + 3.4, -2)), orange.mal(0.85).farbe, 1.2)
        }
    }
    let schwaenze: [(CGFloat, CGFloat)] = [(0, 0), (-3, -1.2)]
    for (dx, dy) in schwaenze {
        let schwanz = Path { p in
            p.move(to: P(-4 + dx * 0.3, -17))
            p.addLine(to: P(-18 + dx, -3 + dy))
            p.addLine(to: P(-13 + dx, -1 + dy))
            p.addLine(to: P(0, -10))
            p.closeSubpath()
        }
        teil(b, schwanz, f.mal(dx == 0 ? 0.78 : 0.66), 1.8)
    }
    linie(b, strich(P(-5, -13), P(-14.5, -4)), f.mix(Pal.weiss, 0.4).farbe.opacity(0.8), 0.8)
    let koerper = oval(P(0, -24), 11.5, 15.5)
    let kopf = kreis(P(3.5, -43), 9.5)
    var bauch: [Path] = []
    if sitzt {
        for x in stride(from: CGFloat(-9), through: 9, by: 4.5) {
            bauch.append(tierBuschel(P(x, -9), laenge: 4.4, breite: 4.6, grad: 90 + Double(x) * 1.2, biegung: 0.1))
        }
    }
    verbunden(b, [koerper, kopf] + bauch, f, 2.2)
    var innen = b
    innen.clip(to: koerper)
    innen.fill(oval(P(5.5, -22), 7, 11), with: .color(f.mix(Pal.weiss, 0.32).farbe))
    // Scale rows on the belly.
    var federn = Path()
    for reihe in 0..<4 {
        let y = CGFloat(-12 - reihe * 6)
        for spalte in 0..<3 {
            let x = CGFloat(spalte) * 5.4 - 1 + (reihe % 2 == 0 ? 0 : 2.7)
            federn.addPath(bogen(P(x - 2.6, y), P(x + 2.6, y), P(x, y + 3.2)))
        }
    }
    innen.stroke(federn, with: .color(f.mix(Pal.weiss, 0.55).farbe.opacity(0.5)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
    innen.fill(oval(P(-4, -32), 3, 8), with: .color(.white.opacity(0.14)))
    b.fill(oval(P(6, -42.6), 6.4, 6.8), with: .color(f.mix(Pal.weiss, 0.82).farbe))
    b.fill(oval(P(1.2, -40), 2.4, 1.8), with: .color(FigurFarbe(0x7C6AD8).farbe.opacity(0.85)))
    for p in [P(2.4, -38.2), P(5.6, -37.4), P(8.2, -38.6)] { b.fill(kreis(p, 0.9), with: .color(f.mal(0.55).farbe)) }
    let auge = P(8, -45)
    b.fill(kreis(auge, 3), with: .color(.white))
    b.fill(kreis(auge, 1.9), with: .color(Pal.tinte.farbe))
    b.fill(kreis(P(auge.x + 0.6, auge.y - 0.7), 0.6), with: .color(.white))
    let schnabel = Path { p in
        p.move(to: P(11.4, -46.5))
        p.addQuadCurve(to: P(17.6, -41.6), control: P(17, -46.6))
        p.addQuadCurve(to: P(11.6, -40.6), control: P(15.4, -39.4))
        p.closeSubpath()
    }
    teil(b, schnabel, orange, 1.2)
    b.fill(oval(P(13.4, -45), 1.8, 0.8), with: .color(.white.opacity(0.45)))
    // Wing: base plus three overlapping feather strips.
    let fluegel = kippe(oval(P(-3.5, -24), 6, 12.5), um: P(-3.5, -24), grad: 10)
    teil(b, fluegel, f.mal(0.74), 1.8)
    var fl = b
    fl.clip(to: fluegel)
    for dy in [CGFloat(-5), 0, 5] {
        fl.fill(oval(P(-3.5, -19 + dy), 7, 3.2), with: .color(f.mal(0.62 + Double(dy + 5) * 0.012).farbe))
        linie(fl, bogen(P(-9.5, -19 + dy), P(2.5, -19 + dy), P(-3.5, -16.2 + dy)), f.mix(Pal.weiss, 0.45).farbe.opacity(0.7), 0.8)
    }
}
