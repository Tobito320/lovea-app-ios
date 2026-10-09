import SwiftUI

extension Zeichner {

    func poseGanz(_ m: Masse) -> (l: Arm, r: Arm) {
        let lx: CGFloat = 100 - m.s + 6
        let rx: CGFloat = 100 + m.s - 6
        let y = m.schulterY
        let wiege: CGFloat = statisch ? 0 : w(1.3) * 1.5
        let restL = Arm(P(lx - 6, y + 50), P(lx - 4 + wiege, y + 92))
        let restR = Arm(P(rx + 6, y + 50), P(rx + 4 - wiege, y + 92))
        // p65: seated on the stage. Sofa: hands rest on the thighs, not clasped. Bed edge: hands on the mattress beside the hips.
        if let p = figurPose, p.sitzt, z == .ruhig {
            if p == .sitzenSofa {
                return (Arm(P(lx - 6, y + 52), P(lx + 4, y + 100 + wiege)), Arm(P(rx + 6, y + 52), P(rx - 4, y + 100 + wiege)))
            }
            return (Arm(P(lx - 10, y + 52), P(lx - 14, y + 90 + wiege)), Arm(P(rx + 10, y + 52), P(rx + 14, y + 90 + wiege)))
        }
        switch z {
        case .imChat:
            let welle: CGFloat = zyklus(5) < 0.45 ? w(9) * 7 : 0
            return (restL, Arm(P(rx + 18, y + 2), P(rx + 22 + welle, y - 36)))
        case .tippt, .liest, .spielt, .karte, .schautBild, .laedt:
            let tipp: CGFloat = z == .tippt ? w(16) * 1.5 : 0
            return (Arm(P(lx - 4, y + 48), P(94, y + 50 + tipp)), Arm(P(rx + 4, y + 48), P(106, y + 50 - tipp)))
        case .kamera:
            return (restL, Arm(P(rx + 16, y + 16), P(rx + 14, y - 30)))
        case .sprache:
            return (restL, Arm(P(rx + 6, y + 40), P(112, y - 18)))
        case .gut, .pokal, .morgen, .lacht, .anstossen:
            let s: CGFloat = z == .morgen ? w(1.6) * 4 : 0
            return (Arm(P(lx - 18, y - 2 - s), P(lx - 22, y - 40 - s)), Arm(P(rx + 18, y - 2 - s), P(rx + 22, y - 40 - s)))
        case .naehe:
            let o: CGFloat = w(2.4) * 4
            return (Arm(P(lx - 24, y + 26 - o), P(lx - 44, y + 10 - o)), Arm(P(rx + 24, y + 26 - o), P(rx + 44, y + 10 - o)))
        case .kuss:
            return (restL, Arm(P(rx + 8, y + 36), P(108, y - 24)))
        case .herz:
            return (Arm(P(lx - 6, y + 44), P(93, y + 32)), Arm(P(rx + 6, y + 44), P(107, y + 32)))
        case .gym:
            if let g = gymGeste { return gymArme(g, m, obenVersatz(haltung, m)) }
            let c: CGFloat = (1 + w(3.2)) / 2
            return (restL, Arm(P(rx + 4, y + 50), P(rx + 8 - c * 10, y + 92 - c * 52)))
        case .supermarkt:
            return (Arm(P(lx - 4, y + 50), P(78, y + 70)), Arm(P(rx + 4, y + 50), P(122, y + 70)))
        case .laeuft:
            // Opposite to the legs: when the left leg lifts, the right arm swings forward (up and in).
            let s: CGFloat = statisch ? 0.9 : w(7)
            let vl: CGFloat = max(0, -s)
            let vr: CGFloat = max(0, s)
            return (Arm(P(lx - 6 + vl * 6, y + 48 - vl * 6), P(lx - 2 + vl * 16, y + 88 - vl * 30)), Arm(P(rx + 6 - vr * 6, y + 48 - vr * 6), P(rx + 2 - vr * 16, y + 88 - vr * 30)))
        case .rennt:
            let s = w(12)
            return (Arm(P(lx - 12, y + 40), P(lx + 4, y + 30 + s * 14)), Arm(P(rx + 12, y + 40), P(rx - 4, y + 30 - s * 14)))
        case .rad:
            return (Arm(P(lx - 8, y + 40), P(66, y + 58)), Arm(P(rx + 8, y + 40), P(134, y + 58)))
        case .scooter:
            let lenk = scooterLenkerY(m)
            return (Arm(P(lx - 8, y + 46), P(64, lenk)), Arm(P(rx + 8, y + 46), P(136, lenk)))
        case .faehrt, .fahrschule:
            return (Arm(P(lx - 6, y + 44), amSteuer(200, y)), Arm(P(rx + 6, y + 44), amSteuer(340, y)))
        case .arbeit:
            let tipp: CGFloat = w(16) * 1.5
            return (Arm(P(lx - 6, y + 48), P(90, y + 78 + tipp)), Arm(P(rx + 6, y + 48), P(110, y + 78 - tipp)))
        case .zuhause, .schule, .schautVideo, .ruhe, .zug:
            return (Arm(P(lx - 6, y + 48), P(86, y + 84)), Arm(P(rx + 6, y + 48), P(114, y + 84)))
        case .zeichnet:
            // Brief Z: the left hand holds the tablet's edge, the right one follows the pencil tip.
            let griff = P(-31, 10).applying(tablett(m))
            let spitze = stiftSpitze(m)
            return (Arm(P(lx - 8, y + 54), griff), Arm(P(rx + 10, y + 52), P(spitze.x + 9, spitze.y + 11)))
        // Mimik (Runde 3); the head space maps to y + (hy - 133.6) * 0.8 here.
        case .zwinkert:
            return (Arm(P(lx - 16, y + 50), P(lx + 4, y + 88)), Arm(P(rx + 24, y + 26), P(rx + 20, y - 8)))
        case .verliebt:
            return (Arm(P(lx - 2, y + 44), P(94, y - 6)), Arm(P(rx + 2, y + 44), P(106, y - 6)))
        case .sauer:
            return (Arm(P(lx - 4, y + 50), P(rx + 2, y + 32)), Arm(P(rx + 4, y + 42), P(lx - 2, y + 58)))
        case .schmollt:
            return (Arm(P(lx - 20, y + 46), P(lx + 2, y + 88)), Arm(P(rx + 20, y + 46), P(rx - 2, y + 88)))
        case .verlegen:
            return (restL, Arm(P(rx + 22, y - 8), P(rx + 6, y - 62)))
        case .muede:
            return (Arm(P(lx - 8, y + 20), P(86, y - 52)), Arm(P(rx + 8, y + 50), P(rx - 10, y + 30)))
        case .ueberrascht:
            let s: CGFloat = w(3) * 2
            return (Arm(P(lx - 14, y + 20), P(lx - 8, y - 30 + s)), Arm(P(rx + 14, y + 20), P(rx + 8, y - 30 + s)))
        case .lachtTraenen:
            return (Arm(P(lx - 6, y + 48), P(92, y + 70)), Arm(P(rx + 10, y + 10), P(120, y - 50)))
        case .weint:
            let s: CGFloat = w(10) * 1.5
            return (Arm(P(lx - 6, y + 20), P(88, y - 50 + s)), Arm(P(rx + 6, y + 20), P(112, y - 50 - s)))
        case .denkt:
            return (Arm(P(lx - 4, y + 54), P(rx, y + 40)), Arm(P(rx + 10, y + 40), P(110, y - 8)))
        case .feiert:
            let s: CGFloat = w(6) * 5
            return (Arm(P(lx - 18, y - 2), P(lx - 26, y - 44 + s)), Arm(P(rx + 18, y - 2), P(rx + 26, y - 44 - s)))
        case .schockiert:
            return (Arm(P(lx - 12, y + 24), P(78, y - 36)), Arm(P(rx + 12, y + 24), P(122, y - 36)))
        case .daumen:
            return (restL, Arm(P(rx + 22, y + 32), P(rx + 16, y + 2)))
        case .tanzt:
            let s = w(5)
            return (Arm(P(lx - 16, y + 10 - s * 8), P(lx - 30, y - 24 + s * 14)), Arm(P(rx + 16, y + 10 + s * 8), P(rx + 30, y - 24 - s * 14)))
        default:
            return (restL, restR)
        }
    }

