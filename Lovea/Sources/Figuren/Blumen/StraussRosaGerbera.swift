import SwiftUI

/// Strauß 3 (p59-strauss-3-rosa-gerbera.png): three soft pink roses with a green-white edge, three
/// hot pink gerberas, seven white marguerites, dark magenta pompon asters, a white chrysanthemum,
/// lots of green (spiky palm leaves, grass, pistachio twigs) and pale blue tissue paper.
enum StraussRosaGerbera {
    static func zeichne(_ g: GraphicsContext, fein: Bool) {
        let a = FotoAbb(ox: 0, oy: 380, sx: 0.165, sy: 0.165, sr: 0.185, dx: 24, dy: 6)
        let tuchOben = FigurFarbe(0xEDF5F9)
        let tuchUnten = FigurFarbe(0xC3D9E7)
        let kante = Color(red: 0.62, green: 0.74, blue: 0.82).opacity(0.9)

        // Tissue: cone with stems, then the two sheets that peek out at the bottom.
        blumeStiele(g, mitteX: 100, unten: 238)
        blumePapier(g, [P(52, 150), P(148, 150), P(120, 232), P(80, 232)], oben: tuchOben, unten: tuchUnten, kante: kante,
                    falten: [(P(74, 160), P(90, 230)), (P(126, 160), P(110, 230))])
        blumePapier(g, a.pfad([(0, 1380), (250, 1480), (330, 1720), (40, 1700)]), oben: tuchOben, unten: tuchUnten, kante: kante,
                    falten: [(a.p(250, 1480), a.p(150, 1700))])
        blumePapier(g, a.pfad([(650, 1330), (880, 1300), (890, 1600), (790, 1740), (620, 1640)]), oben: tuchOben, unten: tuchUnten, kante: kante,
                    falten: [(a.p(880, 1300), a.p(760, 1650))])

        blumenMasse(g, [P(30, 70), P(80, 40), P(150, 50), P(182, 90), P(174, 150), P(140, 186), P(75, 186), P(30, 150)],
                    oben: FigurFarbe(0x5A7E45), unten: FigurFarbe(0x2F5F3A))

        // Spiky dark palm leaves fanning out of the top, thin grass blades.
        let palme = FigurFarbe(0x2A5648)
        let faecher: [(CGFloat, CGFloat)] = [(505, 410), (640, 400), (740, 450), (820, 540), (880, 640), (405, 430), (330, 480), (270, 560)]
        for (x, y) in faecher { blumeLaub(g, a.p(520, 900), a.p(x, y), breite: a.r(17), palme, rund: 0, fein: fein) }
        for (x0, y0, x1, y1) in [(CGFloat(430), CGFloat(800), CGFloat(250), CGFloat(400)), (560, 780, 700, 400), (500, 760, 610, 385)] {
            linie(g, strich(a.p(x0, y0), a.p(x1, y1)), FigurFarbe(0x5E8F4A).farbe, 1.1)
        }

        // Big dark leaves at the bottom.
        let dunkelGruen = FigurFarbe(0x2F5F3A)
        let unten: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (350, 1600, 240, 1370, 40), (520, 1700, 480, 1440, 45), (620, 1650, 880, 1550, 42), (300, 1720, 120, 1560, 36), (700, 1620, 840, 1450, 34),
        ]
        for l in unten { blumeLaub(g, a.p(l.0, l.1), a.p(l.2, l.3), breite: a.r(l.4), dunkelGruen, rund: 0.1, fein: fein) }

