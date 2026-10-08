import SwiftUI

/// p56: elegante Mode (Satin-Camisole, Off-Shoulder-Top, Wickelkleid, kurzer Cardigan, Skinny Jeans mit Blumen).
/// `FigurView` ruft diese Zeichner aus den vorhandenen Index-Fällen auf; sie nutzen nur die gemeinsamen
/// Vektor-Helfer. Die Oberteile arbeiten im Raum der halben Figur wie `oberteilDetails`: `g` zeichnet frei,
/// `h` ist auf den Oberkörper beschnitten, die ganze Figur bildet diesen Raum auf ihren Torso ab.

// MARK: - Helfer

private func verlaufX(_ x0: CGFloat, _ x1: CGFloat, _ stops: [Gradient.Stop]) -> GraphicsContext.Shading {
    .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: x0, y: 0), endPoint: CGPoint(x: x1, y: 0))
}

/// Stoff von links nach rechts: an den Rändern dunkel, links der Mitte ein Lichtstreifen.
private func stoffVerlauf(_ f: FigurFarbe, _ x0: CGFloat, _ x1: CGFloat, dunkel: Double, hell: Double) -> GraphicsContext.Shading {
    verlaufX(x0, x1, [
        .init(color: f.mal(dunkel).farbe, location: 0),
        .init(color: f.mix(Pal.weiss, hell).farbe, location: 0.35),
        .init(color: f.farbe, location: 0.6),
        .init(color: f.mal(dunkel - 0.04).farbe, location: 1),
    ])
}

/// Punkt auf der Bogenkurve a -> b mit Kontrollpunkt c bei t (0 bis 1).
private func punktAufBogen(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    let wa = u * u
    let wc = 2 * u * t
    let wb = t * t
    let x = wa * a.x + wc * c.x + wb * b.x
    let y = wa * a.y + wc * c.y + wb * b.y
    return P(x, y)
}

/// Rüschenband entlang eines Bogens: oben die Kante, unten `n` Wellen, die `tief` nach unten schwingen.
private func rueschenBand(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, hoehe: CGFloat, n: Int, tief: CGFloat) -> Path {
    Path { p in
        p.move(to: a)
        p.addQuadCurve(to: b, control: c)
        var vorher = P(b.x, b.y + hoehe)
        p.addLine(to: vorher)
        for i in stride(from: n - 1, through: 0, by: -1) {
            let q = punktAufBogen(a, b, c, CGFloat(i) / CGFloat(n))
            let naechster = P(q.x, q.y + hoehe)
            p.addQuadCurve(to: naechster, control: P((vorher.x + naechster.x) / 2, (vorher.y + naechster.y) / 2 + 2 * tief))
            vorher = naechster
        }
        p.closeSubpath()
    }
}

/// Eine Blüte aus fünf Blütenblättern mit gelber Mitte (gestickt, Jeans).
private func stickBluete(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, blatt: FigurFarbe) {
    for i in 0..<5 {
        let w = Double(i) * 2 * Double.pi / 5 - Double.pi / 2
        let m = P(c.x + CGFloat(cos(w)) * r * 0.82, c.y + CGFloat(sin(w)) * r * 0.82)
        teil(g, kreis(m, r * 0.62), blatt, 0.5)
    }
    teil(g, kreis(c, r * 0.4), FigurFarbe(0xF2C14E), 0.4)
}

// MARK: - Satin-Camisole (oberteil 36)

