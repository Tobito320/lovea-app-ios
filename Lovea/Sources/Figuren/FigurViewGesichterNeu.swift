import SwiftUI

// MARK: - Brief F2: redesigned faces (Ahmed B, Annika 3). Shapes: GesichterNeuPfade.swift, colours: bau.py.

extension Zeichner {
    /// Ears and face skin. Annika's left ear is hidden under her hair, the right one is tucked out.
    func neuerKopf(_ g: GraphicsContext, _ neu: NeuesGesicht) {
        switch neu {
        case .b:
            for ohr in [GesichtB.ohrL, GesichtB.ohrR] { teil(g, ohr, haut) }
            for innen in [GesichtB.ohrInnenL, GesichtB.ohrInnenR] { linie(g, innen, haut.kontur.opacity(0.6), 1.6) }
            let weich = verlaufRund(P(96, 92), 72, [.init(color: haut.farbe, location: 0.55), .init(color: haut.mal(0.9).farbe, location: 1)])
            flaeche(g, GesichtB.gesicht, weich, rand: haut.kontur, breite: 3.5)
        case .an3:
            flaeche(g, GesichtAn3.ohr, .color(haut.farbe), rand: haut.kontur, breite: 3.2)
            linie(g, GesichtAn3.ohrInnen, haut.kontur.opacity(0.6), 1.4)
            let weich = verlaufRund(P(98, 92), 64, [.init(color: haut.farbe, location: 0.62), .init(color: haut.mal(0.93).farbe, location: 1)])
            flaeche(g, GesichtAn3.gesicht, weich, rand: haut.kontur, breite: 3.2)
        }
    }

    /// Neck with the soft chin shadow.
    func neuerHals(_ g: GraphicsContext, _ neu: NeuesGesicht) {
        let hals = neu == .b ? GesichtB.hals : GesichtAn3.hals
        flaeche(g, hals, .color(haut.farbe), rand: haut.kontur, breite: neu == .b ? 3.5 : 3.2)
        var h = g
        h.clip(to: hals)
        let schatten = haut.mal(0.78).farbe
        let (y0, y1, deckung): (CGFloat, CGFloat, Double) = neu == .b ? (140, 166, 0.9) : (132, 156, 0.8)
        h.fill(neu == .b ? GesichtB.halsSchatten : GesichtAn3.halsSchatten,
               with: verlaufY(y0, y1, [.init(color: schatten.opacity(deckung), location: 0), .init(color: schatten.opacity(0), location: 1)]))
    }

    func neuesGesicht(_ basis: GraphicsContext, _ neu: NeuesGesicht) {
        if neu == .b && eigeneFrisur {
            let taper = verlaufY(78, 104, [.init(color: haar.farbe.opacity(0.95), location: 0), .init(color: haar.farbe.opacity(0.55), location: 0.55), .init(color: haar.farbe.opacity(0.05), location: 1)])
            basis.fill(GesichtB.taperL, with: taper)
            basis.fill(GesichtB.taperR, with: taper)
        }
        let g = gedreht(basis)
        let mundKontext = gedreht(basis, mund: true)
        switch neu {
        case .b: neuesGesichtB(g, mundKontext)
        case .an3: neuesGesichtAn3(g, mundKontext)
        }
    }

    func neuesGesichtB(_ g: GraphicsContext, _ mundKontext: GraphicsContext) {
        var h = g
        h.clip(to: GesichtB.gesicht)
        if eigeneFrisur { h.fill(GesichtB.ponySchatten, with: .color(haut.mal(0.88).farbe.opacity(0.6))) }
        // 25.09. (Ahmed): no cheek shadows, they read as fat cheeks.
        wangenRot(h, .b)
        let bartFarbe = FigurFarbe(0x5C4030)
        if kinnbart > 0 {
            h.fill(GesichtB.kinnbart, with: .color(bartFarbe.farbe.opacity(0.45)))
            h.fill(GesichtB.kinnSchatten, with: .color(bartFarbe.farbe.opacity(0.14)))
        }
        neueAugen(g, .b)
        neueBrauen(g, .b)
        linie(g, GesichtB.nase, haut.kontur, 2.4)
        g.fill(GesichtB.nasenSchatten, with: .color(haut.mal(0.85).farbe.opacity(0.6)))
        gesichtsExtras(g)
        neuerMund(mundKontext, .b)
        if bart > 0 {
            var k = mundKontext
            if case .offen = mundForm { k.translateBy(x: 0, y: -1.5) }
            if case .grinsen = mundForm { k.translateBy(x: 0, y: -1) }
            // ponytail: every mustache style draws B's thin mustache, the other beard styles are not ported yet.
            teil(k, GesichtB.schnurrbart, FigurFarbe(0x5C4030), 1.2)
        }
    }

