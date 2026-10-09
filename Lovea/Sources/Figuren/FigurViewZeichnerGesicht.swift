import SwiftUI

extension Zeichner {

    func kopf(_ g: GraphicsContext) {
        if let neu { neuerKopf(g, neu); return }
        for x in [CGFloat(42), 158] {
            teil(g, kreis(P(x, 100), 11), haut)
            g.fill(kreis(P(x, 100), 5), with: .color(haut.mal(0.85).farbe))
        }
        teil(g, kopfPfad, haut)
    }

    /// `d` scales the thickness (the body type's `armHalb` in the half figure, `arm` on the full body).
    func arm(_ g: GraphicsContext, _ schulter: CGPoint, _ a: Arm, _ d: CGFloat = 1) {
        let oben = strich(schulter, a.ellbogen)
        let unten = strich(a.ellbogen, a.hand)
        let obenFarbe = aermel == .keine ? haut : aermelFarbe
        let untenFarbe = aermel == .lang ? aermelFarbe : haut
        let muskeln = muskelBeulen(schulter, a.ellbogen, d)
        // A raised or folded forearm lies in front of the upper arm, so it is drawn last;
        // otherwise the thick upper arm would swallow it (fix round 1: floating fists).
        let vorn = a.hand.y < a.ellbogen.y - 4
        linie(g, oben, obenFarbe.kontur, 25 * d)
        for m in muskeln { g.fill(kreis(m.c, m.r + 3 * d), with: .color(obenFarbe.kontur)) }
        if vorn {
            linie(g, oben, obenFarbe.farbe, 19 * d)
            for m in muskeln { g.fill(kreis(m.c, m.r), with: .color(obenFarbe.farbe)) }
            linie(g, unten, untenFarbe.kontur, 21 * d)
            linie(g, unten, untenFarbe.farbe, 15.5 * d)
        } else {
            linie(g, unten, untenFarbe.kontur, 21 * d)
            linie(g, unten, untenFarbe.farbe, 15.5 * d)
            linie(g, oben, obenFarbe.farbe, 19 * d)
            for m in muskeln { g.fill(kreis(m.c, m.r), with: .color(obenFarbe.farbe)) }
        }
        aermelDetails(g, schulter, a, d)
    }

    /// Z-38.2: shoulder cap and biceps of the muscular body types, as round bulges on the upper arm.
    func muskelBeulen(_ s: CGPoint, _ e: CGPoint, _ d: CGFloat) -> [(c: CGPoint, r: CGFloat)] {
        let m = km.muskel
        guard m > 0 else { return [] }
        let dx = e.x - s.x
        let dy = e.y - s.y
        let laenge = max(1, (dx * dx + dy * dy).squareRoot())
        // Unit normal pointing away from the body's middle (x = 100).
        var nx = -dy / laenge
        var ny = dx / laenge
        if (s.x - 100) * nx < 0 {
            nx = -nx
            ny = -ny
        }
        let kappe = P(s.x + dx * 0.14 + nx * 1.5 * d, s.y + dy * 0.14 + ny * 1.5 * d)
        let innen: CGFloat = 2 * m * d
        let bizeps = P(s.x + dx * 0.55 - nx * innen, s.y + dy * 0.55 - ny * innen)
        let kappeR: CGFloat = (10.5 + 2.5 * m) * d
        let bizepsR: CGFloat = (9.5 + 2.2 * m) * d
        return [(c: kappe, r: kappeR), (c: bizeps, r: bizepsR)]
    }

    /// Z-39.1 sleeve cues: Adidas three stripes down the whole arm, colored cuffs on the Nike jersey.
    func aermelDetails(_ g: GraphicsContext, _ s: CGPoint, _ a: Arm, _ d: CGFloat) {
        if jacke == 8 {
            dreiStreifen(g, s, a.ellbogen, d)
            dreiStreifen(g, a.ellbogen, a.hand, d)
        } else if jacke == 0 && oberteil == 20 && aermel == .kurz {
            let band = strich(zwischen(s, a.ellbogen, 0.8), zwischen(s, a.ellbogen, 0.97))
            linie(g, band, trikotBesatz.farbe, 19 * d)
        } else if jacke == 14 {
            zeichneCardiganBuendchen(g, ellbogen: a.ellbogen, hand: a.hand, d: d, farbe: jackeF)
        } else if jacke == 0 && oberteil == 37 && aermel == .keine && !sportTop && !oberkoerperFrei {
            zeichneRueschenAermel(g, von: s, nach: a.ellbogen, d: d, farbe: top)
        }
    }

