import SwiftUI

// MARK: - Hairstyles Runde 3 (Z-38.3)

/// Quad strokes (from, to, control) for strand lines and highlights.
typealias Striche = [(CGPoint, CGPoint, CGPoint)]

extension Zeichner {
    /// Strand lines: lighter than very dark hair (dark lines would vanish in black), darker otherwise.
    var straehnenFarbe: Color {
        let hell: Double = haar.r * 0.3 + haar.g * 0.59 + haar.b * 0.11
        return hell < 0.22 ? haar.mix(Pal.weiss, 0.3).farbe : haar.kontur.opacity(0.6)
    }

    /// One piece of a Runde-3 style: all parts as one shape (outlines first), the color's streaks,
    /// strand lines and a highlight.
    func haarStueck(_ g: GraphicsContext, _ teile: [Path], linien: Striche = [], glanz: Striche = []) {
        verbunden(g, teile, haar)
        if let s = straehne { for p in teile { streifen(g, p, s) } }
        if !linien.isEmpty { linie(g, buendel(linien), straehnenFarbe, 1.8) }
        if !glanz.isEmpty { linie(g, buendel(glanz), .white.opacity(0.42), 4.5) }
    }

    func verbinde(_ teile: Striche...) -> Striche { teile.flatMap { $0 } }

    func buendel(_ l: Striche) -> Path {
        Path { p in
            for (a, b, c) in l {
                p.move(to: a)
                p.addQuadCurve(to: b, control: c)
            }
        }
    }

    /// Mirrors strokes around x = 100.
    func gespiegelteStriche(_ l: Striche) -> Striche {
        l.map { (P(200 - $0.0.x, $0.0.y), P(200 - $0.1.x, $0.1.y), P(200 - $0.2.x, $0.2.y)) }
    }

    /// Faded or shaved sides: a short cap mixed with the skin.
    func seitenFade(_ g: GraphicsContext, _ anteil: Double, ansatz: CGFloat = 60, unten: CGFloat = 94) {
        teil(g, kappe(top: 24, scheitel: 100, ansatz: ansatz, unten: unten), haar.mix(haut, anteil), 2.5)
    }

    /// Hair volume on top only (for styles with faded sides).
    func schopf(top: CGFloat, halb: CGFloat, unten: CGFloat) -> Path {
        let seite: CGFloat = top + (unten - top) * 0.35
        return Path { p in
            p.move(to: P(100 - halb, unten))
            p.addCurve(to: P(100, top), control1: P(100 - halb - 4, seite), control2: P(100 - halb * 0.6, top))
            p.addCurve(to: P(100 + halb, unten), control1: P(100 + halb * 0.6, top), control2: P(100 + halb + 4, seite))
            p.addQuadCurve(to: P(100 - halb, unten), control: P(100, unten - 14))
            p.closeSubpath()
        }
    }

    /// Pointed locks hanging from `oben` between `x0` and `x1`; the tips run from `links` to
    /// `rechts` (y) and lean by `neigung` (negative = swept to the viewer's left).
    func pony(_ x0: CGFloat, _ x1: CGFloat, oben: CGFloat, links: CGFloat, rechts: CGFloat, n: Int, neigung: CGFloat) -> Path {
        let b: CGFloat = (x1 - x0) / CGFloat(n)
        return Path { p in
            p.move(to: P(x0, oben))
            for i in 0..<n {
                let a: CGFloat = x0 + CGFloat(i) * b
                let t: CGFloat = n > 1 ? CGFloat(i) / CGFloat(n - 1) : 0.5
                let spitzeY: CGFloat = links + (rechts - links) * t
                let kerbeY: CGFloat = i == n - 1 ? oben : oben + (spitzeY - oben) * 0.42
                let mitteY: CGFloat = (oben + spitzeY) / 2
                p.addQuadCurve(to: P(a + b * 0.5 + neigung, spitzeY), control: P(a + neigung * 0.3, mitteY + 6))
                let zurueck: CGFloat = spitzeY - (spitzeY - kerbeY) * 0.35
                p.addQuadCurve(to: P(a + b, kerbeY), control: P(a + b * 0.85 + neigung * 0.4, zurueck))
            }
            p.closeSubpath()
        }
    }

    /// A strand line down the middle of each `pony` lock.
    func ponyLinien(_ x0: CGFloat, _ x1: CGFloat, oben: CGFloat, links: CGFloat, rechts: CGFloat, n: Int, neigung: CGFloat) -> Striche {
        let b: CGFloat = (x1 - x0) / CGFloat(n)
        return (0..<n).map { (i: Int) -> (CGPoint, CGPoint, CGPoint) in
            let a: CGFloat = x0 + CGFloat(i) * b
            let t: CGFloat = n > 1 ? CGFloat(i) / CGFloat(n - 1) : 0.5
            let spitzeY: CGFloat = links + (rechts - links) * t
            let ende = P(a + b * 0.5 + neigung * 0.8, spitzeY - (spitzeY - oben) * 0.22)
            return (P(a + b * 0.5, oben + 4), ende, P(a + b * 0.45 + neigung * 0.2, (oben + spitzeY) / 2))
        }
    }

    /// One pointed lock from `basis` (`b` wide) to `spitze`, bowed to one side by `biegung`.
    func locke(_ basis: CGPoint, _ spitze: CGPoint, _ b: CGFloat, _ biegung: CGFloat = 0.25) -> Path {
        let dx = spitze.x - basis.x
        let dy = spitze.y - basis.y
        let l = max(1, (dx * dx + dy * dy).squareRoot())
        let nx: CGFloat = -dy / l * b / 2
        let ny: CGFloat = dx / l * b / 2
        let mx: CGFloat = basis.x + dx * 0.5 + nx * biegung * 4
        let my: CGFloat = basis.y + dy * 0.5 + ny * biegung * 4
        return Path { p in
            p.move(to: P(basis.x + nx, basis.y + ny))
            p.addQuadCurve(to: spitze, control: P(mx + nx, my + ny))
            p.addQuadCurve(to: P(basis.x - nx, basis.y - ny), control: P(mx - nx * 0.6, my - ny * 0.6))
            p.closeSubpath()
        }
    }