    func neueAugen(_ g: GraphicsContext, _ neu: NeuesGesicht) {
        let form = augenAusdruck
        var offen = true
        if case .zu = form { offen = false }
        if case .froh = form { offen = false }
        if (offen && abz.contains("herzaugen")) || z == .verliebt {
            let s: CGFloat = 8.5 + 1.2 * w(8)
            for auge in neu.augen { teil(g, herzPfad(auge.c, s), Pal.rose, 2.2) }
            return
        }
        let blinzelt = !statisch && zyklus(4.2, 1.3) < 0.035
        for auge in neu.augen {
            if z == .zwinkert && auge.sd > 0 { neuesAugeZu(g, neu, auge.c, auge.sd, froh: true); continue }
            if blinzelt && offen { neuesAugeZu(g, neu, auge.c, auge.sd, froh: false); continue }
            neuesAuge(g, neu, auge.c, auge.sd, form)
        }
    }

    func neuesAuge(_ g: GraphicsContext, _ neu: NeuesGesicht, _ c: CGPoint, _ sd: CGFloat, _ form: Auge) {
        switch form {
        case .zu:
            neuesAugeZu(g, neu, c, sd, froh: false)
        case .froh:
            neuesAugeOffen(g, neu, c, sd)
            neuesLachLid(g, neu, sd)
        case .offen(let gross):
            if gross {
                var k = g
                k.translateBy(x: c.x, y: c.y)
                k.scaleBy(x: 1.12, y: 1.12)
                k.translateBy(x: -c.x, y: -c.y)
                neuesAugeOffen(k, neu, c, sd)
            } else {
                neuesAugeOffen(g, neu, c, sd)
            }
        case .muede:
            neuesAugeOffen(g, neu, c, sd)
            neuesLid(g, neu, c, sd, innen: 1, aussen: 1)
        case .schock:
            let weiss = oval(c, 9, 11)
            g.fill(weiss, with: .color(.white))
            linie(g, weiss, Pal.tinte.farbe, 2.4)
            g.fill(kreis(P(c.x, c.y + 1), 2.3), with: .color(Pal.tinte.farbe))
        case .boese:
            neuesAugeOffen(g, neu, c, sd)
            neuesLid(g, neu, c, sd, innen: 3, aussen: -7)
        }
    }

    /// Closed eye: a lash line along the lower edge of the almond. `froh` bends it up (^^).
    func neuesAugeZu(_ g: GraphicsContext, _ neu: NeuesGesicht, _ c: CGPoint, _ sd: CGFloat, froh: Bool) {
        let innen = P(c.x - sd * 10, c.y + 1)
        let aussen = P(c.x + sd * 11, c.y - 1)
        linie(g, bogen(innen, aussen, P(c.x, c.y + (froh ? -7 : 6))), Pal.tinte.farbe, 3)
        if neu == .an3 { linie(g, strich(aussen, P(aussen.x + sd * 3.6, aussen.y - 2.8)), Pal.tinte.farbe, 1.6) }
    }

    /// Smile: the lower lid pushes up over the open eye (group `eyes-smile` in bau.py).
    func neuesLachLid(_ g: GraphicsContext, _ neu: NeuesGesicht, _ sd: CGFloat) {
        let links = sd < 0
        let weiss = neu == .b ? (links ? GesichtB.augeWeissL : GesichtB.augeWeissR) : (links ? GesichtAn3.augeWeissL : GesichtAn3.augeWeissR)
        let lid = neu == .b ? (links ? GesichtB.lachLidL : GesichtB.lachLidR) : (links ? GesichtAn3.lachLidL : GesichtAn3.lachLidR)
        let strich = neu == .b ? (links ? GesichtB.lachLidStrichL : GesichtB.lachLidStrichR) : (links ? GesichtAn3.lachLidStrichL : GesichtAn3.lachLidStrichR)
        var h = g
        h.clip(to: weiss)
        h.fill(lid, with: .color(haut.farbe))
        linie(g, strich, (neu == .b ? haut.kontur : haut.mal(0.66).farbe).opacity(0.55), 1.4)
    }

