import SwiftUI

extension Zeichner {

    func pose() -> (l: Arm?, r: Arm?) {
        let v = vForm
        let restL = neu == .b ? Arm(v.ellbogenL, v.handL) : Arm(P(42, 216), P(46, 252))
        let restR = neu == .b ? Arm(P(200 - v.ellbogenL.x, v.ellbogenL.y), P(200 - v.handL.x, v.handL.y)) : Arm(P(158, 216), P(154, 252))
        switch z {
        case .imChat:
            let welle: CGFloat = zyklus(5) < 0.45 ? w(9) * 9 : 0
            return (restL, Arm(P(166, 162), P(172 + welle, 108)))
        case .tippt, .arbeit:
            let tipp = w(16) * 2
            let y: CGFloat = z == .tippt ? 208 : 230
            let dx: CGFloat = z == .arbeit ? 12 : 0
            return (Arm(P(52, 226), P(88 - dx, y + tipp)), Arm(P(148, 226), P(112 + dx, y - tipp)))
        case .kamera:
            return (restL, Arm(P(172, 166), P(172, 104)))
        case .sprache:
            return (restL, Arm(P(152, 222), P(126, 166)))
        case .liest:
            return (Arm(P(54, 228), P(76, 210)), Arm(P(146, 228), P(124, 210)))
        case .schautBild:
            return (Arm(P(40, 196), P(58, 138)), Arm(P(160, 196), P(142, 138)))
        case .schautVideo:
            return (Arm(P(46, 224), P(66, 208)), Arm(P(150, 204), P(120, 150)))
        case .zeichnet:
            return (Arm(P(40, 214), P(50, 194)), Arm(P(140, 226), P(80 + w(7) * 6, 186 + w(5.3) * 4)))
        case .karte:
            return (Arm(P(46, 176), P(74, 118)), Arm(P(154, 176), P(126, 118)))
        case .spielt:
            return (restL, Arm(P(152, 220), P(134, 200)))
        case .laedt:
            return (restL, Arm(P(156, 224), P(140, 206)))
        case .nichtStoeren:
            return (Arm(P(34, 222), P(46, 208)), restR)
        case .laeuft:
            // Arms swing opposite to the legs; a still frame shows mid-stride.
            let s: CGFloat = statisch ? 0.9 : w(7)
            let vl: CGFloat = max(0, -s)
            let vr: CGFloat = max(0, s)
            return (Arm(P(44 + vl * 8, 214 - vl * 10), P(54 + vl * 18, 246 - vl * 34)), Arm(P(156 - vr * 8, 214 - vr * 10), P(146 - vr * 18, 246 - vr * 34)))
        case .rennt:
            let s = w(12)
            return (Arm(P(44, 204), P(66, 184 + s * 14)), Arm(P(156, 204), P(134, 184 - s * 14)))
        case .rad:
            return (Arm(P(44, 220), P(60, 200)), Arm(P(156, 220), P(140, 200)))
        case .faehrt, .fahrschule:
            return (Arm(P(44, 226), amLenkrad(200)), Arm(P(156, 226), amLenkrad(340)))
        case .zuhause:
            return (Arm(P(38, 200), P(24, 184)), Arm(P(162, 200), P(176, 184)))
        case .gym:
            let c = (1 + w(3.2)) / 2
            return (Arm(P(34, 212), P(54, 232)), Arm(P(154, 212), P(146 - c * 8, 238 - c * 58)))
        case .schule:
            return (Arm(P(46, 216), P(66, 206)), Arm(P(150, 218), P(122 + w(9) * 4, 202)))
        case .supermarkt:
            return (Arm(P(48, 218), P(70, 200)), Arm(P(152, 218), P(130, 200)))
        case .morgen:
            let s = w(1.6) * 5
            return (Arm(P(34, 124 - s), P(58, 30 - s)), Arm(P(166, 124 - s), P(142, 30 - s)))
        case .abend:
            return (Arm(P(50, 224), P(84, 212)), Arm(P(150, 224), P(116, 212)))
        case .naehe:
            let o = w(2.4) * 5
            return (Arm(P(28, 176 - o), P(14, 136 - o)), Arm(P(172, 176 - o), P(186, 136 - o)))
        case .ruhe:
            return (nil, nil)
        case .kuss:
            return (restL, Arm(P(158, 196), P(122, 140)))
        case .herz:
            return (Arm(P(52, 222), P(80, 204)), Arm(P(148, 222), P(120, 204)))
        case .lacht:
            return (Arm(P(46, 212), P(78, 226)), Arm(P(154, 212), P(122, 226)))
        case .anstossen:
            return (restL, Arm(P(172, 176), P(170, 136)))
        case .pokal:
            return (Arm(P(50, 224), P(80, 206)), Arm(P(172, 160), P(168, 100)))
        // Mimik (Runde 3)
        case .zwinkert:
            return (Arm(P(28, 222), P(50, 250)), Arm(P(182, 200), P(170, 158)))
        case .verliebt:
            return (Arm(P(56, 214), P(92, 160)), Arm(P(144, 214), P(108, 160)))
        case .sauer:
            // Crossed: two diagonal forearms at different heights, hands tucked at the far elbow.
            return (Arm(P(40, 228), P(136, 204)), Arm(P(160, 216), P(64, 236)))
        case .schmollt:
            return (Arm(P(28, 220), P(48, 248)), Arm(P(172, 220), P(152, 248)))
        case .verlegen:
            return (restL, Arm(P(174, 168), P(158, 86)))
        case .muede:
            return (Arm(P(52, 190), P(76, 106)), Arm(P(152, 222), P(128, 196)))
        case .ueberrascht:
            let s = w(3) * 3
            return (Arm(P(34, 196), P(40, 148 + s)), Arm(P(166, 196), P(160, 148 + s)))
        case .lachtTraenen:
            return (Arm(P(40, 214), P(80, 232)), Arm(P(162, 196), P(132, 110)))
        case .weint:
            let s = w(10) * 2
            return (Arm(P(46, 196), P(76, 108 + s)), Arm(P(154, 196), P(124, 108 - s)))
        case .denkt:
            return (Arm(P(44, 230), P(142, 214)), Arm(P(160, 218), P(114, 150)))
        case .feiert:
            let s = w(6) * 6
            return (Arm(P(30, 160), P(38, 104 + s)), Arm(P(170, 160), P(162, 104 - s)))
        case .schockiert:
            return (Arm(P(34, 196), P(62, 124)), Arm(P(166, 196), P(138, 124)))
        case .daumen:
            return (restL, Arm(P(166, 212), P(146, 174)))
        case .tanzt:
            let s = w(5)
            return (Arm(P(36, 190 - s * 10), P(28 + s * 6, 140 - s * 16)), Arm(P(164, 190 + s * 10), P(172 - s * 6, 140 + s * 16)))
        default:
            return (restL, restR)
        }
    }