    /// Front strand from the temple past the shoulder down to `u` (viewer's left; mirror with `gespiegelt`).
    func strang(u: CGFloat, breit: CGFloat = 30, aussen: CGFloat = 28) -> Path {
        let innen: CGFloat = aussen + breit
        return Path { p in
            p.move(to: P(46, 80))
            p.addCurve(to: P(aussen, u - 10), control1: P(34, 118), control2: P(aussen, u - 50))
            p.addQuadCurve(to: P(innen, u), control: P((aussen + innen) / 2 - 4, u + 8))
            p.addCurve(to: P(60, 104), control1: P(innen, u - 60), control2: P(58, 140))
            p.closeSubpath()
        }
    }

    func strangLinien(u: CGFloat, breit: CGFloat = 30, aussen: CGFloat = 28) -> Striche {
        [(P(48, 100), P(aussen + breit * 0.35, u - 14), P(38, u * 0.55 + 40)),
         (P(55, 112), P(aussen + breit * 0.72, u - 8), P(50, u * 0.6 + 40))]
    }

    /// Wavy front strand (viewer's left).
    func wellenStrang(u: CGFloat) -> Path {
        Path { p in
            p.move(to: P(46, 80))
            p.addQuadCurve(to: P(34, 120), control: P(30, 96))
            p.addQuadCurve(to: P(36, 160), control: P(46, 140))
            p.addQuadCurve(to: P(28, 198), control: P(22, 180))
            p.addQuadCurve(to: P(38, u), control: P(40, u - 16))
            p.addQuadCurve(to: P(64, u - 4), control: P(52, u + 6))
            p.addQuadCurve(to: P(58, 196), control: P(68, u - 22))
            p.addQuadCurve(to: P(62, 156), control: P(48, 176))
            p.addQuadCurve(to: P(56, 116), control: P(70, 136))
            p.addQuadCurve(to: P(60, 100), control: P(54, 104))
            p.closeSubpath()
        }
    }

    /// Braid: overlapping ovals from `a` to `b` with a woven line in each.
    func zopfKette(_ g: GraphicsContext, von a: CGPoint, bis b: CGPoint, n: Int, r: CGFloat) {
        let glieder = (0..<n).map { zwischen(a, b, CGFloat($0) / CGFloat(max(n - 1, 1))) }
        for c in glieder { g.fill(oval(c, r + 2, r * 0.9 + 2), with: .color(haar.kontur)) }
        for c in glieder {
            g.fill(oval(c, r, r * 0.9), with: .color(haar.farbe))
            linie(g, bogen(P(c.x - r * 0.7, c.y - r * 0.2), P(c.x + r * 0.7, c.y - r * 0.2), P(c.x, c.y + r * 0.5)), straehnenFarbe, 1.4)
        }
    }

    /// A thin box braid from `a` to `b`.
    func flechte(_ g: GraphicsContext, von a: CGPoint, bis b: CGPoint) {
        let s = strich(a, b)
        linie(g, s, haar.kontur, 9)
        linie(g, s, haar.farbe, 6)
        let n = Int(max(1, abs(b.y - a.y) / 8))
        for i in 0..<n {
            let c = zwischen(a, b, (CGFloat(i) + 0.5) / CGFloat(n))
            linie(g, strich(P(c.x - 3, c.y - 2), P(c.x + 3, c.y + 2)), straehnenFarbe, 1.2)
        }
    }

    /// Curly puff: bumps around a circle.
    func puff(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat) {
        var bumps: [CGPoint] = []
        for i in 0..<10 {
            let a = Double(i) / 10 * 2 * Double.pi
            bumps.append(P(c.x + r * CGFloat(cos(a)), c.y + r * CGFloat(sin(a))))
        }
        let klein: CGFloat = r * 0.42
        for b in bumps { g.fill(kreis(b, klein + 2.5), with: .color(haar.kontur)) }
        g.fill(kreis(c, r + 2), with: .color(haar.kontur))
        for b in bumps { g.fill(kreis(b, klein), with: .color(haar.farbe)) }
        g.fill(kreis(c, r), with: .color(haar.farbe))
        for b in bumps.prefix(5) { linie(g, bogen(P(b.x - 3, b.y), P(b.x + 3, b.y + 1), P(b.x, b.y - 4)), straehnenFarbe, 1.3) }
    }

    /// Fix round 4: Ahmed's own hairstyles (from his photos), all drawn with the sticker curl engine.
    /// 78 curly fringe over one eye, 79 mushroom cloud (his standard), 80 wavy side swoop,
    /// 81 extra fluffy curls, 82 gym wet look.
    func ahmedFrisur(_ g: GraphicsContext) {
        switch frisur {
        case 78: lockenWolke(g, fransen: 88, neigung: -4, auge: true)
        case 79: lockenWolke(g, fransen: 92)
        case 80: lockenWolke(g, fransen: 86, neigung: 10)
        case 81: lockenWolke(g, fransen: 84, wolke: 1.12)
        default: lockenWolke(g, fransen: 100, nass: true)
        }
    }

