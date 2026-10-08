import SwiftUI

/// p64: die Vektorzeichnungen des Paar-Alltags im Zimmer, im Sticker-Stil der Figuren (`teil`). Jede
/// Zeichnung liegt in ihrem eigenen kleinen Raster (`SignaleBild`) und bleibt bei jeder Größe scharf.
enum AlltagZeichnung {
    static let platteRaster = CGSize(width: 78, height: 62)
    static let nachttischRaster = CGSize(width: 52, height: 60)
    static let kuehlRaster = CGSize(width: 40, height: 66)
    static let spiegelRaster = CGSize(width: 64, height: 96)
    static let waermeRaster = CGSize(width: 50, height: 30)

    private static let holz = FigurFarbe(0xD9B38A)
    private static let holzDunkel = FigurFarbe(0xB98A5E)

    // MARK: Plattenspieler

    /// Der Plattenspieler auf dem Wandregal. `winkel` (Bogenmaß) dreht die Platte, flach gedrückt wie von
    /// schräg oben. `bespielt`: liegt ein Song auf, sonst steht der Tonarm daneben.
    static func plattenspieler(_ g: GraphicsContext, winkel: Double, bespielt: Bool) {
        for x in [8, 62] as [CGFloat] {
            let stuetze = Path { p in
                p.move(to: P(x, 54))
                p.addLine(to: P(x + 8, 54))
                p.addLine(to: P(x, 62))
                p.closeSubpath()
            }
            teil(g, stuetze, holzDunkel, 1.6)
        }
        teil(g, box(0, 48, 78, 6, 2.5), holz, 2)
        teil(g, box(6, 20, 66, 28, 5), FigurFarbe(0xB57A55), 2.5)
        g.fill(kreis(P(17, 43), 2.4), with: .color(Pal.gold.farbe))
        g.fill(kreis(P(25, 43), 2.4), with: .color(Pal.gold.farbe))
        teil(g, herzPfad(P(60, 43), 2.6), Pal.rose, 1)
        teil(g, box(6, 4, 66, 34, 6), FigurFarbe(0xF3E3C8), 2.5)
        teil(g, oval(P(36, 22), 27, 11.5), Pal.silber, 1.5)
        var f = g
        f.translateBy(x: 36, y: 22)
        f.scaleBy(x: 1, y: 0.42)
        f.rotate(by: .radians(winkel))
        platte(f)
        let kopf = bespielt ? P(54, 24) : P(66, 32)
        let arm = strich(P(66, 10), kopf)
        linie(g, arm, Pal.silber.kontur, 3.6)
        linie(g, arm, Pal.silber.farbe, 2)
        teil(g, kreis(P(66, 10), 3.4), Pal.silber, 1.4)
        teil(g, kreis(kopf, 2.4), Pal.dunkel, 1)
    }

