import SwiftUI

// MARK: - Full body (200 x 400; the head is the half-figure head scaled by 0.8)

extension Zeichner {
    func zeichneGanz(_ ctx: GraphicsContext, _ size: CGSize) {
        var g = ctx
        g.scaleBy(x: size.width / 200, y: size.height / 400)
        g.clip(to: Path(CGRect(x: 0, y: 0, width: 200, height: 400)))
        let m = masse()
        let hal = haltung
        let bew = bewegung()
        // Scenes with furniture only bob; standing figures may also sway. Driving (Brief G bugfix):
        // the car drifts and tilts gently, in step with the steering wheel (`lenkWinkel`).
        let winkel: Double = [.stehen, .gehen, .rennen, .fahren, .scooter].contains(hal) ? bew.winkel : 0
        let drift: CGFloat = hal == .fahren ? w(1.8) * 3 : 0
        let atem: CGFloat = z == .offline ? 1 : 1.005 + 0.005 * w(2 * Double.pi / 3.6)
        g.translateBy(x: 100 + drift, y: 392)
        g.rotate(by: .degrees(winkel))
        g.scaleBy(x: atem, y: atem)
        g.translateBy(x: -100, y: bew.hoch - 392)

        let oben = obenVersatz(hal, m)
        var u = g
        u.translateBy(x: 0, y: oben)
        // Head space: half-figure chin (100, 152) sits 12 above the shoulders.
        var k = u
        k.translateBy(x: 20, y: m.schulterY - 133.6)
        k.scaleBy(x: 0.8, y: 0.8)
        if let um = umarmung {
            // Brief K: the head leans onto the partner in the hug and straightens a little to kiss.
            let neigung = um.neigung ?? um.seite * (6 * um.arme * (1 - um.kuss) + 3 * um.kuss)
            k.translateBy(x: 100, y: 152)
            k.rotate(by: .degrees(Double(neigung)))
            k.translateBy(x: -100, y: -152)
        }
        if umarmung?.ebene == .nurArm {
            paarArm(u, m)
            gehalteneHand(u, m)
            return
        }

        if z == .morgen || z == .abend { hintergrund(k) }
        if extras.contains(.schneeflocken) { schneeflocken(g, CGRect(x: 0, y: 0, width: 200, height: 400)) }
        szeneHinten(g, m, oben)
        gymHinten(g, m, oben)
        let arme = umarmt(mitExtrasGanz(poseGanz(m), m), m)
        let dach = schirmDachMitte(halb: false, m)
        if let dach { schirmDach(u, dach, radius: 40) }
        haareHinten(haarKontext(k))
        scooter(g, m, oben)
        if hal != .fahren { beine(g, m, hal, oben) }
        rumpfGanz(u, m)
        if extras.contains(.muetzeSchal) { schal(u, P(100, m.schulterY - 4), s: 0.66) }
        kopfGruppe(k)
        vorArmen(g, u, m, oben)
        // Teil 2: the partner-side arm is drawn separately (`paarArm`) so it can layer over both bodies.
        let paarSeiteLinks = (umarmung?.hand != nil) && (umarmung?.seite ?? 0) < 0
        let paarSeiteRechts = (umarmung?.hand != nil) && (umarmung?.seite ?? 0) > 0
        if neu == .b {
            let torso = rumpfPfad(m, unten: m.hueftY + 4)
            if !paarSeiteLinks { armV(u, P(100 - m.s + 6, m.schulterY + 10), arme.l, m.arm * vForm.dick, rumpf: torso) }
            if !paarSeiteRechts { armV(u, P(100 + m.s - 6, m.schulterY + 10), arme.r, m.arm * vForm.dick, rumpf: torso) }
        } else {
            if !paarSeiteLinks { arm(u, P(100 - m.s + 6, m.schulterY + 10), arme.l, m.arm) }
            if !paarSeiteRechts { arm(u, P(100 + m.s - 6, m.schulterY + 10), arme.r, m.arm) }
        }
        if !rechteHandBelegt { handRequisite(u, arme, m) }
        extrasInHand(u, l: arme.l.hand, r: arme.r.hand, dach: dach, groesse: 0.66)
        if neu != .b {
            let hand: CGFloat = 10 * m.arm
            if !paarSeiteLinks { teil(u, kreis(arme.l.hand, hand), haut, 2.5) }
            if !paarSeiteRechts { teil(u, kreis(arme.r.hand, hand), haut, 2.5) }
        }
        zubehoerGanz(u, arme, m)
        // p48: bigger and on the figure's left, so it does not hide behind the carried bag.
        if let id = tierId { zeichneHaustier(g, id: id, boden: P(40, Masse.fussY + 3), groesse: 0.95, nachLinks: false) }
        auto(g, m, oben)
        switch z {
        case .laeuft, .rennt, .rad, .scooter: tempoStriche(g, m.schulterY + oben)
        case .schautVideo: break
        // In the hug the kiss is the lips themselves, no blown kiss flying off.
        default: if umarmung == nil { effekte(k) }
        }
        abzeichenVorn(k)
        if umarmung?.ebene == .alles {
            paarArm(u, m)
            gehalteneHand(u, m)
        }
    }

