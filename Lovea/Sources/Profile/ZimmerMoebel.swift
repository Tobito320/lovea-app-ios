import SwiftUI

/// p61: the drawings of the shop's room pieces (wall pattern, rug, lamp, bedding pattern) and of the two
/// wall pieces that open the outfit change (clothes rail, shoe shelf). Vector only, in the home scene's
/// design space (390 x 430, `ZuhauseZeichnung`), in the figures' sticker style. Everything is still:
/// nothing runs, nothing loads. The standard of each kind is the room as p58 drew it.
enum ZimmerMoebel {
    /// Where the two wall pieces hang (above the sofa): the touch areas of the scene use the same rects.
    static let stange = CGRect(x: 288, y: 104, width: 96, height: 62)
    static let regal = CGRect(x: 288, y: 166, width: 96, height: 22)

    // MARK: Wall

    /// The pattern on the wall colour (the colour itself is filled by the room): hearts, dots or stripes.
    static func wandMuster(_ g: GraphicsContext, _ t: ZimmerTeil, breite: CGFloat) {
        let ton = FigurFarbe(t.farbe).mix(FigurFarbe(t.zweit), t.muster == .herzen ? 0.07 : 0.16).farbe
        switch t.muster {
        case .herzen:
            for (n, y) in stride(from: CGFloat(-380), to: 290, by: 44).enumerated() {
                for x in stride(from: CGFloat(n % 2 == 0 ? 20 : 42), to: breite, by: 44) { g.fill(herzPfad(P(x, y), 4), with: .color(ton)) }
            }
        case .punkte:
            for (n, y) in stride(from: CGFloat(-380), to: 290, by: 44).enumerated() {
                for x in stride(from: CGFloat(n % 2 == 0 ? 20 : 42), to: breite, by: 44) { g.fill(kreis(P(x, y), 3.5), with: .color(ton)) }
            }
        case .streifen:
            for x in stride(from: CGFloat(0), to: breite, by: 44) { g.fill(box(x, -2000, 22, 2290), with: .color(ton)) }
        default:
            break
        }
    }

    // MARK: Rug

    /// `mitte`: the centre of the rug on the floor, seen from above at a slant (about 224 x 30 points).
    static func teppich(_ g: GraphicsContext, mitte: CGPoint, _ t: ZimmerTeil) {
        let f = FigurFarbe(t.farbe)
        let rand = FigurFarbe(t.zweit)
        switch t.muster {
        case .wolke:
            // A fluffy edge: a ring of little bumps around the oval, outlines first, then the fills.
            var teile = [oval(mitte, 100, 12)]
            for k in 0..<16 {
                let w = Double(k) / 16 * 2 * Double.pi
                teile.append(oval(P(mitte.x + CGFloat(cos(w)) * 100, mitte.y + CGFloat(sin(w)) * 12), 10, 5.5))
            }
            verbunden(g, teile, f, 2.5)
            linie(g, oval(mitte, 84, 8), rand.farbe, 2)
        case .herz:
            let flach = CGAffineTransform(translationX: mitte.x, y: mitte.y).scaledBy(x: 1, y: 0.27)
            teil(g, herzPfad(P(0, 0), 60).applying(flach), f, 2.5)
            linie(g, herzPfad(P(0, 0), 44).applying(flach), rand.farbe.opacity(0.6), 2)
        default:
            teil(g, oval(mitte, 112, 15), f, 2.5)
            linie(g, oval(mitte, 94, 10), rand.farbe.opacity(0.65), 2)
        }
    }

    // MARK: Lamp

