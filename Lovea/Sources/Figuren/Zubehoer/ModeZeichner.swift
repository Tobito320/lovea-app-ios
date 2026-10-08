import SwiftUI

/// p48: detailed drawings for the kept shop fashion (hoodies, blouses, denim and puffer jacket, cargo pants,
/// sneaker). `FigurView` calls these from the existing index cases; they only use the shared vector helpers.

/// True when `a` is (almost) the colour `hex`; shop parts tell brands apart by their fixed colour.
private func nah(_ a: FigurFarbe, _ hex: UInt32) -> Bool {
    let b = FigurFarbe(hex)
    return abs(a.r - b.r) + abs(a.g - b.g) + abs(a.b - b.b) < 0.04
}

private func schrift(_ g: GraphicsContext, _ s: String, _ c: CGPoint, _ groesse: CGFloat, _ farbe: Color) {
    g.draw(Text(s).font(.system(size: groesse, weight: .heavy, design: .rounded)).foregroundStyle(farbe), at: c)
}

private let messingMode = FigurFarbe(0xD9B25A)

/// A swoosh check mark with its tip to the upper right. `breite` is its width, `mitte` its centre.
func swooshPfad(_ mitte: CGPoint, breite: CGFloat) -> Path {
    let k = breite / 22
    var p = Path()
    p.move(to: P(12, -6.5))
    p.addCurve(to: P(-10, -3.5), control1: P(6, 1), control2: P(-4, 8))
    p.addQuadCurve(to: P(-7.5, -5.8), control: P(-10.5, -6))
    p.addCurve(to: P(12, -6.5), control1: P(-3, 0.5), control2: P(4, -1.5))
    p.closeSubpath()
    return p.applying(CGAffineTransform(translationX: mitte.x - k, y: mitte.y + 2 * k).scaledBy(x: k, y: k))
}

// MARK: - Hoodie (oberteil 14: Nike, Guess)