    /// Brief K: blends the arms from the current pose into the hug. The right figure's inner arm
    /// lies over the partner's shoulders, the left one's reaches round the partner's waist behind
    /// them; the outer arm hangs at rest (no blown-kiss hand).
    func umarmt(_ a: (l: Arm, r: Arm), _ m: Masse) -> (l: Arm, r: Arm) {
        guard let um = umarmung, um.arme > 0, um.hand == nil, um.neigung == nil else { return a }
        let y = m.schulterY
        let lx: CGFloat = 100 - m.s + 6
        let rx: CGFloat = 100 + m.s - 6
        let partner = 100 + um.seite * um.abstand
        let restL = Arm(P(lx - 6, y + 50), P(lx - 4, y + 92))
        let restR = Arm(P(rx + 6, y + 50), P(rx + 4, y + 92))
        let hand = P(max(partner - 22, 10), y + 8)
        let ueberSchulter = Arm(P((lx + hand.x) / 2, y - 2), hand)
        let umTaille = Arm(P(partner - 26, y + 48), P(min(partner + 6, 190), y + 58))
        let ziel = um.seite < 0 ? (l: ueberSchulter, r: restR) : (l: restL, r: umTaille)
        func mix(_ von: Arm, _ nach: Arm) -> Arm {
            Arm(zwischen(von.ellbogen, nach.ellbogen, um.arme), zwischen(von.hand, nach.hand, um.arme))
        }
        return (mix(a.l, ziel.l), mix(a.r, ziel.r))
    }

    /// Z-24.2/Z-39.3: worn shop parts and free jewelry, scaled like `jackeZeichnen`'s `s: 0.66` onto the full-body torso.
    func zubehoerGanz(_ g: GraphicsContext, _ arme: (l: Arm, r: Arm), _ m: Masse) {
        let s: CGFloat = 0.66
        if let id = tascheId {
            // Hangs from the right hand, the handle in the fist, big enough to read (fix round 1).
            let gr = taschenGroesse(id: id, ganz: true)
            zeichneTasche(g, id: id, an: P(arme.r.hand.x + 2, arme.r.hand.y + taschenGriff(id: id) * gr), groesse: gr)
        }
        uhrZeichnen(g, arme.l, groesse: m.arm)
        schmuckZeichnen(g, hals: P(100, m.schulterY - 6), linkerArm: arme.l, rechterArm: arme.r, groesse: s)
    }

    func masse() -> Masse {
        let k = km
        let beinL = FigurPoseLogik.beinLaenge(stufe: groesseStufe)
        let hueftY = Masse.fussY - beinL
        return Masse(s: k.s * (neu == .b && z != .gym ? 0.92 : 1), t: k.t, h: k.h, arm: k.arm, bein: k.bein,
                     hueftY: hueftY, schulterY: hueftY - 96, knieY: hueftY + beinL * 0.5)
    }

    var haltung: Haltung {
        if let g = gymGeste { return gymHaltung(g) }
        if figurPose?.sitzt == true { return .sitzen }
        return switch z {
        case .laeuft, .tanzt: .gehen
        case .rennt: .rennen
        case .rad: .rad
        case .faehrt, .fahrschule: .fahren
        case .scooter: .scooter
        case .zuhause, .schule, .arbeit, .schautVideo, .ruhe, .zug, .zeichnet: .sitzen
        default: .stehen
        }
    }

