import SwiftUI

extension Zeichner {

    func kappe(top: CGFloat, scheitel: CGFloat, ansatz: CGFloat, unten: CGFloat) -> Path {
        Path { p in
            p.move(to: P(40, unten))
            p.addCurve(to: P(100, top), control1: P(34, 50), control2: P(60, top))
            p.addCurve(to: P(160, unten), control1: P(140, top), control2: P(166, 50))
            p.addLine(to: P(152, unten - 2))
            p.addCurve(to: P(scheitel, ansatz), control1: P(152, 76), control2: P(scheitel + 30, ansatz))
            p.addCurve(to: P(48, unten - 2), control1: P(scheitel - 30, ansatz), control2: P(48, 76))
            p.closeSubpath()
        }
    }

    /// Hair part with outline, plus highlight streaks when the hair color has them.
    func haarTeil(_ g: GraphicsContext, _ p: Path, _ breite: CGFloat = 3.5) {
        teil(g, p, haar, breite)
        guard let s = straehne else { return }
        streifen(g, p, s)
    }

    /// The hair color's highlight streaks inside `p`.
    func streifen(_ g: GraphicsContext, _ p: Path, _ s: FigurFarbe) {
        var h = g
        h.clip(to: p)
        for i in 0..<7 {
            let x = CGFloat(34 + i * 22)
            linie(h, bogen(P(x, 0), P(x + 10, 240), P(x - 14, 110)), s.farbe.opacity(0.85), 4)
        }
    }

    func lockenKette(_ g: GraphicsContext, _ punkte: [CGPoint], _ r: CGFloat) {
        for c in punkte { g.fill(kreis(c, r + 2), with: .color(haar.kontur)) }
        for c in punkte { g.fill(kreis(c, r), with: .color(haar.farbe)) }
    }

    func langHinten(_ u: CGFloat) -> Path {
        Path { p in
            p.move(to: P(100, 22))
            p.addCurve(to: P(34, 92), control1: P(56, 22), control2: P(34, 50))
            p.addLine(to: P(30, u - 8))
            p.addQuadCurve(to: P(60, u), control: P(40, u + 2))
            p.addLine(to: P(140, u))
            p.addQuadCurve(to: P(170, u - 8), control: P(160, u + 2))
            p.addLine(to: P(166, 92))
            p.addCurve(to: P(100, 22), control1: P(166, 50), control2: P(144, 22))
            p.closeSubpath()
        }
    }

    func seitenLocken(_ bis: CGFloat) -> [CGPoint] {
        var punkte: [CGPoint] = []
        for y in stride(from: CGFloat(104), through: bis, by: 18) {
            punkte.append(P(40, y))
            punkte.append(P(160, y))
        }
        return punkte
    }

    func haareHinten(_ g: GraphicsContext) {
        if let neu, eigeneFrisur { neueHaareHinten(g, neu); return }
        switch frisur {
        case 6, 28:
            haarTeil(g, box(32, 30, 136, 124, 50))
        case 7, 8, 20, 29:
            haarTeil(g, langHinten(222))
        case 26:
            haarTeil(g, kreis(P(100, 12), 13))
            haarTeil(g, langHinten(222))
        case 21:
            haarTeil(g, langHinten(222))
            lockenKette(g, seitenLocken(212), 13)
        case 22:
            haarTeil(g, langHinten(168))
        case 31:
            haarTeil(g, langHinten(170))
            lockenKette(g, seitenLocken(164), 13)
        case 9:
            let zopf = Path { p in
                p.move(to: P(132, 40))
                p.addCurve(to: P(178, 168), control1: P(190, 50), control2: P(194, 130))
                p.addCurve(to: P(150, 100), control1: P(162, 176), control2: P(150, 136))
                p.closeSubpath()
            }
            haarTeil(g, zopf)
        case 10:
            haarTeil(g, kreis(P(100, 24), 18))
        case 17:
            var bumps: [CGPoint] = []
            for i in 0..<14 {
                let a = Double(i) / 14 * 2 * Double.pi
                bumps.append(P(100 + 66 * CGFloat(cos(a)), 78 + 62 * CGFloat(sin(a))))
            }
            for b in bumps { g.fill(kreis(b, 16), with: .color(haar.kontur)) }
            g.fill(oval(P(100, 78), 68, 64), with: .color(haar.kontur))
            for b in bumps { g.fill(kreis(b, 13.5), with: .color(haar.farbe)) }
            g.fill(oval(P(100, 78), 66, 62), with: .color(haar.farbe))
        case 18:
            haarTeil(g, kreis(P(100, 16), 13))
            g.fill(box(88, 25, 24, 5, 2), with: .color(haar.mal(0.6).farbe))
        case 19:
            for x in stride(from: CGFloat(36), through: 164, by: 14) {
                let lang: CGFloat = abs(x - 100) > 40 ? 132 : 70
                let strang = box(x - 6, 40, 12, lang - 40, 6)
                linie(g, strang, haar.kontur, 3)
                g.fill(strang, with: .color(haar.farbe))
            }
        case 23:
            let schweif = Path { p in
                p.move(to: P(96, 20))
                p.addCurve(to: P(172, 150), control1: P(150, -10), control2: P(186, 80))
                p.addCurve(to: P(146, 90), control1: P(160, 150), control2: P(150, 120))
                p.addCurve(to: P(112, 22), control1: P(146, 60), control2: P(130, 30))
                p.closeSubpath()
            }
            haarTeil(g, schweif)
        case 24:
            haarTeil(g, kreis(P(52, 34), 20))
            haarTeil(g, kreis(P(148, 34), 20))
        case 32:
            let schwanz = Path { p in
                p.move(to: P(50, 60))
                p.addCurve(to: P(16, 150), control1: P(14, 60), control2: P(6, 110))
                p.addCurve(to: P(40, 118), control1: P(28, 150), control2: P(40, 136))
                p.addCurve(to: P(56, 76), control1: P(40, 96), control2: P(50, 84))
                p.closeSubpath()
            }
            haarTeil(g, schwanz)
            haarTeil(g, gespiegelt(schwanz))
        case 34...: // Z-38.3 Runde-3 styles
            neueFrisurHinten(g)
        default:
            break
        }
    }