    func amSteuer(_ grad: Double, _ y: CGFloat) -> CGPoint {
        let r = (grad + lenkWinkel) * Double.pi / 180
        return P(100 + 24 * CGFloat(cos(r)), y + 62 + 24 * CGFloat(sin(r)))
    }

    func kleinesHandy(_ g: GraphicsContext, _ c: CGPoint) {
        var h = g
        h.translateBy(x: c.x, y: c.y)
        h.scaleBy(x: 0.55, y: 0.55)
        handy(h, .zero, rueckseite: true)
    }

    func handRequisite(_ g: GraphicsContext, _ arme: (l: Arm, r: Arm), _ m: Masse) {
        let y = m.schulterY
        switch z {
        case .tippt, .liest, .spielt, .karte, .schautBild, .laedt:
            kleinesHandy(g, P(100, y + 40))
        case .zeichnet:
            zeichenStift(g, m)
        case .kamera:
            kleinesHandy(g, P(arme.r.hand.x, arme.r.hand.y - 12))
        case .sprache:
            kleinesHandy(g, P(arme.r.hand.x + 2, arme.r.hand.y - 8))
        case .gym:
            if gymGeste != nil {
                gymInHaenden(g, arme, m)
            } else {
                let h = arme.r.hand
                let stange = strich(P(h.x - 13, h.y), P(h.x + 13, h.y))
                linie(g, stange, Pal.silber.kontur, 5)
                linie(g, stange, Pal.silber.farbe, 3)
                teil(g, box(h.x - 19, h.y - 8, 6, 16, 2), Pal.dunkel, 2)
                teil(g, box(h.x + 13, h.y - 8, 6, 16, 2), Pal.dunkel, 2)
            }
        case .herz:
            let p = Double(zyklus(1.0))
            let a1 = exp(-pow((p - 0.1) / 0.06, 2))
            let a2 = exp(-pow((p - 0.3) / 0.06, 2))
            let schlag = CGFloat(1 + 0.14 * a1 + 0.09 * a2)
            teil(g, herzPfad(P(100, y + 24), 14 * schlag), Pal.rose, 2.5)
        case .zwinkert:
            fingerZeigt(g, arme.r.hand, richtung: P(-6, -15), s: 0.66)
        case .daumen:
            daumenHoch(g, arme.r.hand, s: 0.66)
        case .muede:
            kaffee(g, P(arme.r.hand.x, arme.r.hand.y - 9), s: 0.66)
        default:
            break
        }
    }

