import SwiftUI

extension Zeichner {

    func effekte(_ g: GraphicsContext) {
        let tinte = Pal.tinte.farbe
        switch z {
        case .imChat:
            // Symmetric smiley, not text: the High-Five sticker mirrors this pose.
            blase(g, CGRect(x: 12, y: 30, width: 52, height: 30), spitze: P(52, 66))
            g.fill(kreis(P(31, 41), 2.5), with: .color(tinte))
            g.fill(kreis(P(45, 41), 2.5), with: .color(tinte))
            linie(g, bogen(P(29, 48), P(47, 48), P(38, 56)), tinte, 2.5)
        case .tippt:
            blase(g, CGRect(x: 136, y: 34, width: 50, height: 26), spitze: P(142, 66))
            let aktiv = Int(zyklus(0.9) * 3)
            for i in 0..<3 {
                g.fill(kreis(P(149 + CGFloat(i) * 12, 47), 3.5), with: .color(tinte.opacity(i == aktiv ? 0.9 : 0.3)))
            }
        case .kamera:
            if an(2.2, 0.2) {
                g.fill(kreis(P(180, 58), 18), with: .color(.white.opacity(0.6)))
                g.fill(funkel(P(180, 58), 16), with: .color(Pal.gelb.farbe))
            }
        case .sprache:
            for i in 0..<3 {
                let r = 14 + CGFloat(i) * 7
                let c = P(122, 138)
                var h = g
                h.opacity = Double(0.3 + 0.7 * (1 - zyklus(1.2, Double(i) * 0.4)))
                linie(h, bogen(P(c.x + r * 0.64, c.y - r * 0.77), P(c.x + r * 0.64, c.y + r * 0.77), P(c.x + r * 1.3, c.y)), Pal.rose.farbe, 3)
            }
        case .schautBild:
            for (i, c) in [P(66, 184), P(138, 190), P(130, 168)].enumerated() {
                g.fill(funkel(c, 5 + 3 * abs(w(4, Double(i)))), with: .color(Pal.gelb.farbe))
            }
        case .schautVideo:
            let p = zyklus(1.1)
            var h = g
            h.opacity = Double(1 - p)
            teil(h, kreis(P(66 + 6 * p, 190 - 34 * p), 5), Pal.popcorn, 2)
        case .akkuLeer:
            var h = g
            h.opacity = an(1.0, 0.5) ? 1 : 0.3
            akku(h, 0.12, Pal.rose)
        case .laedt:
            akku(g, statisch ? 0.6 : zyklus(3), Pal.gruen)
            let blitz = Path { p in
                p.move(to: P(164, 24))
                p.addLine(to: P(155, 41))
                p.addLine(to: P(162, 41))
                p.addLine(to: P(157, 55))
                p.addLine(to: P(171, 35))
                p.addLine(to: P(164, 35))
                p.addLine(to: P(169, 24))
                p.closeSubpath()
            }
            teil(g, blitz, Pal.gelb, 2)
        case .offline:
            var h = g
            h.opacity = 0.55 + 0.3 * Double(w(1.5))
            let c = P(164, 58)
            for i in 1...3 {
                let r = CGFloat(i) * 7
                linie(h, bogen(P(c.x - r * 0.7, c.y - r * 0.7), P(c.x + r * 0.7, c.y - r * 0.7), P(c.x, c.y - r * 1.4)), Pal.silber.kontur, 3.5)
            }
            h.fill(kreis(c, 2.5), with: .color(Pal.silber.kontur))
            linie(h, strich(P(150, 32), P(178, 60)), Pal.rose.farbe, 3.5)
        case .schlaeft:
            for i in 0..<3 {
                let p = zyklus(3, Double(i))
                var h = g
                h.opacity = sin(Double(p) * Double.pi)
                text(h, "Z", P(146 + p * 26, 70 - p * 56), 12 + p * 10, Pal.nacht.farbe)
            }
        case .laeuft, .rennt, .rad:
            for i in 0..<3 {
                let y = 150 + CGFloat(i) * 20
                let x = 8 + zyklus(0.5, Double(i) * 0.17) * 10
                linie(g, strich(P(x, y), P(x + 18, y)), Pal.silber.kontur.opacity(0.7), 3.5)
            }
            if z == .rennt { teil(g, tropfenPfad(P(160, 58 + zyklus(1.2) * 18)), Pal.himmel, 2) }
        case .gym:
            teil(g, tropfenPfad(P(158, 60 + zyklus(1.4) * 16)), Pal.himmel, 2)
        case .gut:
            for (i, c) in [P(28, 60), P(174, 40), P(176, 124)].enumerated() {
                g.fill(funkel(c, 6 + 3 * w(4, Double(i) * 2)), with: .color(Pal.gelb.farbe))
            }
        case .mittel:
            teil(g, kreis(P(142, 72), 3), Pal.weiss, 2)
            teil(g, kreis(P(150, 62), 5), Pal.weiss, 2)
            teil(g, box(144, 22, 48, 30, 15), Pal.weiss, 2.5)
            text(g, "…", P(168, 35), 16, tinte)
        case .schlecht:
            let wolke = [kreis(P(112, 22), 12), kreis(P(130, 14), 15), kreis(P(148, 22), 12), box(104, 18, 52, 16, 8)]
            for p in wolke { linie(g, p, Pal.wolke.kontur, 5) }
            for p in wolke { g.fill(p, with: .color(Pal.wolke.farbe)) }
            for i in 0..<3 {
                let p = zyklus(0.9, Double(i) * 0.3)
                var h = g
                h.opacity = Double(1 - p)
                h.fill(tropfenPfad(P(114 + CGFloat(i) * 16, 42 + p * 24)), with: .color(Pal.himmel.farbe))
            }
        case .naehe:
            herzen(g, CGRect(x: 20, y: 30, width: 160, height: 90), 4)
        case .herz:
            herzen(g, CGRect(x: 30, y: 20, width: 140, height: 120), 5)
        case .worte:
            blase(g, CGRect(x: 134, y: 18, width: 54, height: 38), spitze: P(140, 68))
            g.fill(herzPfad(P(161, 38), 10 + 1.5 * w(6)), with: .color(Pal.rose.farbe))
        case .anstupsen:
            let stoss = max(0, w(9)) * 8
            let finger = strich(P(206, 112), P(170 - stoss, 118))
            linie(g, finger, haut.kontur, 14)
            linie(g, finger, haut.farbe, 10)
            linie(g, strich(P(28, 84), P(18, 76)), tinte, 3)
            linie(g, strich(P(26, 102), P(14, 102)), tinte, 3)
        case .kuss:
            let p = zyklus(1.6)
            var h = g
            h.opacity = Double(1 - p * p)
            lippen(h, P(128 + p * 52, 124 - p * 70), 0.7 + p * 0.6)
        case .lacht:
            var h = g
            h.opacity = an(0.5, 0.3) ? 1 : 0.4
            // Brief F2: squint lines and sweat drops sit at the old eye position, narrowed onto the new face.
            let hk = zubehoerKontext(h)
            for seite in [CGFloat(-1), 1] {
                linie(hk, strich(P(100 + seite * 64, 78), P(100 + seite * 76, 70)), tinte, 3)
                linie(hk, strich(P(100 + seite * 68, 96), P(100 + seite * 82, 96)), tinte, 3)
            }
            teil(zubehoerKontext(g), tropfenPfad(P(64, 110)), Pal.himmel, 1.5)
            teil(zubehoerKontext(g), tropfenPfad(P(136, 110)), Pal.himmel, 1.5)
        case .anstossen:
            if an(2.0, 0.25) { g.fill(funkel(P(160, 84), 10), with: .color(Pal.gelb.farbe)) }
        case .pokal:
            for (i, c) in [P(52, 146), P(108, 144), P(184, 84)].enumerated() {
                g.fill(funkel(c, 5 + 3 * abs(w(4, Double(i)))), with: .color(Pal.gelb.farbe))
            }
        case .zwinkert, .verliebt, .sauer, .schmollt, .verlegen, .muede, .ueberrascht, .lachtTraenen, .weint, .denkt, .feiert, .schockiert, .daumen, .tanzt:
            mimikEffekte(g)
        case .ruhig:
            let p = zyklus(5)
            if p < 0.5 && !statisch {
                var h = g
                h.opacity = Double(1 - p * 2)
                h.fill(herzPfad(P(152, 70 - p * 60), 6), with: .color(Pal.rose.farbe))
            }
        default:
            break
        }
    }

