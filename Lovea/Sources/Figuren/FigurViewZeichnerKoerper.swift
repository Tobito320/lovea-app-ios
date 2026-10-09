import SwiftUI

extension Zeichner {

    func rumpf(_ ausschnitt: Int) -> Path {
        if neu == .b { return vRumpf(ausschnitt) }
        return Path { p in
            p.move(to: P(30, 240))
            p.addLine(to: P(33, 200))
            p.addCurve(to: P(72, 164), control1: P(35, 178), control2: P(50, 166))
            halsAusschnitt(&p, ausschnitt)
            p.addLine(to: P(128, 164))
            p.addCurve(to: P(167, 200), control1: P(150, 166), control2: P(165, 178))
            p.addLine(to: P(170, 240))
            p.closeSubpath()
        }
    }

    /// Neckline from (72|164) to (114|161) or (120|162): round, V or wide.
    func halsAusschnitt(_ p: inout Path, _ ausschnitt: Int) {
        switch ausschnitt {
        case 1:
            p.addLine(to: P(86, 161))
            p.addLine(to: P(100, 186))
            p.addLine(to: P(114, 161))
        case 2:
            p.addLine(to: P(80, 162))
            p.addQuadCurve(to: P(120, 162), control: P(100, 192))
        default:
            p.addLine(to: P(86, 161))
            p.addQuadCurve(to: P(114, 161), control: P(100, 178))
        }
    }

    /// Brief F3: V-taper torso without sleeves: waist, armpit, round shoulder, neckline, mirrored.
    /// The shoulder caps come from `armV`.
    func vRumpf(_ ausschnitt: Int) -> Path {
        let v = vForm
        let a = v.achselL
        // p71: `delt` grows the shoulder cap out and up (1 = the old cap).
        let e = (v.delt - 1) * 10
        return Path { p in
            // 25.09. (schulter.py S4): the torso carries the whole round shoulder, the sleeve only
            // hangs below it, so there is no notch and no second shoulder.
            p.move(to: P(v.taille, 240))
            p.addLine(to: a)
            p.addCurve(to: P(v.sch - 16 - e, 180), control1: P(a.x - 2, a.y - 14), control2: P(v.sch - 17 - e, 190))
            p.addCurve(to: P(v.sch + 10, 162), control1: P(v.sch - 15 - e, 170 - e), control2: P(v.sch - 5, 163 - e / 2))
            p.addQuadCurve(to: P(72, 164), control: P(66, 161))
            halsAusschnitt(&p, ausschnitt)
            p.addLine(to: P(128, 164))
            p.addQuadCurve(to: P(200 - v.sch - 10, 162), control: P(134, 161))
            p.addCurve(to: P(200 - v.sch + 16 + e, 180), control1: P(200 - v.sch + 5, 163 - e / 2), control2: P(200 - v.sch + 15 + e, 170 - e))
            p.addCurve(to: P(200 - a.x, a.y), control1: P(200 - v.sch + 17 + e, 190), control2: P(200 - a.x + 2, a.y - 14))
            p.addLine(to: P(200 - v.taille, 240))
            p.closeSubpath()
        }
    }

    var ausschnitt: Int {
        switch oberteil {
        case 2, 12, 13, 20, 25, 38: 1
        case 4, 8, 11, 18: 2
        default: 0
        }
    }