    // MARK: Props

    func hintergrund(_ g: GraphicsContext) {
        switch z {
        case .schlaeft:
            var h = g
            h.translateBy(x: 100, y: 88)
            h.rotate(by: .degrees(-6))
            teil(h, box(-86, -44, 172, 90, 40), Pal.kissen)
        case .zuhause:
            teil(g, box(2, 138, 196, 120, 30), Pal.sofa)
            teil(g, box(14, 148, 84, 90, 20), Pal.sofa.mix(Pal.weiss, 0.15))
            teil(g, box(102, 148, 84, 90, 20), Pal.sofa.mix(Pal.weiss, 0.15))
            teil(g, box(-6, 196, 30, 60, 14), Pal.sofa.mal(0.85))
            teil(g, box(176, 196, 30, 60, 14), Pal.sofa.mal(0.85))
        case .morgen:
            let c = P(166, 42)
            for i in 0..<8 {
                let a = Double(i) * Double.pi / 4 + t * 0.4
                let dx = CGFloat(cos(a))
                let dy = CGFloat(sin(a))
                linie(g, strich(P(c.x + dx * 25, c.y + dy * 25), P(c.x + dx * 33, c.y + dy * 33)), Pal.gelb.farbe, 4)
            }
            teil(g, kreis(c, 18), Pal.gelb)
        case .abend:
            var h = g
            h.clip(to: kreis(P(174, 32), 15), options: .inverse)
            h.fill(kreis(P(164, 40), 16), with: .color(Pal.gelb.farbe))
            for (i, c) in [P(130, 20), P(188, 80), P(22, 46)].enumerated() {
                g.fill(funkel(c, 5 + 2 * w(3, Double(i) * 2)), with: .color(Pal.gelb.farbe))
            }
        default:
            break
        }
    }