    /// Effects of the Runde-3 expressions, in the half-figure (head) space.
    func mimikEffekte(_ g: GraphicsContext) {
        let tinte = Pal.tinte.farbe
        switch z {
        case .zwinkert:
            g.fill(funkel(P(146, 84), 5 + 2 * abs(w(4))), with: .color(Pal.gelb.farbe))
        case .verliebt:
            herzen(g, CGRect(x: 24, y: 16, width: 152, height: 100), 5)
        case .sauer:
            // Anger mark and steam.
            var h = g
            h.translateBy(x: 152, y: 50)
            h.scaleBy(x: 1 + 0.08 * abs(w(8)), y: 1 + 0.08 * abs(w(8)))
            for k in 0..<4 {
                var r = h
                r.rotate(by: .degrees(Double(k) * 90))
                linie(r, bogen(P(3, -9), P(9, -3), P(4, -4)), Pal.rose.farbe, 3)
            }
            for (i, x) in [CGFloat(54), 146].enumerated() {
                let p = zyklus(1.4, Double(i) * 0.7)
                var d = g
                d.opacity = Double(1 - p)
                teil(d, kreis(P(x, 40 - p * 22), 6 + p * 5), Pal.weiss, 2)
            }
        case .schmollt:
            let wolke = [kreis(P(150, 132), 6), kreis(P(160, 128), 8), kreis(P(170, 133), 6)]
            for p in wolke { linie(g, p, Pal.wolke.kontur, 4) }
            for p in wolke { g.fill(p, with: .color(.white)) }
        case .verlegen:
            teil(g, tropfenPfad(P(150, 68 + zyklus(2.2) * 8)), Pal.himmel, 2)
        case .muede:
            // Brief F2: sweat drop at the old eye position, narrowed onto the new face.
            teil(zubehoerKontext(g), tropfenPfad(P(66, 110)), Pal.himmel, 1.5)
        case .ueberrascht:
            let s: CGFloat = 1 + 0.15 * abs(w(6))
            g.fill(box(160, 22, 7 * s, 22 * s, 3.5), with: .color(Pal.rose.farbe))
            g.fill(kreis(P(163.5, 50 * s), 4), with: .color(Pal.rose.farbe))
        case .lachtTraenen:
            // Brief F2: tears start at the old eye position, narrowed onto the new face.
            let lk = zubehoerKontext(g)
            for seite in [CGFloat(-1), 1] {
                linie(lk, strich(P(100 + seite * 64, 78), P(100 + seite * 76, 70)), tinte, 3)
                for i in 0..<2 {
                    let p = zyklus(0.8, Double(i) * 0.4)
                    let tropfen = P(100 + seite * (34 + p * 30), 104 - p * 8 + p * p * 30)
                    teil(lk, tropfenPfad(tropfen), Pal.himmel, 1.5)
                }
            }
        case .weint:
            // Brief F2: the tear stream starts at the old eye position, narrowed onto the new face.
            let wk = zubehoerKontext(g)
            for seite in [CGFloat(-1), 1] {
                let strom = bogen(P(100 + seite * 30, 104), P(100 + seite * 34, 156), P(100 + seite * 38, 128))
                linie(wk, strom, Pal.himmel.kontur.opacity(0.6), 7)
                linie(wk, strom, Pal.himmel.farbe, 4.5)
                let p = zyklus(0.9, seite > 0 ? 0.45 : 0)
                var d = wk
                d.opacity = Double(1 - p)
                teil(d, tropfenPfad(P(100 + seite * 34, 160 + p * 40)), Pal.himmel, 1.5)
            }
        case .denkt:
            teil(g, kreis(P(142, 70), 3), Pal.weiss, 2)
            teil(g, kreis(P(152, 60), 5), Pal.weiss, 2)
            teil(g, box(146, 20, 44, 30, 15), Pal.weiss, 2.5)
            text(g, "?", P(168, 35), 17, Pal.nacht.farbe)
        case .feiert:
            let farben = [Pal.rose, Pal.gelb, Pal.blau, Pal.mint]
            for i in 0..<12 {
                let p = zyklus(2.4, Double(i) * 0.2)
                let x: CGFloat = 14 + CGFloat(i) * 15 + w(3, Double(i)) * 6
                var h = g
                h.translateBy(x: x, y: 10 + p * 200)
                h.rotate(by: .degrees(Double(i) * 37 + t * 120))
                h.fill(box(-3, -1.5, 6, 3, 1), with: .color(farben[i % farben.count].farbe))
            }
        case .schockiert:
            for x in [CGFloat(78), 90, 102, 114, 126] {
                linie(g, strich(P(x, 40), P(x, 58)), Pal.nacht.farbe.opacity(0.35), 2.5)
            }
            teil(g, tropfenPfad(P(154, 72)), Pal.himmel, 1.5)
            teil(g, tropfenPfad(P(46, 76)), Pal.himmel, 1.5)
        case .daumen:
            g.fill(funkel(P(164, 150), 6 + 2 * abs(w(4))), with: .color(Pal.gelb.farbe))
        case .tanzt:
            for i in 0..<2 {
                let p = zyklus(1.8, Double(i) * 0.9)
                var d = g
                d.opacity = Double(1 - p)
                let x: CGFloat = i == 0 ? 30 : 166
                text(d, i == 0 ? "♪" : "♫", P(x + w(3, Double(i)) * 6, 90 - p * 60), 20, Pal.nacht.farbe)
            }
        default:
            break
        }
    }