    // MARK: Scenes

    func szeneHinten(_ g: GraphicsContext, _ m: Masse, _ oben: CGFloat) {
        let sitz = m.hueftY + oben
        switch z {
        case .zuhause, .schautVideo, .ruhe:
            teil(g, box(6, sitz - 112, 188, 118, 30), Pal.sofa)
            teil(g, box(16, sitz - 102, 82, 98, 22), Pal.sofa.mix(Pal.weiss, 0.15))
            teil(g, box(102, sitz - 102, 82, 98, 22), Pal.sofa.mix(Pal.weiss, 0.15))
            for x in [CGFloat(22), 178] { linie(g, strich(P(x, sitz + 40), P(x, 384)), Pal.holz.kontur, 6) }
            teil(g, box(0, sitz - 6, 200, 48, 16), Pal.sofa.mal(0.92))
            teil(g, box(-10, sitz - 54, 36, 92, 14), Pal.sofa.mal(0.85))
            teil(g, box(174, sitz - 54, 36, 92, 14), Pal.sofa.mal(0.85))
        case .zug:
            // Brief G bugfix: a train seat by the window, the landscape rushing past behind the glass.
            let fenster = box(10, sitz - 214, 180, 118, 16)
            teil(g, fenster, Pal.silber, 3)
            var glas = g
            glas.clip(to: box(18, sitz - 206, 164, 102, 10))
            glas.fill(box(18, sitz - 206, 164, 102), with: .linearGradient(Gradient(colors: [Pal.himmel.farbe, Pal.weiss.farbe]), startPoint: P(0, sitz - 206), endPoint: P(0, sitz - 104)))
            glas.fill(box(18, sitz - 140, 164, 36), with: .color(Pal.gruen.farbe.opacity(0.8)))
            for i in 0..<5 {
                let x: CGFloat = 200 - zyklus(0.9, Double(i) * 0.19) * 220
                let y: CGFloat = sitz - 190 + CGFloat(i) * 17
                linie(glas, strich(P(x, y), P(x + 34, y)), .white.opacity(0.7), 3)
            }
            teil(g, box(24, sitz - 104, 152, 110, 22), Pal.band)
            teil(g, box(14, sitz - 6, 172, 36, 12), Pal.band.mal(0.85))
        case .zeichnet:
            // Brief Z: a round knitted pouf to sit on while drawing.
            let pouf = FigurFarbe(0xF2B8A2)
            teil(g, box(38, sitz - 10, 124, Masse.fussY - sitz + 4, 30), pouf)
            for x in stride(from: CGFloat(54), through: 146, by: 15) { linie(g, strich(P(x, sitz + 4), P(x, Masse.fussY - 10)), pouf.mal(0.9).farbe, 2.5) }
            teil(g, oval(P(100, sitz - 8), 60, 11), pouf.mix(Pal.weiss, 0.25), 3)
        case .schule, .arbeit:
            for x in [CGFloat(74), 126] {
                let fuss: CGFloat = x < 100 ? x - 6 : x + 6
                linie(g, strich(P(x, sitz + 8), P(fuss, 384)), Pal.holz.kontur, 5)
            }
            teil(g, box(64, sitz - 2, 72, 12, 6), Pal.holz)
        default:
            break
        }
    }