    func mitte(_ g: GraphicsContext) {
        switch z {
        case .schule:
            teil(g, box(8, 218, 184, 30, 4), Pal.holz.mal(0.85))
            let platte = Path { p in
                p.move(to: P(16, 206))
                p.addLine(to: P(184, 206))
                p.addLine(to: P(198, 220))
                p.addLine(to: P(2, 220))
                p.closeSubpath()
            }
            teil(g, platte, Pal.holz)
            teil(g, box(64, 198, 34, 12, 2), Pal.weiss, 2)
            teil(g, box(98, 198, 34, 12, 2), Pal.weiss, 2)
        case .arbeit:
            teil(g, box(56, 170, 88, 60, 7), Pal.silber)
            g.fill(herzPfad(P(100, 198), 7), with: .color(Pal.rose.farbe))
            teil(g, box(46, 228, 108, 14, 4), Pal.silber.mal(0.85))
        case .ruhe:
            let decke = Path { p in
                p.move(to: P(22, 240))
                p.addLine(to: P(26, 196))
                p.addCurve(to: P(100, 158), control1: P(30, 168), control2: P(62, 156))
                p.addCurve(to: P(174, 196), control1: P(138, 156), control2: P(170, 168))
                p.addLine(to: P(178, 240))
                p.closeSubpath()
            }
            g.fill(decke, with: .color(Pal.decke.farbe))
            var h = g
            h.clip(to: decke)
            for x in stride(from: CGFloat(30), to: 180, by: 22) { linie(h, strich(P(x, 150), P(x, 240)), .white.opacity(0.3), 3) }
            for y in stride(from: CGFloat(180), to: 240, by: 22) { linie(h, strich(P(0, y), P(200, y)), .white.opacity(0.3), 3) }
            linie(g, decke, Pal.decke.kontur, 3.5)
            linie(g, bogen(P(100, 160), P(96, 240), P(106, 200)), Pal.decke.kontur, 3)
            teil(g, kreis(P(86, 204), 9.5), haut)
            teil(g, kreis(P(114, 204), 9.5), haut)
        default:
            break
        }
    }

    func handy(_ g: GraphicsContext, _ c: CGPoint, rueckseite: Bool) {
        teil(g, box(c.x - 14, c.y - 21, 28, 42, 7), Pal.dunkel, 3)
        if rueckseite {
            g.fill(kreis(P(c.x - 6, c.y - 13), 4), with: .color(Pal.silber.farbe))
        } else {
            g.fill(box(c.x - 10, c.y - 16, 20, 30, 3), with: .color(Pal.himmel.farbe))
        }
    }

