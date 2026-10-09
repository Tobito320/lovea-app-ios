import SwiftUI

/// p57: black fluffy cat ("Kuschelkatze"), all vector. Long fur is drawn as tufts: the silhouette itself is
/// scalloped (cheek ruff, chest ruff, fur skirt, bushy tail), inside there are lighter fur strokes and soft
/// highlights so the black does not turn into a flat blob. Big amber eyes with highlights, pink nose, whiskers.
/// Sitting front view like the other cats, tail away from the figure. `.liegt`: loaf with the head on the paws.
/// Nothing animates and nothing is loaded: every call draws a few dozen paths.
private struct KuschelFarben {
    let fell: FigurFarbe
    let rand = FigurFarbe(0x08080C)
    /// Mid tone for tufts and cheeks, light tone for rim light and strokes (both still dark).
    let mitte: FigurFarbe
    let glanz: FigurFarbe
    let iris = FigurFarbe(0xF2B52E)
    let rosa = FigurFarbe(0xE88BA0)

    init(_ f: FigurFarbe) {
        fell = f
        mitte = f.mix(FigurFarbe(0x6A6B88), 0.3)
        glanz = f.mix(FigurFarbe(0x9A9BBB), 0.55)
    }
}

/// Fill plus the near-black outline (the derived `kontur` of a black fur would be invisible).
private func kTeil(_ h: GraphicsContext, _ p: Path, _ c: FigurFarbe, _ k: KuschelFarben, _ breite: CGFloat = 2.2) {
    h.fill(p, with: .color(c.farbe))
    h.stroke(p, with: .color(k.rand.farbe), style: StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round))
}

/// Several overlapping parts as one fur piece: all outlines first, then all fills.
private func kVerbunden(_ h: GraphicsContext, _ teile: [Path], _ c: FigurFarbe, _ k: KuschelFarben, _ breite: CGFloat = 2.2) {
    for p in teile { h.stroke(p, with: .color(k.rand.farbe), style: StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round)) }
    for p in teile { h.fill(p, with: .color(c.farbe)) }
}

