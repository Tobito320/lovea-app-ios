import SwiftUI

/// p63: die Deko nach Anlass, nur Vektor im Aufkleber-Stil der Figuren (`teil`: Fläche plus weiche Kontur).
/// Entwurfsraum 390 x 430 wie `ZuhauseZeichnung`. Alles steht still, nichts läuft von selbst.
/// Plätze: Girlande an der Wand, Boden rechts neben der Kommode, Ballons am Sofa, Streu in der Luft, Fenster-Sims.
enum ZimmerDekoZeichnung {
    static func zeichne(_ g: GraphicsContext, _ d: ZimmerDeko) {
        if let s = d.streu { streu(g, s) }
        if let l = d.luft { luft(g, l) }
        if let f = d.fenster { fenster(g, f, kerzen: d.kerzen) }
        if let b = d.boden { boden(g, b) }
        if let gi = d.girlande { girlande(g, gi) }
    }

    private static func c(_ hex: UInt32) -> FigurFarbe { FigurFarbe(hex) }

    /// Dreht `p` um `m` und liefert das gedrehte Bild.
    private static func gedreht(_ p: Path, um m: CGPoint, _ w: CGFloat) -> Path {
        p.applying(CGAffineTransform(translationX: -m.x, y: -m.y)
            .concatenating(CGAffineTransform(rotationAngle: w))
            .concatenating(CGAffineTransform(translationX: m.x, y: m.y)))
    }

    private static func punkt(_ a: CGPoint, _ b: CGPoint, _ k: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return P(u * u * a.x + 2 * u * t * k.x + t * t * b.x, u * u * a.y + 2 * u * t * k.y + t * t * b.y)
    }

    private static func stern(_ m: CGPoint, _ ra: CGFloat, _ ri: CGFloat, spitzen: Int = 5) -> Path {
        Path { p in
            for k in 0..<spitzen * 2 {
                let w = CGFloat(k) * .pi / CGFloat(spitzen) - .pi / 2
                let r = k % 2 == 0 ? ra : ri
                let q = P(m.x + cos(w) * r, m.y + sin(w) * r)
                if k == 0 { p.move(to: q) } else { p.addLine(to: q) }
            }
            p.closeSubpath()
        }
    }

    private static func blatt(_ m: CGPoint, _ r: CGFloat, _ w: CGFloat) -> Path {
        let form = Path { p in
            p.move(to: P(0, -r))
            p.addQuadCurve(to: P(0, r), control: P(r * 0.95, 0))
            p.addQuadCurve(to: P(0, -r), control: P(-r * 0.95, 0))
        }
        return form.applying(CGAffineTransform(rotationAngle: w)).offsetBy(dx: m.x, dy: m.y)
    }