    func requisite(_ g: GraphicsContext, _ hand: CGPoint) {
        switch z {
        case .tippt:
            handy(g, P(100, 200), rueckseite: false)
        case .kamera:
            handy(g, P(172, 80), rueckseite: true)
        case .sprache:
            let griff = strich(P(126, 168), P(117, 148))
            linie(g, griff, Pal.dunkel.kontur, 9)
            linie(g, griff, Pal.dunkel.farbe, 6)
            teil(g, kreis(P(114, 142), 9), Pal.silber)
            var h = g
            h.clip(to: kreis(P(114, 142), 9))
            for i in -2...2 {
                let y = 142 + CGFloat(i) * 4
                linie(h, strich(P(105, y), P(123, y)), Pal.dunkel.farbe.opacity(0.35), 1)
            }
        case .liest:
            teil(g, box(64, 190, 72, 34, 4), Pal.rose)
            teil(g, box(68, 186, 31, 34, 2), Pal.weiss, 2)
            teil(g, box(101, 186, 31, 34, 2), Pal.weiss, 2)
            for i in 0..<4 {
                let y = 194 + CGFloat(i) * 6
                linie(g, strich(P(73, y), P(94, y)), Pal.silber.kontur, 1.5)
                linie(g, strich(P(106, y), P(127, y)), Pal.silber.kontur, 1.5)
            }
        case .schautBild:
            var h = g
            h.translateBy(x: 100, y: 206)
            h.rotate(by: .degrees(-8))
            teil(h, box(-24, -20, 48, 40, 4), Pal.weiss, 2.5)
            h.fill(box(-19, -15, 38, 26, 2), with: .color(Pal.himmel.farbe))
            h.fill(kreis(P(8, -8), 4), with: .color(Pal.gelb.farbe))
            let huegel = Path { p in
                p.move(to: P(-19, 11))
                p.addQuadCurve(to: P(19, 11), control: P(-2, -12))
                p.closeSubpath()
            }
            h.fill(huegel, with: .color(Pal.gruen.farbe))
        case .schautVideo:
            for c in [P(54, 198), P(64, 192), P(74, 196), P(82, 199), P(60, 203)] { teil(g, kreis(c, 6), Pal.popcorn, 2) }
            let eimer = Path { p in
                p.move(to: P(48, 202))
                p.addLine(to: P(84, 202))
                p.addLine(to: P(79, 244))
                p.addLine(to: P(53, 244))
                p.closeSubpath()
            }
            g.fill(eimer, with: .color(Pal.weiss.farbe))
            var h = g
            h.clip(to: eimer)
            for x in stride(from: CGFloat(52), to: 84, by: 10) { h.fill(box(x, 202, 5, 42), with: .color(Pal.rose.farbe)) }
            linie(g, eimer, Pal.weiss.kontur, 3)
            teil(g, kreis(P(122, 137), 5), Pal.popcorn, 2)
        case .zeichnet:
            var h = g
            h.translateBy(x: 52, y: 176)
            h.rotate(by: .degrees(-6))
            teil(h, box(-24, -18, 48, 36, 3), Pal.weiss, 2.5)
            let kringel = Path { p in
                p.move(to: P(-16, 6))
                p.addCurve(to: P(14, -6), control1: P(-8, -14), control2: P(4, 12))
            }
            linie(h, kringel, Pal.rose.farbe, 3)
            linie(h, bogen(P(-14, -8), P(8, 10), P(10, -12)), Pal.himmel.farbe, 3)
            let spitze = P(hand.x - 12, hand.y - 12)
            let stift = strich(P(hand.x + 8, hand.y + 8), spitze)
            linie(g, stift, Pal.gelb.kontur, 8)
            linie(g, stift, Pal.gelb.farbe, 5)
            g.fill(kreis(spitze, 2.5), with: .color(Pal.tinte.farbe))
        case .karte:
            teil(g, box(94, 90, 12, 12, 2), Pal.dunkel, 2.5)
            for x in [CGFloat(80), 120] {
                teil(g, box(x - 15, 84, 30, 30, 11), Pal.dunkel)
                teil(g, kreis(P(x, 99), 9), Pal.blau, 2)
                g.fill(kreis(P(x - 3, 96), 2.5), with: .color(.white.opacity(0.8)))
            }
        case .spielt:
            var h = g
            h.translateBy(x: 134, y: 176 - abs(w(3)) * 30)
            h.rotate(by: .degrees(t * 140))
            teil(h, box(-10, -10, 20, 20, 5), Pal.weiss, 2.5)
            for d in [P(-5, -5), P(0, 0), P(5, 5)] { h.fill(kreis(d, 2.2), with: .color(Pal.tinte.farbe)) }
        case .laedt:
            let kabel = Path { p in
                p.move(to: P(140, 210))
                p.addCurve(to: P(186, 244), control1: P(142, 238), control2: P(170, 226))
            }
            linie(g, kabel, Pal.weiss.kontur, 7)
            linie(g, kabel, .white, 4)
            teil(g, box(131, 188, 18, 22, 4), Pal.weiss, 2.5)
            linie(g, strich(P(136, 188), P(136, 181)), Pal.silber.kontur, 3)
            linie(g, strich(P(144, 188), P(144, 181)), Pal.silber.kontur, 3)
        case .nichtStoeren:
            linie(g, strich(P(43, 198), P(46, 208)), Pal.holz.kontur, 5)
            teil(g, box(14, 160, 60, 40, 10), Pal.weiss, 3)
            var h = g
            h.clip(to: kreis(P(34, 174), 7), options: .inverse)
            h.fill(kreis(P(30, 178), 8), with: .color(Pal.gelb.farbe))
            text(g, "Pst", P(54, 180), 13, Pal.rose.farbe)
        case .rad:
            let lenker = bogen(P(46, 198), P(154, 198), P(100, 214))
            linie(g, lenker, Pal.dunkel.kontur, 9)
            linie(g, lenker, Pal.silber.farbe, 5)
            teil(g, kreis(P(112, 206), 5), Pal.gelb, 2)
        case .faehrt, .fahrschule:
            var h = g
            h.translateBy(x: 100, y: 216)
            h.rotate(by: .degrees(lenkWinkel))
            linie(h, kreis(.zero, 34), Pal.dunkel.kontur, 11)
            linie(h, kreis(.zero, 34), Pal.dunkel.farbe, 7)
            for grad in [90.0, 210, 330] {
                let r = grad * Double.pi / 180
                linie(h, strich(.zero, P(34 * CGFloat(cos(r)), 34 * CGFloat(sin(r)))), Pal.dunkel.farbe, 5)
            }
            teil(h, kreis(.zero, 9), Pal.dunkel)
            if z == .fahrschule {
                teil(g, box(88, 204, 24, 24, 4), Pal.weiss, 2.5)
                text(g, "L", P(100, 216), 18, Pal.rose.farbe)
            }
        case .gym:
            linie(g, strich(P(hand.x - 20, hand.y), P(hand.x + 20, hand.y)), Pal.silber.kontur, 7)
            linie(g, strich(P(hand.x - 20, hand.y), P(hand.x + 20, hand.y)), Pal.silber.farbe, 4)
            teil(g, box(hand.x - 28, hand.y - 12, 9, 24, 3), Pal.dunkel)
            teil(g, box(hand.x + 19, hand.y - 12, 9, 24, 3), Pal.dunkel)
        case .schule:
            let stift = strich(P(hand.x + 10, hand.y - 18), P(hand.x - 8, hand.y + 4))
            linie(g, stift, Pal.gelb.kontur, 8)
            linie(g, stift, Pal.gelb.farbe, 5)
        case .supermarkt:
            var h = g
            h.translateBy(x: 72, y: 192)
            h.rotate(by: .degrees(-18))
            teil(h, oval(.zero, 7, 20), Pal.brot, 2.5)
            teil(g, kreis(P(100, 200), 8), Pal.gruen, 2.5)
            teil(g, kreis(P(122, 198), 9), Pal.rose, 2.5)
            let korb = Path { p in
                p.move(to: P(40, 204))
                p.addLine(to: P(160, 204))
                p.addLine(to: P(150, 244))
                p.addLine(to: P(50, 244))
                p.closeSubpath()
            }
            g.fill(korb, with: .color(Pal.silber.farbe.opacity(0.4)))
            var k = g
            k.clip(to: korb)
            for x in stride(from: CGFloat(44), to: 160, by: 12) { linie(k, strich(P(x, 204), P(x, 244)), Pal.silber.kontur, 2) }
            for y in stride(from: CGFloat(214), to: 244, by: 10) { linie(k, strich(P(40, y), P(160, y)), Pal.silber.kontur, 2) }
            linie(g, korb, Pal.silber.kontur, 3)
            let griff = strich(P(36, 200), P(164, 200))
            linie(g, griff, Pal.rose.kontur, 9)
            linie(g, griff, Pal.rose.farbe, 6)
        case .abend:
            teil(g, oval(P(100, 226), 20, 17), Pal.teddy)
            teil(g, kreis(P(88, 188), 6), Pal.teddy)
            teil(g, kreis(P(112, 188), 6), Pal.teddy)
            teil(g, kreis(P(100, 202), 15), Pal.teddy)
            teil(g, oval(P(100, 208), 7, 5), Pal.teddy.mix(Pal.weiss, 0.5), 2)
            for c in [P(94, 199), P(106, 199), P(100, 206)] { g.fill(kreis(c, 2), with: .color(Pal.tinte.farbe)) }
        case .herz:
            let p = Double(zyklus(1.0))
            let a1 = exp(-pow((p - 0.1) / 0.06, 2))
            let a2 = exp(-pow((p - 0.3) / 0.06, 2))
            let schlag = CGFloat(1 + 0.14 * a1 + 0.09 * a2)
            teil(g, herzPfad(P(100, 194), 22 * schlag), Pal.rose)
        case .anstossen:
            let k = Double(zyklus(2.0))
            let kipp: Double = statisch ? -10 : (k < 0.2 ? -sin(k / 0.2 * Double.pi) * 12 : 0)
            var h = g
            h.translateBy(x: hand.x, y: hand.y)
            h.rotate(by: .degrees(kipp))
            let kelch = Path { p in
                p.move(to: P(-8, -46))
                p.addLine(to: P(8, -46))
                p.addQuadCurve(to: P(0, -12), control: P(8, -16))
                p.addQuadCurve(to: P(-8, -46), control: P(-8, -16))
                p.closeSubpath()
            }
            h.fill(kelch, with: .color(Pal.sekt.farbe.opacity(0.9)))
            var innen = h
            innen.clip(to: kelch)
            innen.fill(box(-10, -48, 20, 6), with: .color(.white.opacity(0.7)))
            for i in 0..<3 {
                let y = -16 - zyklus(1.2, Double(i) * 0.4) * 26
                innen.fill(kreis(P(CGFloat(i - 1) * 3, y), 1.4), with: .color(.white))
            }
            linie(h, kelch, Pal.silber.kontur, 2.5)
            linie(h, strich(P(0, -12), P(0, 4)), Pal.silber.kontur, 3)
            linie(h, strich(P(-7, 4), P(7, 4)), Pal.silber.kontur, 3)
        case .pokal:
            for c in [P(60, 166), P(100, 166)] {
                linie(g, kreis(c, 7), Pal.gold.kontur, 6)
                linie(g, kreis(c, 7), Pal.gold.farbe, 3)
            }
            let becher = Path { p in
                p.move(to: P(62, 156))
                p.addLine(to: P(98, 156))
                p.addQuadCurve(to: P(80, 188), control: P(98, 186))
                p.addQuadCurve(to: P(62, 156), control: P(62, 186))
                p.closeSubpath()
            }
            teil(g, becher, Pal.gold)
            teil(g, box(76, 186, 8, 10, 2), Pal.gold, 2.5)
            teil(g, box(66, 194, 28, 9, 3), Pal.gold.mal(0.85), 2.5)
            g.fill(funkel(P(72, 166), 5), with: .color(.white.opacity(0.9)))
        case .zwinkert:
            fingerZeigt(g, hand, richtung: P(-6, -15), s: 1)
        case .daumen:
            daumenHoch(g, hand, s: 1)
        case .muede:
            kaffee(g, P(hand.x, hand.y - 14), s: 1)
        default:
            break
        }
    }