/// Haut als Basis (die Figur zeichnet den Torso in Hautfarbe), darauf das Satin-Top: Spaghettiträger mit
/// Schiebern, Spitzenkante und kleine Schleife am Ausschnitt, Glanz auf der Brust, Falten, Abnäher.
func zeichneCamisole(_ g: GraphicsContext, _ h: GraphicsContext, top: FigurFarbe, haut: FigurFarbe) {
    // Der Halsrand des Hautkörpers verschwindet unter Haut.
    g.fill(box(80, 150, 40, 28), with: .color(haut.farbe))
    let oberkante = Path { p in
        p.move(to: P(20, 226))
        p.addQuadCurve(to: P(74, 192), control: P(42, 196))
        p.addQuadCurve(to: P(126, 192), control: P(100, 216))
        p.addQuadCurve(to: P(180, 226), control: P(158, 196))
    }
    var stoff = oberkante
    stoff.addLine(to: P(180, 340))
    stoff.addLine(to: P(20, 340))
    stoff.closeSubpath()
    h.fill(stoff, with: verlaufX(30, 170, [
        .init(color: top.mal(0.76).farbe, location: 0),
        .init(color: top.mix(Pal.weiss, 0.16).farbe, location: 0.3),
        .init(color: top.farbe, location: 0.5),
        .init(color: top.mix(Pal.weiss, 0.1).farbe, location: 0.72),
        .init(color: top.mal(0.72).farbe, location: 1),
    ]))
    var k = h
    k.clip(to: stoff)
    for seite: CGFloat in [-1, 1] {
        // Glanz auf der Brust, Schatten unter der Brust, Abnäher, lange Falten.
        k.fill(oval(P(100 + seite * 22, 208), 6.5, 10), with: .color(.white.opacity(0.24)))
        k.fill(oval(P(100 + seite * 22, 226), 22, 5), with: .color(.black.opacity(0.1)))
        linie(k, bogen(P(100 + seite * 20, 220), P(100 + seite * 15, 250), P(100 + seite * 22, 234)), top.kontur.opacity(0.32), 1.3)
        linie(k, bogen(P(100 + seite * 42, 214), P(100 + seite * 34, 300), P(100 + seite * 40, 258)), top.kontur.opacity(0.22), 1.4)
        linie(k, bogen(P(100 + seite * 30, 232), P(100 + seite * 26, 330), P(100 + seite * 31, 280)), .white.opacity(0.18), 2.2)
    }
    var glanz = Path()
    glanz.move(to: P(58, 200))
    glanz.addLine(to: P(68, 200))
    glanz.addLine(to: P(84, 340))
    glanz.addLine(to: P(70, 340))
    glanz.closeSubpath()
    k.fill(glanz, with: .color(.white.opacity(0.1)))
    linie(k, bogen(P(50, 238), P(150, 238), P(100, 246)), top.kontur.opacity(0.2), 1.3)
    // Kanten: Spitze entlang Armloch und Ausschnitt.
    let spitze = top.mix(Pal.weiss, 0.5)
    let ausschnitt = bogen(P(74, 192), P(126, 192), P(100, 216))
    for kante in [ausschnitt, bogen(P(20, 226), P(74, 192), P(42, 196)), bogen(P(180, 226), P(126, 192), P(158, 196))] {
        linie(g, kante, top.kontur, 6)
        linie(g, kante, spitze.farbe, 4)
    }
    var perlen = Path()
    for i in 0...10 {
        let m = punktAufBogen(P(76, 196.5), P(124, 196.5), P(100, 221), CGFloat(i) / 10)
        perlen.addEllipse(in: CGRect(x: m.x - 1.35, y: m.y - 1.35, width: 2.7, height: 2.7))
    }
    g.stroke(perlen, with: .color(top.kontur.opacity(0.6)), lineWidth: 0.7)
    g.fill(perlen, with: .color(spitze.mix(Pal.weiss, 0.5).farbe))
    // Spaghettiträger mit goldenem Schieber.
    for seite: CGFloat in [-1, 1] {
        let traeger = strich(P(100 + seite * 33, 163), P(100 + seite * 26, 193))
        linie(g, traeger, top.kontur, 5.4)
        linie(g, traeger, top.mix(Pal.weiss, 0.1).farbe, 3.4)
        linie(g, strich(P(100 + seite * 32.4, 166), P(100 + seite * 27.2, 190)), .white.opacity(0.4), 0.9)
        teil(g, box(100 + seite * 29.4 - 2.2, 176, 4.4, 3.4, 1), Pal.gold, 0.7)
    }
    // Kleine Satinschleife in der Mitte des Ausschnitts.
    let schleife = oval(P(95.2, 204), 5, 2.8)
    teil(g, schleife, top.mal(0.86), 1.1)
    teil(g, gespiegelt(schleife), top.mal(0.86), 1.1)
    teil(g, kreis(P(100, 204), 2), top.mal(0.7), 0.9)
}

// MARK: - Off-Shoulder-Top (oberteil 37)