/// Half-figure space like `oberteilDetails`: `g` draws freely, `h` is clipped to the torso.
func zeichneHoodie(_ g: GraphicsContext, _ h: GraphicsContext, top: FigurFarbe) {
    let schnur = top.mix(Pal.weiss, 0.82)
    let nike = nah(top, 0x2B2830)
    let guess = nah(top, 0x8E8C93)
    // The flanks fall into shade.
    h.fill(Path(CGRect(x: 40, y: 150, width: 40, height: 200)),
           with: .linearGradient(Gradient(colors: [.black.opacity(0.2), .black.opacity(0)]), startPoint: P(46, 0), endPoint: P(80, 0)))
    h.fill(Path(CGRect(x: 120, y: 150, width: 40, height: 200)),
           with: .linearGradient(Gradient(colors: [.black.opacity(0), .black.opacity(0.2)]), startPoint: P(120, 0), endPoint: P(154, 0)))
    // Raglan seams from the neck to the armpit.
    for seite: CGFloat in [-1, 1] {
        let naht = bogen(P(100 + seite * 29, 167), P(100 + seite * 41, 206), P(100 + seite * 38, 181))
        linie(h, naht, top.kontur.opacity(0.55), 1.3)
        linie(h, naht.offsetBy(dx: -seite * 1.6, dy: 0), schnur.farbe.opacity(0.22), 0.8)
    }
    // Kangaroo pocket and ribbed hem (they show on the full body).
    let tasche = Path { p in
        p.move(to: P(64, 232))
        p.addLine(to: P(136, 232))
        p.addLine(to: P(148, 288))
        p.addLine(to: P(52, 288))
        p.closeSubpath()
    }
    teil(h, tasche, top.mal(0.94), 2)
    h.fill(box(66, 233, 68, 2.4, 1), with: .color(.white.opacity(0.1)))
    for seite: CGFloat in [-1, 1] {
        linie(h, strich(P(100 + seite * 35, 235), P(100 + seite * 42, 266)), top.kontur.opacity(0.6), 1.6)
    }
    h.fill(box(20, 304, 160, 30), with: .color(top.mal(0.88).farbe))
    linie(h, strich(P(20, 304), P(180, 304)), top.kontur.opacity(0.6), 1.6)
    var rippen = Path()
    for x in stride(from: CGFloat(24), to: 180, by: 5) {
        rippen.move(to: P(x, 306))
        rippen.addLine(to: P(x, 334))
    }
    h.stroke(rippen, with: .color(top.kontur.opacity(0.3)), lineWidth: 0.9)
    // A few folds across the belly.
    linie(h, bogen(P(66, 219), P(98, 227), P(80, 228)), top.kontur.opacity(0.22), 1.2)
    linie(h, bogen(P(134, 221), P(108, 229), P(122, 229)), top.kontur.opacity(0.22), 1.2)
    // Hood: a thick cowl around the neck with a dark inside and a lit rim.
    let kapuze = Path { p in
        p.move(to: P(64, 158))
        p.addQuadCurve(to: P(136, 158), control: P(100, 214))
        p.addQuadCurve(to: P(64, 158), control: P(100, 170))
    }
    teil(g, kapuze, top.mal(0.94), 2.4)
    let innen = Path { p in
        p.move(to: P(73, 159))
        p.addQuadCurve(to: P(127, 159), control: P(100, 189))
        p.addQuadCurve(to: P(73, 159), control: P(100, 170))
    }
    g.fill(innen, with: .color(top.mal(0.5).farbe.opacity(0.6)))
    linie(g, bogen(P(69, 164), P(131, 164), P(100, 207)), .white.opacity(0.12), 2)
    // Drawstrings with metal tips and eyelets.
    for (x, dx, laenge) in [(CGFloat(91), CGFloat(-1), CGFloat(32)), (109, 1, CGFloat(29))] {
        let schnurPfad = bogen(P(x, 187), P(x + dx * 1.4, 187 + laenge), P(x + dx * 3, 187 + laenge * 0.5))
        linie(g, schnurPfad, top.kontur.opacity(0.55), 3.4)
        linie(g, schnurPfad, schnur.farbe, 2.1)
        g.fill(box(x + dx * 1.4 - 1.3, 187 + laenge - 1, 2.6, 5.5, 1.1), with: .color(Pal.silber.farbe))
        g.fill(kreis(P(x, 187), 1.5), with: .color(Pal.silber.mal(0.85).farbe))
    }
    if nike {
        let mark = swooshPfad(P(126, 200), breite: 25)
        g.fill(mark.offsetBy(dx: 0.7, dy: 1), with: .color(.black.opacity(0.3)))
        g.fill(mark, with: .color(.white))
    } else if guess {
        let dreieck = Path { p in
            p.move(to: P(87, 190))
            p.addLine(to: P(113, 190))
            p.addLine(to: P(100, 212))
            p.closeSubpath()
        }
        g.fill(dreieck, with: .color(FigurFarbe(0xC8283F).farbe))
        g.stroke(dreieck, with: .color(.white), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
        schrift(g, "GUESS", P(100, 195.2), 5.2, .white)
    } else {
        teil(h, kreis(P(100, 210), 9), Pal.gold, 2)
    }
}

// MARK: - Blouse (oberteil 16: silk blouse, Dior)

/// Same spaces as `zeichneHoodie`. White (F4F1EE) is the Dior blouse: pointed collar, pearl placket.
/// Every other colour is the silk blouse with a tie-neck bow.
func zeichneBluse(_ g: GraphicsContext, _ h: GraphicsContext, top: FigurFarbe) {
    let dior = nah(top, 0xF4F1EE)
    // Silk: a wide sheen band from the left shoulder, soft shade on the right, folds falling from the shoulders.
    h.fill(Path { p in
        p.move(to: P(58, 158))
        p.addLine(to: P(86, 158))
        p.addLine(to: P(72, 340))
        p.addLine(to: P(40, 340))
        p.closeSubpath()
    }, with: .color(.white.opacity(dior ? 0.28 : 0.18)))
    h.fill(Path { p in
        p.move(to: P(126, 158))
        p.addLine(to: P(160, 158))
        p.addLine(to: P(164, 340))
        p.addLine(to: P(136, 340))
        p.closeSubpath()
    }, with: .color(.black.opacity(0.07)))
    for seite: CGFloat in [-1, 1] {
        for (a, b, c) in [(CGFloat(22), CGFloat(30), CGFloat(21)), (34, 41, 33)] {
            let falte = bogen(P(100 + seite * a, 178), P(100 + seite * b, 262), P(100 + seite * c, 216))
            linie(h, falte, top.kontur.opacity(0.24), 1.3)
            linie(h, falte.offsetBy(dx: seite * 2.2, dy: 0), .white.opacity(0.32), 1.8)
        }
    }
    linie(h, bogen(P(72, 232), P(128, 232), P(100, 242)), top.kontur.opacity(0.18), 1.2)
    if dior {
        let kragenFarbe = top.mal(0.97)
        let kragen = Path { p in
            p.move(to: P(86, 157))
            p.addLine(to: P(100, 193))
            p.addLine(to: P(68, 178))
            p.closeSubpath()
        }
        // Placket with a ridge on each side and pearl buttons.
        linie(h, strich(P(96.5, 192), P(96.5, 340)), top.kontur.opacity(0.35), 1)
        linie(h, strich(P(103.5, 192), P(103.5, 340)), top.kontur.opacity(0.35), 1)
        teil(g, kragen, kragenFarbe, 2.5)
        teil(g, gespiegelt(kragen), kragenFarbe, 2.5)
        let naht = strich(P(86, 163), P(78, 174))
        steppnaht(g, naht, top.kontur.opacity(0.5), 0.6)
        steppnaht(g, gespiegelt(naht), top.kontur.opacity(0.5), 0.6)
        for y in stride(from: CGFloat(204), through: 300, by: 17) {
            teil(g, kreis(P(100, y), 2.3), FigurFarbe(0xFAF7F0), 1)
            g.fill(kreis(P(99.2, y - 0.8), 0.7), with: .color(.white))
        }
        // Small gold brooch at the collar tip, the house's signature touch.
        teil(g, kreis(P(100, 195), 2.1), Pal.gold, 0.9)
    } else {
        // Tie-neck bow: two loops, a knot and two tails with a notch.
        let ton = top.mal(0.9)
        let schleife = Path { p in
            p.move(to: P(98, 178))
            p.addCurve(to: P(78, 172), control1: P(92, 165), control2: P(80, 164))
            p.addCurve(to: P(98, 183), control1: P(76, 185), control2: P(90, 187))
            p.closeSubpath()
        }
        let schwanz = Path { p in
            p.move(to: P(97, 182))
            p.addLine(to: P(86, 218))
            p.addLine(to: P(92, 213))
            p.addLine(to: P(97, 219))
            p.addLine(to: P(102, 185))
            p.closeSubpath()
        }
        teil(g, schwanz, ton, 1.8)
        teil(g, gespiegelt(schwanz).applying(CGAffineTransform(translationX: 0, y: 3)), ton, 1.8)
        teil(g, schleife, ton, 1.8)
        teil(g, gespiegelt(schleife), ton, 1.8)
        linie(g, bogen(P(94, 177), P(84, 174), P(88, 172)), .white.opacity(0.4), 1.2)
        linie(g, bogen(P(106, 177), P(116, 174), P(112, 172)), .white.opacity(0.4), 1.2)
        teil(g, oval(P(100, 180), 4.6, 4), top.mal(0.82), 1.6)
    }
}

// MARK: - Denim jacket (jacke 2)

/// `g` draws freely, `innen` is clipped to the torso. `oben`/`unten`/`s` as in `jackeZeichnen`.
func zeichneJeansjacke(_ g: GraphicsContext, innen: GraphicsContext, f: FigurFarbe, oben: CGFloat, unten: CGFloat, s: CGFloat, innenO: CGFloat, innenU: CGFloat) {
    let faden = FigurFarbe(0xE2A24B)
    // Twill weave and washed-out spots.
    var twill = Path()
    for x in stride(from: CGFloat(-40), to: 200, by: 5) {
        twill.move(to: P(x, oben - 10))
        twill.addLine(to: P(x + 34, unten + 30))
    }
    innen.stroke(twill, with: .color(f.mal(0.82).farbe.opacity(0.35)), lineWidth: 0.6)
    innen.fill(oval(P(100 - 26 * s, oben + 56 * s), 20 * s, 12 * s), with: .color(.white.opacity(0.09)))
    innen.fill(oval(P(100 + 28 * s, unten - 6 * s), 22 * s, 10 * s), with: .color(.white.opacity(0.07)))
    // Hem band with a double topstitch.
    let saumY = unten - 11 * s
    innen.fill(box(0, saumY, 200, 60), with: .color(f.mal(0.9).farbe))
    linie(innen, strich(P(0, saumY), P(200, saumY)), f.mal(0.6).farbe, 1.4)
    steppnaht(innen, strich(P(0, saumY + 2.6 * s), P(200, saumY + 2.6 * s)), faden.farbe, 0.8)
    // Yoke seams from the shoulders.
    for seite: CGFloat in [-1, 1] {
        let joch = bogen(P(100 + seite * 48 * s, oben + 8 * s), P(100 + seite * 15 * s, oben + 20 * s), P(100 + seite * 30 * s, oben + 12 * s))
        linie(innen, joch, f.mal(0.62).farbe, 1.6)
        steppnaht(innen, joch.offsetBy(dx: 0, dy: 2.4 * s), faden.farbe, 0.8)
    }
    // Pointed collar with a stitched edge.
    let kragenFarbe = f.mix(Pal.weiss, 0.1)
    let kragen = Path { p in
        p.move(to: P(innenO, oben))
        p.addLine(to: P(100 - 34 * s, oben - 5 * s))
        p.addLine(to: P(100 - 25 * s, oben + 22 * s))
        p.closeSubpath()
    }
    teil(g, kragen, kragenFarbe, 2)
    teil(g, gespiegelt(kragen), kragenFarbe, 2)
    let kragenNaht = Path { p in
        p.move(to: P(100 - 31.5 * s, oben - 2 * s))
        p.addLine(to: P(100 - 24 * s, oben + 18 * s))
    }
    steppnaht(g, kragenNaht, faden.farbe, 0.7)
    steppnaht(g, gespiegelt(kragenNaht), faden.farbe, 0.7)
    // Chest pockets with pointed flaps and brass buttons.
    for seite: CGFloat in [-1, 1] {
        let x = 100 + seite * 32 * s - 9 * s
        let y = oben + 34 * s
        let w = 18 * s
        teil(innen, box(x, y, w, 15 * s, 2 * s), f.mal(0.9), 1.6)
        let klappe = Path { p in
            p.move(to: P(x, y))
            p.addLine(to: P(x + w, y))
            p.addLine(to: P(x + w, y + 8 * s))
            p.addLine(to: P(x + w / 2, y + 11 * s))
            p.addLine(to: P(x, y + 8 * s))
            p.closeSubpath()
        }
        teil(innen, klappe, f.mal(0.8), 1.6)
        let klappenNaht = Path { p in
            p.move(to: P(x + 1.6 * s, y + 6.4 * s))
            p.addLine(to: P(x + w / 2, y + 8.8 * s))
            p.addLine(to: P(x + w - 1.6 * s, y + 6.4 * s))
        }
        steppnaht(innen, klappenNaht, faden.farbe, 0.6)
        teil(innen, kreis(P(x + w / 2, y + 8.2 * s), 1.7 * s), messingMode, 0.8)
    }
    // Button placket on the right edge, buttonholes on the left.
    let laenge = unten + 30 - oben
    for i in 0..<4 {
        let y = oben + (20 + CGFloat(i) * 26) * s
        guard y < unten - 8 else { break }
        let kante = (y - oben) / laenge * 8 * s
        let rechts = 100 + 12 * s + kante
        teil(g, kreis(P(rechts + 5 * s, y), 2.3 * s), messingMode, 0.9)
        g.fill(kreis(P(rechts + 4.4 * s, y - 0.6 * s), 0.7 * s), with: .color(.white.opacity(0.7)))
        linie(g, strich(P(200 - rechts - 7 * s, y), P(200 - rechts - 3 * s, y)), f.mal(0.4).farbe, 1.1)
    }
}

// MARK: - Puffer jacket (jacke 6: Moncler)

/// Quilted horizontal baffles with highlights, stand collar, centre zip, round tricolour patch, rib hem.
func zeichneSteppjacke(_ g: GraphicsContext, innen: GraphicsContext, f: FigurFarbe, oben: CGFloat, unten: CGFloat, s: CGFloat) {
    innen.fill(Path(CGRect(x: 0, y: oben - 10, width: 200, height: unten - oben + 60)),
               with: .linearGradient(Gradient(stops: [
                   .init(color: .black.opacity(0.24), location: 0),
                   .init(color: .black.opacity(0), location: 0.25),
                   .init(color: .black.opacity(0), location: 0.75),
                   .init(color: .black.opacity(0.24), location: 1),
               ]), startPoint: P(100 - 48 * s, 0), endPoint: P(100 + 48 * s, 0)))
    for y in stride(from: oben + 22 * s, to: unten + 24, by: 19 * s) {
        innen.fill(Path { p in
            p.move(to: P(0, y - 17 * s))
            p.addQuadCurve(to: P(200, y - 17 * s), control: P(100, y - 11 * s))
            p.addLine(to: P(200, y))
            p.addQuadCurve(to: P(0, y), control: P(100, y + 7 * s))
            p.closeSubpath()
        }, with: .color(.white.opacity(0.07)))
        linie(innen, bogen(P(0, y), P(200, y), P(100, y + 7 * s)), f.mal(0.42).farbe, 2.4)
        linie(innen, bogen(P(10, y - 9 * s), P(190, y - 9 * s), P(100, y - 2 * s)), .white.opacity(0.24), 3.4 * s)
    }
    // Rib hem.
    let saumY = unten - 8 * s
    innen.fill(box(0, saumY, 200, 60), with: .color(f.mal(0.78).farbe))
    linie(innen, strich(P(0, saumY), P(200, saumY)), f.mal(0.45).farbe, 1.6)
    var rippen = Path()
    for x in stride(from: CGFloat(0), to: 200, by: 4 * s + 1) {
        rippen.move(to: P(x, saumY))
        rippen.addLine(to: P(x, saumY + 30))
    }
    innen.stroke(rippen, with: .color(f.mal(0.5).farbe.opacity(0.6)), lineWidth: 0.8)
    // Zip with a pull tab.
    let zip = strich(P(100, oben), P(100, unten + 30))
    linie(innen, zip, Pal.dunkel.farbe, 3 * s)
    innen.stroke(zip, with: .color(Pal.silber.farbe), style: StrokeStyle(lineWidth: 2 * s, dash: [1.2, 0.9]))
    // Stand collar.
    let kragen = bogen(P(100 - 23 * s, oben + 2), P(100 + 23 * s, oben + 2), P(100, oben + 11 * s))
    linie(g, kragen, f.kontur, 13 * s)
    linie(g, kragen, f.mal(0.96).farbe, 10 * s)
    linie(g, kragen.offsetBy(dx: 0, dy: -2.6 * s), .white.opacity(0.25), 2 * s)
    linie(g, kragen.offsetBy(dx: 0, dy: 3 * s), f.mal(0.5).farbe.opacity(0.7), 1.2)
    teil(g, box(100 - 1.7 * s, oben + 12 * s, 3.4 * s, 9 * s, 1.2 * s), Pal.silber, 1)
    // Round patch on the left chest: white with a blue and a red bar.
    let brust = P(100 + 26 * s, oben + 38 * s)
    let patch = kreis(brust, 6.5 * s)
    teil(g, patch, Pal.weiss, 1.2)
    var p = g
    p.clip(to: patch)
    p.fill(box(brust.x - 6.5 * s, brust.y - 6.5 * s, 4.3 * s, 13 * s), with: .color(FigurFarbe(0x2C4FA8).farbe))
    p.fill(box(brust.x + 2.2 * s, brust.y - 6.5 * s, 4.3 * s, 13 * s), with: .color(FigurFarbe(0xC8283F).farbe))
}

// MARK: - Cargo pants (hose 5)

/// Pocketed thigh, outer seam stitching, knee creases, belt loops, button and fly. Legs are passed as
/// hip/knee/foot points (`Bein` is private to `FigurView`), `seite` is -1 for the left leg and 1 for the right.
func zeichneCargohose(_ g: GraphicsContext, beine: [(h: CGPoint, k: CGPoint, f: CGPoint, seite: CGFloat)], b: CGFloat, farbe: FigurFarbe, hy: CGFloat, halbBreite: CGFloat) {
    for bn in beine {
        let s = bn.seite
        let naht = Path { p in
            p.move(to: P(bn.h.x + s * (b * 0.62 - 2.4), bn.h.y + 4))
            p.addLine(to: P(bn.k.x + s * (b * 0.5 - 2.4), bn.k.y))
            p.addLine(to: P(bn.f.x + s * (b * 0.45 - 2.4), bn.f.y - 3))
        }
        steppnaht(g, naht, farbe.mal(0.55).farbe.opacity(0.75), 0.8)
        // The thigh pocket is drawn in a frame that follows the leg.
        let mp = P(bn.h.x + (bn.k.x - bn.h.x) * 0.6, bn.h.y + (bn.k.y - bn.h.y) * 0.6)
        let winkel = atan2(-Double(bn.k.x - bn.h.x), Double(bn.k.y - bn.h.y))
        var t = g
        t.translateBy(x: mp.x, y: mp.y)
        t.rotate(by: .radians(winkel))
        let w = b * 0.66
        let cx = s * b * 0.16 - w / 2
        teil(t, box(cx, -8, w, 17, 2), farbe.mal(0.92), 1.4)
        for x in [cx + 1.5, cx + w - 1.5] { linie(t, strich(P(x, -2), P(x, 8)), farbe.kontur.opacity(0.35), 0.8) }
        let klappe = Path { p in
            p.move(to: P(cx, -8))
            p.addLine(to: P(cx + w, -8))
            p.addLine(to: P(cx + w, -2.4))
            p.addLine(to: P(cx + w / 2, 0))
            p.addLine(to: P(cx, -2.4))
            p.closeSubpath()
        }
        teil(t, klappe, farbe.mal(0.82), 1.4)
        let klappenNaht = Path { p in
            p.move(to: P(cx + 1.3, -3.6))
            p.addLine(to: P(cx + w / 2, -1.5))
            p.addLine(to: P(cx + w - 1.3, -3.6))
        }
        steppnaht(t, klappenNaht, farbe.mal(0.5).farbe.opacity(0.8), 0.6)
        teil(t, kreis(P(cx + w / 2, -3.2), 1.1), messingMode, 0.7)
        // Knee creases and an ankle seam.
        linie(g, bogen(P(bn.k.x - b * 0.32, bn.k.y - 3), P(bn.k.x + b * 0.32, bn.k.y - 3), P(bn.k.x, bn.k.y)), farbe.kontur.opacity(0.3), 1.1)
        linie(g, bogen(P(bn.k.x - b * 0.3, bn.k.y + 2.5), P(bn.k.x + b * 0.3, bn.k.y + 2.5), P(bn.k.x, bn.k.y + 5)), farbe.kontur.opacity(0.2), 1)
        linie(g, strich(P(bn.f.x - b * 0.46, bn.f.y - 7), P(bn.f.x + b * 0.46, bn.f.y - 7)), farbe.kontur.opacity(0.45), 1.3)
    }
    // Waistband: belt loops, a seam, the brass button and the fly.
    for dx in [CGFloat(-0.62), -0.22, 0.22, 0.62] {
        teil(g, box(100 + dx * halbBreite - 1.1, hy - 10, 2.2, 8, 0.8), farbe.mal(0.8), 0.8)
    }
    linie(g, strich(P(100 - halbBreite + 2, hy - 3), P(100 + halbBreite - 2, hy - 3)), farbe.kontur.opacity(0.5), 1.1)
    steppnaht(g, strich(P(101.8, hy - 3), P(101.8, hy + 13)), farbe.mal(0.55).farbe.opacity(0.8), 0.7)
    linie(g, strich(P(100, hy - 3), P(100, hy + 14)), farbe.kontur.opacity(0.45), 1.2)
    teil(g, kreis(P(100, hy - 6), 1.7), messingMode, 0.8)
}

// MARK: - Sneaker (schuhe 8: Nike)

/// Side view, toe to the left, in the footprint of the other shoes. A light shoe gets a dark swoosh.
func zeichneNikeSneaker(_ g: GraphicsContext, fuss f: CGPoint, farbe c: FigurFarbe) {
    let x = f.x
    let y = f.y
    let hellerSchuh = c.r + c.g + c.b > 2.3
    let sohle = hellerSchuh ? FigurFarbe(0xE6E3DF) : Pal.weiss
    let zeichen = hellerSchuh ? Pal.tinte : Pal.weiss
    // Tongue and heel pull tab sit behind the upper.
    teil(g, box(x + 3, y - 8.6, 5, 4, 1.4), c.mix(Pal.weiss, 0.15), 1.4)
    teil(g, box(x + 10.2, y - 8.2, 3, 4.4, 1.1), c.mal(0.85), 1.2)
    let oberschuh = Path { p in
        p.move(to: P(x - 13, y + 6))
        p.addQuadCurve(to: P(x - 7, y - 0.8), control: P(x - 13.2, y - 1))
        p.addQuadCurve(to: P(x + 1, y - 4.8), control: P(x - 3, y - 3.2))
        p.addLine(to: P(x + 5, y - 6.4))
        p.addQuadCurve(to: P(x + 11.5, y - 6), control: P(x + 8.5, y - 8.6))
        p.addLine(to: P(x + 12.6, y + 6))
        p.closeSubpath()
    }
    teil(g, oberschuh, c, 2.4)
    // Toe box with perforations, heel patch, laces.
    let kappe = Path { p in
        p.move(to: P(x - 13, y + 5.5))
        p.addQuadCurve(to: P(x - 6.5, y + 0.2), control: P(x - 13.2, y - 0.8))
        p.addLine(to: P(x - 4.5, y + 5.5))
        p.closeSubpath()
    }
    g.fill(kappe, with: .color(c.mix(hellerSchuh ? Pal.tinte : Pal.weiss, 0.16).farbe))
    for (dx, dy) in [(CGFloat(-10.5), CGFloat(2.6)), (-9, 1.2), (-8, 3.4)] {
        g.fill(kreis(P(x + dx, y + dy), 0.45), with: .color(c.kontur.opacity(0.8)))
    }
    g.fill(box(x + 8.6, y - 1, 4, 7, 1.2), with: .color(zeichen.farbe.opacity(0.35)))
    for i in 0..<3 {
        let bx = x - 3.5 + 3.2 * CGFloat(i)
        let by = y - 2.2 - 1.45 * CGFloat(i)
        linie(g, strich(P(bx, by + 0.9), P(bx + 1.7, by - 1.2)), sohle.farbe, 0.9)
    }
    // Midsole over the lower edge of the upper, dark outsole line, swoosh.
    teil(g, box(x - 13.5, y + 5, 27, 6, 3), sohle, 2)
    g.fill(box(x - 12.5, y + 9.6, 25, 1.6, 0.8), with: .color(Pal.tinte.farbe.opacity(0.75)))
    g.fill(swooshPfad(P(x + 0.5, y + 1.8), breite: 13), with: .color(zeichen.farbe))
}