    /// The hanging lamp: its cord comes from above the picture, `ort` is where the bulb hangs.
    static func lampe(_ g: GraphicsContext, ort: CGPoint, _ t: ZimmerTeil) {
        let f = FigurFarbe(t.farbe)
        let ende: CGFloat = t.muster == .laterne ? 50 : (t.muster == .rattan ? 44 : 28)
        linie(g, strich(P(ort.x, -2000), P(ort.x, ort.y - ende)), Pal.dunkel.farbe.opacity(0.55), 2)
        let birne = FigurFarbe(t.muster == .schirm ? t.zweit : 0xFFF8DC).farbe
        switch t.muster {
        case .rattan:
            let kuppel = Path { p in
                p.move(to: P(ort.x - 26, ort.y - 4))
                p.addCurve(to: P(ort.x + 26, ort.y - 4), control1: P(ort.x - 32, ort.y - 62), control2: P(ort.x + 32, ort.y - 62))
                p.closeSubpath()
            }
            teil(g, kuppel, f, 3)
            var h = g
            h.clip(to: kuppel)
            let faden = FigurFarbe(t.zweit).farbe
            for k in 1...3 {
                let y = ort.y - 4 - CGFloat(k) * 11
                linie(h, bogen(P(ort.x - 30, y), P(ort.x + 30, y), P(ort.x, y + 5)), faden, 1.4)
            }
            for dx in stride(from: CGFloat(-20), through: 20, by: 10) {
                linie(h, bogen(P(ort.x + dx * 0.35, ort.y - 46), P(ort.x + dx * 1.15, ort.y - 4), P(ort.x + dx * 0.9, ort.y - 26)), faden, 1.4)
            }
            g.fill(oval(P(ort.x, ort.y - 4), 10, 5), with: .color(birne))
        case .laterne:
            let mitteL = P(ort.x, ort.y - 24)
            let rippe = FigurFarbe(t.zweit)
            teil(g, oval(mitteL, 22, 24), f, 3)
            var h = g
            h.clip(to: oval(mitteL, 22, 24))
            h.fill(oval(mitteL, 13, 15), with: .color(FigurFarbe(0xFFF3C4).farbe.opacity(0.6)))
            for rx in [CGFloat(8), 15] { linie(h, oval(mitteL, rx, 24), rippe.farbe, 1.5) }
            linie(h, strich(P(ort.x - 22, mitteL.y), P(ort.x + 22, mitteL.y)), rippe.farbe, 1.5)
            teil(g, box(ort.x - 6, ort.y - 52, 12, 5, 2), rippe.mal(0.8), 1.5)
            teil(g, box(ort.x - 6, ort.y - 1, 12, 5, 2), rippe.mal(0.8), 1.5)
        default:
            let schirm = Path { p in
                p.move(to: P(ort.x - 21, ort.y - 4))
                p.addQuadCurve(to: P(ort.x + 21, ort.y - 4), control: P(ort.x, ort.y - 54))
                p.closeSubpath()
            }
            teil(g, schirm, f, 3)
            g.fill(oval(P(ort.x, ort.y - 4), 9, 5), with: .color(birne))
        }
    }

    // MARK: Bedding

    /// The bed in front of the sleepers, with the bedding of the choice: its colour on the blanket and
    /// its pattern on top (the bed's own pattern stays when the standard is in use). Bed space 300 x 220.
    static func bettVorn(_ g: GraphicsContext, _ stil: Int, _ wahl: ZimmerWahl, herz: Bool) {
        let t = wahl.eigenes(.bettwaesche)
        SzenenZeichnung.bettVorn(g, stil, herz: herz, decke: t?.farbe)
        guard let t else { return }
        let ton = FigurFarbe(t.zweit).farbe.opacity(0.75)
        switch t.muster {
        case .punkte:
            for (n, y) in [CGFloat(168), 184].enumerated() {
                for x in stride(from: CGFloat(n == 0 ? 20 : 34), to: 290, by: 28) { g.fill(kreis(P(x, y), 3.2), with: .color(ton)) }
            }
        case .streifen:
            for x in stride(from: CGFloat(14), to: 290, by: 30) { g.fill(box(x, 160, 10, 37, 2), with: .color(ton)) }
        case .herzen:
            for (n, y) in [CGFloat(170), 186].enumerated() {
                for x in stride(from: CGFloat(n == 0 ? 22 : 38), to: 290, by: 32) { g.fill(herzPfad(P(x, y), 5), with: .color(ton)) }
            }
        default:
            break
        }
    }

    // MARK: Wall pieces (tap: the outfit change)