        // Pistachio twigs: thin branches with small olive leaves.
        let olive = FigurFarbe(0x73934F)
        let zweige: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (520, 1150, 160, 990), (430, 1100, 470, 880), (540, 1400, 720, 1250), (480, 1450, 150, 1500), (560, 1200, 770, 1420), (430, 1250, 330, 1450),
        ]
        for z in zweige { blumeZweig(g, a.p(z.0, z.1), a.p(z.2, z.3), blatt: olive, anzahl: 6, groesse: a.r(48), fein: fein) }
        // More twigs over the middle, so the green reads as leaves and not as one flat patch (design units).
        let mehr: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (100, 160, 60, 112), (100, 160, 142, 122), (96, 164, 98, 108), (104, 150, 150, 150), (94, 156, 48, 162), (100, 128, 128, 92), (110, 170, 130, 140),
        ]
        for z in mehr { blumeZweig(g, P(z.0, z.1), P(z.2, z.3), blatt: olive, anzahl: 6, groesse: 9, fein: fein) }

        // Pompon asters at the right and the small dark buds at the top left.
        let pomponHell = FigurFarbe(0xB02A8C)
        let pomponDunkel = FigurFarbe(0x6E1458)
        let gelb = FigurFarbe(0xF2DB2E)
        let pompons: [(CGFloat, CGFloat, CGFloat)] = [(110, 570, 40), (250, 555, 35), (905, 1100, 55), (840, 1000, 75), (840, 900, 70), (735, 955, 65)]
        for (i, p) in pompons.enumerated() {
            blumePompon(g, a.p(p.0, p.1), a.r(p.2), hell: pomponHell, dunkel: pomponDunkel, mitte: gelb, winkel: CGFloat(i) * 0.5, fein: fein)
        }

        // White chrysanthemum top right, white marguerites on the left.
        blumeChrysantheme(g, a.p(720, 700), a.r(80), hell: FigurFarbe(0xFFFFFF), dunkel: FigurFarbe(0xD9DCE4), fein: fein)
        let margeriten: [(CGFloat, CGFloat, CGFloat)] = [
            (60, 1330, 75), (140, 1440, 65), (100, 1160, 90), (200, 1050, 80), (270, 1385, 80), (230, 1240, 120), (330, 1090, 105),
        ]
        for (i, m) in margeriten.enumerated() { blumeMargerite(g, a.p(m.0, m.1), a.r(m.2), winkel: CGFloat(i) * 0.6, fein: fein) }

        // Hot pink gerberas.
        let gerHell = FigurFarbe(0xF03C9C)
        let gerDunkel = FigurFarbe(0xA3125E)
        let gerMitte = FigurFarbe(0x5A1038)
        blumeGerbera(g, a.p(450, 530), a.r(100), hell: gerHell, dunkel: gerDunkel, mitte: gerMitte, winkel: 0.2, fein: fein)
        blumeGerbera(g, a.p(60, 700), a.r(110), hell: gerHell, dunkel: gerDunkel, mitte: gerMitte, winkel: 0.9, fein: fein)
        blumeGerbera(g, a.p(820, 1250), a.r(120), hell: gerHell, dunkel: gerDunkel, mitte: gerMitte, winkel: 1.7, fein: fein)

        // Pink roses, back to front, pale green-white outer petals.
        let rosaHell = FigurFarbe(0xF8CBDB)
        let rosaDunkel = FigurFarbe(0xE48DB0)
        let gruenWeiss = FigurFarbe(0xDCE6B4)
        blumeRose(g, a.p(545, 685), a.r(100), hell: rosaHell, dunkel: rosaDunkel, rand: gruenWeiss, winkel: 0.5, fein: fein)
        blumeRose(g, a.p(270, 770), a.r(120), hell: rosaHell, dunkel: rosaDunkel, rand: gruenWeiss, winkel: 1.2, fein: fein)
        blumeRose(g, a.p(545, 880), a.r(140), hell: rosaHell, dunkel: rosaDunkel, rand: gruenWeiss, winkel: 2.1, fein: fein)

        // Fine green sprigs in front of the daisies.
        blumeZweig(g, a.p(400, 1180), a.p(200, 1320), blatt: olive, anzahl: 5, groesse: a.r(46), fein: fein)
        blumeZweig(g, a.p(520, 1230), a.p(700, 1330), blatt: olive, anzahl: 5, groesse: a.r(46), fein: fein)
    }
}