    /// Fix round 5: curls like the ChatGPT stickers (`design/ki/sticker/wir-ich.png`): one solid
    /// near-black mass with a soft cloud silhouette only slightly wider than the head, built from big
    /// soft wave clumps with pointed tips, a messy fringe of thick pointed strands curving across the
    /// forehead, a few broad subtle highlight arcs, over a low taper with free ears. No thin squiggles.
    /// `fransen`: where the fringe ends (y), `neigung` leans it, `wolke` > 1 adds volume and clumps,
    /// `auge` dips one strand toward the right eye, `nass` = flatter mass with longer, thinner strands.
    func lockenWolke(_ g: GraphicsContext, fransen: CGFloat, neigung: CGFloat = 0, wolke: CGFloat = 1, auge: Bool = false, nass: Bool = false) {
        seitenFade(g, 0.6, ansatz: 64, unten: 98)
        var h = g
        h.translateBy(x: 0, y: 6)
        let senken: CGFloat = nass ? 8 : 0
        let r0: CGFloat = 18 * wolke * (nass ? 0.85 : 1)
        let mittelpunkte: [CGPoint] = [
            P(46, 60), P(54, 38), P(72, 22), P(96, 14 + senken), P(120, 16 + senken), P(142, 26), P(154, 46), P(156, 64),
        ]
        let dom = Path { p in
            p.move(to: P(38, 80))
            p.addCurve(to: P(100, 14 + senken), control1: P(34, 32), control2: P(62, 14 + senken))
            p.addCurve(to: P(162, 80), control1: P(138, 14 + senken), control2: P(166, 32))
            p.addQuadCurve(to: P(38, 80), control: P(100, 62))
            p.closeSubpath()
        }
        var teile: [Path] = [dom]
        for c in mittelpunkte { teile.append(kreis(c, r0)) }
        // Big soft wave clumps with pointed tips around the outline.
        var klumpen: [(CGPoint, CGPoint, CGFloat, CGFloat)] = [
            (P(50, 56), P(30, 84), 26, -0.5), (P(58, 34), P(32, 42), 24, 0.45), (P(80, 20), P(64, 6 + senken), 22, -0.4),
            (P(110, 16), P(124, 4 + senken), 22, 0.4), (P(140, 30), P(166, 36), 24, -0.45), (P(152, 56), P(172, 84), 26, 0.5),
        ]
        if wolke > 1.05 {
            klumpen += [(P(96, 14), P(90, 0), 20, 0.3), (P(126, 18), P(146, 12), 20, -0.3)]
        }
        // Thick pointed fringe strands curving across the forehead.
        klumpen += [
            (P(62, 54), P(54, fransen - 8), 24, -0.55), (P(82, 52), P(84 + neigung, fransen), 24, 0.5),
            (P(102, 52), P(110 + neigung, fransen + 2), 24, -0.5), (P(122, 54), P(132 + neigung, fransen - 4), 22, 0.5),
            (P(140, 58), P(150 + neigung, fransen - 14), 18, -0.4),
        ]
        if auge { klumpen.append((P(114, 52), P(126, fransen + 16), 26, 0.45)) }
        if nass { klumpen.append((P(92, 54), P(94, fransen + 6), 16, 0.2)) }
        for k in klumpen { teile.append(locke(k.0, k.1, k.2, k.3)) }
        verbunden(h, teile, haar)
        if let s = straehne { for p in teile { streifen(h, p, s) } }
        // Subtle clump separations: a few broad soft curves.
        let trennungen: Striche = [
            (P(60, 40), P(46, 70), P(46, 52)), (P(84, 26), P(70, 48), P(72, 34)),
            (P(118, 24), P(132, 46), P(130, 32)), (P(144, 40), P(156, 70), P(156, 52)),
        ]
        linie(h, buendel(trennungen), haar.mix(Pal.weiss, 0.12).farbe, 2.4)
        // Broad, subtle highlight arcs.
        let glanz = Path { p in
            p.addArc(center: P(78, 40), radius: 22, startAngle: .degrees(215), endAngle: .degrees(285), clockwise: false)
            p.move(to: P(112 + 20 * CGFloat(cos(235 * Double.pi / 180)), 34 + 20 * CGFloat(sin(235 * Double.pi / 180))))
            p.addArc(center: P(112, 34), radius: 20, startAngle: .degrees(235), endAngle: .degrees(305), clockwise: false)
        }
        linie(h, glanz, haar.mix(Pal.weiss, nass ? 0.3 : 0.2).farbe, 5)
    }

    /// Standard highlight on the left of the crown.
    var glanzLinks: Striche { [(P(62, 56), P(88, 28), P(66, 34)), (P(94, 24), P(104, 23), P(99, 21))] }