    func lockenKopf(_ g: GraphicsContext) {
        g.fill(kappe(top: 22, scheitel: 100, ansatz: 62, unten: 96), with: .color(haar.farbe))
        var locken: [CGPoint] = []
        for grad in stride(from: 190.0, through: 350.0, by: 20.0) {
            let r = grad * Double.pi / 180
            locken.append(P(100 + 60 * CGFloat(cos(r)), 84 + 60 * CGFloat(sin(r))))
        }
        locken += [P(66, 60), P(84, 54), P(100, 52), P(116, 54), P(134, 60)]
        lockenKette(g, locken, 11.8)
    }

    func haareVorn(_ g: GraphicsContext) {
        if let neu, eigeneFrisur { neueHaareVorn(g, neu); return }
        switch frisur {
        case 0:
            haarTeil(g, kappe(top: 18, scheitel: 100, ansatz: 58, unten: 92))
            let bueschel = Path { p in
                p.move(to: P(76, 40))
                p.addQuadCurve(to: P(90, 12), control: P(76, 20))
                p.addQuadCurve(to: P(100, 30), control: P(96, 18))
                p.addQuadCurve(to: P(116, 12), control: P(108, 20))
                p.addQuadCurve(to: P(126, 40), control: P(128, 22))
            }
            g.fill(bueschel, with: .color(haar.farbe))
            linie(g, bueschel, haar.kontur, 3)
        case 1:
            teil(g, kappe(top: 24, scheitel: 100, ansatz: 54, unten: 88), haar.mix(haut, 0.35), 2.5)
        case 2:
            haarTeil(g, kappe(top: 18, scheitel: 72, ansatz: 56, unten: 92))
            let welle = Path { p in
                p.move(to: P(70, 46))
                p.addCurve(to: P(152, 86), control1: P(112, 30), control2: P(150, 52))
                p.addCurve(to: P(104, 62), control1: P(140, 70), control2: P(122, 60))
                p.addCurve(to: P(70, 46), control1: P(88, 64), control2: P(74, 56))
                p.closeSubpath()
            }
            haarTeil(g, welle, 3)
        case 3:
            lockenKopf(g)
        case 4:
            haarTeil(g, kappe(top: 22, scheitel: 100, ansatz: 58, unten: 92))
            let tolle = Path { p in
                p.move(to: P(64, 50))
                p.addCurve(to: P(118, 6), control1: P(60, 20), control2: P(88, 4))
                p.addCurve(to: P(142, 40), control1: P(140, 8), control2: P(150, 26))
                p.addCurve(to: P(100, 50), control1: P(130, 50), control2: P(112, 46))
                p.addCurve(to: P(64, 50), control1: P(86, 56), control2: P(72, 56))
                p.closeSubpath()
            }
            haarTeil(g, tolle, 3)
        case 5:
            linie(g, bogen(P(62, 56), P(84, 38), P(66, 42)), .white.opacity(0.35), 5)
            return
        case 6:
            haarTeil(g, kappe(top: 16, scheitel: 100, ansatz: 70, unten: 106))
        case 7, 8, 26:
            haarTeil(g, kappe(top: 16, scheitel: frisur == 8 ? 80 : 100, ansatz: 50, unten: 106))
            let strang = frisur == 8 ? straehneWellig : straehneGlatt()
            haarTeil(g, strang)
            haarTeil(g, gespiegelt(strang))
            if frisur == 26 { teil(g, box(89, 13, 22, 6, 3), Pal.rose, 1.5) }
        case 9, 10, 24:
            haarTeil(g, kappe(top: 20, scheitel: 100, ansatz: 54, unten: 96))
        case 11:
            haarTeil(g, kappe(top: 18, scheitel: 100, ansatz: 52, unten: 100))
            for seite in [CGFloat(-1), 1] {
                var glieder: [CGPoint] = []
                for i in 0..<6 { glieder.append(P(100 + seite * (54 + CGFloat(i) * 1.5), 112 + CGFloat(i) * 16)) }
                for c in glieder { g.fill(oval(c, 11, 12), with: .color(haar.kontur)) }
                for c in glieder { g.fill(oval(c, 9, 10), with: .color(haar.farbe)) }
                let ende = P(100 + seite * 63, 206)
                teil(g, kreis(ende, 5), Pal.rose, 2)
            }
        case 12:
            let k = kappe(top: 18, scheitel: 100, ansatz: 60, unten: 94)
            haarTeil(g, k)
            var buschel: [Path] = []
            for i in 0..<6 {
                let x0 = CGFloat(48 + i * 17)
                let dx: CGFloat = i % 2 == 0 ? 6 : 12
                let sy: CGFloat = i % 2 == 0 ? 72 : 66
                let spitze = P(x0 + dx, sy)
                buschel.append(Path { p in
                    p.move(to: P(x0, 52))
                    p.addQuadCurve(to: spitze, control: P(x0 + 1, 66))
                    p.addQuadCurve(to: P(x0 + 19, 52), control: P(x0 + 16, 62))
                    p.closeSubpath()
                })
            }
            for p in buschel { linie(g, p, haar.kontur, 5) }
            for p in buschel { g.fill(p, with: .color(haar.farbe)) }
            g.fill(k, with: .color(haar.farbe))
        case 13:
            teil(g, kappe(top: 24, scheitel: 100, ansatz: 60, unten: 92), haar.mix(haut, 0.45), 2.5)
            let oben = Path { p in
                p.move(to: P(48, 62))
                p.addCurve(to: P(100, 8), control1: P(42, 26), control2: P(68, 8))
                p.addCurve(to: P(154, 54), control1: P(134, 8), control2: P(158, 30))
                p.addCurve(to: P(48, 62), control1: P(122, 44), control2: P(78, 34))
                p.closeSubpath()
            }
            haarTeil(g, oben, 3)
            linie(g, bogen(P(70, 40), P(140, 30), P(100, 20)), haar.kontur, 2)
        case 14:
            teil(g, kappe(top: 22, scheitel: 100, ansatz: 60, unten: 94), haar.mix(haut, 0.6), 2.5)
            let oben = Path { p in
                p.move(to: P(52, 60))
                p.addCurve(to: P(100, 18), control1: P(50, 32), control2: P(70, 18))
                p.addCurve(to: P(148, 60), control1: P(130, 18), control2: P(150, 32))
                p.addQuadCurve(to: P(52, 60), control: P(100, 50))
                p.closeSubpath()
            }
            haarTeil(g, oben, 3)
        case 15:
            haarTeil(g, kappe(top: 18, scheitel: 100, ansatz: 50, unten: 94))
            let vorhang = Path { p in
                p.move(to: P(100, 34))
                p.addCurve(to: P(50, 92), control1: P(74, 36), control2: P(52, 58))
                p.addLine(to: P(60, 94))
                p.addCurve(to: P(98, 46), control1: P(64, 64), control2: P(80, 48))
                p.closeSubpath()
            }
            haarTeil(g, vorhang, 3)
            haarTeil(g, gespiegelt(vorhang), 3)
        case 16:
            haarTeil(g, kappe(top: 18, scheitel: 100, ansatz: 72, unten: 98))
            for x in [CGFloat(72), 88, 112, 128] { linie(g, strich(P(x, 58), P(x + 1, 70)), haar.kontur, 2) }
        case 17:
            g.fill(kappe(top: 14, scheitel: 100, ansatz: 56, unten: 96), with: .color(haar.farbe))
            var punkte: [CGPoint] = []
            for x in stride(from: CGFloat(58), through: 142, by: 14) { punkte.append(P(x, 56 + abs(x - 100) * 0.3)) }
            lockenKette(g, punkte, 9)
        case 18:
            teil(g, kappe(top: 22, scheitel: 100, ansatz: 54, unten: 90), haar.mix(haut, 0.3), 2.5)
            let oben = Path { p in
                p.move(to: P(56, 58))
                p.addCurve(to: P(100, 22), control1: P(54, 34), control2: P(72, 22))
                p.addCurve(to: P(144, 58), control1: P(128, 22), control2: P(146, 34))
                p.addQuadCurve(to: P(56, 58), control: P(100, 46))
                p.closeSubpath()
            }
            haarTeil(g, oben, 3)
            for x in [CGFloat(78), 100, 122] { linie(g, bogen(P(x, 50), P(100, 26), P(x, 34)), haar.kontur, 1.8) }
        case 19:
            haarTeil(g, kappe(top: 20, scheitel: 100, ansatz: 58, unten: 94))
            for x in stride(from: CGFloat(58), through: 142, by: 12) {
                let lang: CGFloat = x.truncatingRemainder(dividingBy: 24) == 10 ? 34 : 28
                let strang = box(x - 5, 40, 10, lang, 5)
                linie(g, strang, haar.kontur, 3)
                g.fill(strang, with: .color(haar.farbe))
            }
        case 20:
            haarTeil(g, kappe(top: 16, scheitel: 100, ansatz: 72, unten: 106))
            haarTeil(g, straehneGlatt())
            haarTeil(g, gespiegelt(straehneGlatt()))
        case 21:
            haarTeil(g, kappe(top: 16, scheitel: 88, ansatz: 52, unten: 104))
            lockenKette(g, seitenLocken(200), 11)
        case 22:
            haarTeil(g, kappe(top: 16, scheitel: 100, ansatz: 50, unten: 106))
            haarTeil(g, straehneGlatt(166))
            haarTeil(g, gespiegelt(straehneGlatt(166)))
        case 23:
            haarTeil(g, kappe(top: 18, scheitel: 100, ansatz: 50, unten: 92))
        case 25:
            haarTeil(g, kappe(top: 18, scheitel: 76, ansatz: 52, unten: 100))
            haarTeil(g, gespiegelt(straehneGlatt(120)))
            var glieder: [CGPoint] = []
            // Fix round 1: five links end above the elbow, no stray tie dot.
            for i in 0..<5 { glieder.append(P(152 - CGFloat(i) * 2.5, 112 + CGFloat(i) * 16)) }
            for c in glieder { g.fill(oval(c, 13, 12), with: .color(haar.kontur)) }
            for c in glieder { g.fill(oval(c, 11, 10), with: .color(haar.farbe)) }
        case 27:
            haarTeil(g, kappe(top: 20, scheitel: 70, ansatz: 60, unten: 92))
            let schwung = Path { p in
                p.move(to: P(58, 46))
                p.addCurve(to: P(144, 66), control1: P(98, 30), control2: P(138, 40))
                p.addCurve(to: P(96, 64), control1: P(130, 74), control2: P(112, 64))
                p.addCurve(to: P(58, 46), control1: P(80, 64), control2: P(60, 60))
                p.closeSubpath()
            }
            haarTeil(g, schwung, 3)
        case 28:
            haarTeil(g, kappe(top: 16, scheitel: 100, ansatz: 74, unten: 106))
        case 29:
            haarTeil(g, kappe(top: 16, scheitel: 70, ansatz: 50, unten: 106))
            haarTeil(g, straehneGlatt())
            haarTeil(g, gespiegelt(straehneGlatt()))
            let schwung = Path { p in
                p.move(to: P(70, 36))
                p.addCurve(to: P(156, 110), control1: P(120, 34), control2: P(160, 70))
                p.addLine(to: P(146, 112))
                p.addCurve(to: P(72, 50), control1: P(140, 76), control2: P(110, 50))
                p.closeSubpath()
            }
            haarTeil(g, schwung, 3)
        case 30:
            teil(g, kappe(top: 26, scheitel: 100, ansatz: 60, unten: 92), haar.mix(haut, 0.6), 2.5)
            let kamm = Path { p in
                p.move(to: P(86, 58))
                p.addCurve(to: P(100, 2), control1: P(84, 22), control2: P(92, 6))
                p.addCurve(to: P(114, 58), control1: P(108, 6), control2: P(116, 22))
                p.closeSubpath()
            }
            haarTeil(g, kamm, 3)
        case 31:
            lockenKopf(g)
            lockenKette(g, seitenLocken(150), 11)
        case 32:
            haarTeil(g, kappe(top: 18, scheitel: 100, ansatz: 54, unten: 96))
            teil(g, kreis(P(46, 70), 6), Pal.rose, 2)
            teil(g, kreis(P(154, 70), 6), Pal.rose, 2)
        case 33:
            haarTeil(g, kappe(top: 20, scheitel: 100, ansatz: 44, unten: 88))
            for x in [CGFloat(78), 100, 122] { linie(g, bogen(P(x, 46), P(x + 4, 20), P(x - 6, 32)), .white.opacity(0.35), 3) }
        default:
            // Z-38.3: the Runde-3 styles draw their own strands and highlight.
            neueFrisurVorn(g)
            return
        }
        if ![1, 14, 17, 30].contains(frisur) {
            linie(g, bogen(P(58, 62), P(86, 30), P(62, 36)), .white.opacity(0.45), 5)
        }
    }