    private static func flamme(_ g: GraphicsContext, _ m: CGPoint, _ s: CGFloat = 1) {
        g.fill(kreis(m, 7 * s), with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.85, blue: 0.4).opacity(0.55), .clear]), center: m, startRadius: 0, endRadius: 7 * s))
        teil(g, oval(P(m.x, m.y - 0.5 * s), 1.9 * s, 3.2 * s), Pal.gelb, 0.8)
        g.fill(oval(P(m.x, m.y + 0.6 * s), 0.8 * s, 1.4 * s), with: .color(.white.opacity(0.9)))
    }

    // MARK: Girlande (Wand oben, links und rechts vom Fenster)

    private static let girlandenEnden: [(a: CGPoint, b: CGPoint, k: CGPoint, n: Int)] = [
        (P(-6, 40), P(170, 40), P(82, 78), 8),
        (P(268, 40), P(396, 40), P(332, 72), 5),
    ]

    private static let bunt: [FigurFarbe] = [Pal.rose.mix(Pal.weiss, 0.25), Pal.gelb, Pal.mint, Pal.himmel, Pal.decke]

    private static func girlande(_ g: GraphicsContext, _ art: ZimmerDeko.Girlande) {
        for (a, b, k, n) in girlandenEnden {
            linie(g, bogen(a, b, k), Pal.dunkel.farbe.opacity(0.5), 1.5)
            for i in 0..<n {
                let m = punkt(a, b, k, (CGFloat(i) + 0.5) / CGFloat(n))
                girlandenStueck(g, art, m, i)
            }
        }
    }

    private static func girlandenStueck(_ g: GraphicsContext, _ art: ZimmerDeko.Girlande, _ m: CGPoint, _ i: Int) {
        switch art {
        case .wimpel:
            let f = bunt[i % bunt.count]
            teil(g, Path { p in
                p.move(to: P(m.x - 7, m.y))
                p.addLine(to: P(m.x + 7, m.y))
                p.addLine(to: P(m.x, m.y + 17))
                p.closeSubpath()
            }, f, 1.5)
            g.fill(kreis(P(m.x, m.y + 5), 1.6), with: .color(.white.opacity(0.75)))
        case .herzen:
            let f = i % 2 == 0 ? Pal.rose.mix(Pal.weiss, 0.2) : Pal.rose.mix(Pal.weiss, 0.5)
            linie(g, strich(m, P(m.x, m.y + 3)), Pal.dunkel.farbe.opacity(0.4), 1)
            teil(g, herzPfad(P(m.x, m.y + 9), 7.5), f, 1.5)
            g.fill(kreis(P(m.x - 3, m.y + 6), 1.3), with: .color(.white.opacity(0.8)))
        case .lichter:
            let f = [Pal.gelb, Pal.rose.mix(Pal.weiss, 0.3), Pal.mint, Pal.himmel][i % 4]
            let lampe = P(m.x, m.y + 7)
            linie(g, strich(m, P(m.x, m.y + 4)), Pal.dunkel.farbe.opacity(0.5), 1)
            g.fill(kreis(lampe, 9), with: .radialGradient(Gradient(colors: [f.farbe.opacity(0.55), .clear]), center: lampe, startRadius: 0, endRadius: 9))
            teil(g, oval(lampe, 2.8, 3.6), f, 1)
            g.fill(kreis(P(lampe.x - 0.8, lampe.y - 1), 0.9), with: .color(.white.opacity(0.85)))
        case .blaetter:
            let f = [c(0xE07B39), c(0xC8553D), c(0xE8B04A), c(0x9C6B30)][i % 4]
            linie(g, strich(m, P(m.x, m.y + 5)), Pal.dunkel.farbe.opacity(0.4), 1)
            let neigung: CGFloat = CGFloat(i % 3 - 1) * 0.5
            teil(g, blatt(P(m.x, m.y + 12), 8, neigung), f, 1.5)
            let kopf = P(m.x - 3 * neigung, m.y + 5)
            let fuss = P(m.x + 3 * neigung, m.y + 19)
            linie(g, strich(kopf, fuss), f.mal(0.7).farbe, 1)
        case .blumen:
            let f = [Pal.rose.mix(Pal.weiss, 0.45), Pal.weiss, Pal.gelb, Pal.himmel.mix(Pal.weiss, 0.3)][i % 4]
            let mitte = P(m.x, m.y + 8)
            for k in 0..<5 {
                let w = CGFloat(k) * 2 * .pi / 5
                teil(g, kreis(P(mitte.x + cos(w) * 4.2, mitte.y + sin(w) * 4.2), 3.1), f, 1)
            }
            teil(g, kreis(mitte, 2.4), i % 4 == 2 ? Pal.rose.mix(Pal.weiss, 0.3) : Pal.gelb, 0.8)
        case .eier:
            let f = [Pal.rose.mix(Pal.weiss, 0.45), Pal.gelb.mix(Pal.weiss, 0.3), Pal.mint, Pal.himmel.mix(Pal.weiss, 0.2), Pal.decke][i % 5]
            let mitte = P(m.x, m.y + 11)
            linie(g, strich(m, P(m.x, m.y + 4)), Pal.dunkel.farbe.opacity(0.4), 1)
            teil(g, oval(mitte, 5.5, 7.2), f, 1.4)
            linie(g, bogen(P(mitte.x - 5, mitte.y + 1), P(mitte.x + 5, mitte.y + 1), P(mitte.x, mitte.y + 4)), .white.opacity(0.9), 1.4)
            linie(g, bogen(P(mitte.x - 4, mitte.y - 3), P(mitte.x + 4, mitte.y - 3), P(mitte.x, mitte.y - 1)), .white.opacity(0.7), 1)
        case .fledermaeuse:
            let f = c(0x4B3A66)
            let mitte = P(m.x, m.y + 8)
            linie(g, strich(m, P(m.x, m.y + 4)), Pal.dunkel.farbe.opacity(0.5), 1)
            let fluegel = Path { p in
                for vz: CGFloat in [-1, 1] {
                    p.move(to: P(mitte.x, mitte.y - 1))
                    p.addQuadCurve(to: P(mitte.x + vz * 13, mitte.y - 4), control: P(mitte.x + vz * 6, mitte.y - 10))
                    p.addQuadCurve(to: P(mitte.x + vz * 9, mitte.y + 4), control: P(mitte.x + vz * 11, mitte.y))
                    p.addQuadCurve(to: P(mitte.x + vz * 5, mitte.y + 2), control: P(mitte.x + vz * 7, mitte.y + 5))
                    p.addQuadCurve(to: P(mitte.x, mitte.y + 5), control: P(mitte.x + vz * 2, mitte.y + 4))
                }
            }
            teil(g, fluegel, f, 1.2)
            teil(g, oval(mitte, 3, 4.4), f, 1)
            for vz: CGFloat in [-1, 1] { teil(g, Path { p in
                p.move(to: P(mitte.x + vz * 1.2, mitte.y - 3))
                p.addLine(to: P(mitte.x + vz * 2.8, mitte.y - 6.5))
                p.addLine(to: P(mitte.x + vz * 3.4, mitte.y - 2.4))
                p.closeSubpath()
            }, f, 0.8) }
            for vz: CGFloat in [-1, 1] { g.fill(kreis(P(mitte.x + vz * 1.3, mitte.y - 0.6), 0.9), with: .color(Pal.gelb.farbe)) }
        case .luftschlangen:
            let f = [Pal.rose.mix(Pal.weiss, 0.2), Pal.gelb, Pal.himmel, Pal.mint, Pal.decke][i % 5]
            let band = Path { p in
                p.move(to: m)
                for k in 1...7 {
                    let y = m.y + CGFloat(k) * 3.6
                    p.addQuadCurve(to: P(m.x, y), control: P(m.x + (k % 2 == 0 ? -6 : 6), y - 1.8))
                }
            }
            linie(g, band, f.farbe, 2.6)
            linie(g, band, .white.opacity(0.35), 0.8)
        }
    }

    // MARK: Boden (rechts neben der Kommode, Fuß bei x 272, y 322)

    private static let fuss = P(272, 322)

    private static func boden(_ g: GraphicsContext, _ art: ZimmerDeko.Boden) {
        switch art {
        case .geschenke: geschenke(g)
        case .tannenbaum: tannenbaum(g)
        case .kuerbisse: kuerbisse(g, gesicht: false)
        case .gruselkuerbis: kuerbisse(g, gesicht: true)
        case .osterkorb: osterkorb(g)
        case .blumentopf: blumentopf(g)
        case .stiefel: stiefel(g)
        case .strandball: strandball(g)
        }
    }

    private static func geschenk(_ g: GraphicsContext, _ r: CGRect, _ f: FigurFarbe, _ band: FigurFarbe, schleife: Bool = true) {
        teil(g, box(r.minX, r.minY, r.width, r.height, 2.5), f, 1.6)
        teil(g, box(r.midX - 1.8, r.minY, 3.6, r.height, 0.5), band, 0.8)
        teil(g, box(r.minX, r.midY - 0.5, r.width, 3.4, 0.5), band, 0.8)
        guard schleife else { return }
        for vz: CGFloat in [-1, 1] {
            teil(g, oval(P(r.midX + vz * 3.4, r.minY - 2), 3.4, 2.2), band, 0.8)
        }
        teil(g, kreis(P(r.midX, r.minY - 1.2), 1.4), band, 0.8)
    }

    private static func geschenke(_ g: GraphicsContext) {
        geschenk(g, CGRect(x: 258, y: 306, width: 24, height: 16), Pal.rose.mix(Pal.weiss, 0.3), Pal.gelb)
        geschenk(g, CGRect(x: 262, y: 294, width: 15, height: 12), Pal.himmel, Pal.weiss)
        geschenk(g, CGRect(x: 244, y: 313, width: 14, height: 9), Pal.mint, Pal.rose.mix(Pal.weiss, 0.4))
        g.fill(kreis(P(269, 297), 1.2), with: .color(.white.opacity(0.8)))
    }

    private static func tannenbaum(_ g: GraphicsContext) {
        let x = fuss.x
        teil(g, box(x - 4, 314, 8, 9, 1.5), Pal.holz.mal(0.8), 1.5)
        let gruen = c(0x4FA36A)
        let stufen: [(y: CGFloat, breite: CGFloat, hoehe: CGFloat)] = [(316, 36, 28), (296, 30, 26), (277, 23, 24)]
        for (n, s) in stufen.enumerated() {
            let f = gruen.mix(Pal.weiss, CGFloat(n) * 0.06)
            teil(g, Path { p in
                p.move(to: P(x, s.y - s.hoehe))
                p.addQuadCurve(to: P(x + s.breite / 2, s.y), control: P(x + s.breite * 0.2, s.y - s.hoehe * 0.35))
                p.addQuadCurve(to: P(x - s.breite / 2, s.y), control: P(x, s.y + 3))
                p.addQuadCurve(to: P(x, s.y - s.hoehe), control: P(x - s.breite * 0.2, s.y - s.hoehe * 0.35))
                p.closeSubpath()
            }, f, 1.8)
        }
        // Lichterkette in zwei Schwüngen, Kugeln, Stern.
        linie(g, bogen(P(x - 12, 305), P(x + 11, 296), P(x, 313)), Pal.gold.farbe, 1)
        linie(g, bogen(P(x - 8, 286), P(x + 8, 280), P(x, 293)), Pal.gold.farbe, 1)
        for (dx, y, f) in [(-11, 307, Pal.rose), (6, 311, Pal.gelb), (11, 297, Pal.himmel), (-6, 296, Pal.rose), (5, 288, Pal.gelb), (-3, 277, Pal.himmel)] as [(CGFloat, CGFloat, FigurFarbe)] {
            teil(g, kreis(P(x + dx, y), 2.6), f, 0.8)
            g.fill(kreis(P(x + dx - 0.8, y - 0.8), 0.8), with: .color(.white.opacity(0.85)))
        }
        g.fill(kreis(P(x, 251), 12), with: .radialGradient(Gradient(colors: [Pal.gelb.farbe.opacity(0.6), .clear]), center: P(x, 251), startRadius: 0, endRadius: 12))
        teil(g, stern(P(x, 251), 7, 3.2), Pal.gelb, 1.2)
        // Geschenke unter dem Baum.
        geschenk(g, CGRect(x: x - 22, y: 313, width: 11, height: 9), Pal.rose.mix(Pal.weiss, 0.3), Pal.weiss, schleife: false)
        geschenk(g, CGRect(x: x + 12, y: 316, width: 9, height: 7), Pal.himmel, Pal.gelb, schleife: false)
    }

    private static func kuerbis(_ g: GraphicsContext, _ m: CGPoint, _ r: CGFloat, gesicht: Bool) {
        let orange = c(0xF58A2E)
        for dx in [-0.5, 0.5] as [CGFloat] { teil(g, oval(P(m.x + dx * r, m.y), r * 0.62, r * 0.88), orange.mal(0.94), 1.6) }
        teil(g, oval(m, r * 0.62, r * 0.95), orange.mix(Pal.gelb, 0.12), 1.6)
        for dx in [-0.3, 0.3] as [CGFloat] {
            linie(g, bogen(P(m.x + dx * r, m.y - r * 0.8), P(m.x + dx * r, m.y + r * 0.8), P(m.x + dx * r * 1.7, m.y)), orange.mal(0.7).farbe, 1)
        }
        teil(g, box(m.x - 1.6, m.y - r * 1.2, 3.2, r * 0.45, 1), c(0x5E7F3A), 1)
        linie(g, bogen(P(m.x + 1, m.y - r * 1.05), P(m.x + r * 0.55, m.y - r * 1.05), P(m.x + r * 0.3, m.y - r * 1.45)), c(0x5E7F3A).farbe, 1.2)
        if gesicht {
            let glut = c(0xFFD34E)
            for vz: CGFloat in [-1, 1] {
                teil(g, Path { p in
                    p.move(to: P(m.x + vz * r * 0.42, m.y - r * 0.5))
                    p.addLine(to: P(m.x + vz * r * 0.12, m.y - r * 0.1))
                    p.addLine(to: P(m.x + vz * r * 0.58, m.y - r * 0.1))
                    p.closeSubpath()
                }, glut, 0.8)
            }
            teil(g, Path { p in
                p.move(to: P(m.x - r * 0.5, m.y + r * 0.2))
                p.addQuadCurve(to: P(m.x + r * 0.5, m.y + r * 0.2), control: P(m.x, m.y + r * 0.85))
                p.closeSubpath()
            }, glut, 0.8)
        } else {
            g.fill(oval(P(m.x - r * 0.32, m.y - r * 0.35), r * 0.12, r * 0.22), with: .color(.white.opacity(0.35)))
        }
    }

    private static func kuerbisse(_ g: GraphicsContext, gesicht: Bool) {
        kuerbis(g, P(fuss.x - 12, fuss.y - 8), 8, gesicht: false)
        kuerbis(g, P(fuss.x + 4, fuss.y - 11), 12, gesicht: gesicht)
        kuerbis(g, P(fuss.x + 17, fuss.y - 6), 6.5, gesicht: false)
    }

    private static func osterkorb(_ g: GraphicsContext) {
        let x = fuss.x
        let stroh = c(0xD9A55B)
        linie(g, bogen(P(x - 13, 311), P(x + 13, 311), P(x, 283)), stroh.mal(0.75).farbe, 3)
        linie(g, bogen(P(x - 13, 311), P(x + 13, 311), P(x, 283)), stroh.farbe, 1.4)
        let gras = c(0x7BC96F)
        for dx in stride(from: CGFloat(-13), through: 13, by: 4) {
            linie(g, bogen(P(x + dx, 312), P(x + dx * 1.15, 300), P(x + dx * 0.9, 305)), gras.farbe, 2)
        }
        for (dx, dy, f) in [(-7, 304, Pal.rose.mix(Pal.weiss, 0.4)), (1, 301, Pal.gelb), (8, 305, Pal.himmel.mix(Pal.weiss, 0.2))] as [(CGFloat, CGFloat, FigurFarbe)] {
            teil(g, oval(P(x + dx, dy), 4.4, 5.6), f, 1.2)
            linie(g, bogen(P(x + dx - 4, dy + 0.5), P(x + dx + 4, dy + 0.5), P(x + dx, dy + 3)), .white.opacity(0.85), 1)
        }
        let korb = Path { p in
            p.move(to: P(x - 17, 308))
            p.addLine(to: P(x + 17, 308))
            p.addQuadCurve(to: P(x + 12, 322), control: P(x + 16, 317))
            p.addLine(to: P(x - 12, 322))
            p.addQuadCurve(to: P(x - 17, 308), control: P(x - 16, 317))
            p.closeSubpath()
        }
        teil(g, korb, stroh, 1.8)
        for y in [312.0, 316.0, 320.0] as [CGFloat] { linie(g, strich(P(x - 15, y), P(x + 15, y)), stroh.mal(0.78).farbe, 0.9) }
        for dx in stride(from: CGFloat(-12), through: 12, by: 6) { linie(g, strich(P(x + dx, 308), P(x + dx * 0.9, 322)), stroh.mal(0.78).farbe, 0.9) }
        teil(g, Path { p in
            p.move(to: P(x - 4, 309))
            p.addLine(to: P(x + 4, 309))
            p.addLine(to: P(x + 3, 314))
            p.addLine(to: P(x - 3, 314))
            p.closeSubpath()
        }, Pal.rose.mix(Pal.weiss, 0.3), 0.8)
    }

    private static func blumentopf(_ g: GraphicsContext) {
        let x = fuss.x
        let stiele: [(dx: CGFloat, h: CGFloat, f: FigurFarbe)] = [(-7, 26, Pal.rose.mix(Pal.weiss, 0.2)), (0, 33, Pal.gelb), (7, 24, Pal.weiss)]
        for s in stiele {
            let top = P(x + s.dx, 311 - s.h)
            linie(g, bogen(P(x + s.dx * 0.4, 311), top, P(x + s.dx * 1.3, 311 - s.h * 0.5)), c(0x5DBB7A).mal(0.85).farbe, 1.6)
            if s.dx == 0 {
                for k in 0..<7 {
                    let w = CGFloat(k) * 2 * .pi / 7
                    teil(g, oval(P(top.x + cos(w) * 4.6, top.y + sin(w) * 4.6), 2.6, 2.6), s.f, 0.8)
                }
                teil(g, kreis(top, 2.8), c(0xC98A4B), 0.8)
            } else {
                teil(g, Path { p in
                    p.move(to: P(top.x - 4, top.y - 2))
                    p.addQuadCurve(to: P(top.x + 4, top.y - 2), control: P(top.x, top.y + 8))
                    p.addLine(to: P(top.x + 2.4, top.y - 7))
                    p.addLine(to: P(top.x, top.y - 3.4))
                    p.addLine(to: P(top.x - 2.4, top.y - 7))
                    p.closeSubpath()
                }, s.f, 1)
            }
        }
        teil(g, Path { p in
            p.move(to: P(x - 11, 310))
            p.addLine(to: P(x + 11, 310))
            p.addLine(to: P(x + 8, 322))
            p.addLine(to: P(x - 8, 322))
            p.closeSubpath()
        }, c(0xD9805A), 1.8)
        teil(g, box(x - 12.5, 308, 25, 4.5, 2), c(0xE59773), 1.4)
        teil(g, herzPfad(P(x, 317), 2.6), Pal.rose.mix(Pal.weiss, 0.4), 0.6)
    }

    private static func stiefel(_ g: GraphicsContext) {
        let x = fuss.x
        // Zuckerstangen und Süßes gucken oben heraus.
        for (dx, w) in [(-5, -0.35), (1, 0.05), (6, 0.4)] as [(CGFloat, CGFloat)] {
            let fuss0 = P(x + dx, 302)
            let spitze = P(x + dx + sin(w) * 22, 302 - cos(w) * 22)
            linie(g, strich(fuss0, spitze), Pal.weiss.farbe, 3.4)
            for t in stride(from: CGFloat(0.2), through: 0.9, by: 0.25) {
                let a = P(fuss0.x + (spitze.x - fuss0.x) * t, fuss0.y + (spitze.y - fuss0.y) * t)
                linie(g, strich(P(a.x - 1.6, a.y + 1.4), P(a.x + 1.6, a.y - 1.4)), Pal.rose.farbe, 1.4)
            }
        }
        teil(g, kreis(P(x - 9, 303), 2.8), Pal.gelb, 0.8)
        teil(g, herzPfad(P(x + 10, 302), 3.2), Pal.rose.mix(Pal.weiss, 0.2), 0.8)
        let rot = c(0xD9364B)
        teil(g, Path { p in
            p.move(to: P(x - 9, 304))
            p.addLine(to: P(x + 7, 304))
            p.addLine(to: P(x + 7, 314))
            p.addQuadCurve(to: P(x + 17, 318), control: P(x + 15, 314))
            p.addQuadCurve(to: P(x + 16, 322), control: P(x + 19, 322))
            p.addLine(to: P(x - 14, 322))
            p.addQuadCurve(to: P(x - 9, 314), control: P(x - 14, 316))
            p.closeSubpath()
        }, rot, 1.8)
        teil(g, box(x - 11, 300, 20, 7, 3.5), Pal.weiss, 1.4)
        g.fill(oval(P(x - 4, 312), 1.6, 4), with: .color(.white.opacity(0.35)))
        teil(g, stern(P(x - 1, 315), 3.2, 1.4), Pal.gelb, 0.6)
    }

    private static func strandball(_ g: GraphicsContext) {
        let m = P(fuss.x, fuss.y - 11)
        let farben = [Pal.rose, Pal.weiss, Pal.gelb, Pal.weiss, Pal.himmel, Pal.weiss]
        for (k, f) in farben.enumerated() {
            let s = Path { p in
                p.move(to: m)
                p.addArc(center: m, radius: 11, startAngle: .degrees(Double(k) * 60 - 90), endAngle: .degrees(Double(k + 1) * 60 - 90), clockwise: false)
                p.closeSubpath()
            }
            g.fill(s, with: .color(f.farbe))
        }
        g.stroke(kreis(m, 11), with: .color(Pal.dunkel.farbe.opacity(0.55)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        g.fill(oval(P(m.x - 4, m.y - 5), 3, 2), with: .color(.white.opacity(0.55)))
        teil(g, kreis(m, 1.8), Pal.weiss, 0.8)
        g.fill(oval(P(m.x, fuss.y + 0.5), 11, 2.2), with: .color(.black.opacity(0.12)))
    }

    // MARK: Luft (Ballons am Sofa)

    private static func luft(_ g: GraphicsContext, _ art: ZimmerDeko.Luft) {
        let tie = P(376, 262)
        let satz: [(m: CGPoint, f: FigurFarbe)]
        switch art {
        case .ballons:
            satz = [(P(366, 204), Pal.rose.mix(Pal.weiss, 0.25)), (P(380, 190), Pal.gelb), (P(370, 172), Pal.himmel)]
        case .herzballons:
            satz = [(P(366, 206), Pal.rose), (P(381, 192), Pal.rose.mix(Pal.weiss, 0.45)), (P(369, 175), Pal.weiss)]
        case .goldballons:
            satz = [(P(366, 204), Pal.gold), (P(380, 190), Pal.silber), (P(370, 172), Pal.gold.mix(Pal.weiss, 0.3))]
        }
        for b in satz {
            linie(g, bogen(tie, P(b.m.x, b.m.y + 16), P(b.m.x + (tie.x - b.m.x) * 0.2, (tie.y + b.m.y) / 2)), Pal.dunkel.farbe.opacity(0.55), 1)
        }
        for b in satz {
            if art == .herzballons {
                teil(g, herzPfad(b.m, 12), b.f, 1.6)
                g.fill(oval(P(b.m.x - 5, b.m.y - 5), 2.2, 3.2), with: .color(.white.opacity(0.6)))
                teil(g, Path { p in
                    p.move(to: P(b.m.x, b.m.y + 11))
                    p.addLine(to: P(b.m.x - 2.5, b.m.y + 15))
                    p.addLine(to: P(b.m.x + 2.5, b.m.y + 15))
                    p.closeSubpath()
                }, b.f, 0.8)
            } else {
                teil(g, oval(b.m, 10, 12.5), b.f, 1.6)
                g.fill(oval(P(b.m.x - 4, b.m.y - 5), 2.4, 3.6), with: .color(.white.opacity(0.55)))
                teil(g, Path { p in
                    p.move(to: P(b.m.x, b.m.y + 11.5))
                    p.addLine(to: P(b.m.x - 2.5, b.m.y + 15.5))
                    p.addLine(to: P(b.m.x + 2.5, b.m.y + 15.5))
                    p.closeSubpath()
                }, b.f, 0.8)
            }
        }
    }

    // MARK: Streu (Konfetti, Herzen, Schnee, Schmetterlinge, Blätter)

    /// Feste Punkte quer über die Wand: kein Zufall, jedes Bild gleich.
    private static func streupunkte(_ n: Int) -> [CGPoint] {
        (0..<n).map { (i: Int) -> CGPoint in
            let x: Int = (i * 97 + 31) % 372 + 8
            let y: Int = (i * 53 + 17) % 150 + 78
            return P(CGFloat(x), CGFloat(y))
        }
    }

    private static func streu(_ g: GraphicsContext, _ art: ZimmerDeko.Streu) {
        switch art {
        case .konfetti:
            let farben = [Pal.rose.mix(Pal.weiss, 0.2), Pal.gelb, Pal.himmel, Pal.mint, Pal.decke, Pal.gold]
            for (i, m) in streupunkte(34).enumerated() {
                let f = farben[i % farben.count].farbe
                if i % 3 == 0 {
                    g.fill(kreis(m, 2.2), with: .color(f))
                } else {
                    g.fill(gedreht(box(m.x - 3, m.y - 1.3, 6, 2.6, 0.8), um: m, CGFloat(i) * 0.9), with: .color(f))
                }
            }
        case .herzen:
            for (i, m) in streupunkte(14).enumerated() {
                let s: CGFloat = 3 + CGFloat(i % 3) * 1.6
                g.fill(gedreht(herzPfad(m, s), um: m, CGFloat(i % 5 - 2) * 0.22), with: .color(Pal.rose.mix(Pal.weiss, i % 2 == 0 ? 0.15 : 0.45).farbe.opacity(0.85)))
            }
        case .schnee:
            let glas = ZuhauseZeichnung.fenster.insetBy(dx: 7, dy: 7)
            var innen = g
            innen.clip(to: Path(glas))
            for i in 0..<22 {
                let dx: Int = (i * 37 + 9) % Int(glas.width)
                let dy: Int = (i * 23 + 5) % Int(glas.height)
                let m = P(glas.minX + CGFloat(dx), glas.minY + CGFloat(dy))
                innen.fill(kreis(m, 1.1 + CGFloat(i % 3) * 0.55), with: .color(.white.opacity(0.92)))
            }
            // Papier-Schneeflocken an der Wand.
            for (m, r) in [(P(40, 150), 11), (P(138, 178), 8), (P(312, 96), 9), (P(20, 110), 7)] as [(CGPoint, CGFloat)] {
                for k in 0..<3 {
                    let w = CGFloat(k) * .pi / 3
                    linie(g, strich(P(m.x + cos(w) * r, m.y + sin(w) * r), P(m.x - cos(w) * r, m.y - sin(w) * r)), c(0x9CCBE8).farbe, 1.4)
                }
                g.fill(kreis(m, 1.8), with: .color(c(0x9CCBE8).farbe))
            }
        case .schmetterlinge:
            for (m, f, w) in [(P(150, 130), Pal.rose, -0.3), (P(300, 90), Pal.gelb, 0.25), (P(60, 190), Pal.himmel, 0.1)] as [(CGPoint, FigurFarbe, CGFloat)] {
                for vz: CGFloat in [-1, 1] {
                    let oben = gedreht(oval(P(m.x + vz * 4.5, m.y - 2.6), 4.4, 3.6), um: m, w)
                    let unten = gedreht(oval(P(m.x + vz * 3.4, m.y + 2.6), 3.1, 2.6), um: m, w)
                    teil(g, oben, f.mix(Pal.weiss, 0.2), 0.9)
                    teil(g, unten, f.mix(Pal.weiss, 0.45), 0.9)
                }
                teil(g, gedreht(box(m.x - 0.9, m.y - 4, 1.8, 8, 0.9), um: m, w), Pal.dunkel, 0.5)
            }
        case .blaetter:
            let farben = [c(0xE07B39), c(0xC8553D), c(0xE8B04A), c(0x9C6B30)]
            for (i, m) in streupunkte(9).enumerated() {
                teil(g, blatt(m, 5.5, CGFloat(i) * 0.8), farben[i % 4], 1)
            }
        }
    }

    // MARK: Fenster-Sims (Boden der Dinge bei y 180)

    private static let sims: CGFloat = 181
    private static let mitteFenster = ZuhauseZeichnung.fenster.midX

    private static func fenster(_ g: GraphicsContext, _ art: ZimmerDeko.Fenster, kerzen: Int) {
        let x = mitteFenster
        switch art {
        case .torte: torte(g, x)
        case .kerzen:
            for (dx, h) in [(-17, 16), (0, 24), (17, 18)] as [(CGFloat, CGFloat)] { kerze(g, P(x + dx, sims), h, brennt: true) }
        case .rose: rose(g, x)
        case .osterhase: osterhase(g, x)
        case .tulpen: tulpen(g, x)
        case .sonnenblume: sonnenblume(g, x)
        case .laterne: laterne(g, x)
        case .geist: geist(g, x)
        case .adventskranz: adventskranz(g, x, kerzen: kerzen)
        case .stern:
            let m = P(x, 112)
            linie(g, strich(P(m.x, 70), P(m.x, m.y - 17)), .white.opacity(0.8), 1)
            g.fill(kreis(m, 28), with: .radialGradient(Gradient(colors: [Pal.gelb.farbe.opacity(0.55), .clear]), center: m, startRadius: 2, endRadius: 28))
            teil(g, stern(m, 17, 8), Pal.gelb, 1.8)
            g.fill(stern(m, 9, 4), with: .color(.white.opacity(0.55)))
        case .sektglaeser: sektglaeser(g, x)
        case .kleeblatt: kleeblatt(g, x)
        case .schneehaube: schneehaube(g)
        }
    }

    private static func kerze(_ g: GraphicsContext, _ fuss: CGPoint, _ h: CGFloat, brennt: Bool) {
        teil(g, box(fuss.x - 3, fuss.y - h, 6, h, 1.5), c(0xFFF3DC), 1.2)
        linie(g, bogen(P(fuss.x - 2.4, fuss.y - h + 0.5), P(fuss.x + 2.4, fuss.y - h + 0.5), P(fuss.x, fuss.y - h + 3.4)), Pal.rose.mix(Pal.weiss, 0.3).farbe, 1)
        linie(g, strich(P(fuss.x, fuss.y - h), P(fuss.x, fuss.y - h - 2)), Pal.dunkel.farbe, 0.8)
        if brennt { flamme(g, P(fuss.x, fuss.y - h - 4.4)) }
    }

    private static func torte(_ g: GraphicsContext, _ x: CGFloat) {
        teil(g, oval(P(x, sims), 20, 3.2), Pal.weiss, 1.4)
        teil(g, box(x - 16, sims - 12, 32, 11, 3), Pal.rose.mix(Pal.weiss, 0.35), 1.6)
        teil(g, box(x - 11, sims - 22, 22, 10, 3), Pal.weiss.mix(Pal.gelb, 0.18), 1.6)
        for dx in stride(from: CGFloat(-12), through: 12, by: 6) {
            g.fill(Path(ellipseIn: CGRect(x: x + dx - 1.6, y: sims - 6, width: 3.2, height: 5)), with: .color(Pal.weiss.farbe))
        }
        for (k, dx) in ([-8, -2, 4, 10] as [CGFloat]).enumerated() { g.fill(kreis(P(x + dx, sims - 13.4), 1.2 + CGFloat(k % 2) * 0.2), with: .color(Pal.rose.farbe)) }
        teil(g, kreis(P(x, sims - 24.4), 2.2), Pal.rose, 0.8)
        for dx in [-6, 0, 6] as [CGFloat] { kerze(g, P(x + dx, sims - 22), 8, brennt: true) }
    }

    private static func rose(_ g: GraphicsContext, _ x: CGFloat) {
        let flasche = c(0xBFE3F7)
        teil(g, box(x - 2.4, sims - 16, 4.8, 8, 1.4), flasche, 1.2)
        teil(g, oval(P(x, sims - 6), 7, 6.4), flasche, 1.6)
        linie(g, bogen(P(x, sims - 14), P(x + 2, sims - 34), P(x - 3, sims - 24)), c(0x4FA36A).farbe, 1.8)
        teil(g, blatt(P(x + 6, sims - 24), 5, 0.9), c(0x6FBF7B), 0.8)
        teil(g, blatt(P(x - 6, sims - 19), 4.4, -0.9), c(0x6FBF7B), 0.8)
        let b = P(x + 2, sims - 38)
        teil(g, kreis(b, 7), Pal.rose.mal(0.92), 1.4)
        for (r, f) in [(5, 0.0), (3.2, 0.1), (1.6, 0.2)] as [(CGFloat, Double)] {
            linie(g, Path { p in p.addArc(center: b, radius: r, startAngle: .degrees(f * 100), endAngle: .degrees(f * 100 + 230), clockwise: false) }, Pal.rose.mal(0.62).farbe, 1)
        }
        g.fill(oval(P(b.x - 2.6, b.y - 3), 1.6, 1.1), with: .color(.white.opacity(0.5)))
    }

    private static func osterhase(_ g: GraphicsContext, _ x: CGFloat) {
        let fell = Pal.weiss.mix(c(0xE9DCCB), 0.25)
        teil(g, kreis(P(x + 12, sims - 5), 3.6), Pal.weiss, 1)
        for (dx, w) in [(-4.5, -0.15), (4.5, 0.15)] as [(CGFloat, CGFloat)] {
            let m = P(x + dx, sims - 33)
            teil(g, gedreht(oval(m, 3.4, 9.5), um: m, w), fell, 1.4)
            g.fill(gedreht(oval(m, 1.6, 6.8), um: m, w), with: .color(Pal.rose.mix(Pal.weiss, 0.55).farbe))
        }
        teil(g, oval(P(x, sims - 10), 11, 10), fell, 1.6)
        teil(g, oval(P(x, sims - 21), 8.4, 7.6), fell, 1.6)
        for dx in [-3.2, 3.2] as [CGFloat] {
            g.fill(kreis(P(x + dx, sims - 22), 1.2), with: .color(Pal.tinte.farbe))
            g.fill(oval(P(x + dx * 1.6, sims - 18.4), 1.8, 1.1), with: .color(Pal.rose.mix(Pal.weiss, 0.45).farbe.opacity(0.8)))
        }
        g.fill(oval(P(x, sims - 19.6), 1.5, 1.1), with: .color(Pal.rose.farbe))
        linie(g, bogen(P(x - 2, sims - 17.6), P(x + 2, sims - 17.6), P(x, sims - 16)), Pal.tinte.farbe, 0.8)
        teil(g, oval(P(x - 11, sims - 3), 4, 2.6), fell, 1)
        teil(g, oval(P(x + 4, sims - 3), 4, 2.6), fell, 1)
        teil(g, oval(P(x - 4.5, sims - 9), 3.6, 4.6), Pal.rose.mix(Pal.weiss, 0.35), 1)
        linie(g, strich(P(x - 7, sims - 9), P(x - 2, sims - 9)), .white.opacity(0.85), 1)
    }

    private static func tulpen(_ g: GraphicsContext, _ x: CGFloat) {
        let farben = [Pal.rose, Pal.gelb, Pal.rose.mix(Pal.weiss, 0.45)]
        for (k, dx) in ([-9, 0, 9] as [CGFloat]).enumerated() {
            let top = P(x + dx, sims - (k == 1 ? 34 : 28))
            linie(g, bogen(P(x + dx * 0.3, sims - 6), top, P(x + dx * 1.2, sims - 18)), c(0x4FA36A).farbe, 1.8)
            teil(g, blatt(P(x + dx * 0.3 + (dx == 0 ? 4 : -dx * 0.25), sims - 12), 5.4, dx == 0 ? 0.5 : -0.6), c(0x6FBF7B), 0.8)
            teil(g, Path { p in
                p.move(to: P(top.x - 4.4, top.y - 4))
                p.addQuadCurve(to: P(top.x + 4.4, top.y - 4), control: P(top.x, top.y + 10))
                p.addLine(to: P(top.x + 2.8, top.y - 9.4))
                p.addLine(to: P(top.x, top.y - 4.6))
                p.addLine(to: P(top.x - 2.8, top.y - 9.4))
                p.closeSubpath()
            }, farben[k], 1.2)
        }
        teil(g, Path { p in
            p.move(to: P(x - 14, sims - 8))
            p.addLine(to: P(x + 14, sims - 8))
            p.addLine(to: P(x + 10, sims))
            p.addLine(to: P(x - 10, sims))
            p.closeSubpath()
        }, c(0xD9805A), 1.6)
        teil(g, box(x - 15.5, sims - 10.4, 31, 3.6, 1.6), c(0xE59773), 1.2)
    }

    private static func sonnenblume(_ g: GraphicsContext, _ x: CGFloat) {
        let kopf = P(x, sims - 40)
        linie(g, strich(P(x, sims - 8), P(x, kopf.y + 8)), c(0x4FA36A).farbe, 2.4)
        teil(g, blatt(P(x + 7, sims - 20), 6.6, 1.1), c(0x6FBF7B), 0.9)
        teil(g, blatt(P(x - 7, sims - 14), 6, -1.1), c(0x6FBF7B), 0.9)
        for k in 0..<12 {
            let w = CGFloat(k) * .pi / 6
            teil(g, gedreht(oval(P(kopf.x, kopf.y - 10), 2.9, 5.2), um: kopf, w), Pal.gelb, 0.9)
        }
        teil(g, kreis(kopf, 6.2), c(0x8B5A2B), 1.2)
        for (dx, dy) in [(-2, -1), (2, -2), (0, 2), (-3, 2), (3, 1)] as [(CGFloat, CGFloat)] { g.fill(kreis(P(kopf.x + dx, kopf.y + dy), 0.7), with: .color(c(0x5E3A1B).farbe)) }
        teil(g, Path { p in
            p.move(to: P(x - 10, sims - 9))
            p.addLine(to: P(x + 10, sims - 9))
            p.addLine(to: P(x + 7, sims))
            p.addLine(to: P(x - 7, sims))
            p.closeSubpath()
        }, c(0xD9805A), 1.6)
        teil(g, box(x - 11.5, sims - 11.4, 23, 3.6, 1.6), c(0xE59773), 1.2)
    }

    private static func laterne(_ g: GraphicsContext, _ x: CGFloat) {
        let m = P(x, sims - 17)
        let eisen = c(0x4B3F52)
        linie(g, bogen(P(x - 8, sims - 28), P(x + 8, sims - 28), P(x, sims - 44)), eisen.farbe, 1.6)
        g.fill(kreis(m, 22), with: .radialGradient(Gradient(colors: [Pal.gelb.farbe.opacity(0.45), .clear]), center: m, startRadius: 2, endRadius: 22))
        teil(g, box(x - 9, sims - 26, 18, 25, 4), c(0xFFE9A6), 1.6)
        for dx in [-3.0, 3.0] as [CGFloat] { linie(g, strich(P(x + dx, sims - 25), P(x + dx, sims - 2)), eisen.farbe.opacity(0.7), 1) }
        teil(g, box(x - 11, sims - 29, 22, 4, 2), eisen, 1)
        teil(g, box(x - 11, sims - 3, 22, 4, 2), eisen, 1)
        flamme(g, P(x, sims - 12), 1.3)
        g.fill(oval(P(x - 5, sims - 16), 1.2, 5), with: .color(.white.opacity(0.45)))
    }

    private static func geist(_ g: GraphicsContext, _ x: CGFloat) {
        let koerper = Path { p in
            p.move(to: P(x - 11, sims))
            p.addLine(to: P(x - 11, sims - 20))
            p.addQuadCurve(to: P(x + 11, sims - 20), control: P(x, sims - 44))
            p.addLine(to: P(x + 11, sims))
            for k in 0..<4 {
                let x0 = x + 11 - CGFloat(k) * 5.5
                p.addQuadCurve(to: P(x0 - 5.5, sims), control: P(x0 - 2.75, sims - (k % 2 == 0 ? -4 : 5)))
            }
            p.closeSubpath()
        }
        g.fill(oval(P(x, sims), 14, 3), with: .color(.black.opacity(0.1)))
        teil(g, koerper, Pal.weiss, 1.6)
        for dx in [-4, 4] as [CGFloat] { g.fill(oval(P(x + dx, sims - 20), 1.8, 2.8), with: .color(Pal.tinte.farbe)) }
        for dx in [-7, 7] as [CGFloat] { g.fill(oval(P(x + dx, sims - 16), 2.2, 1.4), with: .color(Pal.rose.mix(Pal.weiss, 0.5).farbe.opacity(0.8))) }
        g.fill(oval(P(x, sims - 14), 1.6, 2.2), with: .color(Pal.tinte.farbe))
        for vz: CGFloat in [-1, 1] { teil(g, oval(P(x + vz * 12, sims - 11), 3.2, 2.2), Pal.weiss, 1) }
    }

    private static func adventskranz(_ g: GraphicsContext, _ x: CGFloat, kerzen: Int) {
        let gruen = c(0x4FA36A)
        for k in 0..<18 {
            let w = CGFloat(k) * 2 * .pi / 18
            let m = P(x + cos(w) * 22, sims - 4 + sin(w) * 4.6)
            teil(g, kreis(m, 4.6), gruen.mix(Pal.weiss, k % 3 == 0 ? 0.12 : 0), 0.9)
        }
        for (k, dx) in ([-14, -5, 5, 14] as [CGFloat]).enumerated() {
            kerze(g, P(x + dx, sims - 3 + (abs(dx) > 10 ? 1 : 3)), 15, brennt: k < kerzen)
        }
        teil(g, Path { p in
            p.move(to: P(x - 4, sims - 1))
            p.addLine(to: P(x - 8, sims + 4))
            p.addLine(to: P(x - 2, sims + 2.4))
            p.closeSubpath()
        }, Pal.rose, 0.8)
        teil(g, Path { p in
            p.move(to: P(x + 4, sims - 1))
            p.addLine(to: P(x + 8, sims + 4))
            p.addLine(to: P(x + 2, sims + 2.4))
            p.closeSubpath()
        }, Pal.rose, 0.8)
        teil(g, kreis(P(x, sims - 0.4), 2.4), Pal.rose, 0.8)
    }

    private static func sektglaeser(_ g: GraphicsContext, _ x: CGFloat) {
        for (dx, w) in [(-9, 0.22), (9, -0.22)] as [(CGFloat, CGFloat)] {
            let fuss = P(x + dx, sims)
            let glas = Path { p in
                p.move(to: P(fuss.x - 4.4, fuss.y - 30))
                p.addLine(to: P(fuss.x + 4.4, fuss.y - 30))
                p.addQuadCurve(to: P(fuss.x + 0.8, fuss.y - 15), control: P(fuss.x + 4.2, fuss.y - 20))
                p.addLine(to: P(fuss.x - 0.8, fuss.y - 15))
                p.addQuadCurve(to: P(fuss.x - 4.4, fuss.y - 30), control: P(fuss.x - 4.2, fuss.y - 20))
                p.closeSubpath()
            }
            let teile: [(Path, FigurFarbe)] = [
                (box(fuss.x - 5, fuss.y - 2.4, 10, 2.4, 1.2), Pal.silber),
                (box(fuss.x - 0.7, fuss.y - 16, 1.4, 14, 0.5), Pal.silber),
                (glas, Pal.sekt.mix(Pal.weiss, 0.3)),
            ]
            for (p, f) in teile { teil(g, gedreht(p, um: fuss, w), f, 1) }
            let m = P(fuss.x, fuss.y - 25)
            g.fill(gedreht(oval(m, 3, 4), um: fuss, w), with: .color(.white.opacity(0.4)))
        }
        for (dx, dy, r) in [(0, 40, 1.5), (-4, 46, 1.1), (5, 50, 1.2), (1, 56, 0.9)] as [(CGFloat, CGFloat, CGFloat)] {
            g.fill(kreis(P(x + dx, sims - dy), r), with: .color(Pal.gold.farbe))
        }
        g.fill(stern(P(x + 15, sims - 44), 3.4, 1.4, spitzen: 4), with: .color(Pal.gold.farbe))
        g.fill(stern(P(x - 14, sims - 50), 2.8, 1.2, spitzen: 4), with: .color(Pal.gold.farbe))
    }

    private static func kleeblatt(_ g: GraphicsContext, _ x: CGFloat) {
        teil(g, Path { p in
            p.move(to: P(x - 10, sims - 9))
            p.addLine(to: P(x + 10, sims - 9))
            p.addLine(to: P(x + 7, sims))
            p.addLine(to: P(x - 7, sims))
            p.closeSubpath()
        }, c(0xD9805A), 1.6)
        teil(g, box(x - 11.5, sims - 11.4, 23, 3.6, 1.6), c(0xE59773), 1.2)
        let m = P(x, sims - 24)
        linie(g, bogen(P(x, sims - 9), m, P(x + 3, sims - 17)), c(0x4FA36A).farbe, 1.6)
        for k in 0..<4 {
            let b = gedreht(herzPfad(P(m.x, m.y - 5.6), 5.2), um: m, CGFloat(k) * .pi / 2 + .pi)
            teil(g, b, c(0x5DBB7A), 1)
        }
        g.fill(kreis(m, 1.3), with: .color(c(0x3D8A55).farbe))
    }

    private static func schneehaube(_ g: GraphicsContext) {
        let f = ZuhauseZeichnung.fenster
        let haube = Path { p in
            p.move(to: P(f.minX - 6, sims + 1))
            var x = f.minX - 6
            while x < f.maxX + 6 {
                p.addQuadCurve(to: P(x + 12, sims + 1), control: P(x + 6, sims - 7 - CGFloat(Int(x) % 3)))
                x += 12
            }
            p.addLine(to: P(f.maxX + 6, sims + 3))
            p.addLine(to: P(f.minX - 6, sims + 3))
            p.closeSubpath()
        }
        teil(g, haube, Pal.weiss, 1.2)
        // Kleiner Schneemann auf dem Sims.
        let x = f.maxX - 24
        teil(g, kreis(P(x, sims - 6), 6.2), Pal.weiss, 1.2)
        teil(g, kreis(P(x, sims - 16), 4.6), Pal.weiss, 1.2)
        teil(g, Path { p in
            p.move(to: P(x, sims - 16))
            p.addLine(to: P(x + 6, sims - 15))
            p.addLine(to: P(x, sims - 14.2))
            p.closeSubpath()
        }, Pal.rose.mix(c(0xF58A2E), 0.7), 0.5)
        for dx in [-1.6, 1.6] as [CGFloat] { g.fill(kreis(P(x + dx, sims - 17.4), 0.7), with: .color(Pal.tinte.farbe)) }
        for dy in [-8, -4] as [CGFloat] { g.fill(kreis(P(x, sims + dy), 0.8), with: .color(Pal.tinte.farbe)) }
        teil(g, box(x - 5, sims - 12.2, 10, 2.4, 1.2), Pal.rose, 0.7)
        teil(g, box(x - 3.6, sims - 22, 7.2, 4.6, 1), Pal.dunkel, 0.7)
    }
}