    /// How far the upper body drops: sitting puts the hips at knee height.
    func obenVersatz(_ hal: Haltung, _ m: Masse) -> CGFloat {
        if let g = gymGeste {
            if g == .kniebeuge { return wdh * 34 }
            if g == .ausfallschritt { return wdh * 26 }
        }
        return switch hal {
        case .sitzen, .fahren: FigurPoseLogik.sitzVersatz(beinLaenge: (m.knieY - m.hueftY) * 2)
        case .rad: 40
        default: 0
        }
    }

    // MARK: Legs, pants, shoes

    func beinGelenke(_ hal: Haltung, _ m: Masse, _ oben: CGFloat) -> (l: Bein, r: Bein) {
        if let g = gymGeste, let b = gymBeine(g, m, oben) { return b }
        let hx: CGFloat = m.h * 0.52
        let hy: CGFloat = m.hueftY + oben
        let fy = Masse.fussY
        func bein(_ seite: CGFloat, _ phase: CGFloat) -> Bein {
            let x: CGFloat = 100 + seite * hx
            let hebt: CGFloat = max(0, phase)
            switch hal {
            case .gehen:
                // Stride: the lifted leg bends, its foot kicks back and up; the other one is planted.
                return Bein(h: P(x, hy), k: P(x + seite * 2 + phase * 4, m.knieY - hebt * 12), f: P(x + seite * 3 - phase * 6, fy - hebt * 24))
            case .rennen:
                return Bein(h: P(x, hy), k: P(x + phase * 2, m.knieY - hebt * 22), f: P(x + phase * 5, fy - 4 - hebt * 30))
            case .sitzen, .fahren:
                return Bein(h: P(x, hy), k: P(x + seite * 5, m.knieY + 10), f: P(x + seite * 4, fy))
            case .rad:
                let pedal: CGFloat = 346 + phase * 14
                let knie: CGFloat = hy + 26 + phase * 11
                return Bein(h: P(x, hy), k: P(x + seite * 10, knie), f: P(x + seite * 2, pedal))
            case .stehen:
                return Bein(h: P(x, hy), k: P(x + seite, m.knieY), f: P(x + seite * 2, fy))
            case .scooter:
                // Both feet side by side on the deck, knees a little bent.
                return Bein(h: P(x, hy), k: P(x + seite * 4, m.knieY + 4), f: P(100 + seite * 10, fy - 2))
            }
        }
        let s: CGFloat
        switch hal {
        case .gehen: s = statisch ? 0.9 : w(7)
        case .rennen: s = w(12)
        case .rad: s = statisch ? 0.6 : w(6)
        default: s = 0
        }
        return (bein(-1, s), bein(1, -s))
    }

    func beinPfad(_ b: Bein, _ oben: CGFloat, _ mitte: CGFloat, _ unten: CGFloat) -> Path {
        Path { p in
            p.move(to: P(b.h.x - oben, b.h.y))
            p.addLine(to: P(b.k.x - mitte, b.k.y))
            p.addLine(to: P(b.f.x - unten, b.f.y))
            p.addLine(to: P(b.f.x + unten, b.f.y))
            p.addLine(to: P(b.k.x + mitte, b.k.y))
            p.addLine(to: P(b.h.x + oben, b.h.y))
            p.closeSubpath()
        }
    }

    var hosenFarbe: FigurFarbe {
        // ponytail: 0/1/2 are named denim washes, not freely dyeable — a picked swatch is ignored
        // there for v2 back-compat, but a free hex color (Z-24.1) always wins.
        if hosenHexAktiv { return hoseF }
        switch hose {
        case 0, 2: return FigurFarbe(0x9DB8D9)
        case 1: return FigurFarbe(0x34507A)
        case 13: return FigurFarbe(0x4B6C98) // Levi's 501, mid blue wash
        default: return hoseF
        }
    }