    func koerper(_ g: GraphicsContext) {
        if let neu {
            neuerHals(g, neu)
            g.fill(neu == .b ? box(88, 156, 24, 36) : box(91, 156, 18, 36), with: .color(haut.farbe))
        } else {
            teil(g, box(86, 132, 28, 58, 10), haut)
            g.fill(box(78, 156, 44, 36), with: .color(haut.farbe))
            g.fill(oval(P(100, 152), 15, 6), with: .color(haut.mal(0.8).farbe.opacity(0.6)))
        }
        var k = g
        k.translateBy(x: 100, y: 0)
        k.scaleBy(x: breite, y: 1)
        k.translateBy(x: -100, y: 0)
        if neu != nil { armeHinten(g) }

        if oberkoerperFrei {
            let form = rumpf(0)
            basis(g, k, form, haut)
            k.fill(box(80, 150, 40, 28), with: .color(haut.farbe))
            var h = k
            h.clip(to: form)
            koerperDetails(h, nackt: true)
        } else if oberteil == 6 {
            let form = rumpf(0)
            basis(g, k, form, haut)
            k.fill(box(80, 150, 40, 28), with: .color(haut.farbe))
            let kleid = Path { p in
                p.move(to: P(20, 250))
                p.addLine(to: P(24, 190))
                p.addQuadCurve(to: P(176, 190), control: P(100, 204))
                p.addLine(to: P(180, 250))
                p.closeSubpath()
            }
            var h = k
            h.clip(to: form)
            teil(h, kleid, top)
            linie(k, form, haut.kontur, 3.5)
            for seite in [CGFloat(-1), 1] {
                let traeger = strich(P(100 + seite * 26, 164), P(100 + seite * 30, 194))
                linie(k, traeger, top.kontur, 6.5)
                linie(k, traeger, top.farbe, 3.5)
            }
        } else {
            let form = rumpf(ausschnitt)
            basis(g, k, form, oberteilBasis)
            var h = k
            h.clip(to: form)
            if oberteil == 11 {
                teil(h, box(0, 226, 200, 40), haut, 2.5)
                h.fill(oval(P(100, 234), 1.6, 2.4), with: .color(haut.kontur))
            }
            oberteilDetails(k, h)
            koerperDetails(h, nackt: false)
            if Self.konturNachMuster.contains(oberteil) {
                if neu != nil { linie(g, hemd(form), top.kontur, 3.5) } else { linie(k, form, top.kontur, 3.5) }
            }
        }
        if jacke > 0 { jackeZeichnen(k, form: rumpf(0), oben: 161, unten: 240, s: 1) }
        if neu != nil { armeVorn(g, torsoK: rumpf(ausschnitt)) }
    }

    /// Z-38.2 body cues in the half-figure torso space (`h` is clipped to the torso; the full body
    /// maps this space onto its torso): chest lines on muscular bodies, a bust line on curvy ones,
    /// and on the bare gym torso collarbones, chest and a light six-pack.
    func koerperDetails(_ h: GraphicsContext, nackt: Bool) {
        let k = km
        let farbe: Color = nackt ? haut.kontur.opacity(0.45) : top.kontur.opacity(0.18 + 0.2 * k.muskel)
        if nackt || k.muskel >= 0.5 {
            for seite in [CGFloat(-1), 1] {
                linie(h, bogen(P(100 + seite * 36, 198), P(100 + seite * 3, 206), P(100 + seite * 20, 218)), farbe, 2.4)
            }
        } else if k.kurve > 0 {
            for seite in [CGFloat(-1), 1] {
                linie(h, bogen(P(100 + seite * 32, 202), P(100 + seite * 5, 206), P(100 + seite * 19, 216)), top.kontur.opacity(0.28), 2)
                h.fill(oval(P(100 + seite * 19, 196), 7, 3.5), with: .color(.white.opacity(0.14)))
            }
        }
        if koerperform == 2 {
            // Kräftig: the round belly shows as a soft fold.
            linie(h, bogen(P(62, 254), P(138, 254), P(100, 274)), (nackt ? haut.kontur : top.kontur).opacity(0.32), 2.2)
        }
        guard nackt else {
            // p71: a chosen belly also shows faintly under a fitted top (nil and smooth draw nothing).
            if !bauchZeilen.isEmpty { bauchLinien(h, top.kontur.opacity(0.16)) }
            return
        }
        for seite in [CGFloat(-1), 1] {
            linie(h, bogen(P(100 + seite * 8, 172), P(100 + seite * 30, 170), P(100 + seite * 18, 176)), farbe, 2)
        }
        if bauch != 0 { bauchLinien(h, farbe) }
        h.fill(oval(P(100, 284), 2, 3), with: .color(haut.kontur.opacity(0.6)))
    }

    /// p71: the rows of the abs for the chosen belly: 4 = two rows, 6 = three (the old look), 8 = four.
    /// Smooth (0) has none; `nil` on the bare torso keeps the old three, under a top none.
    var bauchZeilen: [CGFloat] {
        switch bauch {
        case 0: []
        case 4: [240, 258]
        case 6: [234, 252, 268]
        case 8: [228, 242, 256, 270]
        default: []
        }
    }

    /// The abs lines in the half-figure torso space: outer edges, the middle line and one arc per row.
    func bauchLinien(_ h: GraphicsContext, _ farbe: Color) {
        let zeilen = bauch == nil ? [234, 252, 268] : bauchZeilen
        for seite in [CGFloat(-1), 1] {
            linie(h, bogen(P(100 + seite * 22, 222), P(100 + seite * 16, 286), P(100 + seite * 25, 256)), farbe, 2)
        }
        linie(h, strich(P(100, 214), P(100, 280)), farbe, 2)
        for y in zeilen {
            linie(h, bogen(P(84, y), P(116, y), P(100, y + 4)), farbe, 1.8)
        }
    }

