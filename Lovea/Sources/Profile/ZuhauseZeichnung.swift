import SwiftUI

/// p58: the shared home in the figures' sticker style (`teil`: fill plus the soft outline), vector
/// only, so it stays sharp at any size. Design space 390 x 430 like `SzenenZeichnung` (scaled to the
/// full width, anchored at the bottom). This is everything that stands still; the bed with its
/// sleepers, the bouquets, the figures and the sofa's front cushion are views in `ZuhauseBuehne`.
enum ZuhauseZeichnung {
    static let breite = SzenenZeichnung.breite
    static let hoehe = SzenenZeichnung.hoehe

    // MARK: Layout (design space)

    /// The bed space (300 x 220) of `SzenenZeichnung.bettHinten/bettVorn`: top left and scale.
    static let bettOrt = CGPoint(x: 4, y: 208)
    static let bettMass: CGFloat = 0.56
    /// "Samt rosa", the pink bed.
    static let bettStil = 2

    static let fenster = CGRect(x: 178, y: 62, width: 88, height: 120)
    static let schrank = CGRect(x: 180, y: 248, width: 84, height: 66)
    /// The dresser's top: the bouquets stand on it.
    static let schrankOben: CGFloat = 242
    static let sofa = CGRect(x: 286, y: 232, width: 100, height: 86)
    /// Centre of the round table's top, in front of the dresser.
    static let tisch = CGPoint(x: 222, y: 322)
    static let lampe = CGPoint(x: 110, y: 98)

    /// Every bouquet is drawn into this frame: bottom edge centred on its standing place.
    static let strauss = CGSize(width: 24, height: 40)

    /// Bottom centres of the dresser's three places, left to right.
    static var schrankPlaetze: [CGPoint] {
        (0..<ZuhauseStraeusse.schrankPlaetze).map { CGPoint(x: 196 + CGFloat($0) * 26, y: schrankOben + 2) }
    }

    /// Bottom centre of the vase's bouquet: the stems end inside the vase's neck.
    static var vasenPlatz: CGPoint { CGPoint(x: tisch.x, y: tisch.y - 22) }

    private static var scheibe: CGRect { fenster.insetBy(dx: 7, dy: 7) }

    /// Reaches far above the design space, so a stretched header never shows a gap.
    private static var alles: Path { box(0, -2000, breite, 2800) }

    private static func c(_ hex: UInt32) -> Color { FigurFarbe(hex).farbe }

    // MARK: Room (standing still)

    static func raum(_ g: GraphicsContext, zeit: Tageszeit) {
        wandUndBoden(g)
        fensterZeichnen(g, zeit)
        sofaHinten(g)
        schrankZeichnen(g)
        tischZeichnen(g)
        lampeZeichnen(g)
        abdunkeln(g, zeit)
    }

    private static func wandUndBoden(_ g: GraphicsContext) {
        let wand = FigurFarbe(0xFBEFE0)
        g.fill(alles, with: .color(wand.farbe))
        let herz = wand.mix(Pal.rose, 0.07).farbe
        for (n, y) in stride(from: CGFloat(-380), to: 290, by: 44).enumerated() {
            for x in stride(from: CGFloat(n % 2 == 0 ? 20 : 42), to: breite, by: 44) { g.fill(herzPfad(P(x, y), 4), with: .color(herz)) }
        }
        g.fill(box(0, 150, breite, 150), with: .linearGradient(Gradient(colors: [.clear, .black.opacity(0.07)]), startPoint: P(0, 150), endPoint: P(0, 300)))

        let holz = FigurFarbe(0xE6C9A0)
        g.fill(box(0, 300, breite, 500), with: .linearGradient(Gradient(colors: [holz.mal(0.9).farbe, holz.farbe]), startPoint: P(0, 300), endPoint: P(0, 430)))
        // Rows get taller toward the viewer: a little perspective without a full grid.
        let fuge = holz.mal(0.84).farbe
        var y: CGFloat = 300
        var h: CGFloat = 9
        var reihe = 0
        while y < 430 {
            linie(g, strich(P(0, y), P(breite, y)), fuge, 1.5)
            for x in stride(from: CGFloat(reihe % 3) * 47, to: breite, by: 140) { linie(g, strich(P(x, y), P(x, y + h)), fuge, 1.5) }
            y += h
            h *= 1.28
            reihe += 1
        }
        teil(g, box(-4, 292, breite + 8, 10, 2), Pal.weiss, 2)

        // A round pink rug under the table.
        teil(g, oval(P(tisch.x, tisch.y + 12), 112, 15), FigurFarbe(0xF4C9D4), 2.5)
        linie(g, oval(P(tisch.x, tisch.y + 12), 94, 10), Pal.weiss.farbe.opacity(0.65), 2)
    }

    // MARK: Window

    private static func himmel(_ zeit: Tageszeit) -> (oben: UInt32, unten: UInt32) {
        switch zeit {
        case .morgen: (0xFFC9A8, 0xCDE7F7)
        case .tag: (0x8CCBF2, 0xDDF1FB)
        case .abend: (0x6C5A9E, 0xF4A27E)
        case .nacht: (0x1E2A55, 0x3A3F78)
        }
    }

