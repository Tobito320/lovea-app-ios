import SwiftUI

// MARK: - Teil 4: gym exercises

extension Zeichner {
    /// Rep phase: 0 = start of the rep, 1 = the top. A static render freezes at the middle.
    var wdh: CGFloat { statisch ? 0.5 : (1 + w(3.2)) / 2 }

    /// Which stance an exercise borrows: legs and upper-body drop come from the ordinary `Haltung`
    /// cases, only the treadmill and the seated machines need a different one from `.stehen`.
    func gymHaltung(_ g: GymGeste) -> Haltung {
        switch g {
        case .laufband: return (statisch || zyklus(40) < 0.6) ? .gehen : .rennen
        case .bank, .preacher, .beinstrecker: return .sitzen
        default: return .stehen
        }
    }

    /// Custom leg placement for the exercises whose `Haltung` legs (standing/sitting) aren't enough.
    /// `nil` lets `beinGelenke` fall back to the ordinary legs for `gymHaltung`.
    func gymBeine(_ g: GymGeste, _ m: Masse, _ oben: CGFloat) -> (l: Bein, r: Bein)? {
        let hx: CGFloat = m.h * 0.52
        let hy: CGFloat = m.hueftY + oben
        let fy = Masse.fussY
        let wd = wdh
        switch g {
        case .kniebeuge:
            func bein(_ seite: CGFloat) -> Bein {
                let hipX = 100 + seite * hx
                let footX = 100 + seite * (hx + 8)
                return Bein(h: P(hipX, hy), k: P(footX + seite * (6 + wd * 16), (hy + fy) / 2 + 4), f: P(footX, fy))
            }
            return (bein(-1), bein(1))
        case .ausfallschritt:
            // Front (left) leg takes the load, knee over the foot; the back (right) knee drops low.
            let l = Bein(h: P(100 - hx, hy), k: P(96, (hy + fy) / 2 + wd * 6), f: P(94, fy))
            let r = Bein(h: P(100 + hx, hy), k: P(106, hy + (fy - hy) * (0.55 + wd * 0.3)), f: P(110, fy - 6))
            return (l, r)
        case .beinKabel:
            // Left leg stands (the ordinary `.stehen` shape); the right swings out on the ankle strap.
            let hipR = P(100 + hx, hy)
            let footR = P(100 + hx + 6 + wd * 34, fy - wd * 26)
            let standL = Bein(h: P(100 - hx, hy), k: P(100 - hx - 1, m.knieY), f: P(100 - hx - 2, fy))
            return (standL, Bein(h: hipR, k: zwischen(hipR, footR, 0.5), f: footR))
        case .beinstrecker:
            func bein(_ seite: CGFloat) -> Bein {
                let x = 100 + seite * hx
                let footY = fy + (m.knieY + 24 - fy) * wd
                return Bein(h: P(x, hy), k: P(x + seite * 5, m.knieY + 10), f: P(x + seite * 4, footY))
            }
            return (bein(-1), bein(1))
        default:
            return nil
        }
    }

