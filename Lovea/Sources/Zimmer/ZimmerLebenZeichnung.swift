import SwiftUI

/// Where the living objects sit in the home of `ZuhauseZeichnung` (design space 390 x 430, bottom
/// anchored). Drawing and tap targets read the same rects. Left wall: calendar, frames, TV; right
/// wall above the sofa: board and cups; the plant on the sill; the goal on the floor.
enum ZimmerLebenLayout {
    /// The visible glass between the curtains (`ZuhauseZeichnung.fenster` inset by 7, minus the curtain edges).
    static let fenster = CGRect(x: 188, y: 69, width: 68, height: 106)
    static let kalender = CGRect(x: 8, y: 58, width: 40, height: 50)
    static let fernseher = CGRect(x: 82, y: 104, width: 78, height: 56)
    static let pinnwand = CGRect(x: 298, y: 58, width: 84, height: 60)
    static let pokale = CGRect(x: 298, y: 124, width: 84, height: 44)
    /// Stands on the window sill (y 180), leaning on the left curtain.
    static let pflanze = CGRect(x: 158, y: 112, width: 52, height: 68)
    static let ziel = CGRect(x: 322, y: 350, width: 58, height: 66)
    /// The other one's real whereabouts, a small round window on the left wall above the bed.
    static let andere = CGRect(x: 12, y: 162, width: 42, height: 42)
    /// The three photo frames (slot 0 to 2 of `Zimmer.rahmen`); the photo sits 7 inside.
    static let rahmen = [CGRect(x: 52, y: 62, width: 34, height: 42), CGRect(x: 6, y: 114, width: 36, height: 44), CGRect(x: 45, y: 114, width: 34, height: 44)]

    /// Polaroid `i` on the board: centre and tilt in degrees.
    static func polaroid(_ i: Int) -> (mitte: CGPoint, grad: Double) {
        let alle: [(mitte: CGPoint, grad: Double)] = [(P(318, 90), -8), (P(342, 94), 4), (P(366, 89), 10)]
        return alle[i]
    }

    static let polaroidGroesse = CGSize(width: 28, height: 34)
    /// The photo area inside a polaroid, relative to its centre.
    static let polaroidFoto = CGRect(x: -11, y: -14, width: 22, height: 22)
}

/// Vector drawings of the nine objects in the sticker style of the room (`teil`: fill plus soft
/// outline). Every function draws into the already scaled room context.
enum ZimmerLebenZeichnung {
    private static func farbe(_ hex: UInt32) -> FigurFarbe { FigurFarbe(hex) }

    private static func text(_ g: GraphicsContext, _ s: String, _ c: CGPoint, _ groesse: CGFloat, _ f: FigurFarbe) {
        g.draw(Text(s).font(.system(size: groesse, weight: .heavy, design: .rounded)).foregroundStyle(f.farbe), at: c)
    }

    private static func wolke(_ g: GraphicsContext, _ c: CGPoint, _ s: CGFloat, _ f: FigurFarbe) {
        verbunden(g, [
            kreis(P(c.x - 26 * s, c.y + 4 * s), 18 * s), kreis(P(c.x, c.y - 8 * s), 26 * s),
            kreis(P(c.x + 28 * s, c.y + 2 * s), 20 * s), box(c.x - 44 * s, c.y + 4 * s, 92 * s, 18 * s, 9 * s),
        ], f, 2)
    }

    // MARK: Fenster (2)