    /// Upper lid pulled down: `innen`/`aussen` are the lid edge heights (y offsets from the eye centre)
    /// at the inner and outer corner. Tired = both at +1 (about 55 % closed), angry = inner corner low.
    func neuesLid(_ g: GraphicsContext, _ neu: NeuesGesicht, _ c: CGPoint, _ sd: CGFloat, innen: CGFloat, aussen: CGFloat) {
        let links = sd < 0
        let weiss = neu == .b ? (links ? GesichtB.augeWeissL : GesichtB.augeWeissR) : (links ? GesichtAn3.augeWeissL : GesichtAn3.augeWeissR)
        let pi = P(c.x - sd * 13, c.y + innen)
        let pa = P(c.x + sd * 13, c.y + aussen)
        let lid = Path { p in
            p.move(to: P(pi.x, c.y - 16))
            p.addLine(to: P(pa.x, c.y - 16))
            p.addLine(to: pa)
            p.addLine(to: pi)
            p.closeSubpath()
        }
        var h = g
        h.clip(to: weiss)
        h.fill(lid, with: .color(haut.farbe))
        h.stroke(strich(pi, pa), with: .color(Pal.tinte.farbe), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    func neuesAugeOffen(_ g: GraphicsContext, _ neu: NeuesGesicht, _ c: CGPoint, _ sd: CGFloat) {
        let links = sd < 0
        let b = blick
        switch neu {
        case .b:
            let weiss = links ? GesichtB.augeWeissL : GesichtB.augeWeissR
            g.fill(weiss, with: .color(.white))
            var h = g
            h.clip(to: weiss)
            let ic = P(c.x + sd * 0.5 + b.x * 2.5, 102.2 + b.y * 2)
            h.fill(kreis(ic, 5.4), with: .color(iris.farbe))
            h.fill(kreis(ic, 2.6), with: .color(Pal.tinte.mal(0.7).farbe))
            h.fill(kreis(P(ic.x - 1.6 - sd * 0.5, ic.y - 1.4), 1.4), with: .color(.white))
            h.fill(links ? GesichtB.lidL : GesichtB.lidR, with: .color(haut.farbe))
            linie(g, links ? GesichtB.lidStrichL : GesichtB.lidStrichR, Pal.tinte.farbe, 3)
            linie(g, links ? GesichtB.lidFalteL : GesichtB.lidFalteR, haut.kontur.opacity(0.5), 1.3)
        case .an3:
            let weiss = links ? GesichtAn3.augeWeissL : GesichtAn3.augeWeissR
            g.fill(weiss, with: .color(.white))
            var h = g
            h.clip(to: weiss)
            let ic = P(c.x + sd * 0.3 + b.x * 2.5, 102.3 + b.y * 2)
            let hell = iris.mix(FigurFarbe(0xA8D0F4), 0.5)
            h.fill(oval(ic, 5.2, 6), with: verlaufY(96, 108, [.init(color: iris.mal(0.45).farbe, location: 0), .init(color: hell.farbe, location: 1)]))
            h.fill(kreis(P(ic.x, ic.y + 0.3), 2.4), with: .color(FigurFarbe(0x140C0A).farbe))
            h.fill(kreis(P(ic.x - 1.8, ic.y - 2.1), 1.7), with: .color(.white))
            h.fill(kreis(P(ic.x + 1.9, ic.y + 2.1), 0.8), with: .color(.white.opacity(0.85)))
            linie(g, links ? GesichtAn3.lidStrichL : GesichtAn3.lidStrichR, Pal.tinte.farbe, 3)
            linie(g, links ? GesichtAn3.fluegelL : GesichtAn3.fluegelR, Pal.tinte.farbe, 1.5)
        }
    }

    func neuerMund(_ g: GraphicsContext, _ neu: NeuesGesicht) {
        switch (mundForm, neu) {
        case (.neutral, .b), (.laecheln, .b): lippenB(g)
        case (.neutral, .an3): lippenAn3(g)
        case (.laecheln, .an3), (.grinsen, .an3): lachLippenAn3(g)
        case (.grinsen, .b), (.zaehne, .b): lachMundB(g)
        case (.offen(let r), _):
            let o = oval(P(100, neu.mundMitte), r * 0.7, r * 0.85)
            g.fill(o, with: .color(Pal.mundInnen.farbe))
            linie(g, o, (neu == .b ? lippeB : lippeAn3).mal(0.55).farbe, 2)
        default:
            // Kiss, pout, sad, wavy, crying, crooked and Annika's teeth: the old shapes, moved onto the
            // new mouth and made 15 % smaller.
            var k = g
            k.translateBy(x: 100, y: neu.mundMitte)
            k.scaleBy(x: 0.85, y: 0.85)
            k.translateBy(x: -100, y: -131)
            mund(k)
        }
    }

    func lachMundB(_ g: GraphicsContext) {
        flaeche(g, GesichtB.lachMund, .color(Pal.mundInnen.farbe), rand: lippeB.mal(0.5).farbe, breite: 1.6)
        g.fill(GesichtB.lachZaehne, with: .color(.white))
        g.fill(GesichtB.lachZunge, with: .color(Pal.zunge.farbe))
    }

    func lachLippenAn3(_ g: GraphicsContext) {
        let l = lippeAn3
        let rand = l.mal(0.62).farbe
        g.fill(GesichtAn3.lachLippeOben, with: .color(l.mal(0.88).farbe))
        g.fill(GesichtAn3.lachLippeUnten, with: .color(l.farbe))
        linie(g, GesichtAn3.lachLinie, rand, 1.3)
        linie(g, GesichtAn3.lachWinkelL, rand, 1)
        linie(g, GesichtAn3.lachWinkelR, rand, 1)
    }

    /// 25.09. (Ahmed): thin, calm lips close under the mustache, not full pink ones.
    var lippeB: FigurFarbe { haut.mix(FigurFarbe(0xE07A8A), 0.26) }
    var lippeAn3: FigurFarbe { haut.mix(Pal.rose, 0.4).mal(0.9) }

    func lippenB(_ g: GraphicsContext) {
        let l = lippeB
        var k = g
        k.translateBy(x: 100, y: 141)
        k.scaleBy(x: 0.84, y: 0.58)
        k.translateBy(x: -100, y: -142.5)
        flaeche(k, GesichtB.lippeOben, .color(l.mal(0.9).farbe), rand: l.mal(0.7).farbe, breite: 1.4)
        flaeche(k, GesichtB.lippeUnten, .color(l.farbe), rand: l.mal(0.7).farbe, breite: 1.4)
    }

    func lippenAn3(_ g: GraphicsContext) {
        let l = lippeAn3
        g.fill(GesichtAn3.lippeOben, with: .color(l.mal(0.88).farbe))
        g.fill(GesichtAn3.lippeUnten, with: .color(l.farbe))
        linie(g, GesichtAn3.lippenLinie, l.mal(0.62).farbe, 0.9)
        g.fill(GesichtAn3.lippenGlanz, with: .color(.white.opacity(0.45)))
    }

    func neueHaareHinten(_ g: GraphicsContext, _ neu: NeuesGesicht) {
        switch neu {
        case .b: teil(g, GesichtB.haarHinten, haar)
        case .an3:
            if z == .gym {
                flaeche(g, GesichtAn3.gymZopf, .color(haar.mal(0.85).farbe), rand: haar.mal(0.55).farbe, breite: 3)
            } else {
                flaeche(g, GesichtAn3.haarHinten, .color(haar.mal(0.7).farbe), rand: haar.mal(0.55).farbe, breite: 3)
            }
        }
    }

    func neueHaareVorn(_ g: GraphicsContext, _ neu: NeuesGesicht) {
        switch neu {
        case .b:
            teil(g, GesichtB.haarVorn, haar)
            let ton = haar.mix(Pal.weiss, 0.16).farbe.opacity(0.9)
            for locke in GesichtB.lockenGlanz { linie(g, locke, ton, 2.2) }
        case .an3:
            neueHaareVornAn3(g)
        }
    }

    func neuesGesichtAn3(_ g: GraphicsContext, _ mundKontext: GraphicsContext) {
        var h = g
        h.clip(to: GesichtAn3.gesicht)
        wangenRot(h, .an3)
        neueAugen(g, .an3)
        neueBrauen(g, .an3)
        linie(g, GesichtAn3.nase, haut.kontur, 1.8)
        gesichtsExtras(g)
        neuerMund(mundKontext, .an3)
    }

    /// Annika 3's hair in front: a thin strand, both curtains from the centre parting (the right one
    /// tucked behind the ear), strand lines on the left and soft highlights.
    func neueHaareVornAn3(_ g: GraphicsContext) {
        let rand = haar.mal(0.55).farbe
        if z == .gym {
            // Tied back: hair cap over the head, pink hair tie at the ponytail (annika_gym.py).
            flaeche(g, GesichtAn3.gymKappe, .color(haar.farbe), rand: rand, breite: 3)
            teil(g, GesichtAn3.gymBand, FigurFarbe(0xF07C86), 1.5)
            let glanz = haar.mix(FigurFarbe(0xC9A080), 0.45).farbe.opacity(0.55)
            linie(g, bogen(P(100, 34), P(68, 58), P(80, 38)), glanz, 2.2)
            linie(g, bogen(P(100, 34), P(132, 58), P(120, 38)), glanz, 2.2)
            return
        }
        flaeche(g, GesichtAn3.straehne, .color(haar.farbe), rand: rand, breite: 3)
        let verlauf = verlaufY(30, 236, [
            .init(color: haar.mix(FigurFarbe(0x6A4632), 0.45).farbe, location: 0),
            .init(color: haar.farbe, location: 0.35),
            .init(color: haar.mal(0.85).farbe, location: 1),
        ])
        flaeche(g, GesichtAn3.haarVornL, verlauf, rand: rand, breite: 3)
        flaeche(g, GesichtAn3.haarVornR, verlauf, rand: rand, breite: 3)
        for l in GesichtAn3.haarLinien { linie(g, l, rand.opacity(0.7), 1.2) }
        let glanz = haar.mix(FigurFarbe(0xC9A080), 0.45).farbe.opacity(0.55)
        for l in GesichtAn3.haarGlanz { linie(g, l, glanz, 2.2) }
    }

    /// Same moves as the old `brauen`: up for looking/surprised, inner end up when sad, down when angry.
    func neueBrauen(_ g: GraphicsContext, _ neu: NeuesGesicht) {
        let hoch: CGFloat = (z == .schautBild || z == .schautVideo || z == .anstupsen) ? -5 : 0
        let traurig: CGFloat = [.schlecht, .akkuLeer, .weint, .verlegen].contains(z) ? -6 : 0
        let staunen: CGFloat = [.ueberrascht, .schockiert].contains(z) ? -8 : 0
        let boese: CGFloat = z == .sauer ? 8 : (z == .schmollt ? 4 : 0)
        for (i, sd) in [CGFloat(-1), 1].enumerated() {
            let heben: CGFloat = z == .denkt && sd > 0 ? -6 : staunen
            let aussenX: CGFloat = 100 + sd * 30
            let aussenY: CGFloat = neu == .b ? 92 : 87.2
            // Tilt around the outer end: positive `kipp` lowers the inner end.
            let kipp = atan2(Double(traurig + boese * 1.4), 22) * Double(-sd)
            var k = g
            k.translateBy(x: 0, y: hoch + heben - boese * 0.4)
            k.translateBy(x: aussenX, y: aussenY)
            k.rotate(by: .radians(kipp))
            k.translateBy(x: -aussenX, y: -aussenY)
            if neu == .b {
                linie(k, i == 0 ? GesichtB.braueL : GesichtB.braueR, haar.mal(1.2).farbe, 4.4)
            } else {
                k.fill(i == 0 ? GesichtAn3.braueL : GesichtAn3.braueR, with: .color(haar.mal(1.05).farbe))
            }
        }
    }

    /// Brief F2: no permanent rouge circles any more (they made the old faces look puffy). Blush only
    /// for love, embarrassment, kiss, heart and closeness, or when the look sets `rouge`.
    /// 25.09. (Ahmed): "keine fetten Cheeks", for Annika too, so the look's `rouge` no longer blushes the new faces.
    var erroetet: Bool { [.verliebt, .verlegen, .kuss, .herz, .naehe].contains(z) || (rouge && neu == nil) }

    func wangenRot(_ h: GraphicsContext, _ neu: NeuesGesicht) {
        guard erroetet else { return }
        let rot = FigurFarbe(0xF07C86).farbe
        let stark = [FigurZustand.verliebt, .verlegen].contains(z)
        let (mitten, r): ([CGPoint], CGFloat) = neu == .b ? ([P(66, 121), P(134, 121)], 13) : ([P(73, 119), P(127, 119)], 11)
        let deckung: Double = stark ? 0.45 : 0.3
        for c in mitten {
            h.fill(oval(c, r, r * 0.65), with: verlaufRund(c, r, [.init(color: rot.opacity(deckung), location: 0), .init(color: rot.opacity(0), location: 1)]))
        }
    }

    /// The small extras of the old `gesicht` (embarrassed lines, angry forehead, freckles, moles),
    /// moved onto the narrower face with the accessory map.
    func gesichtsExtras(_ g: GraphicsContext) {
        let k = zubehoerKontext(g)
        if z == .verlegen {
            for x in [CGFloat(62), 68, 74, 126, 132, 138] { linie(k, strich(P(x, 123), P(x + 3, 117)), Pal.rose.kontur.opacity(0.6), 1.4) }
        }
        if z == .sauer {
            var h = g
            h.clip(to: kopfPfad)
            h.fill(box(30, 26, 140, 44), with: .color(Pal.rose.farbe.opacity(0.22)))
        }
        if sommersprossen {
            for c in [P(62, 114), P(69, 110), P(74, 117), P(66, 121), P(92, 110), P(97, 106)] {
                k.fill(kreis(c, 1.4), with: .color(haut.mal(0.72).farbe))
                k.fill(kreis(P(200 - c.x, c.y), 1.4), with: .color(haut.mal(0.72).farbe))
            }
        }
        if muttermal { k.fill(kreis(P(122, 127), 1.9), with: .color(Pal.tinte.farbe.opacity(0.8))) }
        // 25.09. (Ahmed): the new faces draw no cheek moles (`muttermale`).
    }

    /// Brief F2: the old accessories were built for the 116 px wide head. On a new face they move with
    /// `x' = 100 + (x - 100) * 0.81`, `y' = y + 3` (notizen.md). Old faces get `g` back unchanged.
    func zubehoerKontext(_ g: GraphicsContext, dy: CGFloat = 3) -> GraphicsContext {
        guard neu != nil else { return g }
        var k = g
        k.translateBy(x: 100, y: dy)
        k.scaleBy(x: 0.81, y: 1)
        k.translateBy(x: -100, y: 0)
        return k
    }

    // MARK: - Brief F3

    /// F4: one closed outline shoulder -> elbow -> wrist (arme.py `arm_umriss`). `ws`/`we`/`wh` are the
    /// widths at shoulder, elbow and wrist; the ends bulge by `kappeS`/`kappeH` widths. Soft through the elbow.
    func armUmriss(_ s: CGPoint, _ e: CGPoint, _ h: CGPoint, _ ws: CGFloat, _ we: CGFloat, _ wh: CGFloat,
                   kappeS: CGFloat, kappeH: CGFloat) -> Path {
        let n1 = einheitsNormale(s, e)
        let n2 = einheitsNormale(e, h)
        let nm = einheit(P(n1.x + n2.x, n1.y + n2.y))
        let a1 = P(s.x + n1.x * ws / 2, s.y + n1.y * ws / 2)
        let a2 = P(e.x + nm.x * we / 2, e.y + nm.y * we / 2)
        let a3 = P(h.x + n2.x * wh / 2, h.y + n2.y * wh / 2)
        let b1 = P(s.x - n1.x * ws / 2, s.y - n1.y * ws / 2)
        let b2 = P(e.x - nm.x * we / 2, e.y - nm.y * we / 2)
        let b3 = P(h.x - n2.x * wh / 2, h.y - n2.y * wh / 2)
        let u = einheit(P(h.x - e.x, h.y - e.y))
        let v = einheit(P(s.x - e.x, s.y - e.y))
        let spitze = P(h.x + u.x * wh * kappeH, h.y + u.y * wh * kappeH)
        let oben = P(s.x + v.x * ws * kappeS, s.y + v.y * ws * kappeS)
        return Path { p in
            p.move(to: a1)
            p.addQuadCurve(to: a3, control: a2)
            p.addQuadCurve(to: b3, control: spitze)
            p.addQuadCurve(to: b1, control: b2)
            p.addQuadCurve(to: a1, control: oben)
            p.closeSubpath()
        }
    }

    func einheit(_ p: CGPoint) -> CGPoint {
        let l = max(0.001, (p.x * p.x + p.y * p.y).squareRoot())
        return P(p.x / l, p.y / l)
    }

    func einheitsNormale(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let u = einheit(P(b.x - a.x, b.y - a.y))
        return P(-u.y, u.x)
    }

    /// The side of the upper arm toward the shoulder, cut at `saum` (0 = shoulder, 1 = elbow)
    /// perpendicular to the upper arm. Works for raised arms too.
    func schulterSeite(_ s: CGPoint, _ e: CGPoint, saum: CGFloat) -> Path {
        let u = einheit(P(e.x - s.x, e.y - s.y))
        let n = P(-u.y, u.x)
        let m = P(s.x + (e.x - s.x) * saum, s.y + (e.y - s.y) * saum)
        return Path { p in
            p.move(to: P(m.x + n.x * 300, m.y + n.y * 300))
            p.addLine(to: P(m.x - n.x * 300, m.y - n.y * 300))
            p.addLine(to: P(m.x - n.x * 300 - u.x * 400, m.y - n.y * 300 - u.y * 400))
            p.addLine(to: P(m.x + n.x * 300 - u.x * 400, m.y + n.y * 300 - u.y * 400))
            p.closeSubpath()
        }
    }

    /// Brief F4: one closed outline shoulder -> elbow -> wrist (arme.py `arm_umriss`/`arm_haut`/`aermel`).
    /// The short sleeve is a wider copy of the same outline cut at the hem; on the torso it is refilled
    /// without outline so shirt and sleeve are one piece.
    func armV(_ g: GraphicsContext, _ s: CGPoint, _ a: Arm, _ d: CGFloat, rumpf: Path) {
        let armFarbe = aermel == .lang ? aermelFarbe : haut
        // Hand first, the arm's rounded wrist lies over it (no ball on top of the arm).
        teil(g, kreis(P(a.hand.x, a.hand.y + 2 * d), 8.5 * d), haut, 3 * min(d, 1))
        let arm = armUmriss(s, a.ellbogen, a.hand, 26 * d, 20 * d, 15 * d, kappeS: 0.3, kappeH: 0.9)
        teil(g, arm, armFarbe, 3 * min(d, 1))
        var aufRumpf = g
        aufRumpf.clip(to: rumpf)
        switch aermel {
        case .kurz:
            let stoff = armUmriss(s, a.ellbogen, a.hand, 34 * d, 29 * d, 27 * d, kappeS: 0.55, kappeH: 0.4)
            var k = g
            k.clip(to: schulterSeite(s, a.ellbogen, saum: 0.5))
            teil(k, stoff, aermelFarbe, 3.2 * min(d, 1))
            var r = k
            r.clip(to: rumpf)
            r.fill(stoff, with: .color(aermelFarbe.farbe))
        case .lang:
            aufRumpf.fill(arm, with: .color(aermelFarbe.farbe))
        case .keine:
            aufRumpf.fill(arm, with: .color(haut.farbe))
        }
        aermelDetails(g, s, a, d)
    }

    // MARK: - F5: half-figure shirt and sleeves as one outline (new faces only)

    /// The half figure's arms with their shoulder points and thickness.
    func neueArme() -> [(s: CGPoint, a: Arm, d: CGFloat)] {
        let arme = mitExtras(pose())
        let schulter: CGPoint = neu == .b ? vForm.schulterL : P(100 - 40 * breite, 184)
        let d: CGFloat = neu == .b ? vForm.dick : 0.85
        var out: [(s: CGPoint, a: Arm, d: CGFloat)] = []
        if let l = arme.l { out.append((s: schulter, a: l, d: d)) }
        if let r = arme.r { out.append((s: P(200 - schulter.x, schulter.y), a: r, d: d)) }
        return out
    }

    /// A raised or folded forearm lies in front of the body.
    func istVorn(_ a: Arm) -> Bool { a.hand.y < a.ellbogen.y - 4 }

    func armForm(_ s: CGPoint, _ a: Arm, _ d: CGFloat) -> Path {
        // Face B: no bulge at the shoulder end, the torso's round shoulder covers it (schulter.py S4).
        armUmriss(s, a.ellbogen, a.hand, 26 * d, 20 * d, 15 * d, kappeS: neu == .b ? 0 : 0.3, kappeH: 0.9)
    }

    func aermelStoff(_ s: CGPoint, _ a: Arm, _ d: CGFloat) -> Path {
        let form: Path
        if neu == .b {
            // Ahmed: S4 is the cleanest; the wider S5 sleeve starts to separate from the body.
            form = armUmriss(s, a.ellbogen, a.hand, 33 * d, 29 * d, 27 * d, kappeS: 0, kappeH: 0.4)
        } else {
            form = armUmriss(s, a.ellbogen, a.hand, 34 * d, 29 * d, 27 * d, kappeS: 0.55, kappeH: 0.4)
        }
        return form.intersection(schulterSeite(s, a.ellbogen, saum: 0.5))
    }

    /// `koerper` draws in a context scaled by `breite` around x = 100; this maps its paths to the
    /// unscaled half-figure space where the arms live.
    var kMatrix: CGAffineTransform { CGAffineTransform(a: breite, b: 0, c: 0, d: 1, tx: 100 - 100 * breite, ty: 0) }

    /// Torso plus sleeves (or bare arms) as ONE outline, unscaled space.
    func hemd(_ torsoK: Path) -> Path {
        var form = torsoK.applying(kMatrix)
        for arm in neueArme() where !istVorn(arm.a) {
            switch aermel {
            case .kurz: form = form.union(aermelStoff(arm.s, arm.a, arm.d))
            case .lang: form = form.union(armForm(arm.s, arm.a, arm.d))
            // Bare arms join the torso only when the torso is skin too; a sleeveless top keeps its own shape.
            case .keine: if oberkoerperFrei { form = form.union(armForm(arm.s, arm.a, arm.d)) }
            }
        }
        return form
    }

    /// The base shape of a torso branch in `koerper`: old faces unchanged, new faces as one outline.
    func basis(_ g: GraphicsContext, _ k: GraphicsContext, _ form: Path, _ farbe: FigurFarbe) {
        guard neu != nil else { teil(k, form, farbe); return }
        let rand = aermel == .lang ? aermelFarbe.kontur : farbe.kontur
        flaeche(g, hemd(form), .color(farbe.farbe), rand: rand, breite: 3.5)
    }

    /// Before the torso: the hands, and bare arms that disappear under short sleeves.
    func armeHinten(_ g: GraphicsContext) {
        for arm in neueArme() where !istVorn(arm.a) {
            teil(g, kreis(P(arm.a.hand.x, arm.a.hand.y + 2 * arm.d), 8.5 * arm.d), haut, 3 * min(arm.d, 1))
            if aermel == .kurz { teil(g, armForm(arm.s, arm.a, arm.d), haut, 3 * min(arm.d, 1)) }
        }
    }

    /// After torso and jacket: long sleeves get their color (their outline came with `hemd`), arms in
    /// front of the body are drawn whole on top (they bring their own hand and sleeve).
    func armeVorn(_ g: GraphicsContext, torsoK: Path) {
        let torso = torsoK.applying(kMatrix)
        for arm in neueArme() {
            if istVorn(arm.a) {
                armV(g, arm.s, arm.a, arm.d, rumpf: torso)
            } else if aermel == .lang {
                g.fill(armForm(arm.s, arm.a, arm.d), with: .color(aermelFarbe.farbe))
                aermelDetails(g, arm.s, arm.a, arm.d)
            } else if aermel == .keine && !oberkoerperFrei {
                // Sleeveless top (Annika's gym top): bare arm in front of the top's edge.
                teil(g, armForm(arm.s, arm.a, arm.d), haut, 3 * min(arm.d, 1))
                if oberteil == 37 { aermelDetails(g, arm.s, arm.a, arm.d) }
            }
        }
    }
}

// MARK: - Teil 2 (Nähe): the partner-side arm and hand

extension Zeichner {
    /// Where the hand rests, in this figure's full-body space. The partner stands at
    /// `100 + seite * abstand`; y values follow this figure's shoulders (both stand on the same floor).
    func paarZiel(_ um: Umarmung, _ m: Masse) -> CGPoint {
        let partner = 100 + um.seite * um.abstand
        switch um.hand {
        case .schulter: return P(partner + um.seite * 26, m.schulterY + 6)
        case .brust: return P(partner - um.seite * 12, m.schulterY + 34)
        case .hals: return P(partner - um.seite * 12, m.schulterY - 4)
        case .taille: return P(partner - um.seite * 2, m.hueftY - 22)
        case nil: return P(100, m.schulterY)
        }
    }

    func paarArm(_ u: GraphicsContext, _ m: Masse) {
        guard let um = umarmung, let hand = um.hand else { return }
        let ziel = paarZiel(um, m)
        let d = m.arm * (neu == .b ? vForm.dick : 1)
        switch hand {
        case .schulter:
            // The arm runs behind her back; the partner draws the fingers (`haltHand`).
            break
        case .taille:
            flacheHand(u, ziel, 9 * d / 0.8, winkel: -10 * Double(um.seite))
        case .brust, .hals:
            let schulter = P(100 + um.seite * (m.s - 6), m.schulterY + 10)
            let ellbogen = P(100 + um.seite * (m.s + 2), m.schulterY + 56)
            let torso = rumpfPfad(m, unten: m.hueftY + 4)
            armV(u, schulter, Arm(ellbogen, ziel), d, rumpf: torso)
            flacheHand(u, ziel, 8.5 * d / 0.8, winkel: 20 * Double(um.seite))
        }
    }

    /// The partner's fingers over this figure's far shoulder (`Umarmung.haltHand`).
    func gehalteneHand(_ u: GraphicsContext, _ m: Masse) {
        guard let um = umarmung, let farbe = um.haltHand else { return }
        let schulter = P(100 - um.seite * (m.s - 8), m.schulterY + 4)
        fingerUeberSchulter(u, schulter, 9 * m.arm / 0.8, farbe: farbe)
    }

    /// A hand laid over a shoulder from behind: back of the hand and four fingertips.
    func fingerUeberSchulter(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, farbe: FigurFarbe) {
        let form = Path { p in
            p.move(to: P(c.x - r * 1.1, c.y - r * 0.6))
            p.addQuadCurve(to: P(c.x + r * 1.1, c.y - r * 0.6), control: P(c.x, c.y - r * 1.3))
            p.addLine(to: P(c.x + r, c.y + r * 0.5))
            p.addQuadCurve(to: P(c.x - r, c.y + r * 0.5), control: P(c.x, c.y + r * 0.9))
            p.closeSubpath()
        }
        teil(g, form, farbe, 2.6)
        for dx in [CGFloat(-0.62), -0.2, 0.22, 0.62] {
            linie(g, strich(P(c.x + dx * r, c.y + r * 0.1), P(c.x + dx * r, c.y + r * 0.75)), farbe.kontur.opacity(0.6), 1.2)
        }
    }

    /// A flat hand (palm with three finger lines), turned by `winkel` degrees.
    func flacheHand(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, winkel: Double) {
        var h = g
        h.translateBy(x: c.x, y: c.y)
        h.rotate(by: .degrees(winkel))
        h.translateBy(x: -c.x, y: -c.y)
        teil(h, oval(c, r, r * 1.15), haut, 2.6)
        for dx in [-r * 0.35, 0, r * 0.35] {
            linie(h, strich(P(c.x + dx, c.y + r * 0.3), P(c.x + dx, c.y + r * 0.95)), haut.kontur.opacity(0.6), 1.2)
        }
    }
}