    private static func fensterZeichnen(_ g: GraphicsContext, _ zeit: Tageszeit) {
        let glas = scheibe
        teil(g, box(fenster.minX, fenster.minY, fenster.width, fenster.height, 8), Pal.weiss, 3)
        let farben = himmel(zeit)
        g.fill(Path(glas), with: .linearGradient(Gradient(colors: [c(farben.oben), c(farben.unten)]), startPoint: P(glas.midX, glas.minY), endPoint: P(glas.midX, glas.maxY)))
        var innen = g
        innen.clip(to: Path(glas))
        himmelsding(innen, zeit, glas)
        linie(g, strich(P(glas.midX, glas.minY), P(glas.midX, glas.maxY)), Pal.weiss.farbe, 4)
        linie(g, strich(P(glas.minX, glas.midY), P(glas.maxX, glas.midY)), Pal.weiss.farbe, 4)
        teil(g, box(fenster.minX - 6, fenster.maxY - 2, fenster.width + 12, 8, 3), Pal.weiss, 2.5)
        // Curtains with tie-backs, and a string of little lights above.
        let vorhang = FigurFarbe(0xF4B6C6)
        for x in [fenster.minX - 16, fenster.maxX - 10] {
            teil(g, box(x, fenster.minY - 8, 26, fenster.height + 8, 9), vorhang, 3)
            linie(g, strich(P(x + 9, fenster.minY), P(x + 9, fenster.maxY - 12)), vorhang.mal(0.85).farbe, 1.5)
            teil(g, box(x - 1, fenster.midY + 12, 28, 6, 3), Pal.gelb, 2)
        }
        let a = P(fenster.minX - 12, fenster.minY - 14)
        let b = P(fenster.maxX + 12, fenster.minY - 14)
        let kurve = P(fenster.midX, fenster.minY + 12)
        linie(g, bogen(a, b, kurve), Pal.dunkel.farbe.opacity(0.45), 1.5)
        for k in 0...6 {
            let t = CGFloat(k) / 6
            let u = 1 - t
            let x = u * u * a.x + 2 * u * t * kurve.x + t * t * b.x
            let y = u * u * a.y + 2 * u * t * kurve.y + t * t * b.y
            teil(g, kreis(P(x, y + 3), 3), k % 2 == 0 ? Pal.gelb : Pal.rose.mix(Pal.weiss, 0.4), 1.2)
        }
    }

    /// Sun, clouds, moon and stars of the time of day, drawn inside the glass.
    private static func himmelsding(_ g: GraphicsContext, _ zeit: Tageszeit, _ glas: CGRect) {
        switch zeit {
        case .morgen:
            let sonne = P(glas.minX + 22, glas.maxY - 26)
            g.fill(kreis(sonne, 22), with: .radialGradient(Gradient(colors: [Color.white.opacity(0.7), .clear]), center: sonne, startRadius: 2, endRadius: 22))
            teil(g, kreis(sonne, 11), Pal.gelb, 2)
        case .tag:
            let sonne = P(glas.maxX - 20, glas.minY + 20)
            teil(g, kreis(sonne, 11), Pal.gelb, 2)
            wolke(g, P(glas.minX + 26, glas.minY + 36), 1)
            wolke(g, P(glas.maxX - 30, glas.maxY - 34), 0.8)
        case .abend:
            let sonne = P(glas.maxX - 22, glas.maxY - 12)
            teil(g, kreis(sonne, 14), FigurFarbe(0xFF9B54), 2)
            wolke(g, P(glas.minX + 28, glas.minY + 34), 0.9)
        case .nacht:
            let mond = P(glas.maxX - 24, glas.minY + 24)
            g.fill(kreis(mond, 12), with: .color(c(0xFFF3C4)))
            g.fill(kreis(P(mond.x + 6, mond.y - 3), 10.5), with: .color(c(0x2A356A)))
            for (dx, dy) in [(14, 18), (36, 52), (62, 22), (24, 90), (50, 78), (68, 100), (12, 60)] {
                g.fill(kreis(P(glas.minX + CGFloat(dx), glas.minY + CGFloat(dy)), 1.6), with: .color(.white.opacity(0.85)))
            }
        }
    }

    private static func wolke(_ g: GraphicsContext, _ m: CGPoint, _ s: CGFloat) {
        for (dx, dy, r) in [(-10, 2, 8), (0, -3, 10), (11, 2, 8)] as [(CGFloat, CGFloat, CGFloat)] {
            g.fill(kreis(P(m.x + dx * s, m.y + dy * s), r * s), with: .color(.white.opacity(0.92)))
        }
        g.fill(box(m.x - 18 * s, m.y + 1 * s, 36 * s, 9 * s, 4 * s), with: .color(.white.opacity(0.92)))
    }

    // MARK: Furniture

    private static var sofaFarbe: FigurFarbe { FigurFarbe(0x8ED8BE) }