    /// Sky and weather in the glass between the curtains, then the cross of bars drawn again on top.
    static func fenster(_ g: GraphicsContext, _ h: ZimmerHimmel) {
        let glas = ZimmerLebenLayout.fenster
        var c = g
        c.clip(to: Path(glas))
        let grau = h.wetter == .regen || h.wetter == .schnee
        let himmel: [UInt32] = switch (h.nacht, h.wetter) {
        case (true, _): grau ? [0x252B45, 0x3E435F] : [0x1E2A55, 0x3A3F78]
        case (false, .sonne): [0x8CCBF2, 0xDDF1FB]
        case (false, .wolken): [0x9DB7CC, 0xD3DEE8]
        case (false, .regen): [0x6F8498, 0xA9B8C6]
        case (false, .schnee): [0xB9CAD9, 0xEAF1F7]
        }
        c.fill(Path(glas), with: .linearGradient(Gradient(colors: himmel.map { farbe($0).farbe }), startPoint: P(glas.midX, glas.minY), endPoint: P(glas.midX, glas.maxY)))
        let himmelsding = P(glas.maxX - 18, glas.minY + 24)
        if h.nacht && !grau {
            for k in 0..<8 { c.fill(kreis(P(glas.minX + CGFloat((k * 37) % 62) + 3, glas.minY + CGFloat((k * 53) % 80) + 4), k % 3 == 0 ? 1.8 : 1.1), with: .color(farbe(0xFFF6D5).farbe)) }
            c.fill(kreis(himmelsding, 20), with: .radialGradient(Gradient(colors: [farbe(0xFFF1B8).farbe.opacity(0.25), .clear]), center: himmelsding, startRadius: 8, endRadius: 20))
            var m = c
            m.clip(to: kreis(P(himmelsding.x + 5.5, himmelsding.y - 4), 9), options: .inverse)
            m.fill(kreis(himmelsding, 10), with: .color(farbe(0xFFF1B8).farbe))
        }
        if !h.nacht && h.wetter == .sonne {
            for k in 0..<8 {
                let w = Double(k) * .pi / 4
                c.stroke(strich(P(himmelsding.x + 15 * CGFloat(cos(w)), himmelsding.y + 15 * CGFloat(sin(w))), P(himmelsding.x + 20 * CGFloat(cos(w)), himmelsding.y + 20 * CGFloat(sin(w)))), with: .color(Pal.gelb.farbe), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            teil(c, kreis(himmelsding, 11), Pal.gelb, 2.5)
        }
        let wolken = grau ? farbe(0xB4BDC8) : (h.nacht ? farbe(0x6A7194) : Pal.weiss)
        switch h.wetter {
        case .sonne: if !h.nacht { wolke(c, P(glas.minX + 22, glas.maxY - 22), 0.4, Pal.weiss) }
        case .wolken:
            wolke(c, P(glas.minX + 26, glas.minY + 30), 0.4, wolken)
            wolke(c, P(glas.maxX - 24, glas.midY + 28), 0.45, wolken)
        case .regen, .schnee:
            wolke(c, P(glas.minX + 28, glas.minY + 24), 0.42, wolken)
            wolke(c, P(glas.maxX - 22, glas.minY + 40), 0.34, wolken)
            for k in 0..<14 {
                let p = P(glas.minX + CGFloat((k * 41) % 62) + 3, glas.midY + CGFloat((k * 29) % 46))
                if h.wetter == .regen { c.stroke(strich(p, P(p.x - 3, p.y + 9)), with: .color(farbe(0xDDEBF7).farbe.opacity(0.8)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round)) }
                else { c.fill(kreis(p, k % 3 == 0 ? 2.6 : 1.8), with: .color(.white)) }
            }
        }
        linie(c, strich(P(glas.midX, glas.minY), P(glas.midX, glas.maxY)), Pal.weiss.farbe, 4)
        linie(c, strich(P(glas.minX, glas.midY), P(glas.maxX, glas.midY)), Pal.weiss.farbe, 4)
    }

    // MARK: Kalenderblatt (1)

    static func kalender(_ g: GraphicsContext, _ termin: ZimmerTermin?) {
        var k = g
        k.translateBy(x: ZimmerLebenLayout.kalender.minX, y: ZimmerLebenLayout.kalender.minY)
        let blatt = box(0, 0, 40, 50, 4)
        k.fill(blatt, with: .color(Pal.weiss.farbe))
        var oben = k
        oben.clip(to: blatt)
        oben.fill(box(0, 0, 40, 15), with: .color(Pal.rose.farbe))
        k.stroke(blatt, with: .color(Pal.weiss.kontur), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        for x: CGFloat in [11, 29] { teil(k, box(x - 1.5, -3, 3, 7, 1.5), Pal.dunkel, 1.5) }
        if let termin {
            let b = ZimmerKalenderblatt.blatt(termin.tag)
            text(k, b.monat, P(20, 9), 8, Pal.weiss)
            text(k, b.tag, P(20, 33), 22, Pal.tinte)
        } else {
            text(k, "Wir", P(20, 9), 8, Pal.weiss)
            k.fill(herzPfad(P(20, 33), 8), with: .color(Pal.rose.farbe.opacity(0.5)))
        }
    }

    // MARK: Pokalregal (7)

    static func pokale(_ g: GraphicsContext, _ liste: [ZimmerPokal]) {
        var k = g
        k.translateBy(x: ZimmerLebenLayout.pokale.minX, y: ZimmerLebenLayout.pokale.minY)
        for x: CGFloat in [10, 69] { teil(k, box(x, 42, 5, 7, 1), Pal.holz, 1.5) }
        teil(k, box(0, 38, 84, 6, 2), Pal.holz, 2)
        let cups = Array(liste.prefix(3))
        if cups.isEmpty { pokal(k, 42, nil) }
        for (i, p) in cups.enumerated() { pokal(k, 42 + (CGFloat(i) - CGFloat(cups.count - 1) / 2) * 26, p.stufe) }
    }

    /// A cup standing on the board at `x`; `nil` is the empty, pale one.
    private static func pokal(_ g: GraphicsContext, _ x: CGFloat, _ stufe: ZimmerPokal.Stufe?) {
        var k = g
        k.translateBy(x: x, y: 38)
        let f: FigurFarbe
        switch stufe {
        case .gold?: f = Pal.gold
        case .silber?: f = Pal.silber
        case .bronze?: f = farbe(0xCD8A4B)
        case nil: f = farbe(0xD9D6DE)
        }
        for seite: CGFloat in [-1, 1] {
            let griff = bogen(P(seite * 9, -27), P(seite * 7, -17), P(seite * 18, -19))
            linie(k, griff, f.kontur, 4.5)
            linie(k, griff, f.farbe, 2)
        }
        let schale = Path { p in
            p.move(to: P(-10, -31))
            p.addLine(to: P(10, -31))
            p.addQuadCurve(to: P(0, -11), control: P(10, -14))
            p.addQuadCurve(to: P(-10, -31), control: P(-10, -14))
            p.closeSubpath()
        }
        teil(k, box(-2, -12, 4, 9), f, 2)
        teil(k, box(-8, -5, 16, 5, 2), f.mal(0.88), 2)
        teil(k, schale, f, 2.5)
        k.fill(herzPfad(P(0, -22), 4), with: .color(.white.opacity(stufe == nil ? 0.5 : 0.85)))
    }

    // MARK: Pinnwand (4)

    /// The board; the polaroids `anzahl` of them, their photos come on top as views.
    static func pinnwand(_ g: GraphicsContext, anzahl: Int) {
        var k = g
        k.translateBy(x: ZimmerLebenLayout.pinnwand.minX, y: ZimmerLebenLayout.pinnwand.minY)
        teil(k, box(0, 0, 84, 60, 5), farbe(0xC9A27A), 2.5)
        linie(k, Path(roundedRect: CGRect(x: 0, y: 0, width: 84, height: 60), cornerRadius: 5), Pal.holz.farbe, 4)
        for i in 0..<anzahl {
            let p = ZimmerLebenLayout.polaroid(i)
            var c = g
            c.translateBy(x: p.mitte.x, y: p.mitte.y)
            c.rotate(by: .degrees(p.grad))
            teil(c, box(-14, -17, 28, 34, 2), Pal.weiss, 1.5)
            c.fill(Path(roundedRect: ZimmerLebenLayout.polaroidFoto, cornerRadius: 1), with: .color(farbe(0xE6D8F2).farbe))
            c.fill(herzPfad(P(0, -3), 4), with: .color(Pal.rose.farbe.opacity(0.55)))
            c.fill(kreis(P(0, -15), 2.6), with: .color(Pal.rose.farbe))
            c.fill(kreis(P(-0.8, -15.8), 0.9), with: .color(.white.opacity(0.8)))
        }
        if anzahl == 0 {
            k.fill(herzPfad(P(42, 30), 7), with: .color(Pal.rose.farbe.opacity(0.55)))
            k.fill(kreis(P(42, 14), 2.6), with: .color(Pal.rose.farbe))
        }
    }

    // MARK: Fernseher (6)

    static func fernseher(_ g: GraphicsContext, _ film: ZimmerFilm?) {
        var k = g
        k.translateBy(x: ZimmerLebenLayout.fernseher.minX, y: ZimmerLebenLayout.fernseher.minY)
        for x: CGFloat in [6, 68] { teil(k, box(x, 48, 4, 8), Pal.holz, 1.5) }
        teil(k, box(0, 42, 78, 8, 3), Pal.holz, 2)
        teil(k, box(30, 37, 18, 6, 1), Pal.dunkel, 1.5)
        teil(k, box(8, 0, 62, 38, 6), Pal.dunkel, 2.5)
        let schirm = box(12, 4, 54, 29, 3)
        guard let film else {
            k.fill(schirm, with: .color(farbe(0x2A2A33).farbe))
            linie(k, strich(P(39, 13), P(39, 23)), .white.opacity(0.35), 2)
            linie(k, strich(P(34, 18), P(44, 18)), .white.opacity(0.35), 2)
            return
        }
        let paare: [[UInt32]] = [[0xF7B6C6, 0xB9A7E0], [0x8CCBF2, 0x8ED8BE], [0xFFD34E, 0xE59A74], [0xB9A7E0, 0x7FB6E8], [0x8ED8BE, 0xF5C542]]
        let p = paare[film.titel.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % paare.count]
        k.fill(schirm, with: .linearGradient(Gradient(colors: [farbe(p[0]).farbe, farbe(p[1]).farbe]), startPoint: P(12, 4), endPoint: P(66, 33)))
        if film.serie {
            for y: CGFloat in [12, 18.5, 25] { k.fill(Path(roundedRect: CGRect(x: 26, y: y, width: 26, height: 3.5), cornerRadius: 1.75), with: .color(.white.opacity(0.9))) }
        } else {
            let dreieck = Path { d in
                d.move(to: P(34, 11))
                d.addLine(to: P(34, 27))
                d.addLine(to: P(47, 19))
                d.closeSubpath()
            }
            k.fill(dreieck, with: .color(.white.opacity(0.92)))
        }
        k.fill(Path(roundedRect: CGRect(x: 14, y: 6, width: 22, height: 4), cornerRadius: 2), with: .color(.white.opacity(0.28)))
    }

    // MARK: Pflanze (8)

    /// A teardrop leaf from `von`, pointing up and turned by `grad` degrees.
    private static func blatt(_ g: GraphicsContext, _ von: CGPoint, _ grad: Double, _ l: CGFloat, _ f: FigurFarbe) {
        let form = Path { p in
            p.move(to: .zero)
            p.addQuadCurve(to: P(0, -l), control: P(-l * 0.45, -l * 0.6))
            p.addQuadCurve(to: .zero, control: P(l * 0.45, -l * 0.6))
            p.closeSubpath()
        }
        teil(g, form.applying(CGAffineTransform(translationX: von.x, y: von.y).rotated(by: grad * .pi / 180)), f, 2)
    }

    static func pflanze(_ g: GraphicsContext, _ s: ZimmerPflanzenStand) {
        var k = g
        k.translateBy(x: ZimmerLebenLayout.pflanze.midX, y: ZimmerLebenLayout.pflanze.maxY)
        let topf = Path { p in
            p.move(to: P(-11, -16))
            p.addLine(to: P(11, -16))
            p.addLine(to: P(8, 0))
            p.addLine(to: P(-8, 0))
            p.closeSubpath()
        }
        let hoehe: CGFloat = [8, 16, 26, 36, 42][s.stufe]
        let laub = s.haengt ? farbe(0x9FBF8C) : Pal.gruen
        let spitze = P(0, -20 - hoehe)
        linie(k, strich(P(0, -20), spitze), laub.kontur, 5)
        linie(k, strich(P(0, -20), spitze), laub.farbe, 2.5)
        let paare = [1, 1, 2, 3, 3][s.stufe]
        for i in 0..<paare {
            let y = -20 - hoehe * (0.35 + 0.65 * CGFloat(i) / CGFloat(max(paare - 1, 1)))
            for seite in [-1.0, 1.0] { blatt(k, P(0, y), seite * (s.haengt ? 125 : 50), [9, 13, 15, 16, 16][s.stufe], laub) }
        }
        blatt(k, spitze, s.haengt ? 70 : 0, [8, 11, 13, 14, 12][s.stufe], laub)
        if s.stufe == 4 && !s.haengt {
            for w in 0..<5 {
                let a = Double(w) * 2 * .pi / 5
                teil(k, kreis(P(spitze.x + 6 * CGFloat(sin(a)), spitze.y - 5 - 6 * CGFloat(cos(a))), 3.8), farbe(0xF7B6C6), 1.5)
            }
            teil(k, kreis(P(spitze.x, spitze.y - 5), 3.2), Pal.gelb, 1.5)
        }
        teil(k, topf, farbe(0xE59A74), 2.5)
        teil(k, box(-13, -20, 26, 6, 3), farbe(0xEDAE8C), 2.5)
    }

    // MARK: Ziel (9)

    static func ziel(_ g: GraphicsContext, _ z: ZimmerZiel?) {
        var k = g
        k.translateBy(x: ZimmerLebenLayout.ziel.minX, y: ZimmerLebenLayout.ziel.minY)
        let anteil = z?.anteil ?? 0
        let koffer = z?.koffer ?? false
        let koerper = koffer ? box(2, 20, 54, 42, 7) : box(8, 14, 42, 48, 12)
        let stand = 62 - (koffer ? 42 : 48) * anteil
        k.fill(koerper, with: .color(koffer ? farbe(0xB9DCD5).farbe : .white.opacity(0.5)))
        var innen = k
        innen.clip(to: koerper)
        innen.fill(Path(CGRect(x: 0, y: stand, width: 60, height: 70)), with: .color(koffer ? farbe(0x4FB6A0).farbe : Pal.gold.farbe.opacity(0.4)))
        if koffer {
            for x: CGFloat in [14, 39] { innen.fill(Path(CGRect(x: x, y: 20, width: 5, height: 42)), with: .color(Pal.gelb.farbe.opacity(0.9))) }
        } else {
            let muenzen: [CGPoint] = [P(20, 56), P(32, 57), P(26, 49), P(38, 50), P(22, 42), P(34, 43), P(28, 35)]
            for m in muenzen where m.y > stand + 3 { teil(innen, kreis(m, 5), Pal.gold, 1.5) }
        }
        k.stroke(koerper, with: .color((koffer ? farbe(0x4FB6A0) : Pal.silber).kontur), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        if koffer {
            linie(k, bogen(P(21, 20), P(37, 20), P(29, 4)), Pal.dunkel.farbe, 3.5)
            for x: CGFloat in [22, 32] { teil(k, box(x, 28, 4, 5, 1), Pal.dunkel, 1.2) }
            for x: CGFloat in [12, 46] { teil(k, kreis(P(x, 63), 3), Pal.dunkel, 1.2) }
        } else {
            teil(k, box(6, 4, 46, 12, 4), Pal.holz, 2)
        }
        if z == nil {
            linie(k, strich(P(29, 34), P(29, 48)), Pal.silber.kontur, 3)
            linie(k, strich(P(22, 41), P(36, 41)), Pal.silber.kontur, 3)
        } else if z?.geschafft == true {
            k.fill(herzPfad(P(29, koffer ? 0 : -2), 6), with: .color(Pal.rose.farbe))
        }
    }
}