    /// Arm placement per exercise; `oben` is the upper-body drop already in effect (`obenVersatz`),
    /// needed for the machines whose hand rests near the hip.
    func gymArme(_ g: GymGeste, _ m: Masse, _ oben: CGFloat) -> (l: Arm, r: Arm) {
        let lx: CGFloat = 100 - m.s + 6, rx: CGFloat = 100 + m.s - 6, y = m.schulterY
        let wd = wdh
        switch g {
        case .curls:
            let handL = zwischen(P(lx - 2, y + 92), P(lx + 8, y + 44), wd)
            let handR = zwischen(P(rx + 2, y + 92), P(rx - 8, y + 44), 1 - wd)
            return (Arm(P(lx - 4, y + 50), handL), Arm(P(rx + 4, y + 50), handR))
        case .schulterdruecken:
            return (Arm(P(lx - 20, y + 12 - wd * 20), P(lx - 16, y - 20 - wd * 38)),
                    Arm(P(rx + 20, y + 12 - wd * 20), P(rx + 16, y - 20 - wd * 38)))
        case .bank:
            return (Arm(P(lx - 20, y + 40 - wd * 22), P(lx - 10, y + 26 - wd * 52)),
                    Arm(P(rx + 20, y + 40 - wd * 22), P(rx + 10, y + 26 - wd * 52)))
        case .preacher:
            let handL = zwischen(P(80, y + 96), P(86, y + 30), wd)
            let handR = zwischen(P(120, y + 96), P(114, y + 30), wd)
            return (Arm(P(82, y + 62), handL), Arm(P(118, y + 62), handR))
        case .kabelzug:
            let handL = zwischen(P(lx - 30, y - 8), P(94, y + 64), wd)
            let handR = zwischen(P(rx + 30, y - 8), P(106, y + 64), wd)
            let midL = zwischen(P(lx, y), handL, 0.5)
            let midR = zwischen(P(rx, y), handR, 0.5)
            return (Arm(P(midL.x - 10, midL.y), handL), Arm(P(midR.x + 10, midR.y), handR))
        case .beinKabel:
            // Left hand rests on the hip, elbow out; the right holds the tower.
            return (Arm(P(lx - 14, m.hueftY + oben - 30), P(lx + 4, m.hueftY + oben - 6)),
                    Arm(P(rx + 20, y + 30), P(178, y + 30)))
        case .beinstrecker:
            // Hands grip the seat edges beside the hips.
            return (Arm(P(lx - 8, m.hueftY + oben - 16), P(lx - 8, m.hueftY + oben + 4)),
                    Arm(P(rx + 8, m.hueftY + oben - 16), P(rx + 8, m.hueftY + oben + 4)))
        case .kniebeuge:
            return (Arm(P(lx - 16, y + 30), P(lx - 10, y - 2)), Arm(P(rx + 16, y + 30), P(rx + 10, y - 2)))
        case .ausfallschritt, .wadenheben:
            return (Arm(P(lx - 6, y + 50), P(lx - 4, y + 94)), Arm(P(rx + 6, y + 50), P(rx + 4, y + 94)))
        case .laufband:
            if statisch || zyklus(40) < 0.6 {
                let s: CGFloat = statisch ? 0.9 : w(7)
                let vl = max(0, -s), vr = max(0, s)
                return (Arm(P(lx - 6 + vl * 6, y + 48 - vl * 6), P(lx - 2 + vl * 16, y + 88 - vl * 30)),
                        Arm(P(rx + 6 - vr * 6, y + 48 - vr * 6), P(rx + 2 - vr * 16, y + 88 - vr * 30)))
            } else {
                let s = w(12)
                return (Arm(P(lx - 12, y + 40), P(lx + 4, y + 30 + s * 14)), Arm(P(rx + 12, y + 40), P(rx - 4, y + 30 - s * 14)))
            }
        case .pause:
            // Left arm rests; the right holds the bottle at the mouth.
            return (Arm(P(lx - 6, y + 50), P(lx - 4, y + 92)), Arm(P(rx + 8, y + 40), P(110, y - 6)))
        }
    }

