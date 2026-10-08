import SwiftUI

/// Strauß 2 (p59-strauss-2-rot-bunt.jpg): red roses, violet and lilac asters, white marguerites,
/// red geraniums, pink cup flowers, a cream petunia, white gypsophila, red translucent paper with
/// a lighter inner border and four pointed corners.
enum StraussRotBunt {
    static func zeichne(_ g: GraphicsContext, fein: Bool) {
        let a = FotoAbb(ox: 135, oy: 575, sx: 0.19, sy: 0.19, sr: 0.19, dx: 8, dy: 6)
        let rotOben = FigurFarbe(0xBF3D45)
        let rotUnten = FigurFarbe(0x8E1F2C)
        let kante = Color(red: 0.48, green: 0.08, blue: 0.14).opacity(0.95)

        // Paper: cone with the stems, the star-shaped wrap, a lighter inner sheet on top.
        blumeStiele(g, mitteX: 100, unten: 238)
        blumePapier(g, [P(44, 150), P(156, 150), P(122, 230), P(78, 230)], oben: rotUnten, unten: rotUnten.mal(0.85), kante: kante,
                    falten: [(P(70, 160), P(88, 228)), (P(130, 160), P(112, 228))])
        let aussen = a.pfad([(143, 578), (540, 722), (735, 742), (1075, 592), (1086, 1010), (1100, 1150), (1045, 1235), (790, 1560), (560, 1520), (140, 1425), (165, 1000)])
        blumePapier(g, aussen, oben: rotOben, unten: rotUnten, kante: kante, kanteBreite: 1,
                    falten: [(a.p(143, 578), a.p(330, 860)), (a.p(1075, 592), a.p(900, 820)), (a.p(140, 1425), a.p(300, 1250)), (a.p(790, 1560), a.p(700, 1330))])
        let innen = a.pfad([(172, 602), (520, 730), (735, 745), (1050, 612), (1060, 1000), (1070, 1140), (1015, 1210), (790, 1520), (565, 1490), (172, 1395), (190, 1000)])
        blumePapier(g, innen, oben: rotOben.mix(Pal.weiss, 0.18), unten: rotUnten.mix(Pal.weiss, 0.1), kante: kante.opacity(0.5), kanteBreite: 0.6)

        // Dark leaves at the bottom right, variegated with a cream edge.
        let gruen = FigurFarbe(0x2F5A32)
        let rand = FigurFarbe(0xE6E3AE)
        let blaetter: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (700, 1400, 860, 1300, 60), (740, 1420, 890, 1380, 50), (650, 1450, 780, 1260, 45), (560, 1430, 430, 1330, 40),
        ]
        for l in blaetter { blumeLaub(g, a.p(l.0, l.1), a.p(l.2, l.3), breite: a.r(l.4), gruen, rund: 0.5, rand: rand, fein: fein) }

        // Back row: pink and white gypsophila behind, the cup flowers.
        let weiss = FigurFarbe(0xFFFFFF)
        blumeSchleier(g, a.p(400, 790), spreizung: a.r(45), anzahl: 26, punkt: a.r(8), farbe: FigurFarbe(0xF6D3E2), seed: 21, fein: fein)
        blumeSchleier(g, a.p(640, 1470), spreizung: a.r(80), anzahl: 30, punkt: a.r(8), farbe: weiss, seed: 22, fein: fein)
        blumeKelch(g, a.p(245, 925), a.r(70), n: 6, hell: FigurFarbe(0xE8BCE2), dunkel: FigurFarbe(0xC27FB8), schlund: FigurFarbe(0xB468A8), winkel: 0.5, fein: fein)
        blumeKelch(g, a.p(590, 750), a.r(30), n: 5, hell: FigurFarbe(0xF2C6DC), dunkel: FigurFarbe(0xD890B8), schlund: FigurFarbe(0xC870A0), fein: fein)
        blumeKelch(g, a.p(800, 1070), a.r(100), n: 6, hell: FigurFarbe(0xF0B3D5), dunkel: FigurFarbe(0xCF6EA8), schlund: FigurFarbe(0xB0508A),
                   staub: FigurFarbe(0xF08A2A), winkel: 0.3, fein: fein)
        blumeKelch(g, a.p(790, 790), a.r(60), n: 5, hell: FigurFarbe(0xF8F2D2), dunkel: FigurFarbe(0xE2D69E), schlund: FigurFarbe(0xF2D548), winkel: 0.9, fein: fein)
        blumeAster(g, a.p(950, 885), a.r(45), blatt: FigurFarbe(0x9A64D2), grund: FigurFarbe(0x6A3FAE), mitte: FigurFarbe(0xB890E0), mitteRand: FigurFarbe(0x7A4FB8),
                   n: 14, breite: 0.2, mittel: 0.3, fein: fein)