    /// Index finger pointing out of the hand; drawn before the hand circle so the hand covers its base.
    func fingerZeigt(_ g: GraphicsContext, _ hand: CGPoint, richtung d: CGPoint, s: CGFloat) {
        let finger = strich(hand, P(hand.x + d.x * s, hand.y + d.y * s))
        linie(g, finger, haut.kontur, 9 * s)
        linie(g, finger, haut.farbe, 6 * s)
    }

    /// Thumb sticking up out of the fist.
    func daumenHoch(_ g: GraphicsContext, _ hand: CGPoint, s: CGFloat) {
        let daumen = strich(hand, P(hand.x - s, hand.y - 16 * s))
        linie(g, daumen, haut.kontur, 10 * s)
        linie(g, daumen, haut.farbe, 7 * s)
    }

    /// Coffee to go with a little steam.
    func kaffee(_ g: GraphicsContext, _ c: CGPoint, s: CGFloat) {
        var h = g
        h.translateBy(x: c.x, y: c.y)
        h.scaleBy(x: s, y: s)
        let becher = Path { p in
            p.move(to: P(-8, -10))
            p.addLine(to: P(8, -10))
            p.addLine(to: P(6, 10))
            p.addLine(to: P(-6, 10))
            p.closeSubpath()
        }
        teil(h, becher, Pal.weiss, 2)
        h.fill(box(-7, -3, 14, 6), with: .color(Pal.holz.farbe))
        teil(h, box(-9.5, -14, 19, 5, 2), Pal.holz.mal(0.75), 1.5)
        for i in 0..<2 {
            let p = zyklus(1.6, Double(i) * 0.8)
            var d = h
            d.opacity = Double(1 - p)
            let x: CGFloat = CGFloat(i) * 6 - 3
            linie(d, bogen(P(x, -18 - p * 12), P(x + 2, -30 - p * 12), P(x + 5, -24 - p * 12)), Pal.silber.kontur, 1.6)
        }
    }