    /// Equipment behind the body: towers, the bench, seats, the treadmill belt and (Draw-order:
    /// the squat bar must sit behind the head, so it lives here rather than in `gymInHaenden`).
    func gymHinten(_ g: GraphicsContext, _ m: Masse, _ oben: CGFloat) {
        guard let gy = gymGeste else { return }
        let y = m.schulterY
        let sitz = m.hueftY + oben
        let fy = Masse.fussY
        switch gy {
        case .kabelzug:
            for x in [CGFloat(10), 190] {
                linie(g, strich(P(x, y - 80), P(x, 384)), Pal.dunkel.kontur, 10)
                linie(g, strich(P(x, y - 80), P(x, 384)), Pal.dunkel.farbe, 6)
                teil(g, kreis(P(x, y - 80), 8), Pal.silber, 2)
            }
        case .beinKabel:
            linie(g, strich(P(184, y - 80), P(184, 384)), Pal.dunkel.kontur, 10)
            linie(g, strich(P(184, y - 80), P(184, 384)), Pal.dunkel.farbe, 6)
            teil(g, kreis(P(184, fy - 6), 7), Pal.silber, 2)
        case .bank:
            teil(g, box(66, sitz - 150, 68, 150, 12), Pal.dunkel.mix(Pal.weiss, 0.08))
            teil(g, box(70, sitz - 6, 60, 20, 8), Pal.dunkel.mix(Pal.weiss, 0.08))
        case .preacher, .beinstrecker:
            teil(g, box(70, sitz - 6, 60, 20, 8), Pal.dunkel.mix(Pal.weiss, 0.08))
        case .kniebeuge:
            let stange = strich(P(20, y - 4), P(180, y - 4))
            linie(g, stange, Pal.silber.kontur, 6)
            linie(g, stange, Pal.silber.farbe, 4)
            for x in [CGFloat(20), 180] { teil(g, box(x - 5, y - 21, 10, 34, 3), Pal.dunkel, 2) }
        case .laufband:
            var band = Path()
            band.move(to: P(56, fy - 4))
            band.addLine(to: P(144, fy - 4))
            band.addLine(to: P(154, fy + 14))
            band.addLine(to: P(46, fy + 14))
            band.closeSubpath()
            teil(g, band, Pal.dunkel, 2.5)
            for x in [CGFloat(40), 160] { linie(g, strich(P(x, fy + 10), P(x, sitz)), Pal.silber.kontur, 6) }
            linie(g, strich(P(40, sitz), P(160, sitz)), Pal.dunkel.kontur, 6)
        default:
            break
        }
    }

    /// The preacher pad under the elbows, covering the chest.
    func gymVorArmen(_ g: GraphicsContext, _ m: Masse, _ oben: CGFloat) {
        guard gymGeste == .preacher else { return }
        let y = m.schulterY
        let pad = Path { p in
            p.move(to: P(62, y + 44))
            p.addLine(to: P(138, y + 44))
            p.addLine(to: P(130, y + 76))
            p.addLine(to: P(70, y + 76))
            p.closeSubpath()
        }
        teil(g, pad, Pal.dunkel, 2.5)
        teil(g, box(68, y + 46, 64, 8, 4), Pal.dunkel.mix(Pal.weiss, 0.25))
    }

    /// What the hands hold: bars, dumbbells, cable lines and handles, the ankle strap, the
    /// leg-extension roll pad and the water bottle. The squat bar is drawn in `gymHinten` instead
    /// (it must sit behind the head); the hands from `armV`/`arm` land in front of it either way.
    func gymInHaenden(_ g: GraphicsContext, _ arme: (l: Arm, r: Arm), _ m: Masse) {
        guard let gy = gymGeste else { return }
        func hantel(_ c: CGPoint) {
            let stange = strich(P(c.x - 13, c.y), P(c.x + 13, c.y))
            linie(g, stange, Pal.silber.kontur, 5)
            linie(g, stange, Pal.silber.farbe, 3)
            teil(g, box(c.x - 19, c.y - 8, 6, 16, 2), Pal.dunkel, 2)
            teil(g, box(c.x + 13, c.y - 8, 6, 16, 2), Pal.dunkel, 2)
        }
        func barbell(_ a: CGPoint, _ b: CGPoint, platten: Bool) {
            let stange = strich(a, b)
            linie(g, stange, Pal.silber.kontur, 6)
            linie(g, stange, Pal.silber.farbe, 4)
            if platten {
                for x in [a.x, b.x] { teil(g, box(x - 5, a.y - 17, 10, 34, 3), Pal.dunkel, 2) }
            }
        }
        switch gy {
        case .curls, .ausfallschritt, .wadenheben, .schulterdruecken:
            hantel(arme.l.hand)
            hantel(arme.r.hand)
        case .bank:
            barbell(P(16, arme.l.hand.y), P(184, arme.r.hand.y), platten: true)
        case .preacher:
            barbell(arme.l.hand, arme.r.hand, platten: false)
        case .kabelzug:
            linie(g, strich(P(10, m.schulterY - 80), arme.l.hand), Pal.silber.kontur, 2)
            linie(g, strich(P(190, m.schulterY - 80), arme.r.hand), Pal.silber.kontur, 2)
        case .beinKabel:
            let oben = obenVersatz(haltung, m)
            if let beine = gymBeine(gy, m, oben) {
                linie(g, strich(P(184, Masse.fussY - 6), beine.r.f), Pal.dunkel.kontur, 2.5)
                teil(g, box(beine.r.f.x - 6, beine.r.f.y - 4, 12, 8, 3), Pal.dunkel, 1.5)
            }
        case .beinstrecker:
            let oben = obenVersatz(haltung, m)
            if let beine = gymBeine(gy, m, oben) {
                for bein in [beine.l, beine.r] { teil(g, box(bein.f.x - 7, bein.f.y - 5, 14, 10, 4), Pal.dunkel, 1.8) }
            }
        case .pause:
            let mund = arme.r.hand
            teil(g, box(mund.x - 5, mund.y - 24, 10, 20, 3), Pal.himmel, 2)
            teil(g, box(mund.x - 3, mund.y - 28, 6, 6, 2), Pal.himmel.mix(Pal.weiss, 0.3), 1.5)
        default:
            break
        }
    }
}