    /// Die Schallplatte um den Nullpunkt, Halbmesser 24: Rillen, zwei Glanzbögen und ein Etikett mit
    /// Punkt, damit man die Drehung sieht.
    private static func platte(_ g: GraphicsContext) {
        let vinyl = FigurFarbe(0x2E2A36)
        teil(g, kreis(.zero, 24), vinyl, 1.4)
        for r in [10.5, 14, 17.5, 21] as [CGFloat] {
            g.stroke(kreis(.zero, r), with: .color(Color.white.opacity(0.1)), lineWidth: 0.8)
        }
        for start in [200, 20] as [Double] {
            let glanz = Path { p in
                p.addArc(center: .zero, radius: 18, startAngle: .degrees(start), endAngle: .degrees(start + 50), clockwise: false)
            }
            g.stroke(glanz, with: .color(Color.white.opacity(0.35)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
        teil(g, kreis(.zero, 8.5), Pal.rose, 1.2)
        g.fill(kreis(P(5.4, 0), 1.2), with: .color(Pal.weiss.farbe))
        g.fill(kreis(.zero, 1.3), with: .color(vinyl.farbe))
    }

    // MARK: Nachttisch mit Wecker

    /// Der kleine Nachttisch mit Wecker. `gestellt`: die andere Person hat einen Wecker an, er ist rosa.
    static func nachttisch(_ g: GraphicsContext, gestellt: Bool) {
        g.fill(oval(P(26, 58), 24, 2.2), with: .color(Color.black.opacity(0.12)))
        teil(g, box(9, 55, 5, 4, 1.5), holzDunkel, 1.6)
        teil(g, box(38, 55, 5, 4, 1.5), holzDunkel, 1.6)
        teil(g, box(7, 36, 38, 20, 3), holz, 2.2)
        teil(g, box(11, 40, 30, 12, 2), holz.mix(Pal.weiss, 0.3), 1.6)
        g.fill(kreis(P(26, 46), 1.8), with: .color(Pal.gold.farbe))
        teil(g, box(3, 30, 46, 7, 3), holz.mix(Pal.weiss, 0.25), 2.2)
        let ton = gestellt ? FigurFarbe(0xFF8FA3) : FigurFarbe(0xB9CBF2)
        teil(g, kreis(P(17, 9), 4.2), Pal.gold, 1.4)
        teil(g, kreis(P(35, 9), 4.2), Pal.gold, 1.4)
        linie(g, strich(P(20, 28), P(18, 31)), Pal.dunkel.farbe, 1.8)
        linie(g, strich(P(32, 28), P(34, 31)), Pal.dunkel.farbe, 1.8)
        teil(g, kreis(P(26, 19), 10.5), ton, 2.2)
        g.fill(kreis(P(26, 19), 7.6), with: .color(Pal.weiss.farbe))
        for punkt in [P(26, 13.4), P(31.6, 19), P(26, 24.6), P(20.4, 19)] {
            g.fill(kreis(punkt, 0.7), with: .color(Pal.tinte.farbe.opacity(0.5)))
        }
        linie(g, strich(P(26, 19), P(26, 14.4)), Pal.tinte.farbe, 1.5)
        linie(g, strich(P(26, 19), P(29.6, 20.6)), Pal.tinte.farbe, 1.5)
    }

    // MARK: Kühlschrank

    /// Der kleine Kühlschrank mit bis zu drei Magnet-Zetteln an der Tür.
    static func kuehlschrank(_ g: GraphicsContext, zettel: Int) {
        let mint = FigurFarbe(0xCDEBE3)
        g.fill(oval(P(20, 65), 18, 1.8), with: .color(Color.black.opacity(0.12)))
        teil(g, box(7, 62, 5, 3.5, 1.2), Pal.dunkel, 1.2)
        teil(g, box(28, 62, 5, 3.5, 1.2), Pal.dunkel, 1.2)
        teil(g, box(3, 2, 34, 61, 6), mint, 2.5)
        linie(g, strich(P(5, 22), P(35, 22)), mint.kontur, 2)
        teil(g, box(29.5, 8, 3.4, 9, 1.7), Pal.silber, 1.2)
        teil(g, box(29.5, 27, 3.4, 15, 1.7), Pal.silber, 1.2)
        teil(g, herzPfad(P(14, 12), 3.6), Pal.rose, 1.2)
        let farben = [FigurFarbe(0xFFE88A), FigurFarbe(0xFFB8CB), FigurFarbe(0xB9CBF2)]
        let orte: [(CGPoint, Double)] = [(P(10, 25), -5), (P(13, 37), 4), (P(8.5, 49), -3)]
        for i in 0..<min(max(zettel, 0), 3) {
            var f = g
            f.translateBy(x: orte[i].0.x + 7, y: orte[i].0.y + 5.5)
            f.rotate(by: .degrees(orte[i].1))
            teil(f, box(-7, -5.5, 14, 11, 1.5), farben[i], 1.4)
            linie(f, strich(P(-4, -0.5), P(3, -0.5)), farben[i].mal(0.7).farbe, 1.1)
            linie(f, strich(P(-4, 2.5), P(1, 2.5)), farben[i].mal(0.7).farbe, 1.1)
            f.fill(kreis(P(0, -5.5), 1.5), with: .color(Pal.rose.farbe))
        }
    }

    // MARK: Spiegel

    /// Der Wandspiegel. `haengt`: ein Outfit-Foto der anderen Person steckt als Polaroid am Rahmen.
    static func spiegel(_ g: GraphicsContext, haengt: Bool) {
        let rahmen = FigurFarbe(0xF0B9CB)
        teil(g, box(2, 2, 54, 90, 27), rahmen, 2.8)
        let glas = box(7, 7, 44, 80, 22)
        let verlauf = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [FigurFarbe(0xEAF6FF).farbe, FigurFarbe(0xBFE0F5).farbe]),
            startPoint: P(0, 7), endPoint: P(0, 87))
        g.fill(glas, with: verlauf)
        g.stroke(glas, with: .color(rahmen.kontur), lineWidth: 1.4)
        linie(g, strich(P(16, 42), P(27, 22)), Color.white.opacity(0.85), 2.4)
        linie(g, strich(P(14, 52), P(18, 45)), Color.white.opacity(0.85), 2.4)
        teil(g, herzPfad(P(29, 4), 3), Pal.rose, 1)
        guard haengt else { return }
        var f = g
        f.translateBy(x: 47, y: 72)
        f.rotate(by: .degrees(7))
        teil(f, box(-12, -15, 24, 30, 2), Pal.weiss, 1.6)
        teil(f, box(-9, -12, 18, 18, 1.2), FigurFarbe(0xF6C6D6), 1)
        let hemd = Path { p in
            p.move(to: P(-3.5, -9))
            p.addLine(to: P(-7, -6.5))
            p.addLine(to: P(-5.5, -4))
            p.addLine(to: P(-4, -5))
            p.addLine(to: P(-4, 2))
            p.addLine(to: P(4, 2))
            p.addLine(to: P(4, -5))
            p.addLine(to: P(5.5, -4))
            p.addLine(to: P(7, -6.5))
            p.addLine(to: P(3.5, -9))
            p.addQuadCurve(to: P(-3.5, -9), control: P(0, -6.5))
            p.closeSubpath()
        }
        teil(f, hemd, Pal.weiss, 1)
        teil(f, box(-5, -17.5, 10, 5, 1), FigurFarbe(0xFFE08A), 0.8)
    }

    // MARK: Wärmflasche und Tee

    /// Wärmflasche, Tasse Tee und ein Herzkeks. Steht nur an einem schweren Tag auf dem Teppich.
    static func waermeSet(_ g: GraphicsContext) {
        let rosa = FigurFarbe(0xFF9DB5)
        teil(g, box(1, 8, 16, 20, 7), rosa, 2)
        for y in [14, 18, 22] as [CGFloat] {
            linie(g, strich(P(4, y), P(14, y)), rosa.mal(0.8).farbe, 1.2)
        }
        teil(g, box(6, 3, 6, 6, 2), Pal.gold, 1.4)
        teil(g, oval(P(26, 27), 11, 2.8), Pal.weiss, 1.4)
        linie(g, kreis(P(36, 19), 3), Pal.weiss.kontur, 3.2)
        linie(g, kreis(P(36, 19), 3), Pal.weiss.farbe, 1.5)
        teil(g, box(18, 13, 17, 13, 6), Pal.weiss, 1.8)
        g.fill(oval(P(26.5, 14), 7.2, 1.7), with: .color(FigurFarbe(0xC98B5E).farbe))
        teil(g, herzPfad(P(26.5, 21), 2.3), Pal.rose, 0.8)
        linie(g, bogen(P(24, 11), P(24, 3), P(20, 7)), Pal.silber.farbe, 1.4)
        linie(g, bogen(P(29, 11), P(29, 2), P(33, 6.5)), Pal.silber.farbe, 1.4)
        let keks = FigurFarbe(0xB5763E)
        teil(g, herzPfad(P(44.5, 24), 4.8), keks, 1.4)
        g.fill(herzPfad(P(44.5, 24), 3), with: .color(Pal.rose.farbe.opacity(0.55)))
        for punkt in [P(43, 22.5), P(46, 23.5), P(44.5, 26)] {
            g.fill(kreis(punkt, 0.7), with: .color(keks.mal(0.6).farbe))
        }
    }
}
