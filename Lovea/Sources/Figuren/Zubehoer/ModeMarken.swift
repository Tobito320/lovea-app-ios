import SwiftUI

/// p65 D: Marken-Teile mit sichtbarem Logo. Alles Vektor (Path und Text im Canvas), keine Pixelbilder.
/// Die App bleibt privat (TestFlight, zwei Nutzer), darum sind die Logos fest eingebaut, ohne Schalter.
/// `FigurView` ruft diese Zeichner aus `oberteilDetails` (Oberteile 39 bis 43) und `schuhZeichnen` (16, 17) auf.

private func schrift(_ g: GraphicsContext, _ s: String, _ c: CGPoint, _ groesse: CGFloat, _ farbe: Color) {
    g.draw(Text(s).font(.system(size: groesse, weight: .heavy, design: .rounded)).foregroundStyle(farbe), at: c)
}

/// Light logo on a dark top, dark logo on a light one.
private func logoFarbe(_ top: FigurFarbe) -> Color {
    top.r + top.g + top.b < 1.7 ? Pal.weiss.farbe : Pal.tinte.farbe
}

// MARK: - Oberteile (39 Ralph Lauren, 40 Adidas, 41 Carhartt, 42 The North Face, 43 Nike Sport-Top)

/// Half-figure space like `oberteilDetails` (`g` draws freely). `marke` is the real top index 39...43.
func zeichneMarkenOberteil(_ g: GraphicsContext, _ h: GraphicsContext, marke: Int, top: FigurFarbe) {
    let logo = logoFarbe(top)
    switch marke {
    case 39:
        // Polo: the polo player on the left chest, collar comes from the polo shape.
        poloReiter(g, P(126, 206), 0.95, logo)
    case 40:
        // Adidas: trefoil over the wordmark, centered.
        kleeblattLogo(g, P(100, 202), 1.5, logo)
        schrift(g, "adidas", P(100, 226), 7.5, logo)
    case 41:
        // Carhartt: chest pocket with the woven label.
        teil(g, box(108, 196, 32, 32, 3), top.mal(0.93), 1.8)
        g.fill(box(114, 200, 20, 8, 1.5), with: .color(FigurFarbe(0xC9A07A).farbe))
        schrift(g, "carhartt", P(124, 204), 5.2, Pal.tinte.farbe)
        linie(h, strich(P(110, 214), P(138, 214)), top.kontur.opacity(0.35), 1)
    case 42:
        // The North Face: half dome over the wordmark.
        halbKuppel(g, P(100, 206), 11, logo, top.farbe)
        schrift(g, "THE NORTH FACE", P(100, 222), 5.4, logo)
    case 43:
        // Nike sports top: swoosh and wordmark on the chest.
        g.fill(swooshPfad(P(100, 203), breite: 24), with: .color(logo))
        schrift(g, "NIKE", P(100, 216), 6.4, logo)
    default:
        break
    }
}

/// Ralph Lauren polo player: horse, rider and mallet as one small silhouette (20 x 20 unit box).
private func poloReiter(_ g: GraphicsContext, _ mitte: CGPoint, _ s: CGFloat, _ farbe: Color) {
    var h = g
    h.translateBy(x: mitte.x - 10 * s, y: mitte.y - 10 * s)
    h.scaleBy(x: s, y: s)
    h.fill(oval(P(10, 11.5), 5.2, 2.7), with: .color(farbe))
    let hals = Path { p in
        p.move(to: P(13, 10.5))
        p.addLine(to: P(15, 6))
        p.addLine(to: P(18.8, 7.4))
        p.addLine(to: P(18.2, 8.6))
        p.addLine(to: P(16.4, 8.2))
        p.addLine(to: P(15.2, 12))
        p.closeSubpath()
    }
    h.fill(hals, with: .color(farbe))
    let beine: [(CGPoint, CGPoint)] = [(P(13.2, 13), P(15.2, 18)), (P(11.6, 13.6), P(11.8, 18.4)),
                                       (P(7.4, 13.2), P(5.2, 18)), (P(8.8, 13.8), P(8.6, 18.4))]
    for (a, b) in beine { linie(h, strich(a, b), farbe, 1.3) }
    linie(h, bogen(P(5, 10.4), P(2, 14), P(2.8, 10.6)), farbe, 1.2)
    h.fill(kreis(P(10.6, 4.2), 1.5), with: .color(farbe))
    linie(h, strich(P(10.6, 5.6), P(10, 9.6)), farbe, 1.5)
    linie(h, strich(P(10.6, 6.6), P(6, 3)), farbe, 0.9)
}