    func beine(_ g: GraphicsContext, _ m: Masse, _ hal: Haltung, _ oben: CGFloat) {
        let (l, r) = beinGelenke(hal, m, oben)
        let b = m.bein
        let kleid = oberteil == 8 || oberteil == 38
        let nackt = kleid || (6...8).contains(hose)
        let stiefelUeber = schuhe == 3 && hose != 2
        if nackt {
            for bn in [l, r] { teil(g, beinPfad(bn, b * 0.46, b * 0.36, b * 0.3), haut) }
        }
        if !stiefelUeber {
            for bn in [l, r] { schuhZeichnen(g, bn.f) }
        }
        if !kleid { hoseZeichnen(g, l, r, m, m.hueftY + oben) }
        if stiefelUeber {
            for bn in [l, r] { schuhZeichnen(g, bn.f) }
        }
    }

    func hoseZeichnen(_ g: GraphicsContext, _ l: Bein, _ r: Bein, _ m: Masse, _ hy: CGFloat) {
        let b = m.bein
        let farbe = hosenFarbe
        let bund = box(100 - m.h + 1, hy - 10, (m.h - 1) * 2, 26, 8)
        if hose == 7 || hose == 8 {
            let saum: CGFloat = hose == 7 ? m.knieY + 4 : hy + 36
            let weite: CGFloat = hose == 7 ? 12 : 8
            let rock = Path { p in
                p.move(to: P(100 - m.h + 2, hy - 10))
                p.addLine(to: P(100 - m.h - weite, saum))
                p.addQuadCurve(to: P(100 + m.h + weite, saum), control: P(100, saum + 6))
                p.addLine(to: P(100 + m.h - 2, hy - 10))
                p.closeSubpath()
            }
            teil(g, rock, farbe)
            if hose == 7 {
                var h = g
                h.clip(to: rock)
                for dx in [CGFloat(-14), 0, 14] {
                    linie(h, strich(P(100 + dx * 0.6, hy + 4), P(100 + dx, saum)), farbe.kontur.opacity(0.5), 1.5)
                }
            }
            return
        }
        let seiten: [(bein: Bein, seite: CGFloat)] = [(l, -1), (r, 1)]
        if hose == 6 {
            let teile = seiten.map { s in
                beinPfad(Bein(h: s.bein.h, k: zwischen(s.bein.h, s.bein.k, 0.4), f: zwischen(s.bein.h, s.bein.k, 0.85)), b * 0.66, b * 0.62, b * 0.6)
            }
            verbunden(g, teile + [bund], farbe)
            return
        }
        let breiten: (CGFloat, CGFloat, CGFloat)
        switch hose {
        case 2: breiten = (0.64, 0.6, 0.84)
        case 4, 14: breiten = (0.66, 0.56, 0.42)
        case 9, 15: breiten = (0.54, 0.42, 0.34)
        case 20: breiten = (0.58, 0.44, 0.36)
        case 12: breiten = (0.64, 0.56, 0.5)
        default: breiten = (0.62, 0.5, 0.45)
        }
        let teile = [l, r].map { beinPfad($0, b * breiten.0, b * breiten.1, b * breiten.2) }
        verbunden(g, teile + [bund], farbe)
        switch hose {
        case 0, 1, 2:
            linie(g, strich(P(100, hy - 4), P(100, hy + 14)), farbe.kontur, 1.5)
            for bn in [l, r] { g.fill(oval(bn.k, b * 0.3, b * 0.9), with: .color(.white.opacity(0.14))) }
        case 3:
            for bn in [l, r] { linie(g, strich(P(bn.h.x, bn.h.y + 14), P(bn.f.x, bn.f.y - 4)), farbe.kontur.opacity(0.35), 1.2) }
        case 4:
            for s in seiten {
                let f = s.bein.f
                teil(g, box(f.x - b * 0.44, f.y - 9, b * 0.88, 9, 3.5), farbe.mal(0.85), 2)
                let oben = P(s.bein.h.x + s.seite * b * 0.5, s.bein.h.y + 6)
                let unten = P(f.x + s.seite * b * 0.32, f.y - 10)
                linie(g, strich(oben, unten), .white.opacity(0.85), 2.5)
            }
            for dx in [CGFloat(-3), 3] { linie(g, strich(P(100 + dx, hy - 4), P(100 + dx * 1.6, hy + 8)), .white, 1.5) }
        case 5:
            // Cargohose: p48 drawing in Zubehoer/ModeZeichner.swift.
            zeichneCargohose(g, beine: seiten.map { (h: $0.bein.h, k: $0.bein.k, f: $0.bein.f, seite: $0.seite) },
                             b: b, farbe: farbe, hy: hy, halbBreite: m.h)
        case 10:
            // Anzughose: crease line plus a thin belt at the waist.
            for bn in [l, r] { linie(g, strich(P(bn.h.x, bn.h.y + 14), P(bn.f.x, bn.f.y - 4)), farbe.kontur.opacity(0.4), 1.2) }
            linie(g, strich(P(100 - m.h, hy - 8), P(100 + m.h, hy - 8)), Pal.dunkel.farbe, 3)
        case 12...15:
            markenHose(g, seiten, m, hy)
        case 20:
            // Skinny Jeans mit Blumen: p56 drawing in Zubehoer/ModeElegant.swift.
            zeichneBlumenJeans(g, beine: seiten.map { (h: $0.bein.h, k: $0.bein.k, f: $0.bein.f, seite: $0.seite) },
                               b: b, farbe: farbe, hy: hy, halbBreite: m.h)
        case 11:
            // Glitzerhose: scattered sparkles over the whole leg.
            for i in 0..<10 {
                let bn = i % 2 == 0 ? l : r
                let y = bn.h.y + CGFloat(i) * 8 + 6
                g.fill(funkel(P(bn.h.x + (i % 3 == 0 ? -6 : 6), y), 2.5), with: .color(.white.opacity(0.8)))
            }
        default:
            break
        }
    }