/// Point and direction (degrees) on a cubic curve.
private func kubisch(_ t: CGFloat, _ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> (punkt: CGPoint, grad: Double) {
    let u: CGFloat = 1 - t
    let w0: CGFloat = u * u * u
    let w1: CGFloat = 3 * u * u * t
    let w2: CGFloat = 3 * u * t * t
    let w3: CGFloat = t * t * t
    let x: CGFloat = w0 * a.x + w1 * b.x + w2 * c.x + w3 * d.x
    let y: CGFloat = w0 * a.y + w1 * b.y + w2 * c.y + w3 * d.y
    let v0: CGFloat = 3 * u * u
    let v1: CGFloat = 6 * u * t
    let v2: CGFloat = 3 * t * t
    let dx: CGFloat = v0 * (b.x - a.x) + v1 * (c.x - b.x) + v2 * (d.x - c.x)
    let dy: CGFloat = v0 * (b.y - a.y) + v1 * (c.y - b.y) + v2 * (d.y - c.y)
    return (P(x, y), atan2(Double(dy), Double(dx)) * 180 / Double.pi)
}

/// Bushy tail along the cubic `a b c d`: thick round stroke outline plus tufts on both sides and at the tip.
private func kuschelSchwanz(_ h: GraphicsContext, _ k: KuschelFarben, _ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint, breite: CGFloat) {
    let linieForm = Path { p in
        p.move(to: a)
        p.addCurve(to: d, control1: b, control2: c)
    }
    let form = linieForm.strokedPath(StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round))
    var teile: [Path] = [form]
    var haare = Path()
    for t: CGFloat in [0.3, 0.55, 0.8] {
        let m = kubisch(t, a, b, c, d)
        let r = m.grad * Double.pi / 180
        for s: CGFloat in [-1, 1] {
            let basis = P(m.punkt.x - CGFloat(sin(r)) * s * breite * 0.42, m.punkt.y + CGFloat(cos(r)) * s * breite * 0.42)
            let g = m.grad + Double(s) * 45
            teile.append(tierBuschel(basis, laenge: 8, breite: 7, grad: g, biegung: 0.25 * s))
            haare.move(to: basis)
            haare.addLine(to: P(basis.x + CGFloat(cos(g * Double.pi / 180)) * 7, basis.y + CGFloat(sin(g * Double.pi / 180)) * 7))
        }
    }
    for w in [-90.0, -60, -120] {
        teile.append(tierBuschel(d, laenge: 7.5, breite: 6.5, grad: w))
    }
    kVerbunden(h, teile, k.fell, k, 2)
    h.stroke(haare, with: .color(k.glanz.farbe.opacity(0.5)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    linie(h, linieForm.applying(CGAffineTransform(translationX: 2.2, y: 0)), k.glanz.farbe.opacity(0.35), 1.6)
    linie(h, linieForm.applying(CGAffineTransform(translationX: -2.4, y: 0)), k.glanz.farbe.opacity(0.18), 1.1)
}

private func kuschelPfote(_ h: GraphicsContext, _ k: KuschelFarben, _ c: CGPoint) {
    kTeil(h, oval(c, 5.6, 3.5), k.fell, k, 1.8)
    h.fill(oval(P(c.x - 0.6, c.y - 1.5), 3.4, 1.1), with: .color(k.glanz.farbe.opacity(0.35)))
    for dx: CGFloat in [-1.6, 1.6] {
        linie(h, strich(P(c.x + dx, c.y - 0.6), P(c.x + dx, c.y + 2.2)), k.rand.farbe.opacity(0.9), 0.7)
    }
    for dx: CGFloat in [-3, 0, 3] {
        h.fill(tierBuschel(P(c.x + dx, c.y + 2.4), laenge: 2.2, breite: 2.4, grad: 90), with: .color(k.fell.farbe))
    }
}

func kuschelKatze(_ h: GraphicsContext, _ f: FigurFarbe, pose: HaustierPose) {
    let k = KuschelFarben(f)
    if pose == .liegt { kuschelLiegt(h, k) } else { kuschelSteht(h, k) }
}

private func kuschelSteht(_ h: GraphicsContext, _ k: KuschelFarben) {
    let f = k.fell
    kuschelSchwanz(h, k, P(-9, -5), P(-20, -2), P(-26, -22), P(-19, -44), breite: 12)
    let torso = oval(P(0, -19), 15.5, 19)
    var teile: [Path] = [torso, oval(P(-11.5, -9.5), 9.5, 9.5), oval(P(11.5, -9.5), 9.5, 9.5)]
    for x in stride(from: CGFloat(-16), through: 16, by: 4.4) {
        teile.append(tierBuschel(P(x, -4), laenge: 5, breite: 5.2, grad: 90 + Double(x) * 0.8, biegung: 0.1))
    }
    for s: CGFloat in [-1, 1] { teile.append(box(s * 5.8 - 4, -24, 8, 22, 4)) }
    kVerbunden(h, teile, f, k, 2.2)
    var innen = h
    innen.clip(to: torso)
    innen.fill(oval(P(0, -22), 9, 13), with: .color(k.mitte.farbe.opacity(0.5)))
    innen.fill(kippe(oval(P(-7, -27), 3.4, 9), um: P(-7, -27), grad: 12), with: .color(k.glanz.farbe.opacity(0.22)))
    tierFell(h, in: torso, bereich: CGRect(x: -16, y: -38, width: 32, height: 36), abstand: 4.4, laenge: 3.6, grad: 85, farbe: k.glanz.farbe.opacity(0.4))
    for s: CGFloat in [-1, 1] { kuschelPfote(h, k, P(s * 5.8, -3.2)) }
    // Chest ruff under the head, lighter than the back.
    var ruff: [Path] = []
    for i in 0..<7 {
        let x = CGFloat(i - 3) * 3
        ruff.append(tierBuschel(P(x, -31), laenge: 8 - abs(x) * 0.35, breite: 5.4, grad: 90 + Double(x) * 2.2))
    }
    kVerbunden(h, ruff, k.mitte, k, 1.4)
    kuschelKopf(h, k)
}

private func kuschelLiegt(_ h: GraphicsContext, _ k: KuschelFarben) {
    let f = k.fell
    kuschelSchwanz(h, k, P(-19, -11), P(-38, -15), P(-36, -8), P(-8, -8), breite: 11)
    let koerper = oval(P(0, -11), 22, 11)
    var teile: [Path] = [koerper, oval(P(-11, -12), 12, 11)]
    for x in stride(from: CGFloat(-22), through: 22, by: 4.4) {
        teile.append(tierBuschel(P(x, -3), laenge: 5, breite: 5.2, grad: 90 + Double(x) * 0.6, biegung: 0.1))
    }
    kVerbunden(h, teile, f, k, 2.2)
    var innen = h
    innen.clip(to: koerper)
    innen.fill(kippe(oval(P(-4, -19), 12, 3), um: P(-4, -19), grad: -6), with: .color(k.glanz.farbe.opacity(0.25)))
    tierFell(h, in: koerper, bereich: CGRect(x: -24, y: -24, width: 48, height: 24), abstand: 4.4, laenge: 3.6, grad: 75, farbe: k.glanz.farbe.opacity(0.4))
    var kopf = h
    kopf.translateBy(x: 9, y: 24)
    kuschelKopf(kopf, k)
    for x in [CGFloat(3), 16] { kuschelPfote(h, k, P(x, -3.2)) }
}

/// Ears, head with cheek ruff, face, whiskers and collar in the sitting frame (head centre 0 / -45); the lying
/// view moves it.
private func kuschelKopf(_ h: GraphicsContext, _ k: KuschelFarben) {
    let f = k.fell
    // Ears behind the head: fur tuft on the tip, dark pink inside with a few fur strokes.
    for s: CGFloat in [-1, 1] {
        let ohr = Path { p in
            p.move(to: P(s * 15, -52))
            p.addQuadCurve(to: P(s * 12.5, -69), control: P(s * 17, -62))
            p.addQuadCurve(to: P(s * 3.5, -58), control: P(s * 6, -66))
            p.closeSubpath()
        }
        kVerbunden(h, [ohr, tierBuschel(P(s * 12.5, -67.5), laenge: 4.6, breite: 3, grad: -90 + Double(s) * 8)], f, k, 2.2)
        let innenOhr = Path { p in
            p.move(to: P(s * 12.6, -54.5))
            p.addQuadCurve(to: P(s * 11.6, -64), control: P(s * 14, -60))
            p.addQuadCurve(to: P(s * 6, -58), control: P(s * 7, -62))
            p.closeSubpath()
        }
        h.fill(innenOhr, with: .color(k.rosa.mal(0.6).farbe))
        let fusseln: [(CGFloat, CGFloat, CGFloat)] = [(9, 9.6, -61), (7.6, 7.2, -60.4), (10.6, 11.6, -59.5)]
        for (x0, x1, y1) in fusseln {
            linie(h, strich(P(s * x0, -56), P(s * x1, y1)), k.glanz.farbe.opacity(0.65), 0.7)
        }
    }
    let kopf = oval(P(0, -45), 17, 14)
    var kopfTeile: [Path] = [kopf]
    kopfTeile += tierKragen(mitte: P(0, -45), rx: 17, ry: 14, winkel: [10, 30, 52, 72, 90, 108, 128, 150, 170], laenge: 6.5, breite: 6.4)
    kopfTeile += tierKragen(mitte: P(0, -45), rx: 17, ry: 14, winkel: [215, 240, 265, 290, 315], laenge: 3.2, breite: 4)
    kVerbunden(h, kopfTeile, f, k, 2.2)
    var gesicht = h
    gesicht.clip(to: kopf)
    gesicht.fill(kippe(oval(P(-5, -55), 10, 3.2), um: P(-5, -55), grad: -8), with: .color(k.glanz.farbe.opacity(0.3)))
    for s: CGFloat in [-1, 1] { gesicht.fill(oval(P(s * 9, -39), 6, 4), with: .color(k.mitte.farbe.opacity(0.5))) }
    gesicht.fill(oval(P(0, -38.5), 6.5, 4.2), with: .color(k.mitte.farbe.opacity(0.55)))
    var stirn = Path()
    for x in [CGFloat(-3.4), 0, 3.4] {
        stirn.move(to: P(x, -58))
        stirn.addLine(to: P(x * 0.8, -52.5))
    }
    gesicht.stroke(stirn, with: .color(k.glanz.farbe.opacity(0.5)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
    tierFell(h, in: kopf, bereich: CGRect(x: -17, y: -58, width: 34, height: 26), abstand: 4.4, laenge: 3.4, grad: 90, farbe: k.glanz.farbe.opacity(0.4))
    // Rim light on the upper left edge.
    linie(h, bogen(P(-15.5, -50), P(-5, -58.6), P(-14, -58)), k.glanz.farbe.opacity(0.55), 1.1)
    for s: CGFloat in [-1, 1] {
        tierAuge(h, P(s * 6.8, -46.2), rx: 4.7, ry: 5.2, iris: k.iris, schlitz: 0.42)
        linie(h, bogen(P(s * 2.6, -51.4), P(s * 10.6, -51.8), P(s * 6.4, -53.4)), k.rand.farbe, 1.1)
    }
    // Nose and mouth.
    let nase = Path { p in
        p.move(to: P(-2.2, -42.4))
        p.addQuadCurve(to: P(2.2, -42.4), control: P(0, -43.6))
        p.addQuadCurve(to: P(0, -39.8), control: P(2.4, -40.8))
        p.addQuadCurve(to: P(-2.2, -42.4), control: P(-2.4, -40.8))
        p.closeSubpath()
    }
    h.fill(nase, with: .color(k.rosa.farbe))
    h.fill(oval(P(-0.6, -42.5), 0.9, 0.5), with: .color(.white.opacity(0.6)))
    for s: CGFloat in [-1, 1] {
        linie(h, bogen(P(0, -39.8), P(s * 3.4, -38), P(s * 1.4, -37.2)), k.glanz.farbe.opacity(0.85), 0.7)
        // Whiskers and brow whiskers, light so they show on the black fur.
        for i in 0..<3 {
            let y0 = -40.6 + CGFloat(i) * 1.5
            let y1 = -44.5 + CGFloat(i) * 3.8
            linie(h, bogen(P(s * 8, y0), P(s * 25, y1), P(s * 16, y0 - 2.8 + CGFloat(i) * 1.2)), Color(red: 0.77, green: 0.77, blue: 0.83).opacity(0.75), 0.55)
        }
        linie(h, bogen(P(s * 7.5, -52.5), P(s * 14, -56.5), P(s * 11, -55.6)), Color(red: 0.77, green: 0.77, blue: 0.83).opacity(0.6), 0.5)
    }
    // Collar and bell.
    let halsband = bogen(P(-11, -33.5), P(11, -33.5), P(0, -27.5))
    linie(h, halsband, FigurFarbe(0x8E1C2E).farbe, 4.4)
    linie(h, halsband, FigurFarbe(0xC8283F).farbe, 3)
    teil(h, kreis(P(0, -28.4), 2.5), Pal.gold, 1)
    h.fill(box(-1.7, -28.8, 3.4, 0.7), with: .color(Pal.gold.mal(0.5).farbe))
    h.fill(kreis(P(-0.8, -29.4), 0.7), with: .color(.white.opacity(0.65)))
}

/// `p` rotated by `grad` degrees around `c`.
private func kippe(_ p: Path, um c: CGPoint, grad: Double) -> Path {
    let t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: grad * .pi / 180).translatedBy(x: -c.x, y: -c.y)
    return p.applying(t)
}