/// Adidas trefoil: three leaves over three bars.
private func kleeblattLogo(_ g: GraphicsContext, _ c: CGPoint, _ s: CGFloat, _ farbe: Color) {
    let blaetter: [(CGFloat, Double)] = [(-4.5, -38), (0, 0), (4.5, 38)]
    for (dx, grad) in blaetter {
        var h = g
        h.translateBy(x: c.x + dx * s, y: c.y + abs(dx) * 0.3 * s)
        h.rotate(by: .degrees(grad))
        h.fill(oval(P(0, -4 * s), 2.6 * s, 4.6 * s), with: .color(farbe))
    }
    for i in 0..<3 {
        let y: CGFloat = c.y + (2 + CGFloat(i) * 2) * s
        linie(g, strich(P(c.x - 7 * s, y), P(c.x + 7 * s, y)), farbe, 0.9 * s)
    }
}

/// The North Face half dome: a half circle cut into segments by three curves from the base point.
private func halbKuppel(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, _ farbe: Color, _ luecke: Color) {
    let k: CGFloat = 0.5523 * r
    let kuppel = Path { p in
        p.move(to: P(c.x - r, c.y))
        p.addCurve(to: P(c.x, c.y - r), control1: P(c.x - r, c.y - k), control2: P(c.x - k, c.y - r))
        p.addCurve(to: P(c.x + r, c.y), control1: P(c.x + k, c.y - r), control2: P(c.x + r, c.y - k))
        p.closeSubpath()
    }
    g.fill(kuppel, with: .color(farbe))
    let fuss = P(c.x + 1.5, c.y)
    for (ex, ey) in [(CGFloat(-0.95), CGFloat(-0.25)), (-0.6, -0.8), (-0.12, -1.0)] {
        let ziel = P(c.x + ex * r, c.y + ey * r)
        linie(g, bogen(fuss, ziel, P(fuss.x + (ziel.x - fuss.x) * 0.2, fuss.y + (ziel.y - fuss.y) * 0.75)), luecke, 1.2)
    }
}

// MARK: - Schuhe (16 Air Jordan 1, 17 Nike Dunk Low)