    /// Z-39.1 brand pants: Adidas three stripes, Levi's 501 button fly and red tab, Nike Tech Fleece
    /// cuffs and swoosh, Puma leggings side stripe.
    func markenHose(_ g: GraphicsContext, _ seiten: [(bein: Bein, seite: CGFloat)], _ m: Masse, _ hy: CGFloat) {
        let b = m.bein
        let farbe = hosenFarbe
        let linksOben = seiten[0].bein.h
        let rechtsOben = seiten[1].bein.h
        switch hose {
        case 12:
            for s in seiten {
                let oben = P(s.bein.h.x + s.seite * b * 0.46, s.bein.h.y + 6)
                let unten = P(s.bein.f.x + s.seite * b * 0.36, s.bein.f.y - 4)
                dreiStreifen(g, oben, unten, 0.55)
            }
        case 13:
            for i in 0..<3 { g.fill(kreis(P(100, hy - 2 + CGFloat(i) * 6), 1.1), with: .color(Pal.gold.farbe)) }
            g.fill(box(linksOben.x - b * 0.62, hy + 2, 3, 5, 1), with: .color(FigurFarbe(0xC8283F).farbe))
            for s in seiten {
                let naht = bogen(P(s.bein.h.x - s.seite * 2, hy - 4), P(s.bein.h.x + s.seite * b * 0.6, hy + 8), P(s.bein.h.x + s.seite * 2, hy + 8))
                linie(g, naht, FigurFarbe(0xE3A33A).farbe.opacity(0.8), 1)
            }
        case 14:
            for s in seiten {
                let f = s.bein.f
                teil(g, box(f.x - b * 0.44, f.y - 9, b * 0.88, 9, 3.5), farbe.mal(0.85), 2)
            }
            swoosh(g, P(linksOben.x, linksOben.y + 16), 0.5, farbe.mix(Pal.weiss, 0.8).farbe)
            linie(g, strich(P(rechtsOben.x + 2, rechtsOben.y + 10), P(rechtsOben.x + 6, rechtsOben.y + 22)), farbe.kontur, 1.2)
        case 15:
            for s in seiten {
                let oben = P(s.bein.h.x + s.seite * b * 0.5, s.bein.h.y + 4)
                let unten = P(s.bein.f.x + s.seite * b * 0.3, s.bein.f.y - 6)
                linie(g, strich(oben, unten), .white.opacity(0.85), 1.6)
            }
            g.fill(kreis(P(rechtsOben.x + 2, hy + 8), 1.8), with: .color(.white))
        default:
            break
        }
    }