        // Red roses, from the back to the front.
        let roseHell = FigurFarbe(0xD21B26)
        let roseDunkel = FigurFarbe(0x6E0912)
        let rosen: [(CGFloat, CGFloat, CGFloat)] = [
            (870, 825, 55), (355, 885, 65), (275, 1045, 52), (260, 1180, 60), (550, 935, 100), (470, 1215, 85), (700, 1220, 95),
        ]
        for (i, r) in rosen.enumerated() {
            blumeRose(g, a.p(r.0, r.1), a.r(r.2), hell: roseHell, dunkel: roseDunkel, winkel: CGFloat(i) * 0.9, fein: fein)
        }

        // White marguerites.
        let margeriten: [(CGFloat, CGFloat, CGFloat)] = [(520, 775, 50), (645, 1040, 50), (350, 1135, 52), (605, 1140, 65), (600, 1275, 62)]
        for (i, m) in margeriten.enumerated() { blumeMargerite(g, a.p(m.0, m.1), a.r(m.2), winkel: CGFloat(i) * 0.5, fein: fein) }

        // Violet asters with a yellow heart, a cluster left of the middle.
        let violett: [(CGFloat, CGFloat, CGFloat)] = [(462, 855, 52), (385, 938, 40), (415, 970, 42), (340, 1010, 35), (497, 1068, 75)]
        for (i, v) in violett.enumerated() {
            blumeAster(g, a.p(v.0, v.1), a.r(v.2), blatt: FigurFarbe(0x8F6AE0), grund: FigurFarbe(0x5B3FB5), mitte: FigurFarbe(0xF2C230), mitteRand: FigurFarbe(0xC99A1E),
                       n: 20, breite: 0.09, mittel: 0.26, winkel: CGFloat(i) * 0.4, fein: fein)
        }

        // Red geraniums, top right.
        let geranien: [(CGFloat, CGFloat, CGFloat)] = [(680, 795, 55), (735, 910, 75), (1010, 1030, 62), (895, 985, 85)]
        for (i, ge) in geranien.enumerated() {
            blumeGeranie(g, a.p(ge.0, ge.1), a.r(ge.2), hell: FigurFarbe(0xF0262F), dunkel: FigurFarbe(0xAE101E), winkel: CGFloat(i) * 0.6, fein: fein)
        }

        // Lilac asters with long thin petals along the bottom.
        let flieder: [(CGFloat, CGFloat, CGFloat)] = [(570, 1380, 35), (665, 1405, 40), (490, 1335, 55), (330, 1355, 85)]
        for (i, f) in flieder.enumerated() {
            blumeAster(g, a.p(f.0, f.1), a.r(f.2), blatt: FigurFarbe(0xE2D4F6), grund: FigurFarbe(0xB89EDB), mitte: FigurFarbe(0xE4C86A), mitteRand: FigurFarbe(0xB89A40),
                       n: 22, breite: 0.055, mittel: 0.16, winkel: CGFloat(i) * 0.3, fein: fein)
        }

        // White gypsophila in front, falling out to the right.
        blumeSchleier(g, a.p(1000, 1330), spreizung: a.r(100), anzahl: 70, punkt: a.r(9), farbe: weiss, seed: 23, fein: fein)
        blumeSchleier(g, a.p(420, 790), spreizung: a.r(45), anzahl: 22, punkt: a.r(8), farbe: weiss, seed: 24, fein: fein)
        blumeSchleier(g, a.p(580, 1460), spreizung: a.r(70), anzahl: 30, punkt: a.r(8), farbe: weiss, seed: 25, fein: fein)
    }
}