    /// Back and arms of the mint sofa; the seat's front cushion is drawn over the sitters (`sofaVorn`).
    private static func sofaHinten(_ g: GraphicsContext) {
        let m = sofaFarbe
        teil(g, box(sofa.minX + 4, sofa.minY, sofa.width - 8, 62, 16), m)
        teil(g, box(sofa.minX, sofa.minY + 30, 20, 56, 9), m.mal(0.93))
        teil(g, box(sofa.maxX - 20, sofa.minY + 30, 20, 56, 9), m.mal(0.93))
        teil(g, box(sofa.minX + 18, sofa.minY + 52, sofa.width - 36, 14, 6), m.mix(Pal.weiss, 0.25))
        for x in [sofa.minX + 8, sofa.maxX - 14] { teil(g, box(x, sofa.maxY - 2, 8, 6, 2), Pal.holz.mal(0.9), 2) }
    }

    /// In front of the sitters: hides the legs of whoever sits on the sofa.
    static func sofaVorn(_ g: GraphicsContext) {
        let m = sofaFarbe.mix(Pal.weiss, 0.15)
        teil(g, box(sofa.minX + 12, sofa.minY + 58, sofa.width - 24, 28, 10), m)
        linie(g, strich(P(sofa.midX, sofa.minY + 63), P(sofa.midX, sofa.minY + 82)), m.mal(0.82).farbe, 1.5)
    }

    private static func schrankZeichnen(_ g: GraphicsContext) {
        let holz = FigurFarbe(0xE8C9A0)
        for x in [schrank.minX + 6, schrank.maxX - 14] { teil(g, box(x, schrank.maxY - 2, 8, 8, 2), holz.mal(0.85), 2) }
        teil(g, box(schrank.minX, schrank.minY, schrank.width, schrank.height, 8), holz)
        for y in [schrank.minY + 6, schrank.minY + 34] {
            teil(g, box(schrank.minX + 6, y, schrank.width - 12, 24, 5), holz.mix(Pal.weiss, 0.18), 2)
            teil(g, kreis(P(schrank.midX, y + 12), 2.6), Pal.gold, 1.5)
        }
        teil(g, box(schrank.minX - 4, schrankOben - 2, schrank.width + 8, 10, 4), holz.mal(0.9))
    }

    private static func tischZeichnen(_ g: GraphicsContext) {
        let holz = FigurFarbe(0xD9B48A)
        teil(g, oval(P(tisch.x, tisch.y + 25), 17, 4.5), holz.mal(0.9), 2)
        teil(g, box(tisch.x - 4, tisch.y + 4, 8, 22, 2), holz.mal(0.92), 2)
        teil(g, oval(P(tisch.x, tisch.y), 31, 8), holz, 2.5)
        // The vase: round belly, narrow neck, a little heart on it. The bouquet comes from `StraussView`.
        let vase = FigurFarbe(0xBFE3F7)
        teil(g, box(tisch.x - 4, tisch.y - 26, 8, 10, 2), vase, 2)
        teil(g, oval(P(tisch.x, tisch.y - 11), 11, 9.5), vase, 2.5)
        teil(g, herzPfad(P(tisch.x, tisch.y - 11), 3.4), Pal.rose.mix(Pal.weiss, 0.3), 1)
    }

    private static func lampeZeichnen(_ g: GraphicsContext) {
        linie(g, strich(P(lampe.x, -2000), P(lampe.x, lampe.y - 28)), Pal.dunkel.farbe.opacity(0.55), 2)
        let schirm = Path { p in
            p.move(to: P(lampe.x - 21, lampe.y - 4))
            p.addQuadCurve(to: P(lampe.x + 21, lampe.y - 4), control: P(lampe.x, lampe.y - 54))
            p.closeSubpath()
        }
        teil(g, schirm, Pal.gelb, 3)
        g.fill(oval(P(lampe.x, lampe.y - 4), 9, 5), with: .color(c(0xFFF8DC)))
    }

    /// Evening and night: the room goes dark except the window glass, so the sky stays bright.
    private static func abdunkeln(_ g: GraphicsContext, _ zeit: Tageszeit) {
        let staerke: Double = switch zeit {
        case .morgen, .tag: 0
        case .abend: 0.2
        case .nacht: 0.45
        }
        guard staerke > 0 else { return }
        var d = g
        d.clip(to: Path(scheibe), options: .inverse)
        d.fill(alles, with: .color(c(0x141833).opacity(staerke)))
    }

    // MARK: Light

    /// The lamp's warm pool of light, drawn over everything while it is dark.
    static func licht(_ g: GraphicsContext, zeit: Tageszeit) {
        guard zeit.dunkel else { return }
        let st = zeit == .nacht ? 0.42 : 0.3
        let mitte = P(lampe.x, lampe.y)
        g.fill(kreis(mitte, 150), with: .radialGradient(Gradient(colors: [c(0xFFC96B).opacity(st), c(0xFFB347).opacity(st * 0.3), .clear]), center: mitte, startRadius: 6, endRadius: 150))
    }
}