    func abzeichenVorn(_ g: GraphicsContext) {
        if abz.contains("outfit") {
            let fluegel = Path { p in
                p.move(to: P(100, 170))
                p.addLine(to: P(86, 162))
                p.addLine(to: P(86, 178))
                p.closeSubpath()
            }
            teil(g, fluegel, Pal.rose, 2.5)
            teil(g, gespiegelt(fluegel), Pal.rose, 2.5)
            teil(g, kreis(P(100, 170), 4), Pal.rose.mal(0.8), 2)
            g.fill(funkel(P(40, 170), 5), with: .color(Pal.gelb.farbe))
        }
        if abz.contains("uhrwerk") {
            linie(g, strich(P(118, 168), P(128, 196)), Pal.band.farbe, 5)
            linie(g, strich(P(138, 168), P(128, 196)), Pal.band.farbe, 5)
            teil(g, kreis(P(128, 204), 11), Pal.gold, 2.5)
            linie(g, strich(P(128, 204), P(128, 197)), Pal.tinte.farbe, 2)
            linie(g, strich(P(128, 204), P(133, 206)), Pal.tinte.farbe, 2)
        }
        if abz.contains("partyhut") {
            teil(g, box(14, 214, 42, 30, 6), Pal.rose.mix(Pal.weiss, 0.5))
            teil(g, box(12, 208, 46, 10, 5), Pal.weiss, 2.5)
            linie(g, strich(P(35, 208), P(35, 196)), Pal.himmel.farbe, 4)
            let flamme = 1 + 0.15 * w(14)
            teil(g, oval(P(35, 190), 3.5 * flamme, 5.5 * flamme), Pal.gelb, 1.5)
        }
        if abz.contains("herzaugen") {
            linie(g, bogen(P(176, 244), P(172, 200), P(182, 222)), Pal.gruen.farbe, 4)
            teil(g, oval(P(182, 222), 6, 3.5), Pal.gruen, 1.5)
            teil(g, kreis(P(172, 196), 9), Pal.rose, 2.5)
            linie(g, bogen(P(168, 196), P(176, 194), P(172, 190)), Pal.rose.kontur, 2)
        }
    }
}