/// Air Jordan 1: high top, toe cap and collar patch with the wings mark, swoosh. Toe to the left like the other shoes.
func zeichneJordanSneaker(_ g: GraphicsContext, fuss f: CGPoint, farbe c: FigurFarbe) {
    let x = f.x
    let y = f.y
    let hell = c.r + c.g + c.b > 2.3
    let zeichen = hell ? Pal.tinte : Pal.weiss
    let kontrast = hell ? c.mix(Pal.tinte, 0.3) : c.mix(Pal.weiss, 0.18)
    let oberschuh = Path { p in
        p.move(to: P(x - 13, y + 6))
        p.addQuadCurve(to: P(x - 7, y - 1), control: P(x - 13.2, y - 1.5))
        p.addQuadCurve(to: P(x + 0.5, y - 5.5), control: P(x - 3, y - 4))
        p.addLine(to: P(x + 3.5, y - 15.5))
        p.addQuadCurve(to: P(x + 12, y - 14.5), control: P(x + 8, y - 18.5))
        p.addLine(to: P(x + 13, y + 6))
        p.closeSubpath()
    }
    teil(g, oberschuh, c, 2.4)
    let kappe = Path { p in
        p.move(to: P(x - 13, y + 5.5))
        p.addQuadCurve(to: P(x - 7, y - 0.6), control: P(x - 13.2, y - 1.5))
        p.addLine(to: P(x - 3.5, y + 5.5))
        p.closeSubpath()
    }
    g.fill(kappe, with: .color(kontrast.farbe))
    let kragen = Path { p in
        p.move(to: P(x + 4.4, y - 12))
        p.addLine(to: P(x + 3.5, y - 15.2))
        p.addQuadCurve(to: P(x + 12, y - 14.2), control: P(x + 8, y - 18))
        p.addLine(to: P(x + 12.4, y - 9))
        p.closeSubpath()
    }
    g.fill(kragen, with: .color(kontrast.farbe))
    // Wings mark: ball between two small wings, on the collar patch.
    g.fill(kreis(P(x + 8.4, y - 11.4), 1.1), with: .color(zeichen.farbe))
    linie(g, bogen(P(x + 6.8, y - 10.6), P(x + 7.8, y - 13.6), P(x + 6.6, y - 12.6)), zeichen.farbe, 0.8)
    linie(g, bogen(P(x + 10, y - 10.6), P(x + 9, y - 13.6), P(x + 10.2, y - 12.6)), zeichen.farbe, 0.8)
    for i in 0..<4 {
        let bx = x - 3.2 + 2.5 * CGFloat(i)
        let by = y - 2.4 - 3.1 * CGFloat(i)
        linie(g, strich(P(bx, by + 0.9), P(bx + 1.7, by - 1.2)), Pal.weiss.farbe, 0.9)
    }
    g.fill(box(x + 9, y - 3, 4, 9, 1.2), with: .color(kontrast.farbe))
    teil(g, box(x - 13.5, y + 5, 27, 6, 3), Pal.weiss, 2)
    g.fill(box(x - 12.5, y + 9.6, 25, 1.6, 0.8), with: .color(Pal.tinte.farbe.opacity(0.75)))
    g.fill(swooshPfad(P(x + 1.4, y + 0.4), breite: 12), with: .color(zeichen.farbe))
}

/// Nike Dunk Low: white base with colored overlays (toe cap, eyestay, heel) and the swoosh on the side panel.
func zeichneDunkSneaker(_ g: GraphicsContext, fuss f: CGPoint, farbe c: FigurFarbe) {
    let x = f.x
    let y = f.y
    let hell = c.r + c.g + c.b > 2.3
    let ueber = hell ? Pal.silber : c
    let oberschuh = Path { p in
        p.move(to: P(x - 13, y + 6))
        p.addQuadCurve(to: P(x - 7, y - 0.8), control: P(x - 13.2, y - 1))
        p.addQuadCurve(to: P(x + 1, y - 4.8), control: P(x - 3, y - 3.2))
        p.addLine(to: P(x + 5, y - 6.4))
        p.addQuadCurve(to: P(x + 11.5, y - 6), control: P(x + 8.5, y - 8.6))
        p.addLine(to: P(x + 12.6, y + 6))
        p.closeSubpath()
    }
    teil(g, oberschuh, Pal.weiss, 2.4)
    let kappe = Path { p in
        p.move(to: P(x - 13, y + 5.5))
        p.addQuadCurve(to: P(x - 7, y - 0.4), control: P(x - 13.2, y - 1))
        p.addLine(to: P(x - 4.4, y + 5.5))
        p.closeSubpath()
    }
    g.fill(kappe, with: .color(ueber.farbe))
    let schnuerung = Path { p in
        p.move(to: P(x - 3, y + 1))
        p.addLine(to: P(x + 1, y - 4.8))
        p.addLine(to: P(x + 5, y - 6.2))
        p.addLine(to: P(x + 3.2, y - 1.2))
        p.closeSubpath()
    }
    g.fill(schnuerung, with: .color(ueber.farbe))
    g.fill(box(x + 8.6, y - 5, 4, 10.6, 1.2), with: .color(ueber.farbe))
    linie(g, strich(P(x + 6, y + 5), P(x + 6.4, y - 3.4)), Pal.tinte.farbe.opacity(0.18), 0.8)
    teil(g, box(x - 13.5, y + 5, 27, 6, 3), Pal.weiss, 2)
    g.fill(box(x - 12.5, y + 9.6, 25, 1.6, 0.8), with: .color(Pal.tinte.farbe.opacity(0.75)))
    g.fill(swooshPfad(P(x - 0.2, y + 2.4), breite: 11.5), with: .color(ueber.farbe))
}