    func straehneGlatt(_ u: CGFloat = 212) -> Path {
        Path { p in
            p.move(to: P(42, 92))
            p.addCurve(to: P(32, u - 6), control1: P(34, 130), control2: P(30, u - 32))
            p.addQuadCurve(to: P(58, u), control: P(42, u + 4))
            p.addCurve(to: P(54, 104), control1: P(60, u - 42), control2: P(58, 130))
            p.closeSubpath()
        }
    }

    var straehneWellig: Path {
        Path { p in
            p.move(to: P(42, 92))
            p.addCurve(to: P(34, 150), control1: P(28, 112), control2: P(44, 130))
            p.addCurve(to: P(34, 206), control1: P(24, 170), control2: P(40, 190))
            p.addQuadCurve(to: P(60, 212), control: P(46, 218))
            p.addCurve(to: P(56, 150), control1: P(66, 190), control2: P(50, 170))
            p.addCurve(to: P(54, 104), control1: P(64, 130), control2: P(52, 118))
            p.closeSubpath()
        }
    }

    // MARK: Headwear and glasses

    func kopfschmuck(_ g: GraphicsContext) {
        if z == .nichtStoeren {
            let buegel = Path { p in
                p.move(to: P(40, 100))
                p.addCurve(to: P(160, 100), control1: P(36, 0), control2: P(164, 0))
            }
            linie(g, buegel, Pal.dunkel.kontur, 11)
            linie(g, buegel, Pal.dunkel.farbe, 7)
            teil(g, box(28, 82, 22, 38, 10), Pal.rose)
            teil(g, box(150, 82, 22, 38, 10), Pal.rose)
        }
        if z == .rad {
            let helm = Path { p in
                p.move(to: P(36, 84))
                p.addCurve(to: P(164, 84), control1: P(36, 0), control2: P(164, 0))
                p.closeSubpath()
            }
            teil(g, helm, Pal.mint)
            for x in [CGFloat(78), 100, 122] { g.fill(box(x - 4, 28, 8, 20, 4), with: .color(.white.opacity(0.5))) }
            linie(g, strich(P(46, 84), P(66, 136)), Pal.dunkel.farbe, 2.5)
            linie(g, strich(P(154, 84), P(134, 136)), Pal.dunkel.farbe, 2.5)
        }
        if abz.contains("partyhut") {
            let hut = Path { p in
                p.move(to: P(74, 34))
                p.addLine(to: P(92, 6))
                p.addLine(to: P(118, 26))
                p.closeSubpath()
            }
            teil(g, hut, Pal.blau)
            var h = g
            h.clip(to: hut)
            for i in 0..<3 {
                let x = 66 + CGFloat(i) * 14
                linie(h, strich(P(x, 40), P(x + 26, 4)), Pal.gelb.farbe, 4)
            }
            teil(g, kreis(P(92, 6), 6), Pal.rose, 2.5)
        }
        if abz.contains("krone") { krone(g, P(100, 18), Pal.gold) }
        if abz.contains("schnecke") {
            krone(g, P(90, 20), Pal.silber)
            teil(g, box(118, 28, 30, 7, 3.5), Pal.schneckeKoerper, 2)
            linie(g, strich(P(144, 29), P(148, 19)), Pal.schneckeKoerper.kontur, 2)
            teil(g, kreis(P(130, 24), 9), Pal.schnecke, 2.5)
            linie(g, bogen(P(130, 24), P(134, 20), P(136, 26)), Pal.schnecke.kontur, 2)
        }
    }