    func vorArmen(_ g: GraphicsContext, _ u: GraphicsContext, _ m: Masse, _ oben: CGFloat) {
        let sY = m.schulterY
        let sitz = m.hueftY + oben
        switch z {
        case .gym:
            gymVorArmen(g, m, oben)
        case .scooter:
            scooterLenker(g, m)
        case .rad:
            let lenkY: CGFloat = sY + oben + 58
            let reifen = oval(P(100, 336), 8, 38)
            linie(g, reifen, Pal.dunkel.kontur, 10)
            linie(g, reifen, Pal.dunkel.farbe, 6)
            let gabel = strich(P(100, lenkY + 4), P(100, 336))
            linie(g, gabel, Pal.silber.kontur, 7)
            linie(g, gabel, Pal.silber.farbe, 4)
            let lenker = bogen(P(56, lenkY - 6), P(144, lenkY - 6), P(100, lenkY + 10))
            linie(g, lenker, Pal.dunkel.kontur, 8)
            linie(g, lenker, Pal.silber.farbe, 4.5)
            teil(g, kreis(P(100, lenkY + 12), 6), Pal.gelb, 2)
        case .faehrt, .fahrschule:
            var h = u
            h.translateBy(x: 100, y: sY + 62)
            h.rotate(by: .degrees(lenkWinkel))
            linie(h, kreis(.zero, 24), Pal.dunkel.kontur, 9)
            linie(h, kreis(.zero, 24), Pal.dunkel.farbe, 5.5)
            for grad in [90.0, 210, 330] {
                let r = grad * Double.pi / 180
                linie(h, strich(.zero, P(24 * CGFloat(cos(r)), 24 * CGFloat(sin(r)))), Pal.dunkel.farbe, 4)
            }
            teil(h, kreis(.zero, 7), Pal.dunkel, 2)
        case .supermarkt:
            einkaufswagen(g, griffY: sY + 70)
        case .arbeit:
            // Brief G: at a desk, laptop open, a mug and a small plant beside it.
            schreibtisch(g, platte: sitz - 14)
            teil(g, box(66, sitz - 62, 68, 48, 6), Pal.silber)
            g.fill(herzPfad(P(100, sitz - 38), 6), with: .color(Pal.rose.farbe))
            teil(g, box(58, sitz - 17, 84, 5, 2), Pal.silber.mal(0.85), 2)
            teil(g, box(148, sitz - 34, 16, 20, 4), Pal.weiss, 2)
            linie(g, bogen(P(164, sitz - 29), P(164, sitz - 19), P(172, sitz - 24)), Pal.weiss.kontur, 3)
            for (dx, a) in [(CGFloat(-5), -28.0), (0, 0), (5, 28)] {
                var b = g
                b.translateBy(x: 30 + dx, y: sitz - 30)
                b.rotate(by: .degrees(a))
                teil(b, oval(P(0, -9), 4, 9), Pal.gruen, 1.8)
            }
            teil(g, box(22, sitz - 30, 16, 16, 3), FigurFarbe(0xD9825B), 2)
        case .schule:
            // Brief G: a classroom desk with an open laptop (plain lid, no logo) and a notebook.
            schreibtisch(g, platte: sitz - 14)
            teil(g, box(64, sitz - 60, 72, 46, 6), FigurFarbe(0xD5D8DE))
            teil(g, box(56, sitz - 17, 88, 5, 2), FigurFarbe(0xC2C6CD), 2)
            teil(g, box(146, sitz - 20, 32, 6, 1.5), Pal.rose, 1.5)
            linie(g, strich(P(150, sitz - 24), P(176, sitz - 28)), Pal.gelb.kontur, 3)
        case .ruhe:
            teil(g, box(34, sitz - 34, 132, 72, 24), Pal.decke)
        case .zeichnet:
            tablettZeichnen(u, m)
        default:
            break
        }
    }