    func schuhZeichnen(_ g: GraphicsContext, _ f: CGPoint) {
        let c = schuhF
        let hell = c.r > 0.9 && c.g > 0.9 && c.b > 0.9
        let sohle = hell ? FigurFarbe(0xC9CCD3) : FigurFarbe(0xF4F1EE)
        let x = f.x
        let y = f.y
        switch schuhe {
        case 1:
            teil(g, box(x - 11, y - 16, 22, 26, 7), c, 3)
            teil(g, oval(P(x, y + 5), 10, 5.5), sohle, 2)
            g.fill(box(x - 12, y + 8, 24, 4, 2), with: .color(sohle.farbe))
            for dy in [CGFloat(-10), -4] { linie(g, strich(P(x - 4, y + dy), P(x + 4, y + dy)), .white.opacity(0.9), 1.6) }
        case 2:
            teil(g, box(x - 12, y - 4, 24, 14, 7), c, 3)
            teil(g, box(x - 13, y + 6, 26, 6, 3), sohle, 2)
            linie(g, bogen(P(x - 8, y + 4), P(x + 8, y - 1), P(x, y + 6)), sohle.farbe, 2)
        case 3:
            teil(g, box(x - 11, y - 34, 22, 44, 7), c, 3)
            g.fill(box(x - 12, y + 6, 24, 5, 2), with: .color(c.mal(0.55).farbe))
        case 4:
            teil(g, box(x - 11, y - 16, 22, 26, 7), c, 3)
            g.fill(box(x - 4, y - 15, 8, 12, 3), with: .color(c.mal(0.7).farbe))
            g.fill(box(x - 12, y + 6, 24, 4, 2), with: .color(c.mal(0.55).farbe))
        case 5:
            teil(g, oval(P(x, y + 3), 10, 7), haut, 2.5)
            g.fill(box(x - 12, y + 8, 24, 4, 2), with: .color(c.farbe))
            for dy in [CGFloat(0), 5] { linie(g, strich(P(x - 10, y + dy), P(x + 10, y + dy)), c.farbe, 3.5) }
        case 6:
            teil(g, oval(P(x, y), 8.5, 6), haut, 2.5)
            teil(g, box(x - 11, y + 1, 22, 10, 5), c, 2.5)
            teil(g, kreis(P(x, y + 3), 2.5), c.mal(0.8), 1.5)
        case 7:
            teil(g, box(x - 12, y - 3, 24, 13, 6), c, 3)
            g.fill(box(x - 7, y, 14, 4, 2), with: .color(c.mal(0.75).farbe))
            g.fill(box(x - 12, y + 8, 24, 3, 1.5), with: .color(c.mal(0.55).farbe))
        case 8:
            // Logo-Sneaker (Nike, Jordan): p48 drawing in Zubehoer/ModeZeichner.swift.
            zeichneNikeSneaker(g, fuss: f, farbe: c)
        case 9:
            // Two-Tone-Sneaker: base sneaker with a contrasting toe cap.
            teil(g, box(x - 12, y - 5, 24, 15, 7), c, 3)
            teil(g, box(x - 12, y - 5, 11, 15, 7), c.mix(Pal.weiss, 0.35), 2)
            g.fill(box(x - 12, y + 6, 24, 4, 2), with: .color(sohle.farbe))
        case 10:
            // Nike Air Force 1: chunky upper, thick white cupsole, swoosh, perforated toe.
            teil(g, box(x - 13, y - 6, 26, 14, 7), c, 3)
            teil(g, box(x - 14, y + 4, 28, 7, 3), Pal.weiss, 2)
            linie(g, strich(P(x - 13, y + 7.5), P(x + 13, y + 7.5)), Pal.silber.farbe, 1)
            swoosh(g, P(x + 1, y + 1), 0.55, hell ? Pal.silber.mal(0.9).farbe : Pal.weiss.farbe)
            for dx in [CGFloat(-9), -6.5, -4] { g.fill(kreis(P(x + dx, y - 1), 0.7), with: .color(c.kontur)) }
        case 11:
            // Adidas Samba: slim upper, suede T-toe, three stripes, gum sole.
            teil(g, box(x - 13, y - 4, 26, 12, 6), c, 3)
            g.fill(box(x - 13, y - 3, 7, 10, 3), with: .color(c.mal(0.85).farbe))
            let streifenFarbe: Color = hell ? Pal.tinte.farbe : .white
            for dx in [CGFloat(-1), 2.5, 6] { linie(g, strich(P(x + dx, y + 6), P(x + dx + 3.5, y - 3)), streifenFarbe, 1.6) }
            teil(g, box(x - 13.5, y + 7, 27, 4, 2), FigurFarbe(0xC98A4B), 1.5)
        case 12:
            // New Balance 550: chunky leather, green "N", colored heel.
            teil(g, box(x - 13, y - 7, 26, 15, 7), c, 3)
            teil(g, box(x - 13.5, y + 6, 27, 5, 2.5), Pal.weiss, 1.8)
            text(g, "N", P(x + 1, y + 1), 9, FigurFarbe(0x2E7D4F).farbe)
            g.fill(box(x + 8, y - 5, 4, 10, 2), with: .color(FigurFarbe(0x2E7D4F).farbe))
        case 13:
            // Gucci Ace: white leather with the green-red-green web and a gold bee.
            teil(g, box(x - 12, y - 5, 24, 15, 7), c, 3)
            g.fill(box(x - 12, y + 6, 24, 4, 2), with: .color(sohle.farbe))
            g.fill(box(x - 4, y - 4, 4, 10), with: .color(FigurFarbe(0x1F7A45).farbe))
            g.fill(box(x - 2.8, y - 4, 1.6, 10), with: .color(FigurFarbe(0xC8283F).farbe))
            g.fill(kreis(P(x + 6, y), 1.6), with: .color(Pal.gold.farbe))
        case 14:
            // Balenciaga Triple S: stacked chunky sole, layered upper.
            teil(g, box(x - 13, y - 7, 26, 13, 6), c, 3)
            teil(g, box(x - 11, y - 5, 12, 8, 3), c.mix(Pal.weiss, 0.4), 1.5)
            teil(g, box(x - 15, y + 4, 30, 4, 2), Pal.silber, 1.5)
            teil(g, box(x - 15, y + 8, 30, 4, 2), FigurFarbe(0xD8C3A0), 1.5)
            teil(g, box(x - 14, y + 12, 28, 3, 1.5), Pal.dunkel.mix(Pal.weiss, 0.3), 1)
        case 16:
            // p65 D: Air Jordan 1 (Zubehoer/ModeMarken.swift).
            zeichneJordanSneaker(g, fuss: f, farbe: c)
        case 17:
            // p65 D: Nike Dunk Low (Zubehoer/ModeMarken.swift).
            zeichneDunkSneaker(g, fuss: f, farbe: c)
        default:
            teil(g, box(x - 12, y - 5, 24, 15, 7), c, 3)
            g.fill(box(x - 12, y + 6, 24, 4, 2), with: .color(sohle.farbe))
            linie(g, strich(P(x - 4, y - 1), P(x + 4, y - 1)), sohle.farbe, 1.6)
            linie(g, strich(P(x - 4, y + 2.5), P(x + 4, y + 2.5)), sohle.farbe, 1.6)
        }
    }