// MARK: - Extras (Z-39.4)

extension Zeichner {
    /// No umbrella in a vehicle, in bed or on the sofa: the arms are busy there.
    var schirmAktiv: Bool {
        extras.contains(.schirm) && ![.faehrt, .fahrschule, .rad, .scooter, .schlaeft, .zuhause, .ruhe, .zug].contains(z)
    }

    /// Dumbbells only while both hands are free of phone and umbrella, and no real exercise shows (Teil 4).
    var hantelnAktiv: Bool { extras.contains(.hanteln) && !extras.contains(.handyKabel) && !schirmAktiv && gymGeste == nil }

    /// The right hand holds the phone, the umbrella or a dumbbell, so the state's own hand prop steps aside.
    var rechteHandBelegt: Bool { extras.contains(.handyKabel) || schirmAktiv || hantelnAktiv }

    /// Curl phase 0 (arm down) … 1 (weight at the shoulder); the right arm runs half a beat behind.
    func hub(_ versatz: Double) -> CGFloat { (1 + w(3.2, versatz)) / 2 }

    /// Half figure: the right hand holds the phone (the left one the cable) or the umbrella; with
    /// both, the umbrella moves to the left hand.
    func mitExtras(_ arme: (l: Arm?, r: Arm?)) -> (l: Arm?, r: Arm?) {
        var a = arme
        if hantelnAktiv {
            let l = hub(0), r = hub(Double.pi)
            a.l = Arm(P(46, 212), P(54 + l * 8, 238 - l * 58))
            a.r = Arm(P(154, 212), P(146 - r * 8, 238 - r * 58))
        }
        let mitHandy = extras.contains(.handyKabel)
        if mitHandy {
            a.l = Arm(P(40, 222), P(62, 206))
            a.r = Arm(P(160, 222), P(140, 196))
        }
        if schirmAktiv {
            if mitHandy { a.l = Arm(P(30, 188), P(28, 142)) } else { a.r = Arm(P(170, 188), P(172, 142)) }
        }
        return a
    }