    // MARK: Effects

    func blase(_ g: GraphicsContext, _ rahmen: CGRect, spitze: CGPoint) {
        let form = Path(roundedRect: rahmen, cornerRadius: 13)
        let schwanz = Path { p in
            p.move(to: P(spitze.x - 6, rahmen.maxY - 2))
            p.addLine(to: spitze)
            p.addLine(to: P(spitze.x + 6, rahmen.maxY - 2))
            p.closeSubpath()
        }
        linie(g, form, Pal.weiss.kontur, 5)
        linie(g, schwanz, Pal.weiss.kontur, 5)
        g.fill(form, with: .color(.white))
        g.fill(schwanz, with: .color(.white))
    }

    func akku(_ g: GraphicsContext, _ fuellung: CGFloat, _ farbe: FigurFarbe) {
        teil(g, box(144, 30, 32, 18, 5), Pal.weiss, 3)
        g.fill(box(177, 35, 4, 8, 2), with: .color(Pal.weiss.kontur))
        g.fill(box(147.5, 33.5, max(3, 25 * fuellung), 11, 3), with: .color(farbe.farbe))
    }

    func herzen(_ g: GraphicsContext, _ bereich: CGRect, _ n: Int) {
        for i in 0..<n {
            let p = zyklus(2.4, Double(i) * 2.4 / Double(n))
            let anteil = CGFloat(i) / CGFloat(max(n - 1, 1))
            let x = bereich.minX + bereich.width * anteil + w(3, Double(i)) * 4
            let y = bereich.maxY - p * bereich.height
            var h = g
            h.opacity = Double(1 - p)
            h.fill(herzPfad(P(x, y), 6 + p * 3), with: .color(Pal.rose.farbe))
        }
    }

    func lippen(_ g: GraphicsContext, _ c: CGPoint, _ s: CGFloat) {
        let oben = Path { p in
            p.move(to: P(c.x - 9 * s, c.y))
            p.addQuadCurve(to: P(c.x, c.y - 3 * s), control: P(c.x - 5 * s, c.y - 8 * s))
            p.addQuadCurve(to: P(c.x + 9 * s, c.y), control: P(c.x + 5 * s, c.y - 8 * s))
            p.closeSubpath()
        }
        let unten = Path { p in
            p.move(to: P(c.x - 9 * s, c.y))
            p.addQuadCurve(to: P(c.x + 9 * s, c.y), control: P(c.x, c.y + 10 * s))
            p.closeSubpath()
        }
        teil(g, unten, Pal.rose, 2)
        teil(g, oben, Pal.rose, 2)
    }
}