    func krone(_ g: GraphicsContext, _ c: CGPoint, _ f: FigurFarbe) {
        var h = g
        h.translateBy(x: c.x, y: c.y)
        h.rotate(by: .degrees(-8))
        let k = Path { p in
            p.move(to: P(-20, 10))
            p.addLine(to: P(-20, -8))
            p.addLine(to: P(-10, 0))
            p.addLine(to: P(0, -14))
            p.addLine(to: P(10, 0))
            p.addLine(to: P(20, -8))
            p.addLine(to: P(20, 10))
            p.closeSubpath()
        }
        teil(h, k, f, 2.5)
        h.fill(kreis(P(0, 4), 3), with: .color(Pal.rose.farbe))
    }

    func brillen(_ g: GraphicsContext) {
        guard brille > 0 else { return }
        let sonne = Self.sonnenbrillen.contains(brille)
        let rahmen: Color
        switch brille {
        case 7, 12: rahmen = Pal.tinte.farbe.opacity(0.5)
        case 8, 11: rahmen = Pal.gold.mal(0.8).farbe
        case 9: rahmen = Pal.rose.kontur
        default: rahmen = Pal.tinte.farbe
        }
        let links: Path
        switch brille {
        case 1:
            links = kreis(P(80, 98), 14)
        case 4:
            links = oval(P(80, 98), 16, 11)
        case 5:
            links = Path { p in
                p.move(to: P(60, 84))
                p.addQuadCurve(to: P(96, 90), control: P(80, 84))
                p.addQuadCurve(to: P(82, 110), control: P(98, 108))
                p.addQuadCurve(to: P(60, 84), control: P(64, 106))
                p.closeSubpath()
            }
        case 6:
            links = box(62, 84, 36, 28, 5)
        case 7:
            links = box(66, 88, 30, 22, 8)
        case 8:
            links = Path { p in
                p.move(to: P(64, 88))
                p.addLine(to: P(96, 88))
                p.addQuadCurve(to: P(82, 112), control: P(98, 110))
                p.addQuadCurve(to: P(64, 88), control: P(62, 108))
                p.closeSubpath()
            }
        case 9:
            links = herzPfad(P(80, 97), 15)
        case 10:
            links = Path { p in
                p.move(to: P(56, 88))
                p.addQuadCurve(to: P(144, 88), control: P(100, 80))
                p.addLine(to: P(140, 106))
                p.addQuadCurve(to: P(60, 106), control: P(100, 116))
                p.closeSubpath()
            }
        case 11:
            links = oval(P(80, 97), 20, 15)
        case 12:
            links = kreis(P(80, 98), 11)
        default:
            links = box(64, 86, 32, 25, 7)
        }
        let glaeser = brille == 10 ? [links] : [links, gespiegelt(links)]
        let glas: Color
        switch brille {
        case 9: glas = Pal.rose.farbe.opacity(0.85)
        case 10: glas = Pal.himmel.mal(0.7).farbe.opacity(0.9)
        default: glas = sonne ? Pal.tinte.farbe.opacity(0.9) : .white.opacity(0.15)
        }
        let dicke: CGFloat = brille == 6 ? 5 : (brille == 7 || brille == 12) ? 1.4 : 3
        for l in glaeser { g.fill(l, with: .color(glas)) }
        if sonne {
            linie(g, strich(P(70, 92), P(78, 90)), .white.opacity(0.6), 2.5)
            if brille != 10 { linie(g, strich(P(110, 92), P(118, 90)), .white.opacity(0.6), 2.5) }
        }
        for l in glaeser { linie(g, l, rahmen, dicke) }
        if brille != 10 { linie(g, bogen(P(94, 96), P(106, 96), P(100, 91)), rahmen, dicke) }
        linie(g, strich(P(62, 95), P(44, 92)), rahmen, dicke)
        linie(g, strich(P(138, 95), P(156, 92)), rahmen, dicke)
    }