    func neueFrisurHinten(_ g: GraphicsContext) {
        switch frisur {
        case 44:
            haarStueck(g, [langHinten(128)])
        case 45:
            haarStueck(g, [langHinten(150), locke(P(40, 138), P(24, 160), 16, -0.3), locke(P(160, 138), P(176, 160), 16, 0.3)])
        case 46:
            haarStueck(g, [langHinten(176)])
        case 47:
            haarStueck(g, [box(46, 60, 108, 124, 34), locke(P(56, 176), P(50, 196), 14), locke(P(144, 176), P(150, 196), 14)],
                   linien: [(P(56, 120), P(58, 178), P(52, 150)), (P(144, 120), P(142, 178), P(148, 150))])
        case 54:
            haarTeil(g, kreis(P(100, 16), 15))
            linie(g, bogen(P(90, 12), P(110, 20), P(102, 6)), straehnenFarbe, 1.6)
        case 56, 58, 63, 66, 70, 73:
            let seiten: Striche = [(P(36, 110), P(34, 226), P(28, 170)), (P(164, 110), P(166, 226), P(172, 170))]
            haarStueck(g, [langHinten(frisur == 56 ? 236 : 230)], linien: seiten)
        case 57:
            haarStueck(g, [langHinten(222), locke(P(44, 214), P(40, 236), 18), locke(P(156, 214), P(160, 236), 18)])
        case 59:
            haarStueck(g, [langHinten(226), wellenStrang(u: 228), gespiegelt(wellenStrang(u: 228))])
        case 60:
            let schwanz = Path { p in
                p.move(to: P(118, 30))
                p.addCurve(to: P(176, 196), control1: P(186, 30), control2: P(196, 140))
                p.addCurve(to: P(150, 110), control1: P(160, 196), control2: P(150, 150))
                p.addCurve(to: P(128, 40), control1: P(150, 70), control2: P(140, 44))
                p.closeSubpath()
            }
            haarStueck(g, [schwanz], linien: [(P(132, 44), P(170, 186), P(176, 90)), (P(140, 70), P(160, 180), P(158, 120))], glanz: [(P(146, 50), P(168, 110), P(168, 70))])
            teil(g, oval(P(126, 32), 7, 9), Pal.dunkel, 2)
        case 61:
            haarStueck(g, [kreis(P(100, 14), 20), locke(P(112, 6), P(130, -2), 8, 0.4)],
                   linien: [(P(84, 10), P(114, 20), P(100, 0)), (P(90, 22), P(116, 8), P(108, 26))])
        case 62:
            haarStueck(g, [kreis(P(154, 136), 19)], linien: [(P(140, 132), P(166, 140), P(154, 124)), (P(144, 144), P(164, 130), P(160, 148))])
        case 64:
            haarStueck(g, [langHinten(178)])
        case 65:
            haarStueck(g, [box(32, 30, 136, 124, 50)])
        case 69:
            haarStueck(g, [langHinten(212)])
            var locken = seitenLocken(212)
            for y in stride(from: CGFloat(110), through: 200, by: 22) { locken += [P(28, y), P(172, y)] }
            lockenKette(g, locken, 15)
        case 71:
            haarStueck(g, [langHinten(188), locke(P(34, 178), P(20, 198), 16, -0.3), locke(P(58, 184), P(54, 204), 14),
                       locke(P(166, 178), P(180, 198), 16, 0.3), locke(P(142, 184), P(146, 204), 14)])
        case 72:
            haarStueck(g, [langHinten(224)])
        case 74:
            haarStueck(g, [oval(P(100, 22), 34, 18)], linien: [(P(72, 22), P(128, 22), P(100, 10)), (P(76, 28), P(124, 30), P(100, 40))])
            teil(g, box(80, 6, 40, 16, 5), FigurFarbe(0xB07A4F), 2)
            for x in stride(from: CGFloat(86), through: 114, by: 7) { linie(g, strich(P(x, 18), P(x, 26)), FigurFarbe(0x7A5234).farbe, 2) }
        case 75:
            let schwanz = Path { p in
                p.move(to: P(94, 14))
                p.addCurve(to: P(168, 170), control1: P(150, -4), control2: P(190, 100))
                p.addCurve(to: P(140, 90), control1: P(152, 170), control2: P(142, 130))
                p.addCurve(to: P(108, 20), control1: P(138, 50), control2: P(124, 22))
                p.closeSubpath()
            }
            haarStueck(g, [schwanz], linien: [(P(112, 16), P(164, 158), P(170, 60))])
            for i in 0..<6 {
                let a = Double(i) / 6 * 2 * Double.pi
                teil(g, kreis(P(102 + 8 * CGFloat(cos(a)), 16 + 5 * CGFloat(sin(a))), 5), Pal.rose, 1.5)
            }
        case 76:
            puff(g, P(56, 30), 24)
            puff(g, P(144, 30), 24)
        case 77:
            for x in stride(from: CGFloat(34), through: 166, by: 11) where abs(x - 100) > 36 {
                flechte(g, von: P(x, 70), bis: P(x + (x < 100 ? -4 : 4), 232))
            }
        default:
            break
        }
    }