    // MARK: Torso

    func rumpfPfad(_ m: Masse, unten: CGFloat) -> Path {
        let sY = m.schulterY
        let taille: CGFloat = min(sY + 58, unten - 4)
        let saum: CGFloat = unten < m.hueftY ? m.t + 1 : m.h
        // Z-38.2: chest (muscular) or bust (curvy) bows the flank outward; 0 keeps the old straight flank.
        let bauch: CGFloat = 8 * km.muskel + 5 * km.kurve
        let flankeX: CGFloat = (m.s + m.t) / 2 + bauch
        let flankeY: CGFloat = (sY + 14 + taille) / 2
        // Kräftig: a round belly between waist and hem.
        let bauchRund: CGFloat = koerperform == 2 ? 9 : 0
        let bauchX: CGFloat = (m.t + saum) / 2 + bauchRund
        let bauchY: CGFloat = (taille + unten) / 2
        return Path { p in
            p.move(to: P(89, sY - 2))
            p.addQuadCurve(to: P(100 - m.s, sY + 14), control: P(104 - m.s, sY - 2))
            p.addQuadCurve(to: P(100 - m.t, taille), control: P(100 - flankeX, flankeY))
            p.addQuadCurve(to: P(100 - saum, unten), control: P(100 - bauchX, bauchY))
            p.addQuadCurve(to: P(100 + saum, unten), control: P(100, unten + 4))
            p.addQuadCurve(to: P(100 + m.t, taille), control: P(100 + bauchX, bauchY))
            p.addQuadCurve(to: P(100 + m.s, sY + 14), control: P(100 + flankeX, flankeY))
            p.addQuadCurve(to: P(111, sY - 2), control: P(96 + m.s, sY - 2))
            p.addQuadCurve(to: P(89, sY - 2), control: P(100, sY + 10))
            p.closeSubpath()
        }
    }