    // MARK: Drawing on the tablet (Brief Z)

    /// The tablet on the lap, tilted a little; its screen coordinates are centred (`ZeichenStriche`).
    func tablett(_ m: Masse) -> CGAffineTransform {
        CGAffineTransform(translationX: 100, y: m.schulterY + 70).rotated(by: -0.1)
    }

    /// Still frames stop mid-doodle, the live figure runs through it.
    var zeichenZeit: Double { statisch ? ZeichenStriche.stillZeit : t }

    var zeichenStriche: [ZeichenStriche.Strich] { ZeichenStriche.striche(zusammen: extras.contains(.mitzeichnen)) }

    func stiftSpitze(_ m: Masse) -> CGPoint {
        let s = zeichenStriche
        let eigene = ZeichenStriche.eigene(person: person ?? .annika, zusammen: extras.contains(.mitzeichnen), anzahl: s.count)
        return ZeichenStriche.spitze(zeit: zeichenZeit, striche: s, eigene: eigene).applying(tablett(m))
    }

    /// Dark frame, a bright screen with the doodle growing stroke by stroke, colour swatches on the right.
    func tablettZeichnen(_ g: GraphicsContext, _ m: Masse) {
        var h = g
        h.concatenate(tablett(m))
        teil(h, box(-32, -22, 64, 44, 7), Pal.dunkel, 2.5)
        let schirm = box(-28, -18, 56, 36, 4)
        h.fill(schirm, with: .color(Color(white: 0.985)))
        for (i, f) in [UInt32(0xFF3B5C), 0xF5C542, 0x7FB6E8, 0x5DBB7A].enumerated() {
            h.fill(kreis(P(24, -12 + CGFloat(i) * 8), 2.3), with: .color(FigurFarbe(f).farbe))
        }
        let s = zeichenStriche
        let f = ZeichenStriche.fortschritt(zeit: zeichenZeit, anzahl: s.count)
        var b = h
        b.clip(to: schirm)
        b.opacity = ZeichenStriche.deckkraft(zeit: zeichenZeit)
        for i in s.indices where f[i] > 0 {
            let pfad = Path { p in
                p.move(to: s[i].a)
                p.addCurve(to: s[i].b, control1: s[i].c1, control2: s[i].c2)
            }
            linie(b, pfad.trimmedPath(from: 0, to: f[i]), FigurFarbe(s[i].farbe).farbe, 2.6)
        }
    }

    /// A white pencil from the tip up into the right hand, and a sparkle where a stroke just ended.
    func zeichenStift(_ g: GraphicsContext, _ m: Masse) {
        let spitze = stiftSpitze(m)
        let schaft = strich(P(spitze.x + 3, spitze.y + 3.5), P(spitze.x + 16, spitze.y + 19))
        linie(g, schaft, Pal.weiss.kontur, 6.5)
        linie(g, schaft, Pal.weiss.farbe, 4)
        linie(g, strich(spitze, P(spitze.x + 3, spitze.y + 3.5)), Pal.dunkel.farbe, 2.5)
        var h = g
        h.concatenate(tablett(m))
        for f in ZeichenStriche.funken(zeit: zeichenZeit, striche: zeichenStriche) {
            h.fill(funkel(f.punkt, 2 + 4 * f.staerke), with: .color(FigurFarbe(f.farbe).farbe.opacity(Double(f.staerke))))
        }
    }