/// Haut als Basis, Schultern und Schlüsselbein frei. Darunter ein enges gerippt-gestricktes Top mit
/// Rüschenband über der Brust; das Band läuft auf den Oberarmen weiter (`zeichneRueschenAermel`).
func zeichneOffShoulder(_ g: GraphicsContext, _ h: GraphicsContext, top: FigurFarbe, haut: FigurFarbe) {
    g.fill(box(80, 150, 40, 28), with: .color(haut.farbe))
    let a = P(14, 194)
    let b = P(186, 194)
    let c = P(100, 206)
    var stoff = Path()
    stoff.move(to: a)
    stoff.addQuadCurve(to: b, control: c)
    stoff.addLine(to: P(b.x, 340))
    stoff.addLine(to: P(a.x, 340))
    stoff.closeSubpath()
    h.fill(stoff, with: stoffVerlauf(top, 30, 170, dunkel: 0.8, hell: 0.3))
    var k = h
    k.clip(to: stoff)
    // Rippenstrick und Taillen-Raffung.
    var rippen = Path()
    for x in stride(from: CGFloat(36), through: 164, by: 4.5) {
        rippen.move(to: P(x, 214))
        rippen.addLine(to: P(x, 340))
    }
    k.stroke(rippen, with: .color(top.kontur.opacity(0.13)), lineWidth: 1)
    for seite: CGFloat in [-1, 1] {
        k.fill(oval(P(100 + seite * 22, 218), 8, 11), with: .color(.white.opacity(0.18)))
        linie(k, bogen(P(100 + seite * 40, 226), P(100 + seite * 33, 262), P(100 + seite * 41, 244)), top.kontur.opacity(0.3), 1.6)
        linie(k, bogen(P(100 + seite * 44, 236), P(100 + seite * 34, 270), P(100 + seite * 42, 252)), top.kontur.opacity(0.2), 1.2)
    }
    linie(k, bogen(P(56, 244), P(144, 244), P(100, 252)), top.kontur.opacity(0.2), 1.3)
    // Rüschenband mit Wellenkante.
    let band = rueschenBand(a, b, c, hoehe: 15, n: 12, tief: 2.4)
    h.fill(band, with: verlaufX(30, 170, [
        .init(color: top.mal(0.9).farbe, location: 0),
        .init(color: top.mix(Pal.weiss, 0.4).farbe, location: 0.4),
        .init(color: top.mix(Pal.weiss, 0.2).farbe, location: 0.7),
        .init(color: top.mal(0.88).farbe, location: 1),
    ]))
    for i in 1..<12 {
        let t = CGFloat(i) / 12
        let q = punktAufBogen(a, b, c, t)
        linie(h, bogen(P(q.x, q.y + 1), P(q.x, q.y + 15), P(q.x + (t < 0.5 ? 1.2 : -1.2), q.y + 8)), top.kontur.opacity(0.28), 1)
    }
    h.stroke(band, with: .color(top.kontur.opacity(0.75)), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
    linie(h, bogen(P(14, 195.6), P(186, 195.6), P(100, 207.6)), .white.opacity(0.35), 1)
    // Schatten des Bands auf der Haut.
    g.fill(oval(P(100, 192), 54, 3), with: .color(haut.mal(0.8).farbe.opacity(0.35)))
}

/// Das Rüschenband auf dem Oberarm (Off-Shoulder): ein Ring um den Arm von `s` Richtung `e` (Ellbogen),
/// die Unterkante mit vier Wellen. `d` ist die Armdicke wie in `aermelDetails`.
func zeichneRueschenAermel(_ g: GraphicsContext, von s: CGPoint, nach e: CGPoint, d: CGFloat, farbe: FigurFarbe) {
    let dx = e.x - s.x
    let dy = e.y - s.y
    let l = max(1, (dx * dx + dy * dy).squareRoot())
    let ux = dx / l
    let uy = dy / l
    let nx = -uy
    let ny = ux
    func pt(_ t: CGFloat, _ q: CGFloat) -> CGPoint {
        let laengs = l * t
        let x = s.x + ux * laengs + nx * q
        let y = s.y + uy * laengs + ny * q
        return P(x, y)
    }
    let oben: CGFloat = 0.1
    let unten: CGFloat = 0.42
    let w0: CGFloat = 13.5 * d
    let w1: CGFloat = 16.5 * d
    let band = Path { p in
        p.move(to: pt(oben, -w0))
        p.addLine(to: pt(oben, w0))
        p.addLine(to: pt(unten, w1))
        let n = 4
        for i in 1...n {
            let q = w1 - 2 * w1 * CGFloat(i) / CGFloat(n)
            let mitte = w1 - 2 * w1 * (CGFloat(i) - 0.5) / CGFloat(n)
            let c = pt(unten + 0.09, mitte)
            p.addQuadCurve(to: pt(unten, q), control: c)
        }
        p.closeSubpath()
    }
    teil(g, band, farbe.mix(Pal.weiss, 0.12), 1.8)
    for i in 1..<4 {
        let q = w1 - 2 * w1 * CGFloat(i) / 4
        linie(g, strich(pt(oben + 0.02, q * 0.8), pt(unten + 0.01, q)), farbe.kontur.opacity(0.3), 1)
    }
    linie(g, strich(pt(oben + 0.012, -w0 * 0.9), pt(oben + 0.012, w0 * 0.9)), .white.opacity(0.4), 1)
}

// MARK: - Wickelkleid (oberteil 38)

/// Oberteil des Wickelkleids: tiefer V-Ausschnitt mit Paspel, die obere Lage kreuzt zum Knoten an der
/// linken Hüfte, Raffung um den Knoten, Taillenband. Der Rock kommt aus `zeichneWickelRock`.
func zeichneWickelkleid(_ g: GraphicsContext, _ h: GraphicsContext, top: FigurFarbe, haut: FigurFarbe) {
    h.fill(box(0, 150, 200, 200), with: stoffVerlauf(top, 30, 170, dunkel: 0.8, hell: 0.1))
    // Der V-Ausschnitt ist Haut (auf der ganzen Figur wird der Torso nicht ausgeschnitten).
    let v = Path { p in
        p.move(to: P(83, 157))
        p.addLine(to: P(100, 189))
        p.addLine(to: P(117, 157))
        p.closeSubpath()
    }
    g.fill(v, with: .color(haut.farbe))
    // Untere Lage (links) liegt im Schatten, die obere Lage kreuzt von rechts zum Knoten.
    let unterLage = Path { p in
        p.move(to: P(86, 160))
        p.addLine(to: P(100, 189))
        p.addQuadCurve(to: P(72, 233), control: P(78, 208))
        p.addLine(to: P(30, 233))
        p.addLine(to: P(30, 160))
        p.closeSubpath()
    }
    h.fill(unterLage, with: .color(.black.opacity(0.1)))
    let kante = bogen(P(100, 189), P(72, 233), P(78, 208))
    linie(h, kante, top.kontur.opacity(0.75), 2.2)
    linie(h, kante.offsetBy(dx: 2.4, dy: 0), .white.opacity(0.3), 1.6)
    // Raffung um den Knoten und weiche Brustfalten.
    for dx in [CGFloat(0), 7, 14] {
        linie(h, bogen(P(72, 232), P(84 + dx, 204 - dx * 0.2), P(74 + dx * 0.4, 218)), top.kontur.opacity(0.3), 1.2)
        linie(h, bogen(P(73.6, 232), P(85.4 + dx, 204 - dx * 0.2), P(75.6 + dx * 0.4, 218)), .white.opacity(0.16), 1.4)
    }
    for seite: CGFloat in [-1, 1] {
        h.fill(oval(P(100 + seite * 24, 206), 7, 9), with: .color(.white.opacity(0.14)))
        linie(h, bogen(P(100 + seite * 30, 214), P(100 + seite * 22, 226), P(100 + seite * 30, 222)), top.kontur.opacity(0.22), 1.2)
    }
    // Paspel am V-Ausschnitt.
    let rand = Path { p in
        p.move(to: P(86, 160))
        p.addLine(to: P(100, 189))
        p.addLine(to: P(114, 160))
    }
    linie(g, rand, top.kontur, 5.6)
    linie(g, rand, top.mix(Pal.weiss, 0.22).farbe, 3.6)
    // Taillenband mit Knoten links.
    h.fill(box(20, 227, 160, 11), with: .color(top.mal(0.82).farbe))
    linie(h, strich(P(20, 227.5), P(180, 227.5)), top.kontur, 1.3)
    linie(h, strich(P(20, 238), P(180, 238)), top.kontur, 1.3)
    linie(h, strich(P(20, 229.5), P(180, 229.5)), .white.opacity(0.2), 1)
    teil(g, kreis(P(72, 233), 4.4), top.mal(0.78), 1.4)
    g.fill(kreis(P(70.6, 231.6), 1.2), with: .color(.white.opacity(0.35)))
}

/// Rock des Wickelkleids (ganze Figur): ausgestellt bis über das Knie, Überschlag vom Knoten in die
/// Mitte des Saums, fließende Falten, Saumkante und die Schleifenbänder des Knotens.
func zeichneWickelRock(_ g: GraphicsContext, top: FigurFarbe, taille: CGFloat, saum: CGFloat, t: CGFloat, h: CGFloat, knotenX: CGFloat) {
    let weite = h + 22
    let rock = Path { p in
        p.move(to: P(100 - t, taille))
        p.addQuadCurve(to: P(100 - weite, saum), control: P(100 - h - 4, taille + (saum - taille) * 0.35))
        p.addQuadCurve(to: P(100 + weite, saum), control: P(100, saum + 10))
        p.addQuadCurve(to: P(100 + t, taille), control: P(100 + h + 4, taille + (saum - taille) * 0.35))
        p.closeSubpath()
    }
    teil(g, rock, top)
    var k = g
    k.clip(to: rock)
    k.fill(Path(CGRect(x: 0, y: taille - 2, width: 200, height: saum - taille + 16)), with: stoffVerlauf(top, 100 - weite, 100 + weite, dunkel: 0.8, hell: 0.1))
    // Fließende Falten von der Taille zum Saum.
    for i in 0..<6 {
        let f = CGFloat(i) / 5
        let x0 = 100 - t + 2 * t * f
        let x1 = 100 - weite + 2 * weite * f
        let schwung: CGFloat = (f - 0.5) * 6
        let falte = bogen(P(x0, taille + 6), P(x1, saum + 2), P((x0 + x1) / 2 + schwung, taille + (saum - taille) * 0.5))
        linie(k, falte, top.kontur.opacity(0.22), 1.3)
        linie(k, falte.offsetBy(dx: 2.2, dy: 0), .white.opacity(0.14), 1.6)
    }
    // Überschlag: vom Knoten zum Saum, die obere Lage heller.
    let ueber = bogen(P(knotenX, taille + 4), P(100 + weite * 0.35, saum + 3), P(knotenX + 6, taille + (saum - taille) * 0.6))
    linie(k, ueber, top.kontur.opacity(0.75), 2.2)
    linie(k, ueber.offsetBy(dx: 2.6, dy: 0), .white.opacity(0.3), 1.6)
    // Saumkante.
    linie(k, bogen(P(100 - weite, saum - 3), P(100 + weite, saum - 3), P(100, saum + 7)), top.mal(0.7).farbe.opacity(0.6), 2)
    linie(k, bogen(P(100 - weite, saum - 5.2), P(100 + weite, saum - 5.2), P(100, saum + 4.8)), .white.opacity(0.2), 1)
    // Taillenband und Knoten mit zwei Bändern.
    k.fill(box(0, taille - 2, 200, 6), with: .color(top.mal(0.82).farbe))
    linie(k, strich(P(0, taille + 4), P(200, taille + 4)), top.kontur, 1.2)
    let band = Path { p in
        p.move(to: P(knotenX - 2, taille + 2))
        p.addQuadCurve(to: P(knotenX - 8, taille + 30), control: P(knotenX - 9, taille + 13))
        p.addLine(to: P(knotenX - 3, taille + 26))
        p.addLine(to: P(knotenX + 1, taille + 32))
        p.addQuadCurve(to: P(knotenX + 2, taille + 2), control: P(knotenX + 2, taille + 14))
        p.closeSubpath()
    }
    teil(g, band, top.mal(0.86), 1.5)
    teil(g, band.applying(CGAffineTransform(translationX: knotenX, y: taille).rotated(by: 0.5).translatedBy(x: -knotenX, y: -taille)), top.mal(0.8), 1.5)
    teil(g, kreis(P(knotenX, taille + 1), 3.6), top.mal(0.78), 1.3)
    g.fill(kreis(P(knotenX - 1.2, taille), 1), with: .color(.white.opacity(0.35)))
}

// MARK: - Kurzer Cardigan (jacke 14)

/// Perlen-Cardigan. `g` zeichnet frei, `innen` ist auf den Torso beschnitten; Koordinaten wie bei
/// `jackeZeichnen` (`oben`/`unten` sind das Ende des kurzen Schnitts, `s` skaliert die Details).
func zeichneCardigan(_ g: GraphicsContext, innen: GraphicsContext, f: FigurFarbe, oben: CGFloat, unten: CGFloat, s: CGFloat, innenO: CGFloat, innenU: CGFloat) {
    let perle = FigurFarbe(0xF7F2EA)
    let laenge = unten - oben
    let links = Path { p in
        p.move(to: P(-20, oben - 60))
        p.addLine(to: P(innenO, oben - 60))
        p.addLine(to: P(innenO, oben))
        p.addLine(to: P(innenU, unten))
        p.addLine(to: P(-20, unten))
        p.closeSubpath()
    }
    for seite in [links, gespiegelt(links)] {
        var k = innen
        k.clip(to: seite)
        // Seitlich Schatten, in der Mitte Licht, dazu feine Rippen und Schulternaht.
        k.fill(Path(CGRect(x: 0, y: oben - 20, width: 200, height: laenge + 30)), with: verlaufX(24, 176, [
            .init(color: .black.opacity(0.16), location: 0),
            .init(color: .black.opacity(0), location: 0.3),
            .init(color: .white.opacity(0.1), location: 0.62),
            .init(color: .black.opacity(0.14), location: 1),
        ]))
        var rippen = Path()
        for x in stride(from: CGFloat(10), through: 190, by: 5 * s) {
            rippen.move(to: P(x, oben))
            rippen.addLine(to: P(x, unten))
        }
        k.stroke(rippen, with: .color(f.kontur.opacity(0.2)), lineWidth: 0.8 * s)
        // Kleiner Zopf entlang der Mitte jeder Hälfte.
        let zopf = Path { p in
            p.move(to: P(0, oben))
            p.addLine(to: P(0, unten))
        }
        for x in [100 - 48 * s, 100 + 48 * s] {
            for dx in [CGFloat(-1.6), 1.6] {
                linie(k, zopf.offsetBy(dx: x + dx * s, dy: 0), f.kontur.opacity(0.28), 0.9 * s)
            }
        }
        // Saumrippe unten, nur auf den Vorderteilen (die Mitte bleibt offen).
        k.fill(Path(CGRect(x: -20, y: unten - 9 * s, width: 240, height: 9 * s)), with: .color(f.mal(0.9).farbe))
        var saumRippen = Path()
        for x in stride(from: CGFloat(0), through: 200, by: 3 * s) {
            saumRippen.move(to: P(x, unten - 9 * s))
            saumRippen.addLine(to: P(x, unten))
        }
        k.stroke(saumRippen, with: .color(f.kontur.opacity(0.3)), lineWidth: 0.7 * s)
        linie(k, strich(P(-20, unten - 9 * s), P(220, unten - 9 * s)), f.kontur.opacity(0.6), 1.3 * s)
    }
    // Knopfleisten an den Vorderkanten.
    let leiste = Path { p in
        p.move(to: P(innenO, oben))
        p.addLine(to: P(innenU, unten))
        p.addLine(to: P(innenU - 7 * s, unten))
        p.addLine(to: P(innenO - 7 * s, oben))
        p.closeSubpath()
    }
    teil(innen, leiste, f.mal(0.93), 1.3)
    teil(innen, gespiegelt(leiste), f.mal(0.93), 1.3)
    for i in 1..<7 {
        let y = oben + laenge * CGFloat(i) / 7
        let xi = innenO + (innenU - innenO) * (y - oben) / laenge
        linie(innen, strich(P(xi - 6.4 * s, y), P(xi - 0.6 * s, y)), f.kontur.opacity(0.22), 0.8 * s)
        linie(innen, strich(P(200 - xi + 0.6 * s, y), P(200 - xi + 6.4 * s, y)), f.kontur.opacity(0.22), 0.8 * s)
    }
    // Perlenknöpfe links, Knopflöcher rechts.
    for t in [CGFloat(0.18), 0.4, 0.62, 0.84] {
        let y = oben + laenge * t
        let xi = innenO + (innenU - innenO) * (y - oben) / laenge - 3.5 * s
        teil(g, kreis(P(xi, y), 3.1 * s), perle, 0.9)
        g.fill(kreis(P(xi - 0.9 * s, y - 0.9 * s), 0.9 * s), with: .color(.white))
        linie(g, strich(P(200 - xi - 2.2 * s, y), P(200 - xi + 2.2 * s, y)), f.kontur.opacity(0.75), 1 * s)
    }
}

/// Rippenbündchen am Handgelenk des Cardigans mit Perlenknopf.
func zeichneCardiganBuendchen(_ g: GraphicsContext, ellbogen e: CGPoint, hand: CGPoint, d: CGFloat, farbe f: FigurFarbe) {
    let dx = hand.x - e.x
    let dy = hand.y - e.y
    let a = P(e.x + dx * 0.8, e.y + dy * 0.8)
    let b = P(e.x + dx * 0.97, e.y + dy * 0.97)
    let band = strich(a, b)
    g.stroke(band, with: .color(f.kontur), style: StrokeStyle(lineWidth: 17.6 * d, lineCap: .butt))
    g.stroke(band, with: .color(f.mal(0.9).farbe), style: StrokeStyle(lineWidth: 15.4 * d, lineCap: .butt))
    let l = max(1, (dx * dx + dy * dy).squareRoot())
    let nx = -dy / l * 7 * d
    let ny = dx / l * 7 * d
    for t in [CGFloat(0.25), 0.5, 0.75] {
        let m = P(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
        linie(g, strich(P(m.x - nx, m.y - ny), P(m.x + nx, m.y + ny)), f.kontur.opacity(0.35), 0.9)
    }
    let knopfX = a.x + (b.x - a.x) * 0.4 + nx * 0.5
    let knopfY = a.y + (b.y - a.y) * 0.4 + ny * 0.5
    teil(g, kreis(P(knopfX, knopfY), 1.9 * d), FigurFarbe(0xF7F2EA), 0.7)
}

// MARK: - Skinny Jeans mit Blumen (hose 20)

/// Vorderansicht, Aufbau wie `zeichneCargohose`. Enge Röhre in Denim: Gürtelschlaufen, Knopf mit Reißverschluss,
/// geschwungene Eingrifftaschen mit Nieten und Ziernähten, Waschungen an Oberschenkel und Knie, Saumumschlag,
/// dazu eine kleine Blumenranke über dem rechten Knöchel (die großen Blumen sind auf den Gesäßtaschen, siehe
/// `zeichneJeansRueckseite`).
func zeichneBlumenJeans(_ g: GraphicsContext, beine: [(h: CGPoint, k: CGPoint, f: CGPoint, seite: CGFloat)], b: CGFloat, farbe: FigurFarbe, hy: CGFloat, halbBreite: CGFloat) {
    let faden = FigurFarbe(0xE2A24B)
    let kupfer = FigurFarbe(0xC98A4B)
    for bn in beine {
        let s = bn.seite
        // Äußere Seitennaht mit Ziernaht.
        let naht = Path { p in
            p.move(to: P(bn.h.x + s * (b * 0.58 - 2.2), bn.h.y + 4))
            p.addLine(to: P(bn.k.x + s * (b * 0.44 - 2), bn.k.y))
            p.addLine(to: P(bn.f.x + s * (b * 0.36 - 2), bn.f.y - 3))
        }
        steppnaht(g, naht, faden.farbe.opacity(0.75), 0.7)
        // Helle Waschung vorn am Oberschenkel, Schnurrhaare an der Hüfte, Knie ausgeblichen.
        let mp = P(bn.h.x + (bn.k.x - bn.h.x) * 0.5, bn.h.y + (bn.k.y - bn.h.y) * 0.5)
        g.fill(oval(P(mp.x + s * 0.5, mp.y), b * 0.2, (bn.k.y - bn.h.y) * 0.34), with: .color(.white.opacity(0.17)))
        for i in 0..<3 {
            let y = bn.h.y + 7 + CGFloat(i) * 2.6
            linie(g, strich(P(bn.h.x - s * b * 0.3, y), P(bn.h.x + s * b * 0.18, y + 2.4)), .white.opacity(0.26), 0.9)
        }
        g.fill(oval(P(bn.k.x, bn.k.y), b * 0.26, 7), with: .color(.white.opacity(0.2)))
        linie(g, bogen(P(bn.k.x - b * 0.3, bn.k.y - 4), P(bn.k.x + b * 0.3, bn.k.y - 4), P(bn.k.x, bn.k.y - 1)), farbe.kontur.opacity(0.28), 1)
        linie(g, bogen(P(bn.k.x - b * 0.28, bn.k.y + 3), P(bn.k.x + b * 0.28, bn.k.y + 3), P(bn.k.x, bn.k.y + 6)), farbe.kontur.opacity(0.2), 0.9)
        // Eingrifftasche: Bogen von der Taille zur Seitennaht, mit Naht und Kupfernieten.
        let tasche = Path { p in
            p.move(to: P(bn.h.x + s * b * 0.04, hy + 2))
            p.addQuadCurve(to: P(bn.h.x + s * (b * 0.58 - 1), hy + 17), control: P(bn.h.x + s * b * 0.1, hy + 17))
        }
        linie(g, tasche, farbe.kontur.opacity(0.55), 1.3)
        steppnaht(g, tasche.offsetBy(dx: -s * 1.1, dy: 1.3), faden.farbe.opacity(0.8), 0.6)
        for ende in [P(bn.h.x + s * b * 0.04, hy + 2.5), P(bn.h.x + s * (b * 0.58 - 1), hy + 17)] {
            teil(g, kreis(ende, 1), kupfer, 0.5)
        }
        // Saumumschlag am Knöchel.
        g.fill(box(bn.f.x - b * 0.36, bn.f.y - 8, b * 0.72, 8), with: .color(farbe.mix(Pal.weiss, 0.22).farbe))
        linie(g, strich(P(bn.f.x - b * 0.36, bn.f.y - 8), P(bn.f.x + b * 0.36, bn.f.y - 8)), farbe.kontur.opacity(0.55), 1.1)
        steppnaht(g, strich(P(bn.f.x - b * 0.32, bn.f.y - 6.2), P(bn.f.x + b * 0.32, bn.f.y - 6.2)), faden.farbe.opacity(0.8), 0.6)
    }
    // Gürtelbund: Schlaufen, Ziernaht, Kupferknopf, Reißverschluss mit J-Naht.
    for dx in [CGFloat(-0.7), -0.36, 0.36, 0.7] {
        teil(g, box(100 + dx * halbBreite - 1.1, hy - 10, 2.2, 8, 0.8), farbe.mal(0.82), 0.7)
    }
    linie(g, strich(P(100 - halbBreite + 2, hy - 3), P(100 + halbBreite - 2, hy - 3)), farbe.kontur.opacity(0.5), 1.1)
    steppnaht(g, strich(P(100 - halbBreite + 2, hy - 4.6), P(100 + halbBreite - 2, hy - 4.6)), faden.farbe.opacity(0.8), 0.55)
    let jNaht = Path { p in
        p.move(to: P(101.8, hy - 3))
        p.addLine(to: P(101.8, hy + 9))
        p.addQuadCurve(to: P(97.4, hy + 14), control: P(101.6, hy + 14))
    }
    steppnaht(g, jNaht, faden.farbe.opacity(0.85), 0.65)
    linie(g, strich(P(100, hy - 3), P(100, hy + 12)), farbe.kontur.opacity(0.5), 1.1)
    teil(g, kreis(P(100, hy - 6.4), 1.8), kupfer, 0.7)
    // Kleine Blumenranke über dem rechten Knöchel.
    if let r = beine.first(where: { $0.seite > 0 }) {
        let fuss = r.f
        let stiel = bogen(P(fuss.x + b * 0.12, fuss.y - 13), P(fuss.x - b * 0.1, fuss.y - 33), P(fuss.x - b * 0.02, fuss.y - 22))
        linie(g, stiel, FigurFarbe(0x5E8F5A).farbe, 1)
        for (dx, dy, rr) in [(CGFloat(0.1), CGFloat(-33), CGFloat(2.7)), (-0.12, -24, 2.3), (0.12, -16.5, 2)] {
            stickBluete(g, P(fuss.x + b * dx, fuss.y + dy), rr, blatt: FigurFarbe(0xF4E8EC))
        }
    }
}

// MARK: - Jeans von hinten (Shop-Detail)

/// Rückansicht der Skinny Jeans in einem Feld von 200 x 260: Passe, Gürtelschlaufen, zwei Gesäßtaschen mit
/// großen gestickten Blumen, Lederpatch, Beinnähte und Saumumschlag. Für die Detailansicht im Shop.
func zeichneJeansRueckseite(_ g: GraphicsContext, farbe: FigurFarbe) {
    let faden = FigurFarbe(0xE2A24B)
    let kupfer = FigurFarbe(0xC98A4B)
    var umriss = Path()
    for seite: CGFloat in [-1, 1] {
        let bein = Path { p in
            p.move(to: P(100 + seite * 1.5, 40))
            p.addLine(to: P(100 + seite * 50, 40))
            p.addQuadCurve(to: P(100 + seite * 38, 140), control: P(100 + seite * 54, 96))
            p.addLine(to: P(100 + seite * 33, 252))
            p.addLine(to: P(100 + seite * 12, 252))
            p.addQuadCurve(to: P(100 + seite * 1.5, 120), control: P(100 + seite * 12, 160))
            p.closeSubpath()
        }
        teil(g, bein, farbe, 3)
        umriss.addPath(bein)
    }
    var k = g
    k.clip(to: umriss)
    // Waschung und Schatten an den Seiten.
    k.fill(Path(CGRect(x: 0, y: 40, width: 200, height: 220)), with: verlaufX(46, 154, [
        .init(color: .black.opacity(0.18), location: 0),
        .init(color: .white.opacity(0.1), location: 0.3),
        .init(color: .black.opacity(0.06), location: 0.5),
        .init(color: .white.opacity(0.1), location: 0.7),
        .init(color: .black.opacity(0.18), location: 1),
    ]))
    for seite: CGFloat in [-1, 1] {
        k.fill(oval(P(100 + seite * 30, 170), 11, 26), with: .color(.white.opacity(0.16)))
        k.fill(oval(P(100 + seite * 24, 218), 8, 14), with: .color(.white.opacity(0.1)))
    }
    // Bund, Gürtelschlaufen, Passe mit V-Naht, Mittelnaht.
    teil(g, box(48, 30, 104, 18, 4), farbe.mal(0.94), 2.4)
    for dx in [CGFloat(-38), -18, 18, 38] {
        teil(g, box(100 + dx - 3, 28, 6, 22, 1.4), farbe.mal(0.8), 1.2)
    }
    steppnaht(g, strich(P(52, 34), P(148, 34)), faden.farbe.opacity(0.85), 0.9)
    steppnaht(g, strich(P(52, 44), P(148, 44)), faden.farbe.opacity(0.85), 0.9)
    let passe = Path { p in
        p.move(to: P(50, 48))
        p.addLine(to: P(100, 70))
        p.addLine(to: P(150, 48))
    }
    linie(g, passe, farbe.kontur.opacity(0.6), 1.6)
    steppnaht(g, passe.offsetBy(dx: 0, dy: 2.4), faden.farbe.opacity(0.85), 0.9)
    linie(g, strich(P(100, 70), P(100, 128)), farbe.kontur.opacity(0.5), 1.4)
    steppnaht(g, strich(P(102.4, 70), P(102.4, 128)), faden.farbe.opacity(0.85), 0.9)
    // Gesäßtaschen mit großen gestickten Blumen.
    for seite: CGFloat in [-1, 1] {
        let cx = 100 + seite * 27
        let tasche = Path { p in
            p.move(to: P(cx - 18, 78))
            p.addLine(to: P(cx + 18, 78))
            p.addLine(to: P(cx + 18, 112))
            p.addLine(to: P(cx, 124))
            p.addLine(to: P(cx - 18, 112))
            p.closeSubpath()
        }
        teil(g, tasche, farbe.mal(0.96), 2)
        steppnaht(g, tasche.applying(CGAffineTransform(translationX: cx, y: 101).scaledBy(x: 0.86, y: 0.86).translatedBy(x: -cx, y: -101)), faden.farbe.opacity(0.85), 0.8)
        linie(g, strich(P(cx - 14, 83), P(cx + 14, 83)), farbe.kontur.opacity(0.4), 1)
        // Ranke mit Blättern und drei Blüten.
        let stiel = Path { p in
            p.move(to: P(cx - 10, 112))
            p.addQuadCurve(to: P(cx + 10, 90), control: P(cx - 8, 96))
        }
        linie(g, stiel, FigurFarbe(0x4F8A52).farbe, 1.6)
        for (dx, dy, w) in [(CGFloat(-8), CGFloat(103), Double(-0.6)), (CGFloat(-3), CGFloat(97), Double(0.7)), (CGFloat(3), CGFloat(94), Double(-0.5))] {
            var blatt = g
            blatt.translateBy(x: cx + dx, y: dy)
            blatt.rotate(by: .radians(w))
            teil(blatt, oval(P(0, 0), 4.2, 2), FigurFarbe(0x5E9E5F), 0.5)
        }
        stickBluete(g, P(cx + 7, 91), 5.4, blatt: FigurFarbe(0xF4E8EC))
        stickBluete(g, P(cx - 5, 100), 4.6, blatt: FigurFarbe(0xF4B6C6))
        stickBluete(g, P(cx + 3, 110), 3.4, blatt: FigurFarbe(0xF4E8EC))
        teil(g, kreis(P(cx - 17, 79), 1.1), kupfer, 0.5)
        teil(g, kreis(P(cx + 17, 79), 1.1), kupfer, 0.5)
    }
    // Lederpatch am Bund.
    teil(g, box(88, 50, 24, 8, 1.5), FigurFarbe(0xB48A5C), 1)
    linie(g, strich(P(93, 54), P(107, 54)), FigurFarbe(0x5A3E24).farbe, 1.1)
    // Saumumschlag.
    for seite: CGFloat in [-1, 1] {
        g.fill(box(100 + seite * 22.5 - 10.5, 236, 21, 16), with: .color(farbe.mix(Pal.weiss, 0.22).farbe))
        linie(g, strich(P(100 + seite * 33, 236), P(100 + seite * 12, 236)), farbe.kontur.opacity(0.55), 1.2)
        steppnaht(g, strich(P(100 + seite * 32, 239), P(100 + seite * 13, 239)), faden.farbe.opacity(0.85), 0.7)
    }
}