    /// Three parallel stripes along a limb segment (Adidas); `d` scales their spacing.
    func dreiStreifen(_ g: GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ d: CGFloat, farbe: Color = .white) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let laenge = max(1, (dx * dx + dy * dy).squareRoot())
        let nx: CGFloat = -dy / laenge * 3.4 * d
        let ny: CGFloat = dx / laenge * 3.4 * d
        for k in [CGFloat(-1), 0, 1] {
            linie(g, strich(P(a.x + nx * k, a.y + ny * k), P(b.x + nx * k, b.y + ny * k)), farbe, 1.6 * d)
        }
    }

    /// Nike jersey trim: Brazil green on a yellow jersey, white otherwise.
    var trikotBesatz: FigurFarbe {
        top.r > 0.8 && top.g > 0.65 && top.b < 0.5 ? FigurFarbe(0x1E8A4C) : Pal.weiss
    }

    // MARK: Face

    /// Tired only while nothing more telling is going on (not asleep, no gesture or expression).
    /// Sitting up in bed after "Gute Nacht" (Brief G fix 2) is always tired.
    var schlaefrig: Bool { (extras.contains(.schlaefrig) || z == .sitztImBett) && !Self.keinePoseUeberschreibung.contains(z) }

    /// A short yawn about every half minute; never on a still frame (Reduce Motion, stickers).
    var gaehnt: Bool { schlaefrig && !statisch && zyklus(29) < 0.08 }

    var augenAusdruck: Auge {
        if umarmung?.augenZu == true { return .zu }
        if schlaefrig { return gaehnt ? .zu : .muede }
        return switch z {
        case .schlaeft, .morgen: .zu
        case .lacht, .kuss, .gut, .naehe: .froh
        case .akkuLeer, .abend, .ruhe: .muede
        case .schautBild, .schautVideo, .anstupsen, .ueberrascht: .offen(gross: true)
        case .lachtTraenen, .feiert, .daumen, .tanzt: .froh
        case .weint: .zu
        case .muede: .muede
        case .schockiert: .schock
        case .sauer: .boese
        default: .offen(gross: false)
        }
    }

    var mundForm: Mund {
        // Teil 2: the pair kiss purses the lips without the blown-kiss hand of `.kuss`.
        if let um = umarmung, um.augenZu, um.kuss > 0.5 { return .kuss }
        if gaehnt { return .offen(7 + 7 * CGFloat(sin(Double(zyklus(29)) / 0.08 * Double.pi))) }
        return switch z {
        case .gut, .lacht, .pokal, .anstossen, .imChat: .grinsen
        case .schautBild, .schautVideo, .rennt: .offen(6)
        case .morgen: .offen(9)
        case .sprache: .offen(4 + 3 * abs(w(11)))
        case .schlaeft: .offen(3)
        case .mittel, .offline, .nichtStoeren: .neutral
        case .schlecht, .akkuLeer: .traurig
        case .kuss: .kuss
        case .zwinkert, .lachtTraenen, .feiert, .daumen, .tanzt: .grinsen
        case .sauer: .zaehne
        case .schmollt: .schmoll
        case .verlegen: .wellig
        case .muede, .ueberrascht: .offen(7)
        case .weint: .heulen
        case .denkt: .schief
        case .schockiert: .offen(13)
        default: .laecheln
        }
    }

    var blick: CGPoint {
        switch z {
        case .liest: P(w(1.6), 0.7)
        case .tippt, .arbeit, .schule, .zeichnet, .laedt: P(0, 0.7)
        case .kamera, .spielt: P(0.6, -0.7)
        case .anstupsen: P(0.8, 0)
        case .schmollt: P(-0.9, 0.1)
        case .verlegen: P(0.7, 0.8)
        case .denkt: P(-0.6, -0.9)
        default: P(0, 0)
        }
    }

    /// Brief K: a 2D three-quarter turn toward the hugged partner. The features (and glasses)
    /// slide toward them and narrow, clipped to the head; `mund` moves the lips a bit further so
    /// the kiss meets near the edge of the head. Unchanged while there is no turn.
    func gedreht(_ g: GraphicsContext, mund: Bool = false) -> GraphicsContext {
        guard let um = umarmung else { return g }
        // Brief F2: the new faces are narrower, so the features slide less.
        let schmal: CGFloat = neu == nil ? 1 : 0.6
        let dreh: CGFloat
        if let d = um.drehung {
            dreh = d
        } else {
            guard um.arme + um.kuss > 0 else { return g }
            dreh = um.seite * (10 * um.arme + 18 * um.kuss) * schmal
        }
        guard dreh != 0 else { return g }
        var h = g
        h.clip(to: kopfPfad)
        h.translateBy(x: 100 + dreh, y: 0)
        h.scaleBy(x: 1 - abs(dreh) / 150, y: 1)
        h.translateBy(x: -100 + (mund ? um.seite * 12 * um.kuss * schmal : 0), y: 0)
        return h
    }

    func gesicht(_ basis: GraphicsContext) {
        if let neu { neuesGesicht(basis, neu); return }
        let g = gedreht(basis)
        let mundKontext = gedreht(basis, mund: true)
        let staerke = [.verliebt, .verlegen, .schmollt].contains(z) ? 0.7 : ((z == .kuss || z == .herz || z == .naehe || rouge) ? 0.5 : 0.28)
        let wange = Pal.rose.farbe.opacity(staerke)
        // Pouting puffs the cheeks.
        let backe: CGFloat = z == .schmollt ? 1.5 : 1
        g.fill(oval(P(68, 120), 10 * backe, 6 * backe), with: .color(wange))
        g.fill(oval(P(132, 120), 10 * backe, 6 * backe), with: .color(wange))
        if z == .verlegen {
            for x in [CGFloat(62), 68, 74, 126, 132, 138] { linie(g, strich(P(x, 123), P(x + 3, 117)), Pal.rose.kontur.opacity(0.6), 1.4) }
        }
        if z == .sauer {
            // Red forehead.
            var h = g
            h.clip(to: kopfPfad)
            h.fill(box(30, 30, 140, 40), with: .color(Pal.rose.farbe.opacity(0.22)))
        }
        if sommersprossen {
            let punkte: [CGPoint] = [P(62, 114), P(69, 110), P(74, 117), P(66, 121), P(92, 110), P(97, 106)]
            for c in punkte {
                g.fill(kreis(c, 1.4), with: .color(haut.mal(0.72).farbe))
                g.fill(kreis(P(200 - c.x, c.y), 1.4), with: .color(haut.mal(0.72).farbe))
            }
        }
        if muttermal { g.fill(kreis(P(122, 127), 1.9), with: .color(Pal.tinte.farbe.opacity(0.8))) }
        if muttermale {
            for c in [P(66, 118), P(130, 124)] { g.fill(kreis(c, 1.1), with: .color(haut.mal(0.5).farbe.opacity(0.75))) }
        }
        bartZeichnen(g)
        kinnbartZeichnen(g)
        brauen(g)
        augen(g)
        nase(g)
        mund(mundKontext)
        schnurrbartVorn(mundKontext)
    }

    func brauen(_ g: GraphicsContext) {
        let farbe = haar.mal(0.8)
        let hoch: CGFloat = (z == .schautBild || z == .schautVideo || z == .anstupsen) ? -5 : 0
        let traurig: CGFloat = [.schlecht, .akkuLeer, .weint, .verlegen].contains(z) ? -6 : 0
        let staunen: CGFloat = [.ueberrascht, .schockiert].contains(z) ? -8 : 0
        // Angry: inner ends down (V); pouting a little; thinking lifts one brow.
        let boese: CGFloat = z == .sauer ? 8 : (z == .schmollt ? 4 : 0)
        let dicken: [CGFloat] = [4.5, 2.6, 7, 5, 4.5, 4.5, 4.5, 4, 7.5]
        for seite in [CGFloat(-1), 1] {
            let heben: CGFloat = z == .denkt && seite > 0 ? -6 : staunen
            var aussen = P(100 + seite * 30, 81 + hoch + heben - boese * 0.4)
            var innen = P(100 + seite * 10, 80 + hoch + traurig + heben + boese)
            var ctrl = P(100 + seite * 20, 75 + hoch + heben)
            switch brauenStil {
            case 3:
                ctrl.y = 79 + hoch
                aussen.y = 80 + hoch
            case 8:
                // Dick gerade (Ahmed): thick, dark and nearly straight; expressions still move it.
                ctrl.y = 78 + hoch + heben
                aussen.y = 80 + hoch + heben - boese * 0.4
                innen.x = 100 + seite * 6 // almost joined
            case 4:
                ctrl.y = 68 + hoch
                aussen.y = 80 + hoch
            case 7:
                aussen = P(100 + seite * 26, 80 + hoch)
                innen.x = 100 + seite * 13
                ctrl.y = 76 + hoch
            default:
                break
            }
            switch brauenStil {
            case 5:
                let busch = Path { p in
                    p.move(to: P(innen.x, innen.y + 3))
                    p.addQuadCurve(to: aussen, control: P(ctrl.x, ctrl.y + 5))
                    p.addQuadCurve(to: P(innen.x, innen.y - 5), control: P(ctrl.x, ctrl.y - 3))
                    p.closeSubpath()
                }
                teil(g, busch, farbe, 2)
            case 6:
                let spitze = P(100 + seite * 23, 74 + hoch)
                let knick = Path { p in
                    p.move(to: innen)
                    p.addLine(to: spitze)
                    p.addLine(to: aussen)
                }
                linie(g, knick, farbe.farbe, 4.5)
            default:
                linie(g, bogen(aussen, innen, ctrl), farbe.farbe.opacity(brauenStil == 7 ? 0.85 : 1), dicken[brauenStil])
            }
        }
    }

    func augen(_ g: GraphicsContext) {
        let form = augenAusdruck
        var offen = true
        if case .zu = form { offen = false }
        if case .froh = form { offen = false }
        if (offen && abz.contains("herzaugen")) || z == .verliebt {
            let s: CGFloat = 10 + 1.5 * w(8)
            for x in [CGFloat(80), 120] { teil(g, herzPfad(P(x, 98), s), Pal.rose, 2.5) }
            return
        }
        let blinzelt = !statisch && zyklus(4.2, 1.3) < 0.035
        let seiten: [(x: CGFloat, aussen: CGFloat)] = [(80, -1), (120, 1)]
        for s in seiten {
            let c = P(s.x, 98)
            if z == .zwinkert && s.aussen > 0 {
                geschlossen(g, c, s.aussen, froh: true)
                continue
            }
            if blinzelt && offen {
                geschlossen(g, c, s.aussen, froh: false)
                continue
            }
            switch form {
            case .zu: geschlossen(g, c, s.aussen, froh: false)
            case .froh: geschlossen(g, c, s.aussen, froh: true)
            case .offen(let gross): offenesAuge(g, c, s.aussen, gross: gross, lid: false)
            case .muede: offenesAuge(g, c, s.aussen, gross: false, lid: true)
            case .schock: schockAuge(g, c)
            case .boese:
                offenesAuge(g, c, s.aussen, gross: false, lid: false)
                // Slanted lid: the inner corner closes a little.
                let lid = Path { p in
                    p.move(to: P(c.x - s.aussen * 12, c.y - 14))
                    p.addLine(to: P(c.x + s.aussen * 12, c.y - 14))
                    p.addLine(to: P(c.x + s.aussen * 12, c.y - 10))
                    p.addLine(to: P(c.x - s.aussen * 12, c.y - 1))
                    p.closeSubpath()
                }
                g.fill(lid, with: .color(haut.farbe))
                linie(g, strich(P(c.x - s.aussen * 11, c.y - 1.5), P(c.x + s.aussen * 11, c.y - 10)), Pal.tinte.farbe, 3)
            }
        }
    }

    /// Shocked: big white eye, tiny pupil.
    func schockAuge(_ g: GraphicsContext, _ c: CGPoint) {
        let weiss = oval(c, 12, 15)
        g.fill(weiss, with: .color(.white))
        linie(g, weiss, Pal.tinte.farbe, 2.6)
        g.fill(kreis(P(c.x, c.y + 1), 2.6), with: .color(Pal.tinte.farbe))
    }

    func geschlossen(_ g: GraphicsContext, _ c: CGPoint, _ aussen: CGFloat, froh: Bool) {
        let dy: CGFloat = froh ? -8 : 6
        linie(g, bogen(P(c.x - 9, c.y + 1), P(c.x + 9, c.y + 1), P(c.x, c.y + 1 + dy)), Pal.tinte.farbe, 3.2)
        if wimpern {
            let ende = P(c.x + aussen * 9, c.y + 1)
            linie(g, strich(ende, P(ende.x + aussen * 4, ende.y - 3)), Pal.tinte.farbe, 2.2)
        }
    }

    /// Eye shapes: size, tilt of the outer corner, lid cover and a liner wing.
    static let augenMasse: [(sx: CGFloat, sy: CGFloat, kipp: Double, deckel: CGFloat, strich: Bool)] = [
        (1, 1, 0, 0, false),          // Rund
        (1.12, 0.78, 6, 0, false),    // Mandel
        (1.15, 1.15, 0, 0, false),    // Groß
        (1.05, 0.6, 0, 0, false),     // Schmal
        (1.05, 0.95, 0, 0.38, false), // Verträumt
        (1.05, 0.85, -9, 0.12, false),// Hängend
        (1.1, 0.8, 12, 0, true),      // Katzenauge
        (0.8, 0.8, 0, 0, false),      // Klein
        (1.1, 0.86, 4, 0.16, false),  // Scharf (fix round 3: crisp, relaxed, not sleepy)
    ]

    /// `aussen` is -1 for the left eye and 1 for the right one (side of the outer corner).
    func offenesAuge(_ g: GraphicsContext, _ c: CGPoint, _ aussen: CGFloat, gross: Bool, lid: Bool) {
        let f = Self.augenMasse[augenform]
        let tinte = Pal.tinte.farbe
        let rx: CGFloat = (gross ? 11 : 9.5) * f.sx
        let ry: CGFloat = (gross ? 14 : 12) * f.sy
        var e = g
        e.translateBy(x: c.x, y: c.y)
        e.rotate(by: .degrees(-f.kipp * Double(aussen)))
        let weiss = oval(.zero, rx, ry)
        e.fill(weiss, with: .color(.white))
        var h = e
        h.clip(to: weiss)
        let b = blick
        let ic = P(b.x * 3, 2 + b.y * 3)
        let ir: CGFloat = 7.5 * min(f.sx, 1.05)
        h.fill(kreis(ic, ir), with: .color(iris.farbe))
        h.fill(kreis(ic, ir * 0.5), with: .color(tinte))
        h.fill(kreis(P(ic.x - 2.5, ic.y - 3), 2.3), with: .color(.white))
        let deckel: CGFloat = lid ? 1.05 : f.deckel * 2
        if deckel > 0 { h.fill(box(-rx, -ry, rx * 2, ry * deckel), with: .color(haut.farbe)) }
        linie(e, weiss, tinte.opacity(0.5), 1.6)
        let kante: CGFloat = deckel > 0 ? -ry + ry * deckel : -1
        let bogenY: CGFloat = deckel > 0 ? kante + 1 : -2 * ry + 1
        // "Scharf" gets a stronger upper lid line.
        linie(e, bogen(P(-rx, kante), P(rx, kante), P(0, bogenY)), tinte, augenform == 8 ? 4.2 : 3.2)
        let ax: CGFloat = aussen * rx
        if wimpern {
            let y1: CGFloat = min(-ry * 0.45, kante)
            linie(e, strich(P(ax * 0.92, y1), P(ax * 0.92 + aussen * 5, y1 - 4)), tinte, 2.2)
            let y2: CGFloat = min(-ry * 0.78, kante)
            linie(e, strich(P(ax * 0.66, y2), P(ax * 0.66 + aussen * 4, y2 - 5)), tinte, 2.2)
        }
        if f.strich {
            let y: CGFloat = -ry * 0.3
            linie(e, strich(P(ax * 0.9, y), P(ax + aussen * 7, y - 5)), tinte, 3)
        }
    }

    func nase(_ g: GraphicsContext) {
        let k = haut.kontur
        switch nasenStil {
        case 1:
            g.fill(oval(P(100, 114), 5.5, 4.5), with: .color(haut.mal(0.84).farbe))
            g.fill(kreis(P(98, 112), 1.5), with: .color(.white.opacity(0.6)))
        case 2:
            let p = Path { p in
                p.move(to: P(101, 100))
                p.addLine(to: P(104, 113))
                p.addQuadCurve(to: P(96, 116), control: P(106, 118))
            }
            linie(g, p, k, 2.5)
        case 3:
            linie(g, bogen(P(91, 114), P(109, 114), P(100, 121)), k, 2.5)
            for x in [CGFloat(95), 105] { g.fill(kreis(P(x, 115), 1.5), with: .color(k)) }
        case 4:
            linie(g, kreis(P(100, 112), 3.5), k, 2)
            for x in [CGFloat(97), 103] { g.fill(kreis(P(x, 116.5), 1.2), with: .color(k)) }
        case 5:
            let p = Path { p in
                p.move(to: P(99, 98))
                p.addLine(to: P(97, 114))
                p.addQuadCurve(to: P(104, 115), control: P(98, 119))
            }
            linie(g, p, k, 2.5)
        default:
            linie(g, bogen(P(96, 115), P(104, 115), P(100, 119)), k, 2.5)
        }
    }

    var lippe: FigurFarbe? {
        switch mundStil {
        case 3: haut.mix(Pal.rose, 0.4).mal(0.9)
        case 6: FigurFarbe(0xE56B8A)
        case 7: FigurFarbe(0xC8283F)
        case 8: FigurFarbe(0xF0B8BA) // Lippen hellrosa (Ahmed), pale
        default: nil
        }
    }

    func volleLippen(_ g: GraphicsContext, _ f: FigurFarbe) {
        let oben = Path { p in
            p.move(to: P(88, 128))
            p.addQuadCurve(to: P(100, 126), control: P(94, 121))
            p.addQuadCurve(to: P(112, 128), control: P(106, 121))
            p.addQuadCurve(to: P(88, 128), control: P(100, 131))
            p.closeSubpath()
        }
        let unten = Path { p in
            p.move(to: P(89, 129))
            p.addQuadCurve(to: P(111, 129), control: P(100, 141))
            p.addQuadCurve(to: P(89, 129), control: P(100, 132))
            p.closeSubpath()
        }
        teil(g, unten, f, 1.5)
        teil(g, oben, f, 1.5)
        linie(g, bogen(P(88, 128), P(112, 128), P(100, 132)), Pal.tinte.farbe, 2)
        g.fill(oval(P(103, 134), 3, 1.5), with: .color(.white.opacity(0.4)))
    }

    func mund(_ g: GraphicsContext) {
        let tinte = Pal.tinte.farbe
        let rand: Color = lippe?.mal(0.75).farbe ?? tinte
        switch mundForm {
        case .laecheln:
            if let l = lippe {
                if mundStil == 8 {
                    // Fix round 5: Ahmed's lips smaller and less prominent.
                    var k = g
                    k.translateBy(x: 100, y: 131)
                    k.scaleBy(x: 0.78, y: 0.78)
                    k.translateBy(x: -100, y: -131)
                    volleLippen(k, l)
                } else {
                    volleLippen(g, l)
                }
                return
            }
            switch mundStil {
            case 1:
                let m = Path { p in
                    p.move(to: P(90, 127))
                    p.addLine(to: P(110, 127))
                    p.addQuadCurve(to: P(90, 127), control: P(100, 140))
                    p.closeSubpath()
                }
                g.fill(m, with: .color(.white))
                linie(g, m, tinte, 2.5)
            case 2:
                linie(g, bogen(P(91, 130), P(111, 126), P(101, 136)), tinte, 3)
                linie(g, strich(P(112, 124), P(113, 128)), tinte, 2)
            case 4:
                linie(g, bogen(P(93, 129), P(107, 129), P(100, 133)), tinte, 2.5)
            case 5:
                linie(g, bogen(P(84, 126), P(116, 126), P(100, 141)), tinte, 3)
                linie(g, bogen(P(82, 123), P(83, 130), P(80, 126)), tinte, 2)
                linie(g, bogen(P(118, 123), P(117, 130), P(120, 126)), tinte, 2)
            default:
                linie(g, bogen(P(90, 128), P(110, 128), P(100, 137)), tinte, 3)
            }
        case .grinsen:
            let breit: CGFloat = mundStil == 5 ? 4 : 0
            let m = Path { p in
                p.move(to: P(86 - breit, 126))
                p.addLine(to: P(114 + breit, 126))
                p.addQuadCurve(to: P(86 - breit, 126), control: P(100, 150))
                p.closeSubpath()
            }
            g.fill(m, with: .color(Pal.mundInnen.farbe))
            var h = g
            h.clip(to: m)
            h.fill(oval(P(100, 142), 9, 6), with: .color(Pal.zunge.farbe))
            h.fill(box(80, 124, 40, 5), with: .color(.white))
            linie(g, m, rand, lippe == nil ? 2.5 : 3.5)
        case .offen(let r):
            let o = oval(P(100, 132), r * 0.8, r)
            g.fill(o, with: .color(Pal.mundInnen.farbe))
            linie(g, o, rand, lippe == nil ? 2.5 : 3.5)
        case .neutral:
            linie(g, strich(P(92, 131), P(108, 131)), rand, lippe == nil ? 3 : 4)
        case .traurig:
            linie(g, bogen(P(91, 134), P(109, 134), P(100, 125)), rand, lippe == nil ? 3 : 4)
        case .kuss:
            let f = lippe ?? Pal.rose
            teil(g, oval(P(101, 131), 6, 5), f, 2.5)
            linie(g, strich(P(96, 131), P(106, 131)), f.kontur, 1.5)
        case .schmoll:
            let f = lippe ?? haut.mix(Pal.rose, 0.45)
            teil(g, oval(P(100, 133), 7, 4.5), f, 2.2)
            linie(g, bogen(P(94, 133), P(106, 133), P(100, 130)), rand, 1.6)
        case .wellig:
            let welle = Path { p in
                p.move(to: P(90, 130))
                p.addQuadCurve(to: P(96, 130), control: P(93, 127))
                p.addQuadCurve(to: P(102, 130), control: P(99, 133))
                p.addQuadCurve(to: P(108, 130), control: P(105, 127))
                p.addQuadCurve(to: P(112, 129), control: P(110, 132))
            }
            linie(g, welle, rand, 2.6)
        case .heulen:
            let m = Path { p in
                p.move(to: P(86, 140))
                p.addQuadCurve(to: P(114, 140), control: P(100, 118))
                p.addQuadCurve(to: P(86, 140), control: P(100, 148))
                p.closeSubpath()
            }
            g.fill(m, with: .color(Pal.mundInnen.farbe))
            var h = g
            h.clip(to: m)
            h.fill(oval(P(100, 145), 8, 5), with: .color(Pal.zunge.farbe))
            linie(g, m, rand, lippe == nil ? 2.5 : 3.5)
        case .zaehne:
            let m = box(87, 125, 26, 12, 5)
            g.fill(m, with: .color(.white))
            for x in [CGFloat(93.5), 100, 106.5] { linie(g, strich(P(x, 125), P(x, 137)), Pal.tinte.farbe.opacity(0.5), 1.2) }
            linie(g, strich(P(87, 131), P(113, 131)), Pal.tinte.farbe.opacity(0.5), 1.2)
            linie(g, m, rand, 2.5)
        case .schief:
            linie(g, bogen(P(93, 132), P(108, 128), P(101, 133)), rand, 2.8)
        }
    }

    /// Fix round 3: chin hair on its own (combines with every mustache), medium brown like
    /// Ahmed's mustache. 1 = light, sparse goatee; 2 = fuller chin patch.
    func kinnbartZeichnen(_ g: GraphicsContext) {
        guard kinnbart > 0 else { return }
        // Fix round 5: only faint stubble, a few tiny soft dots, no shape, no outline.
        let deckung: Double = kinnbart == 2 ? 0.4 : 0.22
        let punkte: [CGPoint] = [P(95, 145), P(100, 148), P(105, 145), P(98, 152), P(103, 151), P(92, 149), P(108, 149)]
        for c in punkte.prefix(kinnbart == 2 ? 7 : 5) {
            g.fill(kreis(c, 0.75), with: .color(FigurFarbe(0x6B4A36).farbe.opacity(deckung)))
        }
    }

    /// Fix round 5: the mustaches 14/15 sit on top of the lips, so they are drawn after the mouth.
    /// 14: two soft lobes meeting under the nose, reaching the mouth corners; 15: trimmed, curled ends.
    func schnurrbartVorn(_ g: GraphicsContext) {
        guard bart == 14 || bart == 15 else { return }
        let braun = FigurFarbe(0x5C3E2C)
        var h = g
        h.clip(to: kopfPfad)
        if bart == 14 {
            for seite in [CGFloat(-1), 1] {
                let lappen = Path { p in
                    p.move(to: P(100, 119))
                    p.addQuadCurve(to: P(100 + seite * 15, 126), control: P(100 + seite * 9, 117))
                    p.addQuadCurve(to: P(100, 123), control: P(100 + seite * 8, 126))
                    p.closeSubpath()
                }
                h.fill(lappen, with: .color(braun.farbe))
            }
            return
        }
        let form = Path { p in
            p.move(to: P(100, 120.5))
            p.addQuadCurve(to: P(84, 126.5), control: P(90, 119))
            p.addQuadCurve(to: P(81, 123.5), control: P(81.5, 126.5))
            p.addQuadCurve(to: P(100, 124.5), control: P(88, 127))
            p.addQuadCurve(to: P(119, 123.5), control: P(112, 127))
            p.addQuadCurve(to: P(116, 126.5), control: P(118.5, 126.5))
            p.addQuadCurve(to: P(100, 120.5), control: P(110, 119))
            p.closeSubpath()
        }
        teil(h, form, braun, 1.2)
    }

    /// Beard area: the head minus the face above `innen` (works for every face shape).
    func bartZone(_ g: GraphicsContext, innen: CGFloat, deckung: Double) {
        let gesichtsFeld = Path { p in
            p.move(to: P(52, 40))
            p.addLine(to: P(148, 40))
            p.addLine(to: P(148, 100))
            p.addCurve(to: P(100, innen + 12), control1: P(146, innen), control2: P(124, innen + 12))
            p.addCurve(to: P(52, 100), control1: P(76, innen + 12), control2: P(54, innen))
            p.closeSubpath()
        }
        var h = g
        h.clip(to: gesichtsFeld, options: .inverse)
        h.opacity = deckung
        h.fill(Path(CGRect(x: 20, y: 92, width: 160, height: 90)), with: .color(haar.farbe))
        if deckung >= 1 {
            linie(h, gesichtsFeld, haar.kontur, 5)
            linie(h, kopfPfad, haar.kontur, 7)
        }
    }

    func bartZeichnen(_ g: GraphicsContext) {
        guard bart > 0 else { return }
        var h = g
        h.clip(to: kopfPfad)
        let schnurr = Path { p in
            p.move(to: P(100, 122))
            p.addQuadCurve(to: P(82, 130), control: P(88, 118))
            p.addQuadCurve(to: P(100, 126), control: P(90, 128))
            p.addQuadCurve(to: P(118, 130), control: P(110, 128))
            p.addQuadCurve(to: P(100, 122), control: P(112, 118))
            p.closeSubpath()
        }
        switch bart {
        case 1:
            bartZone(h, innen: 130, deckung: 0.22)
            h.fill(schnurr, with: .color(haar.farbe.opacity(0.22)))
        case 2:
            teil(h, schnurr, haar, 2)
        case 3:
            teil(h, oval(P(100, 144), 11, 8), haar, 2)
            teil(h, schnurr, haar, 2)
        case 4:
            bartZone(h, innen: 118, deckung: 1)
            teil(h, schnurr, haar, 2)
        case 5:
            let spitz = Path { p in
                p.move(to: P(92, 139))
                p.addQuadCurve(to: P(100, 156), control: P(92, 150))
                p.addQuadCurve(to: P(108, 139), control: P(108, 150))
                p.closeSubpath()
            }
            teil(h, spitz, haar, 2)
        case 6:
            bartZone(h, innen: 136, deckung: 1)
        case 7:
            bartZone(h, innen: 118, deckung: 1)
            let lang = Path { p in
                p.move(to: P(66, 136))
                p.addQuadCurve(to: P(100, 186), control: P(70, 182))
                p.addQuadCurve(to: P(134, 136), control: P(130, 182))
                p.closeSubpath()
            }
            teil(g, lang, haar, 2.5)
            teil(h, schnurr, haar, 2)
        case 9:
            // Fu-Manchu: mustache with two long strands drooping past the jaw.
            teil(h, schnurr, haar, 2)
            for seite in [CGFloat(-1), 1] {
                let strang = strich(P(100 + seite * 15, 128), P(100 + seite * 12, 152))
                linie(h, strang, haar.kontur, 4.5)
                linie(h, strang, haar.farbe, 2.5)
            }
        case 10:
            // Anker-Bart: mustache plus a thin chin stripe (anchor beard).
            teil(h, schnurr, haar, 2)
            teil(h, box(97, 128, 6, 24, 3), haar, 1.5)
        case 11:
            bartZone(h, innen: 126, deckung: 0.55)
            teil(h, schnurr, haar, 2)
        case 12:
            // Backenbart mit Schnurrbart: sideburns connected to the mustache, no chin.
            for x in [CGFloat(42), 146] { h.fill(box(x, 80, 14, 46, 4), with: .color(haar.farbe)) }
            teil(h, schnurr, haar, 2)
        case 13:
            // Feiner Schnurrbart (Ahmed's Bitmoji): thin, with little curled tips.
            for seite in [CGFloat(-1), 1] {
                let oberlippe = bogen(P(100, 123.5), P(100 + seite * 16, 127), P(100 + seite * 8, 120.5))
                let spitze = bogen(P(100 + seite * 16, 127), P(100 + seite * 20, 121.5), P(100 + seite * 21, 127.5))
                // Fix round 2: really thin and subtle, like the Bitmoji.
                linie(h, oberlippe, haar.farbe.opacity(0.85), 2)
                linie(h, spitze, haar.farbe.opacity(0.85), 1.4)
            }
        case 14, 15:
            break // drawn after the mouth, see `schnurrbartVorn`
        default:
            for x in [CGFloat(42), 146] { h.fill(box(x, 80, 12, 40, 4), with: .color(haar.farbe)) }
        }
    }

    // MARK: Hair
}
