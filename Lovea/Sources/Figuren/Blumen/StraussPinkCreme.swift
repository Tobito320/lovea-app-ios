import SwiftUI

/// Strauß 4 (p59-strauss-4-pink-creme.png): deep pink (cerise) roses and spray roses, cream and
/// blush roses with green outer petals, peach roses, small buds, clouds of white gypsophila, pale
/// frosted paper with a leaf print. The photo is a close-up, so the flowers fill the whole dome.
enum StraussPinkCreme {
    static func zeichne(_ g: GraphicsContext, fein: Bool) {
        // Positions are squeezed vertically (sy < sx) so the long close-up fits the dome.
        let a = FotoAbb(ox: 0, oy: 150, sx: 0.2, sy: 0.12, sr: 0.17, dx: 8, dy: 6)
        let papierOben = FigurFarbe(0xF5F2F6)
        let papierUnten = FigurFarbe(0xD8D2DC)
        let kante = Color(red: 0.66, green: 0.62, blue: 0.7).opacity(0.9)

        // Frosted paper behind the whole bouquet, with the leaf print at the top right.
        blumeStiele(g, mitteX: 100, unten: 238)
        blumePapier(g, [P(50, 150), P(150, 150), P(120, 232), P(80, 232)], oben: papierOben, unten: papierUnten, kante: kante,
                    falten: [(P(74, 160), P(90, 230)), (P(126, 160), P(110, 230))])
        blumePapier(g, a.pfad([(0, 130), (430, 150), (700, 200), (921, 215), (921, 1500), (860, 1750), (500, 1790), (100, 1760), (0, 1500)]),
                    oben: papierOben, unten: papierUnten, kante: kante, kanteBreite: 1,
                    falten: [(a.p(700, 200), a.p(760, 520)), (a.p(0, 1500), a.p(160, 1300))])
        if fein {
            for (x, y, w) in [(CGFloat(760), CGFloat(330), CGFloat(0.4)), (830, 420, 1.8), (700, 440, 3.2), (860, 250, 5.0)] {
                var h = g
                h.translateBy(x: a.p(x, y).x, y: a.p(x, y).y)
                h.rotate(by: .radians(Double(w)))
                h.stroke(blumenBlatt(P(0, 0), P(0, -a.r(120)), breite: a.r(44), rund: 0.5), with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 0.5))
            }
        }

        let cerHell = FigurFarbe(0xE0287F)
        let cerDunkel = FigurFarbe(0x8A0F4A)
        let cerRand = FigurFarbe(0xF25AA0)
        let cremeHell = FigurFarbe(0xF3E2CD)
        let cremeDunkel = FigurFarbe(0xD9A8A0)
        let gruenRand = FigurFarbe(0xD3E2A4)
        let pfirsichHell = FigurFarbe(0xEBC3B2)
        let pfirsichDunkel = FigurFarbe(0xC78C88)

        // Cream and blush roses along the top, the biggest in the middle.
        let creme: [(CGFloat, CGFloat, CGFloat)] = [(50, 450, 100), (330, 270, 120), (590, 330, 110), (790, 530, 80), (410, 450, 130)]
        for (i, r) in creme.enumerated() {
            blumeRose(g, a.p(r.0, r.1), a.r(r.2), hell: cremeHell, dunkel: cremeDunkel, rand: gruenRand, winkel: CGFloat(i) * 1.1, fein: fein)
        }

        // Cerise roses behind, then the big ones, left to right and top to bottom.
        let hinten: [(CGFloat, CGFloat, CGFloat)] = [(245, 600, 70), (390, 650, 100)]
        for (i, r) in hinten.enumerated() {
            blumeRose(g, a.p(r.0, r.1), a.r(r.2), hell: cerHell, dunkel: cerDunkel, rand: cerRand, winkel: CGFloat(i) * 0.8, fein: fein)
        }
        blumeKnospe(g, a.p(120, 250), a.r(40), hell: FigurFarbe(0xE86AA0), dunkel: cerDunkel, winkel: -0.3)
        blumeKnospe(g, a.p(70, 1050), a.r(40), hell: cerHell, dunkel: cerDunkel, winkel: 0.5)
        blumeKnospe(g, a.p(110, 1190), a.r(35), hell: FigurFarbe(0xE86AA0), dunkel: cerDunkel, winkel: -0.4)

        // Gypsophila behind the lower roses.
        let weiss = FigurFarbe(0xFFFFFF)
        blumeSchleier(g, a.p(430, 1250), spreizung: a.r(115), anzahl: 50, punkt: a.r(11), farbe: weiss, seed: 41, fein: fein)
        blumeSchleier(g, a.p(180, 1410), spreizung: a.r(100), anzahl: 40, punkt: a.r(11), farbe: weiss, seed: 42, fein: fein)

        let gross: [(CGFloat, CGFloat, CGFloat)] = [
            (850, 870, 60), (120, 720, 150), (320, 910, 130), (500, 1010, 90), (685, 1070, 90), (790, 1130, 80), (230, 1100, 90),
        ]
        for (i, r) in gross.enumerated() {
            blumeRose(g, a.p(r.0, r.1), a.r(r.2), hell: cerHell, dunkel: cerDunkel, rand: cerRand, winkel: CGFloat(i) * 0.7, fein: fein)
        }

        // Peach roses and the lower cerise ones.
        blumeRose(g, a.p(385, 1170), a.r(110), hell: pfirsichHell, dunkel: pfirsichDunkel, rand: gruenRand, winkel: 0.6, fein: fein)
        blumeRose(g, a.p(50, 1480), a.r(100), hell: pfirsichHell, dunkel: pfirsichDunkel, rand: gruenRand, winkel: 1.5, fein: fein)
        blumeRose(g, a.p(250, 1590), a.r(80), hell: cerHell, dunkel: cerDunkel, rand: cerRand, winkel: 2.3, fein: fein)
        blumeRose(g, a.p(630, 1640), a.r(70), hell: cerHell, dunkel: cerDunkel, rand: cerRand, winkel: 0.4, fein: fein)

        // The white gypsophila clouds in front.
        let wolken: [(CGFloat, CGFloat, CGFloat, Int)] = [
            (500, 700, 110, 52), (740, 740, 90, 38), (690, 880, 100, 44), (300, 1330, 70, 26), (500, 1500, 110, 50), (700, 1440, 90, 38), (560, 1640, 100, 40),
        ]
        for (i, w) in wolken.enumerated() {
            blumeSchleier(g, a.p(w.0, w.1), spreizung: a.r(w.2), anzahl: w.3, punkt: a.r(11), farbe: weiss, seed: UInt64(50 + i), fein: fein)
        }
    }
}