    func hemdKragen(_ g: GraphicsContext) {
        let kragen = top.mix(Pal.weiss, 0.4)
        let links = Path { p in
            p.move(to: P(86, 160))
            p.addLine(to: P(100, 186))
            p.addLine(to: P(78, 178))
            p.closeSubpath()
        }
        teil(g, links, kragen, 2.5)
        teil(g, gespiegelt(links), kragen, 2.5)
        for y in [CGFloat(198), 214, 230, 246, 262] { g.fill(kreis(P(100, y), 2.2), with: .color(top.kontur)) }
    }

    /// Top details in the half-figure space. `g` draws freely, `h` is clipped to the torso.
    /// Patterns run past y 240 so the full body (which maps this space onto its torso) is covered too.
    func oberteilDetails(_ g: GraphicsContext, _ h: GraphicsContext) {
        switch oberteil {
        case 1:
            let kapuze = bogen(P(70, 164), P(130, 164), P(100, 196))
            linie(g, kapuze, top.kontur, 13)
            linie(g, kapuze, top.mal(0.88).farbe, 8.5)
            linie(g, strich(P(93, 180), P(91, 202)), .white.opacity(0.9), 2.5)
            linie(g, strich(P(107, 180), P(109, 202)), .white.opacity(0.9), 2.5)
            teil(h, box(68, 216, 64, 40, 14), top.mal(0.92), 2.5)
        case 2:
            if z == .abend {
                for x in stride(from: CGFloat(36), to: 170, by: 18) {
                    for y in stride(from: CGFloat(180), to: 290, by: 18) {
                        h.fill(kreis(P(x, y), 3), with: .color(.white.opacity(0.7)))
                    }
                }
            }
            hemdKragen(g)
        case 3:
            let bund = bogen(P(86, 161), P(114, 161), P(100, 178))
            linie(g, bund, top.kontur, 8)
            linie(g, bund, top.mal(0.85).farbe, 5)
            g.fill(herzPfad(P(100, 208), 9), with: .color(top.mix(Pal.weiss, 0.45).farbe))
        case 4:
            let schleife = Path { p in
                p.move(to: P(100, 178))
                p.addLine(to: P(91, 173))
                p.addLine(to: P(91, 183))
                p.closeSubpath()
            }
            teil(g, schleife, top.mal(0.8), 2)
            teil(g, gespiegelt(schleife), top.mal(0.8), 2)
        case 5:
            h.fill(box(88, 150, 24, 160), with: .color(Pal.weiss.farbe))
            linie(h, strich(P(88, 166), P(88, 300)), top.kontur, 3)
            linie(h, strich(P(112, 166), P(112, 300)), top.kontur, 3)
            let revers = Path { p in
                p.move(to: P(86, 161))
                p.addLine(to: P(96, 200))
                p.addLine(to: P(76, 180))
                p.closeSubpath()
            }
            teil(g, revers, top.mal(0.9), 2.5)
            teil(g, gespiegelt(revers), top.mal(0.9), 2.5)
        case 7:
            for y in stride(from: CGFloat(178), to: 300, by: 14) {
                h.fill(box(20, y, 160, 6), with: .color(.white.opacity(0.75)))
            }
        case 8:
            let guertel = strich(P(20, 232), P(180, 232))
            linie(h, guertel, top.kontur, 8)
            linie(h, guertel, top.mal(0.8).farbe, 5)
            teil(g, kreis(P(100, 232), 5), top.mal(0.75), 2)
            g.fill(herzPfad(P(100, 186), 5), with: .color(top.mix(Pal.weiss, 0.5).farbe))
        case 9:
            let kragen = top.mix(Pal.weiss, 0.2)
            let links = Path { p in
                p.move(to: P(86, 160))
                p.addLine(to: P(99, 174))
                p.addLine(to: P(80, 176))
                p.closeSubpath()
            }
            teil(g, links, kragen, 2.5)
            teil(g, gespiegelt(links), kragen, 2.5)
            linie(g, strich(P(100, 170), P(100, 196)), top.kontur, 2)
            for y in [CGFloat(182), 192] { g.fill(kreis(P(100, y), 2), with: .color(top.kontur)) }
        case 10:
            let kragen = box(82, 138, 36, 30, 12)
            teil(g, kragen, top.mal(0.92))
            var r = g
            r.clip(to: kragen)
            for x in stride(from: CGFloat(86), to: 118, by: 6) { linie(r, strich(P(x, 138), P(x, 168)), top.kontur.opacity(0.5), 1.5) }
        case 12:
            h.fill(box(30, 160, 12, 160), with: .color(.white.opacity(0.85)))
            h.fill(box(158, 160, 12, 160), with: .color(.white.opacity(0.85)))
            let v = Path { p in
                p.move(to: P(86, 161))
                p.addLine(to: P(100, 186))
                p.addLine(to: P(114, 161))
            }
            linie(g, v, .white, 3.5)
            text(g, "10", P(100, 216), 26, .white)
        case 13:
            let streifen = top.mal(0.62).farbe.opacity(0.45)
            for x in stride(from: CGFloat(28), to: 180, by: 16) { h.fill(box(x, 150, 6, 170), with: .color(streifen)) }
            for y in stride(from: CGFloat(172), to: 320, by: 16) { h.fill(box(20, y, 160, 6), with: .color(streifen)) }
            hemdKragen(g)
        case 14:
            // Logo-Hoodie (Nike, Guess): p48 drawing in Zubehoer/ModeZeichner.swift.
            zeichneHoodie(g, h, top: top)
        case 15:
            // Statement-Shirt: bold diagonal brand stripe across the chest.
            var streifenH = h
            streifenH.rotate(by: .degrees(-18))
            streifenH.fill(box(50, 180, 100, 16, 4), with: .color(top.mix(Pal.weiss, 0.7).farbe))
        case 16:
            // Seidenbluse and Dior-Bluse: p48 drawing in Zubehoer/ModeZeichner.swift.
            zeichneBluse(g, h, top: top)
        case 36:
            // p56: Camisole, Off-Shoulder-Top und Wickelkleid: Zubehoer/ModeElegant.swift.
            zeichneCamisole(g, h, top: top, haut: haut)
        case 37:
            zeichneOffShoulder(g, h, top: top, haut: haut)
        case 38:
            zeichneWickelkleid(g, h, top: top, haut: haut)
        case 17...26, 31, 34, 35:
            markenOberteil(g, h)
        default:
            break
        }
        // p65 D: brand tops on a base shape (39...43) add their logo on top of it.
        if marke != 0 { zeichneMarkenOberteil(g, h, marke: marke, top: top) }
    }

