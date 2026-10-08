import SwiftUI

/// Strauß 5 (p59-strauss-5-glitzer-rot.png): nine big open red glitter roses with dark hearts in
/// black wrapping paper with a gold edge, tied with a curling red ribbon.
enum StraussGlitzerRot {
    static func zeichne(_ g: GraphicsContext, fein: Bool) {
        let a = FotoAbb(ox: 0, oy: 365, sx: 0.2, sy: 0.2, sr: 0.235, dx: 8, dy: 6)
        let schwarzOben = FigurFarbe(0x1E1A1B)
        let schwarzUnten = FigurFarbe(0x090707)
        let gold = Color(red: 0.8, green: 0.63, blue: 0.28)
        let goldFalte = gold.opacity(0.6)

        // Paper: stems and cone, then four black sheets with a gold edge, one over the other.
        blumeStiele(g, mitteX: 100, unten: 238)
        blumePapier(g, [P(54, 150), P(146, 150), P(116, 232), P(84, 232)], oben: schwarzOben, unten: schwarzUnten, kante: gold, kanteBreite: 1.4,
                    falten: [(P(76, 160), P(90, 230)), (P(124, 160), P(110, 230))], faltenFarbe: goldFalte, glanz: .white.opacity(0.06))
        let blaetter: [[(CGFloat, CGFloat)]] = [
            [(0, 730), (280, 650), (250, 900), (0, 1190)],
            [(0, 1190), (250, 900), (560, 1180), (420, 1215), (210, 1175)],
            [(690, 490), (850, 650), (920, 720), (900, 900), (770, 1070), (700, 900)],
            [(410, 365), (590, 450), (640, 440), (850, 650), (560, 1180), (300, 760), (280, 650)],
        ]
        for b in blaetter {
            blumePapier(g, a.pfad(b), oben: schwarzOben, unten: schwarzUnten, kante: gold, kanteBreite: 1.6, faltenFarbe: goldFalte, glanz: .white.opacity(0.06))
        }
        for (p, q) in [((410, 365), (280, 650)), ((640, 440), (840, 790)), ((250, 900), (560, 1180))] as [((CGFloat, CGFloat), (CGFloat, CGFloat))] {
            linie(g, strich(a.p(p.0, p.1), a.p(q.0, q.1)), goldFalte, 0.9)
        }

        // The roses: deep red, bright edges, glitter all over. Back to front.
        let hell = FigurFarbe(0xA3171F)
        let dunkel = FigurFarbe(0x3A0508)
        let kante = FigurFarbe(0xE0413A)
        let funken: [Color] = [Color(red: 1, green: 0.25, blue: 0.25), Color(red: 1, green: 0.48, blue: 0.24), Color(red: 1, green: 0.8, blue: 0.75), Color(red: 0.78, green: 0.12, blue: 0.14)]
        let rosen: [(CGFloat, CGFloat, CGFloat)] = [
            (310, 700, 50), (465, 625, 105), (665, 700, 90), (570, 830, 95), (330, 830, 100), (180, 990, 70), (275, 1000, 80), (650, 980, 100), (425, 1070, 100),
        ]
        for (i, r) in rosen.enumerated() {
            let c = a.p(r.0, r.1)
            let rr = a.r(r.2)
            blumeRose(g, c, rr, hell: hell, dunkel: dunkel, rand: kante, winkel: CGFloat(i) * 0.8, fein: fein)
            if fein {
                blumeGlitzer(g, c, rr * 0.92, anzahl: 110, farben: funken, punkt: 0.45, seed: UInt64(70 + i))
            }
        }

        // The ribbon: a small bow at the neck, two curling tails.
        let band = FigurFarbe(0xD62A2A)
        for (von, nach) in [(P(100, 172), P(80, 162)), (P(100, 172), P(120, 162))] {
            let schlaufe = blumenBlatt(von, nach, breite: 5, rund: 1)
            g.fill(schlaufe, with: .color(band.farbe))
            g.stroke(schlaufe, with: .color(band.kontur), style: StrokeStyle(lineWidth: 0.8))
        }
        let schwanz1 = Path { p in
            p.move(to: P(102, 172))
            p.addCurve(to: P(128, 212), control1: P(116, 180), control2: P(116, 200))
            p.addCurve(to: P(122, 226), control1: P(134, 222), control2: P(120, 230))
        }
        let schwanz2 = Path { p in
            p.move(to: P(98, 172))
            p.addCurve(to: P(72, 206), control1: P(86, 182), control2: P(76, 192))
            p.addCurve(to: P(82, 222), control1: P(66, 218), control2: P(80, 226))
        }
        for s in [schwanz1, schwanz2] {
            linie(g, s, band.kontur, 4.6)
            linie(g, s, band.farbe, 3.4)
            linie(g, s, band.mix(Pal.weiss, 0.45).farbe.opacity(0.7), 0.9)
        }
        g.fill(oval(P(100, 172), 4, 3.2), with: .color(band.farbe))
        g.stroke(oval(P(100, 172), 4, 3.2), with: .color(band.kontur), style: StrokeStyle(lineWidth: 0.8))
    }
}