    /// AirPods Pro, small and subtle: a glossy white bud tucked into the ear opening, a short thin
    /// stem pointing down and slightly toward the face (about 35 % of the ear height), soft gray
    /// shading on one side, a tiny highlight, only a very light #D8D8D8 rim. Head space, so it
    /// scales with the head.
    func airpodsZeichnen(_ g: GraphicsContext) {
        let rand = FigurFarbe(0xD8D8D8).farbe
        for (ohr, seite) in [(CGFloat(42), CGFloat(-1)), (158, 1)] {
            let x: CGFloat = ohr + seite * 4
            let stiel = strich(P(x, 103.5), P(x - seite * 1.5, 111))
            linie(g, stiel, rand, 3.4)
            linie(g, stiel, .white, 2.4)
            let knopf = oval(P(x, 101), 3.2, 2.8)
            g.fill(knopf, with: .color(.white))
            linie(g, knopf, rand, 0.8)
            g.fill(oval(P(x + seite * 1.1, 102), 1.8, 1.4), with: .color(FigurFarbe(0xE6E6E8).farbe))
            g.fill(kreis(P(x - seite * 1.1, 100.2), 0.7), with: .color(.white))
        }
    }

    func ohrringeZeichnen(_ g: GraphicsContext) {
        // A shop earring (Z-39.2) replaces the free pair.
        if let id = juwelen.first(where: { schmuckKatalog[$0]?.stil.ort == .ohr }) {
            zeichneOhrschmuck(g, id: id)
            return
        }
        guard ohrring > 0 else { return }
        for x in [CGFloat(42), 158] {
            switch ohrring {
            case 1:
                teil(g, kreis(P(x, 110), 3), Pal.gold, 1.5)
            case 2:
                linie(g, kreis(P(x, 119), 8), Pal.gold.kontur, 4.5)
                linie(g, kreis(P(x, 119), 8), Pal.gold.farbe, 2.5)
            case 3:
                linie(g, strich(P(x, 110), P(x, 121)), Pal.gold.farbe, 2)
                teil(g, oval(P(x, 126), 3.5, 5), Pal.gold, 1.5)
            case 5:
                // Diamant-Stecker
                teil(g, kreis(P(x, 111), 3.4), FigurFarbe(0xE6F3FF), 1.2)
                g.fill(funkel(P(x, 111), 2.6), with: .color(.white))
            case 6:
                // Große Kreolen
                linie(g, kreis(P(x, 124), 13), Pal.gold.kontur, 4.5)
                linie(g, kreis(P(x, 124), 13), Pal.gold.farbe, 2.6)
            case 7:
                // Herz-Hänger
                linie(g, strich(P(x, 110), P(x, 118)), Pal.gold.farbe, 1.6)
                teil(g, herzPfad(P(x, 122), 4.2), Pal.rose, 1.2)
            case 8:
                // 25.09.: white flower like on Annika's photo, hanging at the lobe.
                let mitte = P(x, 121)
                for i in 0..<5 {
                    let w = Double(i) / 5 * 2 * Double.pi - Double.pi / 2
                    teil(g, kreis(P(mitte.x + CGFloat(cos(w)) * 3.4, mitte.y + CGFloat(sin(w)) * 3.4), 2.7), FigurFarbe(0xFBF7EE), 1)
                }
                g.fill(kreis(mitte, 1.6), with: .color(Pal.gelb.farbe))
            default:
                teil(g, kreis(P(x, 112), 4.2), FigurFarbe(0xF4EEE6), 1.5)
                g.fill(kreis(P(x - 1.3, 110.7), 1.3), with: .color(.white))
            }
        }
    }