    /// Tops whose pattern runs over the torso edge, so the outline is drawn again on top.
    static let konturNachMuster: Set<Int> = [7, 12, 13, 18, 24, 25]

    /// Z-39.1/Z-39.2 brand tops, same spaces as `oberteilDetails` (`h` clipped to the torso).
    func markenOberteil(_ g: GraphicsContext, _ h: GraphicsContext) {
        let hell = top.mix(Pal.weiss, 0.75)
        switch oberteil {
        case 17:
            // H&M: plain tee, red logo on the chest.
            text(g, "H&M", P(126, 204), 11, FigurFarbe(0xE50010).farbe)
        case 18:
            // Zara: fitted rib knit with a square neck.
            for x in stride(from: CGFloat(34), to: 170, by: 7) { linie(h, strich(P(x, 150), P(x, 320)), top.kontur.opacity(0.22), 1.4) }
        case 19, 26:
            let kapuze = bogen(P(70, 164), P(130, 164), P(100, 196))
            linie(g, kapuze, top.kontur, 13)
            linie(g, kapuze, top.mal(0.88).farbe, 8.5)
            if oberteil == 19 {
                // Nike Tech Fleece: center zip, chest zip pocket, curved panel seams, swoosh.
                linie(h, strich(P(100, 190), P(100, 320)), Pal.silber.farbe, 2.5)
                linie(h, strich(P(62, 212), P(84, 200)), top.kontur, 2)
                teil(g, box(84, 197, 3, 6, 1), Pal.silber, 0.8)
                for seite in [CGFloat(-1), 1] { linie(h, bogen(P(100 + seite * 66, 190), P(100 + seite * 40, 300), P(100 + seite * 34, 240)), top.kontur.opacity(0.5), 1.6) }
                swoosh(g, P(128, 206), 0.9, hell.farbe)
            } else {
                // Balenciaga: oversized hoodie with the wordmark across the chest.
                text(g, "BALENCIAGA", P(100, 222), 9, hell.farbe)
            }
        case 20:
            // Nike jersey: trim-colored V collar, swoosh right, crest left (Brazil green on yellow).
            let v = Path { p in
                p.move(to: P(86, 161))
                p.addLine(to: P(100, 186))
                p.addLine(to: P(114, 161))
            }
            linie(g, v, trikotBesatz.kontur, 6)
            linie(g, v, trikotBesatz.farbe, 4)
            swoosh(g, P(74, 204), 0.8, trikotBesatz.farbe)
            let wappen = Path { p in
                p.move(to: P(118, 196))
                p.addLine(to: P(134, 196))
                p.addLine(to: P(134, 206))
                p.addQuadCurve(to: P(126, 214), control: P(134, 212))
                p.addQuadCurve(to: P(118, 206), control: P(118, 212))
                p.closeSubpath()
            }
            teil(g, wappen, FigurFarbe(0x2C5DB0), 1.5)
            g.fill(kreis(P(126, 204), 2.6), with: .color(Pal.gelb.farbe))
        case 21:
            // Puma: leaping cat over the wordmark.
            let katze = Path { p in
                p.move(to: P(84, 212))
                p.addQuadCurve(to: P(108, 200), control: P(94, 198))
                p.addLine(to: P(114, 194))
                p.addLine(to: P(116, 200))
                p.addQuadCurve(to: P(104, 210), control: P(112, 206))
                p.addQuadCurve(to: P(88, 216), control: P(96, 214))
                p.closeSubpath()
            }
            g.fill(katze, with: .color(hell.farbe))
            linie(g, bogen(P(84, 212), P(76, 222), P(78, 214)), hell.farbe, 2)
            text(g, "PUMA", P(100, 228), 10, hell.farbe)
        case 22:
            // Stüssy: the hand-written script logo.
            g.draw(Text("Stüssy").font(.custom("SnellRoundhand-Black", size: 17)).foregroundStyle(hell.farbe), at: P(100, 210))
        case 23:
            // Gucci: green-red-green web band across the chest.
            h.fill(box(20, 200, 160, 10), with: .color(FigurFarbe(0x1F7A45).farbe))
            h.fill(box(20, 203, 160, 4), with: .color(FigurFarbe(0xC8283F).farbe))
            text(g, "GUCCI", P(100, 190), 8, top.kontur)
        case 24:
            // Dior Oblique: diagonal jacquard lines and the wordmark.
            for x in stride(from: CGFloat(-40), to: 200, by: 12) {
                linie(h, strich(P(x, 330), P(x + 170, 150)), hell.farbe.opacity(0.35), 2)
            }
            text(g, "DIOR", P(100, 212), 11, hell.farbe)
        case 25:
            // Louis Vuitton: monogram flowers in gold on brown, shirt collar and buttons.
            let gold = FigurFarbe(0xD8B46A).farbe
            for y in stride(from: CGFloat(178), to: 320, by: 16) {
                let versatz: CGFloat = Int((y - 178) / 16) % 2 == 0 ? 0 : 9
                for x in stride(from: CGFloat(30) + versatz, to: 172, by: 18) { h.fill(funkel(P(x, y), 4), with: .color(gold)) }
            }
            hemdKragen(g)
        case 31:
            // Ahmed's pink knit: rib collar, a big white abstract graphic across the chest, rib hem.
            let bund = bogen(P(86, 161), P(114, 161), P(100, 176))
            linie(g, bund, top.kontur, 8)
            linie(g, bund, top.mal(0.9).farbe, 5)
            let weiss = Pal.weiss.farbe
            var grafik = Path()
            grafik.move(to: P(30, 206))
            grafik.addLine(to: P(62, 196))
            grafik.addLine(to: P(88, 182))
            grafik.addLine(to: P(104, 198))
            grafik.addLine(to: P(124, 184))
            grafik.addLine(to: P(170, 200))
            grafik.move(to: P(36, 226))
            grafik.addQuadCurve(to: P(110, 224), control: P(70, 244))
            grafik.addQuadCurve(to: P(168, 218), control: P(144, 206))
            grafik.move(to: P(40, 214))
            grafik.addQuadCurve(to: P(72, 206), control: P(50, 200))
            grafik.move(to: P(132, 230))
            grafik.addQuadCurve(to: P(160, 210), control: P(160, 232))
            linie(h, grafik, weiss, 3)
            h.fill(funkel(P(96, 212), 9), with: .color(weiss))
            for y in [CGFloat(292), 298] { linie(h, strich(P(20, y), P(180, y)), top.kontur.opacity(0.35), 1.4) }
        case 34, 35:
            // Gymshark (fix round 4): fitted, raglan seams, small shark logo on the chest.
            for seite in [CGFloat(-1), 1] {
                linie(h, bogen(P(100 + seite * 16, 164), P(100 + seite * 62, 198), P(100 + seite * 44, 170)), top.kontur.opacity(0.35), 1.6)
            }
            let hellesShirt = top.r + top.g + top.b > 1.5
            let hai = Path { p in
                p.move(to: P(118, 200))
                p.addQuadCurve(to: P(138, 195), control: P(130, 189))
                p.addQuadCurve(to: P(130, 203), control: P(136, 201))
                p.addQuadCurve(to: P(118, 200), control: P(124, 206))
                p.closeSubpath()
            }
            g.fill(hai, with: .color(hellesShirt ? Pal.dunkel.mal(0.8).farbe : Color.white))
        default:
            break
        }
    }