    /// A desk in front of the sitting figure (school and work): top at `platte`, a front panel down
    /// to the floor that hides the legs and the stool.
    func schreibtisch(_ g: GraphicsContext, platte: CGFloat) {
        let farben: [UInt32] = [0xC69C6D, 0xF2F2F0, 0x6A432C, 0x2F3136]
        let holz = FigurFarbe(farben[min(max(tisch, 0), farben.count - 1)])
        teil(g, box(14, platte + 8, 172, Masse.fussY - platte - 4, 6), holz.mal(0.85))
        teil(g, box(4, platte, 192, 12, 4), holz)
    }

    func einkaufswagen(_ g: GraphicsContext, griffY: CGFloat) {
        let rand = griffY + 6
        let korb = Path { p in
            p.move(to: P(44, rand))
            p.addLine(to: P(156, rand))
            p.addLine(to: P(146, rand + 64))
            p.addLine(to: P(54, rand + 64))
            p.closeSubpath()
        }
        for x in [CGFloat(60), 140] { linie(g, strich(P(x, rand + 64), P(x, 372)), Pal.silber.kontur, 3.5) }
        for x in [CGFloat(60), 140] { teil(g, kreis(P(x, 376), 6), Pal.dunkel, 2) }
        teil(g, kreis(P(76, rand - 2), 8), Pal.gruen, 2)
        var brot = g
        brot.translateBy(x: 108, y: rand - 8)
        brot.rotate(by: .degrees(18))
        teil(brot, oval(.zero, 7, 18), Pal.brot, 2.5)
        teil(g, kreis(P(132, rand - 2), 8), Pal.rose, 2)
        g.fill(korb, with: .color(Pal.silber.farbe.opacity(0.45)))
        var k = g
        k.clip(to: korb)
        for x in stride(from: CGFloat(48), to: 156, by: 12) { linie(k, strich(P(x, rand), P(x, rand + 64)), Pal.silber.kontur, 2) }
        for y in stride(from: rand + 12, to: rand + 64, by: 12) { linie(k, strich(P(40, y), P(160, y)), Pal.silber.kontur, 2) }
        linie(g, korb, Pal.silber.kontur, 3)
        let griff = strich(P(40, griffY), P(160, griffY))
        linie(g, griff, Pal.rose.kontur, 8)
        linie(g, griff, Pal.rose.farbe, 5)
    }

    /// Convertible seen from the front; drawn over the lower body, the hands stay on the wheel.
    func auto(_ g: GraphicsContext, _ m: Masse, _ oben: CGFloat) {
        guard z == .faehrt || z == .fahrschule else { return }
        let dach: CGFloat = m.schulterY + oben + 80
        for x in [CGFloat(16), 150] { teil(g, box(x, 356, 34, 30, 9), Pal.dunkel) }
        let karosserie = Path { p in
            p.move(to: P(10, 372))
            p.addLine(to: P(10, dach + 28))
            p.addQuadCurve(to: P(40, dach), control: P(12, dach))
            p.addLine(to: P(160, dach))
            p.addQuadCurve(to: P(190, dach + 28), control: P(188, dach))
            p.addLine(to: P(190, 372))
            p.closeSubpath()
        }
        teil(g, karosserie, Pal.rose)
        for x in [CGFloat(42), 158] {
            teil(g, kreis(P(x, dach + 38), 12), Pal.weiss, 2.5)
            g.fill(kreis(P(x, dach + 38), 6), with: .color(Pal.gelb.farbe))
        }
        teil(g, box(72, dach + 44, 56, 18, 7), Pal.dunkel, 2.5)
        teil(g, box(4, 356, 192, 18, 9), Pal.silber)
        if z == .fahrschule {
            teil(g, box(88, dach + 6, 24, 24, 4), Pal.weiss, 2.5)
            text(g, "L", P(100, dach + 18), 18, Pal.rose.farbe)
        }
    }

    /// Runde 4 "Unterwegs": the green Ryde e-scooter from the front, like the bike. The deck lies
    /// under the feet (drawn before the legs), stem and handlebar come in `vorArmen`, the hands on the grips.
    func scooter(_ g: GraphicsContext, _ m: Masse, _ oben: CGFloat) {
        guard z == .scooter else { return }
        let fy = Masse.fussY
        teil(g, oval(P(100, fy + 19), 11, 12), Pal.dunkel, 2.5)
        teil(g, oval(P(100, fy + 19), 4, 5), Pal.silber, 1.5)
        teil(g, box(87, fy + 5, 26, 8, 4), Pal.gruen, 2)
        teil(g, trapez(fy - 6, 66, 134, fy + 12, 56, 144), Pal.gruen, 2.5)
        g.fill(trapez(fy - 3, 72, 128, fy + 5, 66, 134), with: .color(Pal.dunkel.farbe.opacity(0.85)))
        text(g, "RYDE", P(100, fy + 9), 6, .white)
    }