    /// Full-body counterpart of `mitExtras`, in body space.
    func mitExtrasGanz(_ arme: (l: Arm, r: Arm), _ m: Masse) -> (l: Arm, r: Arm) {
        var a = arme
        let lx: CGFloat = 100 - m.s + 6
        let rx: CGFloat = 100 + m.s - 6
        let y = m.schulterY
        if hantelnAktiv {
            let l = hub(0), r = hub(Double.pi)
            a.l = Arm(P(lx - 4, y + 50), P(lx - 8 + l * 10, y + 92 - l * 52))
            a.r = Arm(P(rx + 4, y + 50), P(rx + 8 - r * 10, y + 92 - r * 52))
        }
        let mitHandy = extras.contains(.handyKabel)
        if mitHandy {
            a.l = Arm(P(lx - 6, y + 46), P(lx + 8, y + 44))
            a.r = Arm(P(rx + 6, y + 46), P(rx - 8, y + 30))
        }
        if schirmAktiv {
            if mitHandy { a.l = Arm(P(lx - 16, y + 30), P(lx - 18, y - 22)) } else { a.r = Arm(P(rx + 16, y + 30), P(rx + 18, y - 22)) }
        }
        return a
    }

    /// Umbrella canopy center, beside the head on the holding hand's side (`nil` = no umbrella).
    func schirmDachMitte(halb: Bool, _ m: Masse? = nil) -> CGPoint? {
        guard schirmAktiv else { return nil }
        let links = extras.contains(.handyKabel)
        if halb { return P(links ? 46 : 154, 38) }
        let s: CGFloat = m?.s ?? 41
        let y: CGFloat = (m?.schulterY ?? 152) - 112
        return P(links ? 100 - s + 4 : 100 + s - 4, y)
    }

    /// Canopy leaning toward the head, drawn behind it; the shaft comes with the hands.
    func schirmDach(_ g: GraphicsContext, _ c: CGPoint, radius r: CGFloat) {
        var h = g
        h.translateBy(x: c.x, y: c.y)
        h.rotate(by: .degrees(c.x > 100 ? -12 : 12))
        let n = 4
        let feld: CGFloat = 2 * r / CGFloat(n)
        let form = Path { p in
            p.move(to: P(-r, 0))
            p.addCurve(to: P(r, 0), control1: P(-r * 0.98, -r * 1.28), control2: P(r * 0.98, -r * 1.28))
            for i in 0..<n {
                let x0: CGFloat = r - CGFloat(i) * feld
                p.addQuadCurve(to: P(x0 - feld, 0), control: P(x0 - feld / 2, -r * 0.2))
            }
            p.closeSubpath()
        }
        let f = FigurFarbe(0xFF6F8A)
        teil(h, form, f)
        var innen = h
        innen.clip(to: form)
        for i in [1, 3] {
            let x0: CGFloat = -r + CGFloat(i) * feld
            let keil = Path { p in
                p.move(to: P(0, -r * 0.96))
                p.addLine(to: P(x0, 2))
                p.addLine(to: P(x0 + feld, 2))
                p.closeSubpath()
            }
            innen.fill(keil, with: .color(Pal.weiss.farbe.opacity(0.5)))
        }
        for i in 1..<n {
            let x: CGFloat = -r + CGFloat(i) * feld
            linie(h, bogen(P(0, -r * 0.96), P(x, 0), P(x * 0.55, -r * 0.62)), f.kontur, 1.6)
        }
        teil(h, kreis(P(0, -r * 0.97), 3), Pal.dunkel, 1.5)
    }

