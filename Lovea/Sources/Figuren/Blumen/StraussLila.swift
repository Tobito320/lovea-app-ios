import SwiftUI

/// Strauß 1 (p59-strauss-1-lila.jpg): six lilac and pink roses, lilac chrysanthemums, pale
/// alstroemeria, pink gypsophila, glossy ruscus leaves, white frosted wrapping paper.
enum StraussLila {
    static func zeichne(_ g: GraphicsContext, fein: Bool) {
        let a = FotoAbb(ox: 70, oy: 505, sx: 0.195, sy: 0.195, sr: 0.195, dx: 5, dy: 8)
        let papierOben = FigurFarbe(0xF8F5EE)
        let papierUnten = FigurFarbe(0xD7D1DB)
        let kante = Color(red: 0.62, green: 0.58, blue: 0.67).opacity(0.9)

        // Wrapping: stems, the cone at the bottom, then three sheets folded around the flowers.
        blumeStiele(g, mitteX: 100, unten: 238)
        blumePapier(g, [P(52, 118), P(148, 112), P(120, 228), P(80, 228)], oben: papierOben, unten: papierUnten, kante: kante,
                    falten: [(P(78, 130), P(92, 226)), (P(122, 126), P(108, 226))])
        blumePapier(g, a.pfad([(330, 1255), (420, 1275), (520, 1235), (600, 1150), (450, 1030), (330, 1000)]),
                    oben: papierOben, unten: papierUnten, kante: kante)
        blumePapier(g, a.pfad([(112, 930), (125, 800), (330, 700), (430, 760), (380, 1000), (330, 1255), (215, 1160), (118, 1010)]),
                    oben: papierOben, unten: papierUnten, kante: kante, falten: [(a.p(330, 700), a.p(250, 1000))])
        blumePapier(g, a.pfad([(560, 595), (730, 508), (800, 610), (900, 740), (1000, 860), (1040, 1000), (1000, 1090), (905, 1160), (700, 1110), (640, 820)]),
                    oben: papierOben, unten: papierUnten, kante: kante,
                    falten: [(a.p(730, 508), a.p(790, 800)), (a.p(900, 740), a.p(820, 980))])
        if fein {
            // The faint flower print on the right sheet.
            for (x, y, w) in [(CGFloat(850), CGFloat(820), CGFloat(0.5)), (900, 930, 2.4), (800, 960, 4.0)] {
                var h = g
                h.translateBy(x: a.p(x, y).x, y: a.p(x, y).y)
                h.rotate(by: .radians(Double(w)))
                h.stroke(blumenBlatt(P(0, 0), P(0, -a.r(70)), breite: a.r(26), rund: 0.5), with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 0.5))
            }
        }

        // Ruscus leaves behind the flowers: the tall group top left, a few on the right.
        let laub = FigurFarbe(0x3F8F3A)
        let hinten: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (250, 820, 265, 520, 40), (240, 830, 350, 590, 36), (225, 840, 95, 640, 34), (200, 860, 0, 800, 30), (200, 880, 70, 940, 28),
            (650, 900, 790, 830, 30), (700, 1000, 860, 1050, 28), (660, 760, 760, 690, 26),
        ]
        for l in hinten { blumeLaub(g, a.p(l.0, l.1), a.p(l.2, l.3), breite: a.r(l.4), laub, rund: 0.25, fein: fein) }

        // Chrysanthemums, the lilac pompons that fill the gaps.
        let chrys: [(CGFloat, CGFloat, CGFloat)] = [
            (700, 615, 55), (780, 645, 52), (735, 700, 50), (690, 730, 45), (330, 830, 50), (305, 880, 60), (205, 960, 72),
            (295, 1035, 68), (215, 1075, 56), (650, 1100, 48), (780, 1085, 55), (855, 1135, 55), (690, 1245, 60), (775, 1235, 50), (545, 1205, 36),
        ]
        for (i, c) in chrys.enumerated() {
            blumeChrysantheme(g, a.p(c.0, c.1), a.r(c.2), hell: FigurFarbe(0xD9A2E2), dunkel: FigurFarbe(0x9A52B0), winkel: CGFloat(i) * 0.7, fein: fein)
        }

        // Alstroemeria, pale pink with dark streaks.
        let alstro: [(CGFloat, CGFloat, CGFloat)] = [(120, 745, 42), (175, 805, 30), (375, 650, 40), (640, 860, 36), (590, 1150, 30)]
        for (i, c) in alstro.enumerated() {
            blumeAlstroemerie(g, a.p(c.0, c.1), a.r(c.2), hell: FigurFarbe(0xFCE6EE), dunkel: FigurFarbe(0xE7A3C2), strich: FigurFarbe(0xB04070),
                              winkel: CGFloat(i) * 1.1, fein: fein)
        }

        // Roses: mauve with a pink-red edge, the top and the right one two-tone pink.
        let mauveHell = FigurFarbe(0xCDA0C8)
        let mauveDunkel = FigurFarbe(0x8A5388)
        let rosaHell = FigurFarbe(0xE88DB8)
        let rosaDunkel = FigurFarbe(0xA8407A)
        let rosaRand = FigurFarbe(0xD8386E)
        blumeRose(g, a.p(490, 668), a.r(62), hell: rosaHell, dunkel: rosaDunkel, rand: rosaRand, winkel: 0.4, fein: fein)
        blumeRose(g, a.p(520, 842), a.r(55), hell: mauveHell, dunkel: mauveDunkel, rand: FigurFarbe(0xD8588A), winkel: 1.1, fein: fein)
        blumeRose(g, a.p(940, 925), a.r(68), hell: rosaHell, dunkel: mauveDunkel, rand: rosaRand, winkel: 2.0, fein: fein)
        blumeRose(g, a.p(415, 915), a.r(64), hell: mauveHell, dunkel: mauveDunkel, winkel: 0.2, fein: fein)
        blumeRose(g, a.p(650, 935), a.r(62), hell: mauveHell, dunkel: mauveDunkel, rand: rosaRand, winkel: 0.8, fein: fein)
        blumeRose(g, a.p(545, 985), a.r(88), hell: mauveHell, dunkel: mauveDunkel, winkel: 1.6, fein: fein)

        // Pink gypsophila.
        let schleier = FigurFarbe(0xEA5FA6)
        blumeSchleier(g, a.p(405, 790), spreizung: a.r(70), anzahl: 55, punkt: a.r(7), farbe: schleier, seed: 11, fein: fein)
        blumeSchleier(g, a.p(520, 585), spreizung: a.r(28), anzahl: 22, punkt: a.r(7), farbe: schleier, seed: 12, fein: fein)
        blumeSchleier(g, a.p(345, 1135), spreizung: a.r(55), anzahl: 32, punkt: a.r(7), farbe: schleier, seed: 13, fein: fein)

        // The leaves in front, at the bottom of the dome.
        let vorn: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (470, 1240, 440, 1060, 28), (520, 1230, 610, 1100, 26), (440, 1235, 345, 1170, 26), (560, 1215, 680, 1180, 22), (430, 1240, 400, 1130, 22),
        ]
        for l in vorn { blumeLaub(g, a.p(l.0, l.1), a.p(l.2, l.3), breite: a.r(l.4), laub, rund: 0.25, fein: fein) }
    }
}