    /// A deck-like trapezoid: top edge at `oben` from `ol` to `or`, bottom edge at `unten` from `ul` to `ur`.
    func trapez(_ oben: CGFloat, _ ol: CGFloat, _ or: CGFloat, _ unten: CGFloat, _ ul: CGFloat, _ ur: CGFloat) -> Path {
        Path { p in
            p.move(to: P(ol, oben))
            p.addLine(to: P(or, oben))
            p.addLine(to: P(ur, unten))
            p.addLine(to: P(ul, unten))
            p.closeSubpath()
        }
    }

    func scooterLenkerY(_ m: Masse) -> CGFloat { m.hueftY - 4 }

    /// Stem with headlight, handlebar with grips and brake levers, and Ahmed's iPhone in a holder
    /// in the middle, screen on (a map with the route).
    func scooterLenker(_ g: GraphicsContext, _ m: Masse) {
        let lenk = scooterLenkerY(m)
        teil(g, trapez(lenk + 4, 94, 106, Masse.fussY + 8, 91, 109), Pal.gruen, 2.5)
        let licht = P(100, lenk + 24)
        g.fill(kreis(licht, 16), with: verlaufRund(licht, 16, [.init(color: .white.opacity(0.75), location: 0), .init(color: .white.opacity(0), location: 1)]))
        teil(g, kreis(licht, 6.5), Pal.weiss, 2)
        g.fill(kreis(licht, 3.5), with: .color(Pal.gelb.mix(Pal.weiss, 0.5).farbe))
        let bar = strich(P(52, lenk), P(148, lenk))
        linie(g, bar, Pal.dunkel.kontur, 8)
        linie(g, bar, Pal.silber.farbe, 4.5)
        for (a, e) in [(P(62, lenk + 2), P(76, lenk + 9)), (P(138, lenk + 2), P(124, lenk + 9))] {
            linie(g, strich(a, e), Pal.dunkel.kontur, 3)
        }
        teil(g, box(44, lenk - 5, 16, 10, 5), Pal.dunkel, 2)
        teil(g, box(140, lenk - 5, 16, 10, 5), Pal.dunkel, 2)
        // Phone holder: clamp on the bar, the phone standing on it with its screen on.
        teil(g, box(95, lenk - 4, 10, 8, 2), Pal.dunkel, 1.5)
        let handy = P(100, lenk - 21)
        g.fill(kreis(handy, 26), with: verlaufRund(handy, 26, [.init(color: Pal.himmel.farbe.opacity(0.45), location: 0), .init(color: Pal.himmel.farbe.opacity(0), location: 1)]))
        teil(g, box(89, lenk - 38, 22, 34, 5), Pal.dunkel, 2)
        g.fill(box(91.5, lenk - 35.5, 17, 29, 3), with: .color(Color(red: 0.86, green: 0.93, blue: 1)))
        var route = Path()
        route.move(to: P(95, lenk - 10))
        route.addQuadCurve(to: P(104, lenk - 30), control: P(106, lenk - 20))
        g.stroke(route, with: .color(Color.loveaRose), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        g.fill(kreis(P(95, lenk - 10), 2.2), with: .color(Color(red: 0.18, green: 0.44, blue: 0.89)))
        linie(g, strich(P(88, lenk - 28), P(88, lenk - 16)), Pal.dunkel.kontur, 2.5)
        linie(g, strich(P(112, lenk - 28), P(112, lenk - 16)), Pal.dunkel.kontur, 2.5)
    }

    func tempoStriche(_ g: GraphicsContext, _ y0: CGFloat) {
        for i in 0..<3 {
            let y: CGFloat = y0 + 30 + CGFloat(i) * 22
            let x: CGFloat = 6 + zyklus(0.5, Double(i) * 0.17) * 10
            linie(g, strich(P(x, y), P(x + 20, y)), Pal.silber.kontur.opacity(0.7), 3.5)
        }
    }
}