    func rumpfGanz(_ g: GraphicsContext, _ m: Masse) {
        let sY = m.schulterY
        let unten = m.hueftY + 4
        teil(g, box(91, sY - 28, 18, 34, 8), haut)
        g.fill(oval(P(100, sY - 14), 9, 3.5), with: .color(haut.mal(0.8).farbe.opacity(0.6)))
        let voll = rumpfPfad(m, unten: unten)
        if oberkoerperFrei {
            teil(g, voll, haut)
            g.fill(box(90, sY - 8, 20, 14), with: .color(haut.farbe))
            var d = g
            d.clip(to: voll)
            d.translateBy(x: 100, y: sY - 2)
            d.scaleBy(x: 0.66 * m.s / 41, y: 0.8)
            d.translateBy(x: -100, y: -161)
            koerperDetails(d, nackt: true)
            return
        }
        let form: Path
        switch oberteil {
        case 6:
            teil(g, voll, haut)
            var h = g
            h.clip(to: voll)
            teil(h, box(-10, sY + 18, 220, 200), top)
            for seite in [CGFloat(-1), 1] {
                let traeger = strich(P(100 + seite * 22, sY + 2), P(100 + seite * 24, sY + 20))
                linie(g, traeger, top.kontur, 5)
                linie(g, traeger, top.farbe, 2.8)
            }
            form = voll
        case 11:
            teil(g, voll, haut)
            g.fill(oval(P(100, sY + 80), 1.6, 2.4), with: .color(haut.kontur))
            form = rumpfPfad(m, unten: sY + 64)
            teil(g, form, top)
        default:
            form = voll
            teil(g, form, oberteilBasis)
        }
        if oberteil != 6 {
            // Top details are drawn in the half-figure torso space, mapped onto this torso.
            var dg = g
            // Details follow the body's width (Normal = the old 0.66).
            let quer: CGFloat = 0.66 * m.s / 41
            dg.translateBy(x: 100, y: sY - 2)
            dg.scaleBy(x: quer, y: 0.8)
            dg.translateBy(x: -100, y: -161)
            var d = g
            d.clip(to: form)
            d.translateBy(x: 100, y: sY - 2)
            d.scaleBy(x: quer, y: 0.8)
            d.translateBy(x: -100, y: -161)
            oberteilDetails(dg, d)
            koerperDetails(d, nackt: false)
            if Self.konturNachMuster.contains(oberteil) { linie(g, form, top.kontur, 3.5) }
        }
        if oberteil == 8 {
            let taille: CGFloat = sY + 58
            let saum: CGFloat = m.knieY + 6
            let rock = Path { p in
                p.move(to: P(100 - m.t, taille))
                p.addLine(to: P(100 - m.h - 18, saum))
                p.addQuadCurve(to: P(100 + m.h + 18, saum), control: P(100, saum + 8))
                p.addLine(to: P(100 + m.t, taille))
                p.closeSubpath()
            }
            teil(g, rock, top)
        }
        if oberteil == 38 {
            // p56: Wickelkleid, Rock und Knoten: Zubehoer/ModeElegant.swift.
            zeichneWickelRock(g, top: top, taille: sY + 58, saum: m.knieY - 6, t: m.t, h: m.h, knotenX: 100 - 18.5 * m.s / 41)
        }
        if jacke > 0 { jackeZeichnen(g, form: voll, oben: sY - 2, unten: unten, s: 0.66) }
    }

    // MARK: Arms and props
}