    /// A clothes rail on the wall with three pieces on hangers: black tee, cream dress, pink jacket.
    static func kleiderstange(_ g: GraphicsContext) {
        let r = stange
        linie(g, strich(P(r.minX + 6, r.minY + 8), P(r.maxX - 6, r.minY + 8)), Pal.silber.kontur, 4.5)
        for x in [r.minX + 4, r.maxX - 10] { teil(g, box(x, r.minY + 2, 6, 14, 2), Pal.silber, 1.5) }
        let farben: [UInt32] = [0x3B3A44, 0xF6EBDD, 0xF4B6C6]
        let laengen: [CGFloat] = [32, 42, 36]
        for (i, x) in [r.minX + 22, r.midX, r.maxX - 22].enumerated() {
            linie(g, bogen(P(x - 8, r.minY + 17), P(x + 8, r.minY + 17), P(x, r.minY + 7)), Pal.silber.kontur, 1.6)
            teil(g, box(x - 9, r.minY + 17, 18, laengen[i], 4), FigurFarbe(farben[i]), 2)
            if i == 0 {
                for dx in [CGFloat(-13), 7] { teil(g, box(x + dx, r.minY + 17, 6, 10, 3), FigurFarbe(farben[i]), 2) }
            }
            if i == 2 { linie(g, strich(P(x, r.minY + 19), P(x, r.minY + 17 + laengen[i] - 3)), FigurFarbe(farben[i]).mal(0.8).farbe, 1.5) }
        }
    }

    /// A white wall shelf with three sneakers.
    static func schuhregal(_ g: GraphicsContext) {
        let r = regal
        teil(g, box(r.minX + 2, r.minY + 8, r.width - 4, 7, 3), Pal.weiss, 2)
        for x in [r.minX + 10, r.maxX - 16] { teil(g, box(x, r.minY + 15, 5, 6, 1.5), Pal.silber, 1.5) }
        let farben: [(UInt32, UInt32)] = [(0xC8102E, 0x111111), (0xFFFFFF, 0xC8102E), (0x111111, 0xFFFFFF)]
        for (i, c) in farben.enumerated() {
            let x = r.minX + 8 + CGFloat(i) * 30
            teil(g, box(x, r.minY - 1, 22, 9.5, 4), FigurFarbe(c.0), 1.5)
            g.fill(box(x + 8, r.minY, 8, 4, 1), with: .color(FigurFarbe(c.1).farbe))
            g.fill(box(x, r.minY + 6, 22, 2.5), with: .color(.white))
        }
    }
}

/// One shop tile or detail picture of a room piece: the home scene itself, cropped to where the piece
/// is, so the preview is exactly what the room will show. Wall, rug and lamp crop the room; the bedding
/// shows the empty bed on the wall colour.
struct ZimmerTeilVorschau: View {
    let id: String

    /// The room crop per kind in design space, all 0.875 wide to high like a shop tile (84 x 96).
    private static func ausschnitt(_ art: ZimmerArt) -> CGRect {
        switch art {
        case .wand: CGRect(x: 270, y: 20, width: 112, height: 128)
        case .teppich: CGRect(x: 100, y: 170, width: 240, height: 274)
        case .lampe: CGRect(x: 70, y: 30, width: 80, height: 91.4)
        case .bettwaesche: CGRect(x: 0, y: 0, width: 300, height: 343)
        }
    }

    var body: some View {
        let wahl = ZimmerWahl.nur(id)
        let art = ZimmerTeile.alle[id]?.art ?? .wand
        let reg = Self.ausschnitt(art)
        Canvas { g, size in
            let k = size.width / reg.width
            var r = g
            if art == .bettwaesche {
                g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(FigurFarbe(0xFBEFE0).farbe))
                r.translateBy(x: 0, y: size.height * 0.2)
                r.scaleBy(x: k, y: k)
                SzenenZeichnung.bettHinten(r, ZuhauseZeichnung.bettStil, kissen: [112, 188], bild: nil)
                ZimmerMoebel.bettVorn(r, ZuhauseZeichnung.bettStil, wahl, herz: false)
            } else {
                r.translateBy(x: -reg.minX * k, y: -reg.minY * k)
                r.scaleBy(x: k, y: k)
                ZuhauseZeichnung.raum(r, zeit: .tag, wahl: wahl)
            }
        }
        .aspectRatio(0.875, contentMode: .fit)
        .clipped()
        .accessibilityHidden(true)
    }
}