    /// What the hands hold: the umbrella shaft with its hook, the phone (right) and the white
    /// charging cable ending in a plug in the left hand. `s` scales it (0.66 on the full body).
    func extrasInHand(_ g: GraphicsContext, l: CGPoint?, r: CGPoint?, dach: CGPoint?, groesse s: CGFloat) {
        if hantelnAktiv {
            for h in [l, r].compactMap({ $0 }) {
                let stange = strich(P(h.x - 20 * s, h.y), P(h.x + 20 * s, h.y))
                linie(g, stange, Pal.silber.kontur, 7 * s)
                linie(g, stange, Pal.silber.farbe, 4 * s)
                teil(g, box(h.x - 28 * s, h.y - 12 * s, 9 * s, 24 * s, 3 * s), Pal.dunkel, 3 * s)
                teil(g, box(h.x + 19 * s, h.y - 12 * s, 9 * s, 24 * s, 3 * s), Pal.dunkel, 3 * s)
            }
        }
        let mitHandy = extras.contains(.handyKabel)
        if let dach, let griff = mitHandy ? l : r {
            let stock = strich(griff, dach)
            linie(g, stock, Pal.dunkel.kontur, 6 * s)
            linie(g, stock, Pal.silber.farbe, 3.6 * s)
            let seite: CGFloat = griff.x < 100 ? 1 : -1
            let haken = bogen(P(griff.x, griff.y + 2 * s), P(griff.x + seite * 9 * s, griff.y + 13 * s), P(griff.x + seite * s, griff.y + 19 * s))
            linie(g, haken, Pal.holz.kontur, 6.5 * s)
            linie(g, haken, Pal.holz.farbe, 4 * s)
        }
        guard mitHandy, let r else { return }
        let ziel = l ?? P(r.x - 60 * s, r.y + 20 * s)
        let start = P(r.x, r.y + 6 * s)
        let kabel = Path { p in
            p.move(to: start)
            p.addCurve(to: P(ziel.x, ziel.y - 6 * s), control1: P(start.x - 4 * s, start.y + 46 * s), control2: P(ziel.x + 4 * s, ziel.y + 44 * s))
        }
        linie(g, kabel, Pal.weiss.kontur, 5.5 * s)
        linie(g, kabel, .white, 3.2 * s)
        var t = g
        t.translateBy(x: r.x, y: r.y - 14 * s)
        t.scaleBy(x: s * 0.9, y: s * 0.9)
        handy(t, .zero, rueckseite: true)
        if let l {
            teil(g, box(l.x - 4 * s, l.y - 17 * s, 8 * s, 12 * s, 2.5 * s), Pal.weiss, 1.6 * s)
            g.fill(box(l.x - 2.4 * s, l.y - 22 * s, 4.8 * s, 6 * s, s), with: .color(Pal.silber.farbe))
        }
    }

    /// Scarf around the neck with a hanging end, in the winter hat's color. `c`: collar point.
    func schal(_ g: GraphicsContext, _ c: CGPoint, s: CGFloat) {
        var h = g
        h.translateBy(x: c.x, y: c.y)
        h.scaleBy(x: s, y: s)
        let f = muetzeF
        teil(h, box(5, 2, 15, 46, 5), f.mal(0.92), 3)
        for y in [CGFloat(14), 30] { linie(h, strich(P(6, y), P(19, y)), Pal.weiss.farbe, 3) }
        for x in stride(from: CGFloat(7), through: 18, by: 3.6) { linie(h, strich(P(x, 48), P(x, 55)), f.farbe, 2) }
        let band = bogen(P(-26, -6), P(26, -6), P(0, 16))
        linie(h, band, f.kontur, 18)
        linie(h, band, f.farbe, 13.5)
        linie(h, bogen(P(-20, -3), P(20, -3), P(0, 14)), Pal.weiss.farbe.opacity(0.85), 2.5)
    }

    /// Slowly falling snowflakes over `bereich`, behind the figure.
    func schneeflocken(_ g: GraphicsContext, _ bereich: CGRect) {
        let n = 9
        for i in 0..<n {
            let p = zyklus(7, Double(i) * 7 / Double(n))
            let x: CGFloat = bereich.minX + bereich.width * (CGFloat(i) + 0.5) / CGFloat(n) + w(1.3, Double(i)) * 6
            let y: CGFloat = bereich.minY + bereich.height * (CGFloat((i * 37) % 100) / 100 + p).truncatingRemainder(dividingBy: 1)
            let r: CGFloat = bereich.height / 60 + CGFloat(i % 3)
            for k in 0..<3 {
                let a = Double(k) * Double.pi / 3 + Double(i)
                let dx = CGFloat(cos(a)) * r
                let dy = CGFloat(sin(a)) * r
                let strahl = strich(P(x - dx, y - dy), P(x + dx, y + dy))
                linie(g, strahl, Pal.himmel.kontur.opacity(0.55), 3.2)
                linie(g, strahl, .white, 1.7)
            }
        }
    }
}