    /// Nike swoosh centered at `c`, `s` scales it.
    func swoosh(_ g: GraphicsContext, _ c: CGPoint, _ s: CGFloat, _ farbe: Color) {
        let p = Path { p in
            p.move(to: P(c.x - 9 * s, c.y - 1 * s))
            p.addQuadCurve(to: P(c.x + 11 * s, c.y - 6 * s), control: P(c.x - 6 * s, c.y + 8 * s))
            p.addQuadCurve(to: P(c.x - 9 * s, c.y - 1 * s), control: P(c.x - 5 * s, c.y + 4 * s))
            p.closeSubpath()
        }
        g.fill(p, with: .color(farbe))
    }

    /// Adidas trefoil: three leaves over three bars.
    func kleeblatt(_ g: GraphicsContext, _ c: CGPoint, _ s: CGFloat, _ farbe: Color) {
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

    /// Open jacket: two front panels cut from the torso `form`, the top shows in the middle.
    /// `s` scales details (1 in the half figure, smaller on the full-body torso).
    func jackeZeichnen(_ g: GraphicsContext, form: Path, oben: CGFloat, unten untenRoh: CGFloat, s: CGFloat) {
        let f = jackeF
        // p56: der Perlen-Cardigan (14) endet an der Taille und lässt das Oberteil frei, die anderen Jacken laufen bis zur Hüfte.
        let unten = jacke == 14 ? oben + (s >= 1 ? 66 : 53) : untenRoh
        let zugabe: CGFloat = jacke == 14 ? 0 : 30
        // Zipped jackets (Adidas, The North Face, Moncler) close in the middle.
        let zu = [6, 8, 9, 11].contains(jacke)
        let innenO: CGFloat = zu ? 100 : 100 - 12 * s
        let innenU: CGFloat = zu ? 100 : 100 - 20 * s
        let links = Path { p in
            p.move(to: P(-20, oben - 60))
            p.addLine(to: P(innenO, oben - 60))
            p.addLine(to: P(innenO, oben))
            p.addLine(to: P(innenU, unten + zugabe))
            p.addLine(to: P(-20, unten + zugabe))
            p.closeSubpath()
        }
        let rechts = gespiegelt(links)
        for seite in [links, rechts] {
            var h = g
            h.clip(to: seite)
            teil(h, form, f)
        }
        var innen = g
        innen.clip(to: form)
        linie(innen, links, f.kontur, 3)
        linie(innen, rechts, f.kontur, 3)

        switch jacke {
        case 1, 4:
            let revers = Path { p in
                p.move(to: P(innenO, oben))
                p.addLine(to: P(100 - 34 * s, oben + 8 * s))
                p.addLine(to: P(100 - 17 * s, oben + 46 * s))
                p.closeSubpath()
            }
            let rf = jacke == 4 ? f.mix(Pal.weiss, 0.12) : f.mal(0.8)
            teil(g, revers, rf, 2.5)
            teil(g, gespiegelt(revers), rf, 2.5)
            if jacke == 1 {
                linie(g, strich(P(innenO - 3 * s, oben + 48 * s), P(innenU - 3 * s, unten - 4)), Pal.silber.farbe, 2.2)
                for seite in [CGFloat(-1), 1] {
                    let x: CGFloat = 100 + seite * 44 * s
                    linie(innen, strich(P(x, oben + 30 * s), P(x, unten - 10)), .white.opacity(0.22), 4 * s)
                }
            } else {
                teil(g, kreis(P(innenU + 2 * s, unten - 30 * s), 3.5 * s), f.mal(0.7), 1.5)
            }
        case 2:
            // Jeansjacke: p48 drawing in Zubehoer/ModeZeichner.swift.
            zeichneJeansjacke(g, innen: innen, f: f, oben: oben, unten: unten, s: s, innenO: innenO, innenU: innenU)
        case 3:
            let bund = bogen(P(100 - 26 * s, oben + 1), P(100 + 26 * s, oben + 1), P(100, oben + 24 * s))
            linie(g, bund, f.kontur, 9 * s)
            linie(g, bund, f.mal(0.75).farbe, 6.5 * s)
            teil(innen, box(0, unten - 12 * s, 200, 40), f.mal(0.75), 2)
            linie(g, strich(P(innenO - 2 * s, oben + 20 * s), P(innenU - 2 * s, unten)), Pal.silber.farbe, 2)
        case 5:
            for seite in [links, rechts] {
                var h = innen
                h.clip(to: seite)
                for i in 0..<9 {
                    let y: CGFloat = oben + (18 + CGFloat(i) * 17) * s
                    linie(h, bogen(P(0, y), P(200, y), P(100, y + 6 * s)), f.kontur, 2)
                }
            }
        case 6:
            // Moncler Steppjacke: p48 drawing in Zubehoer/ModeZeichner.swift (closed, zipped in the middle).
            zeichneSteppjacke(g, innen: innen, f: f, oben: oben, unten: unten, s: s)
        case 7:
            // Cape: poncho bund (case 3) with a gem clasp instead of the zip strap.
            let bund = bogen(P(100 - 30 * s, oben + 1), P(100 + 30 * s, oben + 1), P(100, oben + 30 * s))
            linie(g, bund, f.kontur, 9 * s)
            linie(g, bund, f.mal(0.75).farbe, 6.5 * s)
            teil(innen, box(0, unten - 12 * s, 200, 40), f.mal(0.75), 2)
            teil(g, kreis(P(100, oben + 6 * s), 4 * s), Pal.gold, 1.5)
        case 14:
            // Perlen-Cardigan: p56 drawing in Zubehoer/ModeElegant.swift.
            zeichneCardigan(g, innen: innen, f: f, oben: oben, unten: unten, s: s, innenO: innenO, innenU: innenU)
        case 8...13:
            markenJacke(g, innen, oben: oben, unten: unten, s: s)
        default:
            break
        }
    }

    /// Z-39.1/Z-39.2 brand jackets. `innen` is clipped to the torso, `s` scales the details.
    func markenJacke(_ g: GraphicsContext, _ innen: GraphicsContext, oben: CGFloat, unten: CGFloat, s: CGFloat) {
        let f = jackeF
        let brustR = P(100 + 26 * s, oben + 38 * s)
        switch jacke {
        case 8:
            // Adidas track jacket (stripes on the sleeves come with the arms): stand collar, zip, trefoil.
            let kragen = bogen(P(100 - 24 * s, oben + 1), P(100 + 24 * s, oben + 1), P(100, oben + 12 * s))
            linie(g, kragen, f.kontur, 9 * s)
            linie(g, kragen, Pal.weiss.farbe, 6 * s)
            linie(innen, strich(P(100, oben), P(100, unten)), Pal.silber.farbe, 2.2 * s)
            kleeblatt(g, brustR, 1.1 * s, Pal.weiss.farbe)
        case 9, 11:
            // The North Face Nuptse (black shoulders, half-dome patch) and Moncler Maya (glossy, tricolore patch).
            if jacke == 9 { innen.fill(box(0, oben - 20, 200, 30 * s + 20), with: .color(Pal.dunkel.farbe)) }
            for i in 0..<8 {
                let y: CGFloat = oben + (26 + CGFloat(i) * 19) * s
                linie(innen, bogen(P(0, y), P(200, y), P(100, y + 7 * s)), f.kontur, 2.2)
                if jacke == 11 { linie(innen, bogen(P(20, y - 8 * s), P(180, y - 8 * s), P(100, y - 2 * s)), .white.opacity(0.28), 3 * s) }
            }
            linie(innen, strich(P(100, oben), P(100, unten)), Pal.silber.farbe, 2 * s)
            let kragen = bogen(P(100 - 22 * s, oben + 2), P(100 + 22 * s, oben + 2), P(100, oben + 10 * s))
            linie(g, kragen, f.kontur, 11 * s)
            linie(g, kragen, (jacke == 9 ? Pal.dunkel : f).farbe, 8 * s)
            if jacke == 9 {
                teil(g, box(brustR.x - 8 * s, brustR.y - 5 * s, 16 * s, 10 * s, 2 * s), Pal.dunkel, 1.2)
                for r in [CGFloat(2), 3.6, 5.2] {
                    linie(g, Path { p in p.addArc(center: P(brustR.x, brustR.y + 3 * s), radius: r * s, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false) }, .white, 0.9 * s)
                }
            } else {
                let patch = kreis(brustR, 6 * s)
                teil(g, patch, Pal.weiss, 1.2)
                var p = g
                p.clip(to: patch)
                p.fill(box(brustR.x - 6 * s, brustR.y - 6 * s, 4 * s, 12 * s), with: .color(FigurFarbe(0x2C4FA8).farbe))
                p.fill(box(brustR.x + 2 * s, brustR.y - 6 * s, 4 * s, 12 * s), with: .color(FigurFarbe(0xC8283F).farbe))
            }
        case 10:
            // Carhartt Detroit jacket: corduroy collar, chest pocket with the square label.
            let kragen = Path { p in
                p.move(to: P(100 - 12 * s, oben))
                p.addLine(to: P(100 - 34 * s, oben - 4 * s))
                p.addLine(to: P(100 - 26 * s, oben + 22 * s))
                p.closeSubpath()
            }
            let kord = FigurFarbe(0x4A3222)
            teil(g, kragen, kord, 2)
            teil(g, gespiegelt(kragen), kord, 2)
            let tasche = box(brustR.x - 10 * s, brustR.y - 8 * s, 20 * s, 18 * s, 2 * s)
            teil(innen, tasche, f.mal(0.93), 1.6)
            teil(g, box(brustR.x - 4 * s, brustR.y - 6 * s, 8 * s, 8 * s, 1.2 * s), FigurFarbe(0xE3A33A), 1)
            linie(g, strich(P(brustR.x - 1.5 * s, brustR.y - 2 * s), P(brustR.x + 1.5 * s, brustR.y - 2 * s)), Pal.tinte.farbe, 1.2 * s)
        case 12:
            // Chanel tweed: bouclé dots, braided trim along the front edges, gold buttons, CC.
            // ponytail: one path for all bouclé dots (a single fill per frame), fixed 9-unit grid.
            var boucle = Path()
            for y in stride(from: oben, to: unten + 20, by: 9) {
                let dx: CGFloat = Int((y - oben) / 9) % 2 == 0 ? 0 : 4.5
                for x in stride(from: CGFloat(24), to: 180, by: 9) {
                    boucle.addEllipse(in: CGRect(x: x + dx - 1.3, y: y - 1.3, width: 2.6, height: 2.6))
                }
            }
            innen.fill(boucle, with: .color(f.kontur.opacity(0.35)))
            let kante = strich(P(100 - 12 * s, oben), P(100 - 20 * s, unten))
            linie(g, kante, Pal.tinte.farbe, 4 * s)
            linie(g, kante, Pal.weiss.farbe, 2 * s)
            linie(g, gespiegelt(kante), Pal.tinte.farbe, 4 * s)
            linie(g, gespiegelt(kante), Pal.weiss.farbe, 2 * s)
            for i in 0..<3 { teil(g, kreis(P(100 - 26 * s, oben + (34 + CGFloat(i) * 22) * s), 3 * s), Pal.gold, 1) }
            chanelCC(g, brustR, 3.4 * s)
        case 13:
            // Prada Re-Nylon: glossy black nylon with the silver triangle plaque.
            for seite in [CGFloat(-1), 1] {
                linie(innen, strich(P(100 + seite * 44 * s, oben + 30 * s), P(100 + seite * 44 * s, unten - 10)), .white.opacity(0.18), 4 * s)
            }
            let dreieck = Path { p in
                p.move(to: P(brustR.x - 8 * s, brustR.y - 5 * s))
                p.addLine(to: P(brustR.x + 8 * s, brustR.y - 5 * s))
                p.addLine(to: P(brustR.x, brustR.y + 6 * s))
                p.closeSubpath()
            }
            teil(g, dreieck, Pal.silber, 1.2)
            linie(g, strich(P(100 - 12 * s, oben + 4), P(100 - 20 * s, unten - 4)), Pal.silber.farbe, 2 * s)
        default:
            break
        }
    }
}