    func neueFrisurVorn(_ g: GraphicsContext) {
        switch frisur {
        case 34:
            // Ahmed's Bitmoji (fix round 2, after the `wir-*` stickers): full, messy, textured hair with
            // fluffy volume on top, locks falling over the ear tops and a wavy fringe into the forehead.
            let k = kappe(top: 14, scheitel: 118, ansatz: 44, unten: 100)
            let fr = pony(46, 152, oben: 34, links: 88, rechts: 72, n: 6, neigung: -7)
            let volumen = [oval(P(64, 40), 22, 20), oval(P(88, 24), 23, 19), oval(P(114, 22), 23, 19), oval(P(138, 36), 22, 20)]
            let locken = [locke(P(50, 66), P(38, 108), 18, -0.3), locke(P(150, 66), P(162, 106), 18, 0.3),
                          locke(P(58, 30), P(42, 44), 14, -0.6), locke(P(142, 28), P(158, 42), 14, 0.6),
                          locke(P(72, 20), P(60, 8), 10, -0.5), locke(P(130, 18), P(144, 8), 10, 0.5)]
            let linien = verbinde(ponyLinien(46, 152, oben: 34, links: 88, rechts: 72, n: 6, neigung: -7),
                                  [(P(118, 16), P(72, 44), P(90, 20)), (P(126, 22), P(100, 52), P(116, 28)), (P(140, 30), P(148, 62), P(148, 44)),
                                   (P(70, 30), P(56, 60), P(58, 40)), (P(96, 12), P(84, 30), P(90, 18)),
                                   (P(150, 60), P(160, 96), P(158, 76)), (P(50, 62), P(42, 98), P(42, 78))])
            haarStueck(g, [k, fr] + volumen + locken, linien: linien, glanz: [(P(66, 34), P(92, 18), P(72, 20)), (P(104, 16), P(120, 18), P(112, 13))])
        case 35:
            seitenFade(g, 0.5)
            let fr = pony(54, 146, oben: 40, links: 70, rechts: 62, n: 6, neigung: -6)
            haarStueck(g, [schopf(top: 14, halb: 50, unten: 64), fr, locke(P(96, 20), P(86, 4), 9, -0.3)],
                   linien: ponyLinien(54, 146, oben: 40, links: 70, rechts: 62, n: 6, neigung: -6), glanz: glanzLinks)
        case 36:
            let fr = pony(46, 100, oben: 40, links: 92, rechts: 58, n: 3, neigung: -7)
            let fl = ponyLinien(46, 100, oben: 40, links: 92, rechts: 58, n: 3, neigung: -7)
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 44, unten: 98), fr, gespiegelt(fr)],
                   linien: verbinde(fl, gespiegelteStriche(fl), [(P(100, 18), P(100, 44), P(99, 30))]), glanz: glanzLinks)
        case 37:
            seitenFade(g, 0.55, ansatz: 58)
            let quiff = Path { p in
                p.move(to: P(56, 60))
                p.addCurve(to: P(92, 4), control1: P(50, 30), control2: P(64, 6))
                p.addCurve(to: P(146, 34), control1: P(124, 2), control2: P(150, 14))
                p.addCurve(to: P(146, 58), control1: P(144, 44), control2: P(148, 52))
                p.addQuadCurve(to: P(56, 60), control: P(100, 42))
                p.closeSubpath()
            }
            haarStueck(g, [quiff], linien: [(P(64, 52), P(96, 10), P(66, 22)), (P(84, 50), P(118, 8), P(88, 18)), (P(108, 48), P(138, 22), P(120, 24))],
                   glanz: [(P(72, 38), P(96, 14), P(78, 20))])
        case 38:
            seitenFade(g, 0.5, ansatz: 62)
            let fr = pony(52, 148, oben: 44, links: 60, rechts: 58, n: 9, neigung: 1)
            var textur: Striche = []
            for x in stride(from: CGFloat(62), through: 138, by: 12) { textur.append((P(x, 24), P(x + 2, 40), P(x - 1, 32))) }
            haarStueck(g, [schopf(top: 18, halb: 50, unten: 58), fr], linien: textur, glanz: glanzLinks)
        case 39:
            teil(g, kappe(top: 26, scheitel: 100, ansatz: 54, unten: 90), haar.mix(haut, 0.4), 2.5)
            linie(g, bogen(P(62, 60), P(86, 36), P(66, 44)), haut.farbe, 2.5)
            linie(g, buendel([(P(70, 40), P(96, 30), P(80, 32))]), .white.opacity(0.3), 3.5)
        case 40:
            seitenFade(g, 0.55)
            let top = Path { p in
                p.move(to: P(54, 62))
                p.addCurve(to: P(100, 12), control1: P(50, 30), control2: P(70, 12))
                p.addCurve(to: P(150, 60), control1: P(132, 12), control2: P(154, 34))
                p.addCurve(to: P(74, 50), control1: P(128, 48), control2: P(96, 44))
                p.addQuadCurve(to: P(54, 62), control: P(62, 52))
                p.closeSubpath()
            }
            haarStueck(g, [top], linien: [(P(80, 20), P(148, 52), P(126, 22)), (P(80, 34), P(140, 58), P(118, 36))], glanz: [(P(84, 22), P(120, 18), P(100, 14))])
            linie(g, bogen(P(72, 50), P(80, 18), P(72, 30)), haut.mal(0.9).farbe, 2)
        case 41:
            seitenFade(g, 0.55, ansatz: 58)
            let pomp = Path { p in
                p.move(to: P(54, 60))
                p.addCurve(to: P(100, 2), control1: P(46, 22), control2: P(66, 2))
                p.addCurve(to: P(146, 60), control1: P(134, 2), control2: P(154, 22))
                p.addQuadCurve(to: P(54, 60), control: P(100, 50))
                p.closeSubpath()
            }
            haarStueck(g, [pomp], linien: [(P(62, 56), P(96, 8), P(62, 24)), (P(80, 54), P(110, 6), P(82, 18)), (P(102, 52), P(128, 10), P(106, 16)), (P(122, 54), P(142, 24), P(130, 26))],
                   glanz: [(P(70, 30), P(96, 10), P(76, 14))])
        case 42:
            let k = kappe(top: 20, scheitel: 100, ansatz: 56, unten: 94)
            let spitzen: [(CGFloat, CGFloat)] = [(58, 20), (76, 8), (94, 3), (112, 5), (130, 10), (146, 22)]
            let teile = [k] + spitzen.map { locke(P($0.0, 38), P($0.0 + ($0.0 - 100) * 0.12, $0.1), 18) }
            haarStueck(g, teile, linien: spitzen.map { (P($0.0, 40), P($0.0 + ($0.0 - 100) * 0.1, $0.1 + 10), P($0.0, 28)) }, glanz: glanzLinks)
        case 43:
            seitenFade(g, 0.65, ansatz: 62, unten: 92)
            let top = Path { p in
                p.move(to: P(52, 60))
                p.addCurve(to: P(96, 10), control1: P(48, 28), control2: P(66, 10))
                p.addCurve(to: P(160, 70), control1: P(136, 10), control2: P(162, 36))
                p.addCurve(to: P(150, 96), control1: P(162, 84), control2: P(156, 94))
                p.addCurve(to: P(110, 52), control1: P(146, 72), control2: P(130, 54))
                p.addQuadCurve(to: P(52, 60), control: P(78, 50))
                p.closeSubpath()
            }
            haarStueck(g, [top], linien: [(P(62, 52), P(150, 84), P(116, 16)), (P(76, 50), P(146, 94), P(128, 30))], glanz: [(P(70, 30), P(110, 16), P(84, 18))])
        case 44:
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 50, unten: 104)],
                   linien: [(P(66, 58), P(86, 18), P(70, 30)), (P(86, 50), P(100, 16), P(88, 26)), (P(114, 50), P(104, 16), P(112, 26)), (P(134, 58), P(114, 18), P(130, 30))],
                   glanz: [(P(60, 50), P(92, 22), P(66, 28)), (P(110, 22), P(136, 36), P(128, 24))])
        case 45:
            haarStueck(g, [kappe(top: 12, scheitel: 100, ansatz: 48, unten: 110), locke(P(44, 100), P(30, 128), 14, -0.3), locke(P(156, 100), P(170, 128), 14, 0.3)],
                   linien: [(P(64, 56), P(58, 110), P(50, 70)), (P(82, 48), P(100, 14), P(84, 24)), (P(118, 48), P(100, 14), P(116, 24)), (P(136, 56), P(142, 110), P(150, 70))],
                   glanz: glanzLinks)
        case 46:
            let s = strang(u: 170, breit: 24, aussen: 30)
            let sl = strangLinien(u: 170, breit: 24, aussen: 30)
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 46, unten: 108), s, gespiegelt(s)],
                   linien: verbinde(sl, gespiegelteStriche(sl), [(P(100, 16), P(100, 46), P(99, 30)), (P(98, 46), P(56, 86), P(66, 50)), (P(102, 46), P(144, 86), P(134, 50))]),
                   glanz: glanzLinks)
        case 47:
            let fr = pony(54, 146, oben: 40, links: 64, rechts: 64, n: 7, neigung: 0)
            haarStueck(g, [kappe(top: 18, scheitel: 100, ansatz: 54, unten: 104), fr],
                   linien: ponyLinien(54, 146, oben: 40, links: 64, rechts: 64, n: 7, neigung: 0), glanz: glanzLinks)
        case 48:
            seitenFade(g, 0.6)
            let top = Path { p in
                p.move(to: P(50, 60))
                p.addCurve(to: P(100, 14), control1: P(48, 28), control2: P(70, 14))
                p.addCurve(to: P(150, 60), control1: P(130, 14), control2: P(152, 28))
                p.addQuadCurve(to: P(50, 60), control: P(100, 62))
                p.closeSubpath()
            }
            var textur: Striche = []
            for x in stride(from: CGFloat(58), through: 142, by: 10) { textur.append((P(x, 40), P(x, 58), P(x + 1, 50))) }
            haarStueck(g, [top], linien: textur, glanz: [(P(64, 34), P(92, 20), P(72, 22))])
        case 49:
            seitenFade(g, 0.5)
            let fr = pony(52, 148, oben: 44, links: 62, rechts: 60, n: 10, neigung: -3)
            haarStueck(g, [schopf(top: 16, halb: 50, unten: 56), fr, locke(P(84, 22), P(76, 6), 9, -0.3), locke(P(108, 20), P(116, 4), 9, 0.3)],
                   linien: ponyLinien(52, 148, oben: 44, links: 62, rechts: 60, n: 10, neigung: -3), glanz: glanzLinks)
        case 50:
            seitenFade(g, 0.6)
            haarStueck(g, [schopf(top: 22, halb: 26, unten: 60), locke(P(88, 48), P(92, 14), 22), locke(P(100, 38), P(104, 2), 22), locke(P(112, 48), P(116, 12), 20)],
                   linien: [(P(92, 50), P(98, 12), P(92, 30)), (P(108, 50), P(112, 16), P(108, 30))], glanz: [(P(86, 36), P(96, 12), P(88, 20))])
        case 51:
            let k = kappe(top: 22, scheitel: 100, ansatz: 54, unten: 92)
            teil(g, k, haar, 2.5)
            var wellen = Path()
            for y in stride(from: CGFloat(30), through: 54, by: 8) {
                wellen.addPath(Path { p in
                    p.move(to: P(56, y + 6))
                    for i in 0..<6 {
                        let xa: CGFloat = 56 + CGFloat(i) * 15
                        let dy: CGFloat = i % 2 == 0 ? -4 : 4
                        p.addQuadCurve(to: P(xa + 15, y + 6), control: P(xa + 7.5, y + 6 + dy))
                    }
                })
            }
            var h = g
            h.clip(to: k)
            linie(h, wellen, straehnenFarbe, 1.6)
            linie(g, buendel(glanzLinks), .white.opacity(0.35), 4)
        case 52:
            seitenFade(g, 0.55)
            haarStueck(g, [schopf(top: 24, halb: 48, unten: 58)])
            for x in stride(from: CGFloat(58), through: 142, by: 12) {
                let strang = box(x - 5, 14 + abs(x - 100) * 0.22, 10, 24, 5)
                linie(g, strang, haar.kontur, 3)
                g.fill(strang, with: .color(haar.farbe))
                linie(g, strich(P(x - 3, 20 + abs(x - 100) * 0.22), P(x + 3, 26 + abs(x - 100) * 0.22)), straehnenFarbe, 1.3)
            }
        case 53:
            teil(g, kappe(top: 24, scheitel: 100, ansatz: 50, unten: 92), haar.mix(haut, 0.3), 2.5)
            for x in [CGFloat(64), 82, 100, 118, 136] {
                zopfKette(g, von: P(x, 54), bis: P(100 + (x - 100) * 0.45, 24), n: 5, r: 5)
            }
        case 54:
            seitenFade(g, 0.55)
            haarStueck(g, [schopf(top: 22, halb: 44, unten: 56)],
                   linien: [(P(66, 52), P(94, 24), P(74, 30)), (P(100, 52), P(100, 24), P(102, 38)), (P(134, 52), P(106, 24), P(126, 30))], glanz: glanzLinks)
        case 55:
            let fr = pony(46, 154, oben: 38, links: 72, rechts: 70, n: 8, neigung: 3)
            let flicks = [locke(P(44, 60), P(24, 74), 14, -0.3), locke(P(156, 60), P(176, 72), 14, 0.3),
                          locke(P(62, 22), P(46, 8), 12, -0.3), locke(P(138, 22), P(154, 8), 12, 0.3), locke(P(100, 12), P(104, 0), 12, 0.2)]
            haarStueck(g, [kappe(top: 8, scheitel: 100, ansatz: 50, unten: 104), fr] + flicks,
                   linien: ponyLinien(46, 154, oben: 38, links: 72, rechts: 70, n: 8, neigung: 3), glanz: glanzLinks)
        case 56:
            // Annika's Bitmoji: long, straight, middle part, front strands over the shoulders.
            let s = strang(u: 232, breit: 32, aussen: 26)
            let sl = strangLinien(u: 232, breit: 32, aussen: 26)
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 42, unten: 108), s, gespiegelt(s)],
                   linien: verbinde(sl, gespiegelteStriche(sl), [(P(100, 16), P(100, 44), P(99, 30)), (P(98, 42), P(52, 88), P(64, 48)), (P(102, 42), P(148, 88), P(136, 48))]),
                   glanz: [(P(60, 64), P(84, 30), P(64, 40)), (P(116, 26), P(130, 30), P(124, 25))])
        case 57:
            let s = strang(u: 196, breit: 30, aussen: 28)
            let lagen = [locke(P(52, 90), P(66, 144), 18, 0.3), locke(P(148, 90), P(134, 144), 18, -0.3)]
            let sl = strangLinien(u: 196)
            haarStueck(g, [kappe(top: 12, scheitel: 92, ansatz: 44, unten: 108), s, gespiegelt(s)] + lagen,
                   linien: verbinde(sl, gespiegelteStriche(sl), [(P(92, 44), P(56, 84), P(64, 50))]), glanz: glanzLinks)
        case 58:
            let vorhang = Path { p in
                p.move(to: P(100, 38))
                p.addCurve(to: P(54, 100), control1: P(76, 40), control2: P(56, 64))
                p.addLine(to: P(64, 102))
                p.addCurve(to: P(98, 50), control1: P(66, 72), control2: P(82, 52))
                p.closeSubpath()
            }
            let s = strang(u: 226)
            let sl = strangLinien(u: 226)
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 44, unten: 108), s, gespiegelt(s), vorhang, gespiegelt(vorhang)],
                   linien: verbinde(sl, gespiegelteStriche(sl), [(P(96, 48), P(62, 94), P(70, 58)), (P(104, 48), P(138, 94), P(130, 58))]), glanz: glanzLinks)
        case 59:
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 44, unten: 108)],
                   linien: [(P(100, 16), P(100, 44), P(99, 30)), (P(96, 44), P(54, 90), P(62, 52)), (P(104, 44), P(146, 90), P(138, 52))], glanz: glanzLinks)
        case 60:
            haarStueck(g, [kappe(top: 18, scheitel: 100, ansatz: 50, unten: 94)],
                   linien: [(P(62, 60), P(124, 28), P(80, 30)), (P(84, 52), P(126, 30), P(100, 36)), (P(138, 60), P(128, 30), P(140, 42))],
                   glanz: [(P(64, 50), P(96, 24), P(70, 28)), (P(104, 22), P(122, 26), P(114, 20))])
        case 61:
            haarStueck(g, [kappe(top: 18, scheitel: 100, ansatz: 50, unten: 100), locke(P(52, 84), P(58, 140), 10, 0.4), locke(P(148, 84), P(142, 140), 10, -0.4)],
                   linien: [(P(66, 58), P(94, 22), P(72, 30)), (P(134, 58), P(106, 22), P(128, 30))], glanz: glanzLinks)
        case 62:
            haarStueck(g, [kappe(top: 16, scheitel: 100, ansatz: 46, unten: 104)],
                   linien: [(P(100, 18), P(100, 46), P(99, 32)), (P(96, 46), P(56, 92), P(62, 54)), (P(104, 46), P(146, 92), P(138, 54))],
                   glanz: [(P(60, 60), P(86, 28), P(64, 36)), (P(114, 28), P(140, 60), P(136, 36))])
        case 63:
            let s = strang(u: 222)
            let sl = strangLinien(u: 222)
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 46, unten: 106), s, gespiegelt(s)],
                   linien: verbinde(sl, gespiegelteStriche(sl), [(P(100, 16), P(100, 46), P(99, 30))]), glanz: glanzLinks)
            let schleife = Path { p in
                p.move(to: P(100, 14))
                p.addLine(to: P(82, 4))
                p.addLine(to: P(82, 24))
                p.closeSubpath()
            }
            teil(g, schleife, Pal.rose, 2)
            teil(g, gespiegelt(schleife), Pal.rose, 2)
            teil(g, kreis(P(100, 14), 4.5), Pal.rose.mal(0.85), 2)
        case 64:
            let s = strang(u: 176, breit: 30, aussen: 28)
            let sl = strangLinien(u: 176)
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 44, unten: 108), s, gespiegelt(s)],
                   linien: verbinde(sl, gespiegelteStriche(sl), [(P(100, 16), P(100, 44), P(99, 30))]), glanz: glanzLinks)
        case 65:
            let seite = Path { p in
                p.move(to: P(44, 70))
                p.addQuadCurve(to: P(36, 110), control: P(32, 90))
                p.addQuadCurve(to: P(42, 150), control: P(48, 130))
                p.addQuadCurve(to: P(68, 150), control: P(56, 160))
                p.addQuadCurve(to: P(58, 110), control: P(70, 130))
                p.addQuadCurve(to: P(56, 76), control: P(52, 92))
                p.closeSubpath()
            }
            let welle = Path { p in
                p.move(to: P(70, 46))
                p.addCurve(to: P(152, 86), control1: P(112, 30), control2: P(150, 52))
                p.addCurve(to: P(104, 62), control1: P(140, 70), control2: P(122, 60))
                p.addCurve(to: P(70, 46), control1: P(88, 64), control2: P(74, 56))
                p.closeSubpath()
            }
            haarStueck(g, [kappe(top: 16, scheitel: 76, ansatz: 50, unten: 106), seite, gespiegelt(seite), welle],
                   linien: [(P(76, 48), P(146, 80), P(118, 42)), (P(46, 90), P(50, 144), P(38, 120)), (P(154, 90), P(150, 144), P(162, 120))], glanz: glanzLinks)
        case 66, 70:
            let ponyForm = Path { p in
                p.move(to: P(50, 44))
                p.addCurve(to: P(100, 20), control1: P(52, 26), control2: P(72, 20))
                p.addCurve(to: P(150, 44), control1: P(128, 20), control2: P(148, 26))
                p.addLine(to: P(152, 72))
                p.addQuadCurve(to: P(48, 72), control: P(100, 78))
                p.closeSubpath()
            }
            var textur: Striche = []
            for x in stride(from: CGFloat(62), through: 138, by: 12) { textur.append((P(x, 36), P(x, 68), P(x - 2, 52))) }
            var teile = [kappe(top: 14, scheitel: 100, ansatz: 50, unten: 108), ponyForm]
            if frisur == 66 {
                let s = strang(u: 228)
                teile += [s, gespiegelt(s)]
                textur += verbinde(strangLinien(u: 228), gespiegelteStriche(strangLinien(u: 228)))
            } else {
                let seite = Path { p in
                    p.move(to: P(44, 76))
                    p.addLine(to: P(38, 152))
                    p.addLine(to: P(64, 152))
                    p.addLine(to: P(60, 90))
                    p.closeSubpath()
                }
                teile += [seite, gespiegelt(seite)]
            }
            haarStueck(g, teile, linien: textur, glanz: [(P(64, 34), P(92, 24), P(72, 24))])
        case 67:
            let schwung = Path { p in
                p.move(to: P(64, 40))
                p.addCurve(to: P(160, 110), control1: P(120, 30), control2: P(162, 70))
                p.addLine(to: P(146, 114))
                p.addCurve(to: P(70, 54), control1: P(140, 76), control2: P(108, 50))
                p.closeSubpath()
            }
            haarStueck(g, [kappe(top: 16, scheitel: 78, ansatz: 50, unten: 104), schwung],
                   linien: [(P(72, 44), P(152, 104), P(136, 46)), (P(80, 52), P(148, 110), P(126, 58))], glanz: glanzLinks)
            zopfKette(g, von: P(152, 114), bis: P(142, 226), n: 8, r: 11)
            teil(g, kreis(P(141, 234), 5), Pal.rose, 2)
        case 68:
            haarStueck(g, [kappe(top: 18, scheitel: 100, ansatz: 50, unten: 98)], linien: [(P(100, 20), P(100, 50), P(99, 34))], glanz: glanzLinks)
            for seite in [CGFloat(-1), 1] {
                zopfKette(g, von: P(100 + seite * 26, 44), bis: P(100 + seite * 48, 96), n: 4, r: 8)
                zopfKette(g, von: P(100 + seite * 52, 104), bis: P(100 + seite * 56, 214), n: 7, r: 10)
                teil(g, kreis(P(100 + seite * 56, 224), 4.5), Pal.rose, 1.5)
            }
        case 69:
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 46, unten: 106)], linien: [(P(100, 16), P(100, 44), P(99, 30))])
            lockenKette(g, [P(58, 42), P(74, 26), P(90, 20), P(110, 20), P(126, 26), P(142, 42)], 12)
            lockenKette(g, seitenLocken(200), 12)
        case 71:
            let fr = pony(52, 148, oben: 40, links: 72, rechts: 72, n: 7, neigung: 0)
            let lagen = [locke(P(48, 94), P(34, 140), 16, -0.3), locke(P(50, 124), P(40, 172), 14, -0.2),
                         locke(P(152, 94), P(166, 140), 16, 0.3), locke(P(150, 124), P(160, 172), 14, 0.2)]
            haarStueck(g, [kappe(top: 10, scheitel: 100, ansatz: 48, unten: 106), fr] + lagen,
                   linien: ponyLinien(52, 148, oben: 40, links: 72, rechts: 72, n: 7, neigung: 0), glanz: glanzLinks)
        case 72:
            let fluegel = Path { p in
                p.move(to: P(56, 60))
                p.addCurve(to: P(30, 132), control1: P(40, 80), control2: P(26, 110))
                p.addQuadCurve(to: P(48, 136), control: P(38, 144))
                p.addCurve(to: P(62, 70), control1: P(52, 110), control2: P(60, 84))
                p.closeSubpath()
            }
            let s = strang(u: 222, breit: 30, aussen: 24)
            haarStueck(g, [kappe(top: 10, scheitel: 100, ansatz: 44, unten: 106), s, gespiegelt(s), fluegel, gespiegelt(fluegel)],
                   linien: [(P(100, 14), P(100, 44), P(99, 28)), (P(58, 74), P(36, 128), P(40, 96)), (P(142, 74), P(164, 128), P(160, 96))], glanz: glanzLinks)
        case 73:
            let schwung = Path { p in
                p.move(to: P(70, 36))
                p.addCurve(to: P(156, 110), control1: P(120, 34), control2: P(160, 70))
                p.addLine(to: P(146, 112))
                p.addCurve(to: P(72, 50), control1: P(140, 76), control2: P(110, 50))
                p.closeSubpath()
            }
            let s = gespiegelt(strang(u: 228))
            haarStueck(g, [kappe(top: 14, scheitel: 70, ansatz: 48, unten: 100), schwung, s],
                   linien: verbinde([(P(76, 42), P(150, 100), P(130, 42))], gespiegelteStriche(strangLinien(u: 228))), glanz: glanzLinks)
        case 74:
            haarStueck(g, [kappe(top: 18, scheitel: 100, ansatz: 48, unten: 98), locke(P(56, 76), P(54, 132), 9, 0.5), locke(P(144, 76), P(146, 132), 9, -0.5)],
                   linien: [(P(66, 56), P(96, 20), P(72, 28)), (P(134, 56), P(104, 20), P(128, 28))], glanz: glanzLinks)
        case 75:
            let fr = pony(56, 144, oben: 42, links: 66, rechts: 66, n: 6, neigung: 0)
            haarStueck(g, [kappe(top: 18, scheitel: 100, ansatz: 52, unten: 96), fr],
                   linien: ponyLinien(56, 144, oben: 42, links: 66, rechts: 66, n: 6, neigung: 0), glanz: glanzLinks)
        case 76:
            haarStueck(g, [kappe(top: 22, scheitel: 100, ansatz: 50, unten: 96)], linien: [(P(100, 24), P(100, 50), P(99, 36))])
            teil(g, box(66, 40, 14, 7, 3.5), Pal.gelb, 1.5)
            teil(g, box(120, 40, 14, 7, 3.5), Pal.gelb, 1.5)
        case 77:
            haarStueck(g, [kappe(top: 16, scheitel: 100, ansatz: 48, unten: 104)],
                   linien: [(P(100, 18), P(100, 48), P(99, 32)), (P(70, 34), P(130, 34), P(100, 28)), (P(62, 48), P(138, 48), P(100, 42))])
            for x in [CGFloat(46), 56] {
                flechte(g, von: P(x, 90), bis: P(x - 6, 226))
                flechte(g, von: P(200 - x, 90), bis: P(206 - x, 226))
            }
        case 78...82:
            ahmedFrisur(g)
        default:
            break
        }
    }
}