    func muetzeZeichnen(_ g: GraphicsContext) {
        let f = muetzeF
        switch muetze {
        case 1, 2:
            let krone = Path { p in
                p.move(to: P(40, 66))
                p.addCurve(to: P(100, 6), control1: P(36, 22), control2: P(64, 6))
                p.addCurve(to: P(160, 66), control1: P(136, 6), control2: P(164, 22))
                p.addQuadCurve(to: P(40, 66), control: P(100, 54))
                p.closeSubpath()
            }
            teil(g, krone, f)
            var h = g
            h.clip(to: krone)
            for x in [CGFloat(72), 128] { linie(h, bogen(P(x, 62), P(100, 6), P(x, 20)), f.kontur, 1.5) }
            teil(g, kreis(P(100, 8), 4.5), f.mal(0.85), 2)
            if muetze == 1 {
                teil(g, oval(P(100, 64), 58, 10), f.mal(0.85))
                g.fill(herzPfad(P(100, 38), 8), with: .color(f.mix(Pal.weiss, 0.7).farbe))
            } else {
                teil(g, box(84, 46, 32, 14, 6), haar, 2)
                linie(g, strich(P(86, 53), P(114, 53)), f.mal(0.7).farbe, 3)
            }
        case 3:
            let form = Path { p in
                p.move(to: P(38, 70))
                p.addCurve(to: P(100, 2), control1: P(34, 20), control2: P(64, 2))
                p.addCurve(to: P(162, 70), control1: P(136, 2), control2: P(166, 20))
                p.closeSubpath()
            }
            teil(g, form, f)
            let bund = box(34, 50, 132, 22, 10)
            teil(g, bund, f.mal(0.85))
            var h = g
            h.clip(to: bund)
            for x in stride(from: CGFloat(42), to: 164, by: 9) { linie(h, strich(P(x, 50), P(x, 72)), f.kontur, 1.5) }
            if extras.contains(.muetzeSchal) {
                // Winter extra: pompom on top.
                teil(g, kreis(P(100, 8), 9), Pal.weiss, 2.5)
                for dx in [CGFloat(-4), 0, 4] { linie(g, strich(P(100 + dx, 3), P(100 + dx * 1.3, 13)), Pal.weiss.kontur.opacity(0.5), 1.2) }
            }
        case 7:
            // Carhartt Beanie: short watch cap high on the head, deep cuff with the square label.
            let form = Path { p in
                p.move(to: P(42, 62))
                p.addCurve(to: P(100, 8), control1: P(40, 26), control2: P(66, 8))
                p.addCurve(to: P(158, 62), control1: P(134, 8), control2: P(160, 26))
                p.closeSubpath()
            }
            teil(g, form, f)
            var r = g
            r.clip(to: form)
            for x in stride(from: CGFloat(50), to: 156, by: 8) { linie(r, strich(P(x, 8), P(x, 44)), f.kontur.opacity(0.35), 1.4) }
            let bund = box(38, 40, 124, 26, 11)
            teil(g, bund, f.mal(0.9))
            var h = g
            h.clip(to: bund)
            for x in stride(from: CGFloat(44), to: 160, by: 7) { linie(h, strich(P(x, 40), P(x, 66)), f.kontur.opacity(0.7), 1.3) }
            teil(g, box(90, 45, 20, 16, 2.5), FigurFarbe(0xE3A33A), 1.6)
            linie(g, Path { p in p.addArc(center: P(100, 53), radius: 4, startAngle: .degrees(40), endAngle: .degrees(320), clockwise: false) }, Pal.tinte.farbe, 2)
        case 8:
            // Trucker Cap (fix round 4): tall front panel, mesh sides, curved brim, blackletter logo in tone.
            let krone = Path { p in
                p.move(to: P(40, 68))
                p.addCurve(to: P(100, 2), control1: P(34, 20), control2: P(62, 2))
                p.addCurve(to: P(160, 68), control1: P(138, 2), control2: P(166, 20))
                p.addQuadCurve(to: P(40, 68), control: P(100, 56))
                p.closeSubpath()
            }
            teil(g, krone, f)
            var netz = g
            netz.clip(to: krone)
            for x in stride(from: CGFloat(34), to: 62, by: 5) { linie(netz, strich(P(x, 20), P(x, 70)), f.kontur.opacity(0.45), 1) }
            for x in stride(from: CGFloat(140), to: 168, by: 5) { linie(netz, strich(P(x, 20), P(x, 70)), f.kontur.opacity(0.45), 1) }
            teil(g, kreis(P(100, 4), 4), f.mal(0.85), 2)
            // Fix round 5: a real curved front brim, lit on top, shaded along its front edge;
            // the fringe peeks out underneath.
            let schirm = Path { p in
                p.move(to: P(42, 64))
                p.addQuadCurve(to: P(158, 64), control: P(100, 50))
                p.addQuadCurve(to: P(42, 64), control: P(100, 96))
                p.closeSubpath()
            }
            teil(g, schirm, f.mal(0.82))
            linie(g, bogen(P(54, 69), P(146, 69), P(100, 88)), f.mal(0.55).farbe, 3)
            linie(g, bogen(P(62, 61), P(138, 61), P(100, 53)), Color.white.opacity(0.14), 3)
            g.draw(Text("\u{1D504}").font(.system(size: 26, weight: .bold)).foregroundStyle(f.mix(Pal.weiss, 0.16).farbe), at: P(100, 34))
        case 4:
            let krone = Path { p in
                p.move(to: P(50, 58))
                p.addCurve(to: P(100, 6), control1: P(48, 18), control2: P(70, 6))
                p.addCurve(to: P(150, 58), control1: P(130, 6), control2: P(152, 18))
                p.closeSubpath()
            }
            let krempe = Path { p in
                p.move(to: P(40, 52))
                p.addLine(to: P(160, 52))
                p.addLine(to: P(178, 76))
                p.addQuadCurve(to: P(22, 76), control: P(100, 88))
                p.closeSubpath()
            }
            teil(g, krone, f)
            teil(g, krempe, f.mal(0.9))
            linie(g, strich(P(50, 53), P(150, 53)), f.mal(0.7).farbe, 4)
        case 5:
            let band = bogen(P(42, 72), P(158, 72), P(100, 42))
            linie(g, band, f.kontur, 14)
            linie(g, band, f.farbe, 10)
        case 6:
            let reif = bogen(P(44, 84), P(156, 84), P(100, -6))
            linie(g, reif, f.kontur, 7)
            linie(g, reif, f.farbe, 4)
        default:
            break
        }
    }

    // MARK: Poses

    /// Every `z` with its own scripted arm animation: device/mood states, plus live Gesten (kiss lean
    /// in `ProfileView`, high-five/laugh/toast/trophy). The sleepy extra never shows over these.
    static let keinePoseUeberschreibung: Set<FigurZustand> = Set<FigurZustand>([.schlaeft, .offline, .akkuLeer, .schlecht, .kuss, .herz, .lacht, .anstossen, .pokal]).union(FigurZustand.mimik)
}
