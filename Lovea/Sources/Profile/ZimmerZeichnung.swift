import SwiftUI

/// Brief G: `profil.zimmer` per person, `{bett, wand, boden, deko: [String], rahmen: [{slot, medienId}]}`.
/// A fixed, designed room: one variant per slot, deco toggled on or off, up to 3 photo frames.
/// Reading is tolerant: anything unknown, missing or out of range falls back to the defaults.
struct Zimmer: Equatable, Sendable {
    struct Rahmen: Equatable, Sendable {
        var slot: Int
        var medienId: String
    }

    var bett = 0
    var wand = 0
    var boden = 0
    var deko = Zimmer.standardDeko
    var rahmen: [Rahmen] = []

    static let betten = ["Holz hell", "Holz dunkel", "Samt rosa", "Metall weiß", "Boxspring grau"]
    static let waende = ["Creme", "Rosa Streifen", "Salbei", "Himmelblau", "Lavendel", "Nachtblau"]
    static let boeden = ["Holz hell", "Holz dunkel", "Teppich creme", "Fliesen", "Teppich rosa"]
    static let dekoArten: [(id: String, name: String)] = [
        ("fenster", "Fenster"), ("teppich", "Teppich"), ("lampe", "Lampe"), ("pflanze", "Pflanze"),
        ("regal", "Regal"), ("lichterkette", "Lichterkette"), ("poster", "Poster"),
    ]
    static let standardDeko = ["fenster", "teppich", "lampe", "pflanze"]
    static let rahmenPlaetze = 3

    func hat(_ id: String) -> Bool { deko.contains(id) }

    func medien(_ slot: Int) -> String? { rahmen.first { $0.slot == slot }?.medienId }

    static func lesen(_ wert: JSONValue?) -> Zimmer {
        var z = Zimmer()
        guard case .object(let o)? = wert else { return z }
        func index(_ schluessel: String, _ anzahl: Int) -> Int? {
            guard case .number(let d)? = o[schluessel], d >= 0, d < Double(anzahl) else { return nil }
            return Int(d)
        }
        z.bett = index("bett", betten.count) ?? 0
        z.wand = index("wand", waende.count) ?? 0
        z.boden = index("boden", boeden.count) ?? 0
        if case .array(let liste)? = o["deko"] {
            let bekannt = Set(dekoArten.map(\.id))
            var gesehen = Set<String>()
            z.deko = liste.compactMap { eintrag -> String? in
                guard case .string(let id) = eintrag, bekannt.contains(id), gesehen.insert(id).inserted else { return nil }
                return id
            }
        }
        if case .array(let liste)? = o["rahmen"] {
            var belegt = Set<Int>()
            z.rahmen = liste.compactMap { eintrag -> Rahmen? in
                guard case .object(let r) = eintrag, case .number(let d)? = r["slot"], d >= 0, d < Double(rahmenPlaetze),
                      case .string(let id)? = r["medienId"], !id.isEmpty, belegt.insert(Int(d)).inserted else { return nil }
                return Rahmen(slot: Int(d), medienId: id)
            }
        }
        return z
    }

    var json: JSONValue {
        .object([
            "bett": .number(Double(bett)), "wand": .number(Double(wand)), "boden": .number(Double(boden)),
            "deko": .array(deko.map { .string($0) }),
            "rahmen": .array(rahmen.map { .object(["slot": .number(Double($0.slot)), "medienId": .string($0.medienId)]) }),
        ])
    }
}

@MainActor
extension Zimmer {
    static func von(_ person: Person) -> Zimmer { lesen(EinstellungenModell.shared.werte[person]?["profil.zimmer"]) }

    // ponytail: per person via `werte[person]` (like `profil.hintergrund`), not `geteilt` - that one
    // is last-wins across both, so one room would overwrite the other.
    func sichern() { EinstellungenModell.shared.setzen("profil.zimmer", json) }
}

// MARK: - Drawing

/// Brief G: the scenes, drawn in code in the figures' sticker style (soft fills with the thick soft
/// outline of `teil`), so nothing needs an asset. Design space 390 x 430, scaled to the full width and
/// anchored at the bottom: a taller canvas (the stretchy header) only shows more wall or sky above.
/// `t` drives the few moving bits; still callers pass a constant.
enum SzenenZeichnung {
    static let breite: CGFloat = 390
    static let hoehe: CGFloat = 430

    /// The three photo frames on the wall, above the figures' heads.
    static let rahmenRects: [CGRect] = [
        CGRect(x: 156, y: 70, width: 58, height: 72),
        CGRect(x: 226, y: 58, width: 84, height: 64),
        CGRect(x: 322, y: 70, width: 52, height: 66),
    ]

    /// Where the real photo sits inside a frame, `nil` for an unknown slot.
    static func fotoRect(_ slot: Int) -> CGRect? {
        rahmenRects.indices.contains(slot) ? rahmenRects[slot].insetBy(dx: 7, dy: 7) : nil
    }

    static func raum(_ g: GraphicsContext, _ size: CGSize) -> GraphicsContext {
        var r = g
        let s = size.width / breite
        r.translateBy(x: 0, y: size.height - hoehe * s)
        r.scaleBy(x: s, y: s)
        return r
    }

    /// Reaches far above the design space, so a stretched header never shows a gap.
    private static var alles: Path { box(0, -2000, breite, 2800) }

    // MARK: Room

    private static let wandFarben: [UInt32] = [0xF6EBDD, 0xF9DCE3, 0xCFDCC8, 0xD6E8F5, 0xE3D9F2, 0x2E3A5C]
    private static let bodenFarben: [UInt32] = [0xE2C29A, 0x8A5E3F, 0xEFE6DA, 0xE9ECEF, 0xF4C9D4]

    /// `bett`: the optional `szene-bett-<n>` picture for the headboard.
    static func zimmer(_ g: GraphicsContext, _ z: Zimmer, nacht: Bool, mitBett: Bool, bett: UIImage?, t: Double) {
        wand(g, z.wand)
        boden(g, z.boden)
        if z.hat("fenster") { fenster(g, nacht: nacht, t: t) }
        if z.hat("poster") { poster(g) }
        if z.hat("regal") { regal(g) }
        for r in z.rahmen where rahmenRects.indices.contains(r.slot) { rahmen(g, rahmenRects[r.slot]) }
        if z.hat("teppich") { teppich(g) }
        if z.hat("pflanze") { pflanze(g) }
        if mitBett {
            var b = g
            b.translateBy(x: 2, y: 222)
            b.scaleBy(x: 0.49, y: 0.49)
            bettHinten(b, z.bett, kissen: [88, 212], bild: bett)
            bettVorn(b, z.bett, herz: false)
        }
        if z.hat("lampe") { lampe(g) }
        if nacht {
            g.fill(alles, with: .color(farbe(0x1B1F3A).opacity(0.3)))
            if z.hat("lampe") {
                let c = P(172, 250)
                g.fill(kreis(c, 70), with: .radialGradient(Gradient(colors: [farbe(0xFFD27A).opacity(0.5), .clear]), center: c, startRadius: 4, endRadius: 70))
            }
        }
        if z.hat("lichterkette") { lichterkette(g, t: t) }
    }

    private static func wand(_ g: GraphicsContext, _ i: Int) {
        let f = FigurFarbe(wandFarben[min(max(i, 0), wandFarben.count - 1)])
        g.fill(alles, with: .color(f.farbe))
        switch i {
        case 1:
            for x in stride(from: CGFloat(0), to: breite, by: 36) { g.fill(box(x, -400, 18, 700), with: .color(f.mal(0.95).farbe)) }
        case 2:
            g.fill(box(0, 214, breite, 86), with: .color(f.mal(0.92).farbe))
            linie(g, strich(P(0, 214), P(breite, 214)), Pal.weiss.farbe, 5)
        case 3:
            for (n, y) in stride(from: CGFloat(-380), to: 300, by: 34).enumerated() {
                for x in stride(from: CGFloat(n % 2 == 0 ? 12 : 29), to: breite, by: 34) { g.fill(kreis(P(x, y), 3), with: .color(.white.opacity(0.7))) }
            }
        case 4:
            for (n, y) in stride(from: CGFloat(-380), to: 290, by: 44).enumerated() {
                for x in stride(from: CGFloat(n % 2 == 0 ? 20 : 42), to: breite, by: 44) { g.fill(herzPfad(P(x, y), 4), with: .color(f.mal(0.9).farbe)) }
            }
        case 5:
            for k in 0..<40 {
                let p = P(zufall(k * 2) * breite, -380 + zufall(k * 2 + 1) * 660)
                g.fill(stern(p, 2.5 + zufall(k) * 2), with: .color(farbe(0xF5C542).opacity(0.55)))
            }
        default:
            break
        }
        // Soft shade toward the floor.
        g.fill(box(0, 150, breite, 150), with: .linearGradient(Gradient(colors: [.clear, .black.opacity(0.08)]), startPoint: P(0, 150), endPoint: P(0, 300)))
    }

    private static func boden(_ g: GraphicsContext, _ i: Int) {
        let f = FigurFarbe(bodenFarben[min(max(i, 0), bodenFarben.count - 1)])
        g.fill(box(0, 300, breite, 500), with: .linearGradient(Gradient(colors: [f.mal(0.88).farbe, f.farbe]), startPoint: P(0, 300), endPoint: P(0, 430)))
        let fuge = f.mal(0.82).farbe
        if i == 0 || i == 1 || i == 3 {
            // Rows get taller toward the viewer: a little perspective without a full grid.
            var y: CGFloat = 300
            var h: CGFloat = 9
            var reihe = 0
            while y < 430 {
                linie(g, strich(P(0, y), P(breite, y)), fuge, 1.5)
                if i != 3 {
                    for x in stride(from: CGFloat(reihe % 3) * 47, to: breite, by: 140) { linie(g, strich(P(x, y), P(x, y + h)), fuge, 1.5) }
                }
                y += h
                h *= 1.28
                reihe += 1
            }
        }
        if i == 3 {
            // Tile seams run toward a point above the middle of the room.
            for k in -9...9 {
                let x = CGFloat(k) * 52
                linie(g, strich(P(195 + x * 150 / 280, 300), P(195 + x, 430)), fuge, 1.5)
            }
        }
        teil(g, box(-4, 292, breite + 8, 10, 2), Pal.weiss, 2)
    }

    private static func fenster(_ g: GraphicsContext, nacht: Bool, t: Double) {
        let rahmen = CGRect(x: 22, y: 72, width: 112, height: 124)
        let glas = rahmen.insetBy(dx: 7, dy: 7)
        teil(g, Path(roundedRect: rahmen, cornerRadius: 6), Pal.weiss, 3)
        let himmel = nacht ? [farbe(0x1E2A55), farbe(0x3A3F78)] : [farbe(0x8CCBF2), farbe(0xDDF1FB)]
        g.fill(Path(glas), with: .linearGradient(Gradient(colors: himmel), startPoint: P(glas.midX, glas.minY), endPoint: P(glas.midX, glas.maxY)))
        var innen = g
        innen.clip(to: Path(glas))
        if nacht {
            sterne(innen, in: glas, anzahl: 7, t: t)
            mond(innen, P(104, 104), 11)
        } else {
            wolke(innen, P(62, 156), 0.45, Pal.weiss)
            wolke(innen, P(112, 118), 0.3, Pal.weiss)
        }
        linie(g, strich(P(rahmen.midX, glas.minY), P(rahmen.midX, glas.maxY)), Pal.weiss.farbe, 5)
        linie(g, strich(P(glas.minX, rahmen.midY), P(glas.maxX, rahmen.midY)), Pal.weiss.farbe, 5)
        teil(g, box(14, 192, 128, 9, 3), Pal.weiss, 2)
        // Curtains on a wooden rod.
        let stoff = FigurFarbe(0xF7B6C6)
        let links = Path { p in
            p.move(to: P(10, 64))
            p.addLine(to: P(42, 64))
            p.addQuadCurve(to: P(30, 206), control: P(18, 140))
            p.addLine(to: P(8, 208))
            p.closeSubpath()
        }
        teil(g, links, stoff, 2.5)
        teil(g, links.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 156, ty: 0)), stoff, 2.5)
        linie(g, strich(P(4, 64), P(152, 64)), Pal.holz.kontur, 6)
        linie(g, strich(P(4, 64), P(152, 64)), Pal.holz.farbe, 3.5)
    }

    private static func poster(_ g: GraphicsContext) {
        var h = g
        h.translateBy(x: 264, y: 186)
        h.rotate(by: .degrees(-3))
        teil(h, box(-28, -36, 56, 72, 2), FigurFarbe(0xFF8FA3), 2)
        h.fill(herzPfad(P(0, -6), 14), with: .color(.white))
        h.draw(Text("amore").font(.system(size: 9, weight: .heavy, design: .rounded)).foregroundStyle(Color.white), at: P(0, 24))
        h.fill(box(-9, -40, 18, 8, 1), with: .color(.white.opacity(0.7)))
    }

    private static func regal(_ g: GraphicsContext) {
        let buecher: [(x: CGFloat, h: CGFloat, f: UInt32)] = [(306, 24, 0xE56B6F), (318, 30, 0x6C91C2), (330, 26, 0xF2C46D), (342, 21, 0x8FB8A8)]
        for b in buecher { teil(g, box(b.x, 176 - b.h, 11, b.h, 2), FigurFarbe(b.f), 2) }
        teil(g, box(364, 162, 16, 14, 3), FigurFarbe(0xE8906A), 2)
        for (dx, a) in [(CGFloat(-4), -30.0), (0, 0), (4, 30)] {
            var b = g
            b.translateBy(x: 372 + dx, y: 162)
            b.rotate(by: .degrees(a))
            teil(b, oval(P(0, -9), 4, 9), Pal.gruen, 1.8)
        }
        teil(g, box(300, 176, 84, 7, 2), Pal.holz, 2.5)
        for x in [CGFloat(314), 370] { linie(g, strich(P(x, 183), P(x, 193)), Pal.holz.kontur, 3) }
    }

    /// Frame with a mat and a drawn stand-in; the real photo is laid over it (`ProfilSzeneHintergrund`).
    private static func rahmen(_ g: GraphicsContext, _ r: CGRect) {
        let nagel = P(r.midX, r.minY - 10)
        linie(g, strich(P(r.minX + 8, r.minY), nagel), Pal.dunkel.farbe.opacity(0.5), 1.2)
        linie(g, strich(P(r.maxX - 8, r.minY), nagel), Pal.dunkel.farbe.opacity(0.5), 1.2)
        g.fill(kreis(nagel, 2), with: .color(Pal.dunkel.farbe))
        g.fill(Path(roundedRect: r.offsetBy(dx: 2, dy: 3), cornerRadius: 3), with: .color(.black.opacity(0.12)))
        teil(g, Path(roundedRect: r, cornerRadius: 3), FigurFarbe(0xD9B26A), 2.5)
        g.fill(Path(r.insetBy(dx: 4, dy: 4)), with: .color(.white))
        let foto = r.insetBy(dx: 7, dy: 7)
        g.fill(Path(foto), with: .linearGradient(Gradient(colors: [farbe(0xFBD3DE), farbe(0xF6A9BD)]), startPoint: P(foto.minX, foto.minY), endPoint: P(foto.maxX, foto.maxY)))
        g.fill(herzPfad(P(foto.midX, foto.midY), min(foto.width, foto.height) * 0.18), with: .color(.white.opacity(0.8)))
    }

    private static func teppich(_ g: GraphicsContext) {
        teil(g, oval(P(250, 384), 134, 30), FigurFarbe(0xF3A5B8), 2.5)
        linie(g, oval(P(250, 384), 116, 22), .white.opacity(0.6), 2.5)
        linie(g, oval(P(250, 384), 100, 16), FigurFarbe(0xF3A5B8).mal(0.85).farbe, 2)
    }

    private static func pflanze(_ g: GraphicsContext) {
        for (a, l) in [(-58.0, CGFloat(34)), (-30, 44), (-4, 50), (24, 44), (52, 36)] {
            var b = g
            b.translateBy(x: 366, y: 288)
            b.rotate(by: .degrees(a))
            teil(b, oval(P(0, -l / 2), 9, l / 2), Pal.gruen, 2.5)
            linie(b, strich(P(0, -4), P(0, -l + 6)), Pal.gruen.mal(0.8).farbe, 1.5)
        }
        let topf = Path { p in
            p.move(to: P(346, 286))
            p.addLine(to: P(386, 286))
            p.addLine(to: P(380, 320))
            p.addLine(to: P(352, 320))
            p.closeSubpath()
        }
        teil(g, topf, FigurFarbe(0xD9825B), 2.5)
    }

    /// Bedside table right of the bed with a small lamp; its glow comes with the night.
    private static func lampe(_ g: GraphicsContext) {
        for x in [CGFloat(158), 186] { linie(g, strich(P(x, 312), P(x, 324)), Pal.holz.kontur, 4) }
        teil(g, box(154, 282, 36, 32, 3), Pal.holz.mal(0.92), 2.5)
        g.fill(kreis(P(172, 298), 2.5), with: .color(Pal.holz.kontur))
        teil(g, box(150, 276, 44, 8, 3), Pal.holz, 2.5)
        teil(g, oval(P(172, 274), 9, 3.5), Pal.gold, 2)
        linie(g, strich(P(172, 272), P(172, 258)), Pal.gold.kontur, 3)
        let schirm = Path { p in
            p.move(to: P(163, 238))
            p.addLine(to: P(181, 238))
            p.addLine(to: P(188, 259))
            p.addLine(to: P(156, 259))
            p.closeSubpath()
        }
        teil(g, schirm, FigurFarbe(0xFFE3B0), 2.5)
    }

    private static func lichterkette(_ g: GraphicsContext, t: Double) {
        let farben: [UInt32] = [0xFFD580, 0xFF9EB5, 0xFFF3C4, 0xA8E0FF]
        for n in 0..<3 {
            let a = P(CGFloat(n) * 130, 36)
            let b = P(CGFloat(n + 1) * 130, 36)
            let c = P((a.x + b.x) / 2, 64)
            linie(g, bogen(a, b, c), Pal.dunkel.farbe.opacity(0.45), 1.5)
            for k in 1..<6 {
                let s = CGFloat(k) / 6
                let u = 1 - s
                let x = u * u * a.x + 2 * u * s * c.x + s * s * b.x
                let y = u * u * a.y + 2 * u * s * c.y + s * s * b.y + 4
                let i = n * 6 + k
                let f = farbe(farben[i % farben.count])
                let an = 0.6 + 0.4 * sin(t * 2.1 + Double(i) * 1.7)
                g.fill(kreis(P(x, y), 8), with: .color(f.opacity(0.35 * an)))
                g.fill(kreis(P(x, y), 3.2), with: .color(f))
            }
        }
    }

    // MARK: Bed (own 300 x 220 space: headboard, pillows, blanket, frame)

    private static let bettStile: [(kopfteil: UInt32, decke: UInt32, gestell: UInt32)] = [
        (0xD9B48A, 0xB9A7E0, 0xC69C6D), (0x7A4E33, 0x8FB8A8, 0x6A432C), (0xE8A0B4, 0xFFD1DC, 0xD98BA0),
        (0xF4F4F4, 0x9CC7E8, 0xE6E6E6), (0x9DA3AE, 0xF1EDE6, 0x8A909B),
    ]

    private static func stil(_ i: Int) -> (kopfteil: UInt32, decke: UInt32, gestell: UInt32) {
        bettStile[min(max(i, 0), bettStile.count - 1)]
    }

    /// Headboard, sheet and the empty pillows (`kissen`: their x centers). A sleeping figure brings
    /// its own pillow (FigurView's "schläft"), so its place stays free.
    static func bettHinten(_ g: GraphicsContext, _ i: Int, kissen: [CGFloat], bild: UIImage?) {
        let k = FigurFarbe(stil(i).kopfteil)
        if let bild {
            g.draw(Image(uiImage: bild), in: CGRect(x: 0, y: 0, width: 300, height: 132))
        } else {
            kopfteil(g, i, k)
        }
        teil(g, box(8, 100, 284, 52, 12), Pal.weiss, 2.5)
        for x in kissen {
            var h = g
            h.translateBy(x: x, y: 104)
            h.rotate(by: .degrees(x < 150 ? -4 : 4))
            teil(h, box(-54, -24, 108, 48, 20), Pal.kissen, 3)
        }
    }

    private static func kopfteil(_ g: GraphicsContext, _ i: Int, _ k: FigurFarbe) {
        switch i {
        case 1:
            teil(g, box(22, 14, 256, 110, 6), k)
            for x in [CGFloat(40), 160] { linie(g, box(x, 34, 100, 70, 6), k.mal(0.8).farbe, 3) }
            teil(g, box(12, 2, 276, 18, 6), k.mix(Pal.weiss, 0.15))
        case 2:
            let bogen = Path { p in
                p.move(to: P(18, 124))
                p.addLine(to: P(18, 50))
                p.addQuadCurve(to: P(150, 0), control: P(18, 0))
                p.addQuadCurve(to: P(282, 50), control: P(282, 0))
                p.addLine(to: P(282, 124))
                p.closeSubpath()
            }
            teil(g, bogen, k)
            var h = g
            h.clip(to: bogen)
            for (n, y) in [CGFloat(34), 64, 94].enumerated() {
                for x in stride(from: CGFloat(n % 2 == 0 ? 50 : 72), to: 270, by: 44) { h.fill(kreis(P(x, y), 3), with: .color(k.mal(0.8).farbe)) }
            }
        case 3:
            teil(g, box(16, 14, 268, 9, 4), k)
            for x in stride(from: CGFloat(48), to: 260, by: 26) { teil(g, box(x, 23, 5, 104, 2), k, 2) }
            for x in [CGFloat(16), 272] {
                teil(g, box(x, 0, 12, 132, 6), k)
                teil(g, kreis(P(x + 6, 0), 8), Pal.gold, 2.5)
            }
        case 4:
            teil(g, box(14, 0, 272, 130, 14), k)
            for x in stride(from: CGFloat(48), to: 270, by: 34) { linie(g, strich(P(x, 10), P(x, 124)), k.mal(0.88).farbe, 2.5) }
        default:
            let platte = Path(roundedRect: CGRect(x: 18, y: 0, width: 264, height: 130), cornerRadius: 40)
            teil(g, platte, k)
            var h = g
            h.clip(to: platte)
            for x in stride(from: CGFloat(50), to: 260, by: 32) { linie(h, strich(P(x, 14), P(x, 130)), k.mal(0.86).farbe, 3) }
        }
    }

    /// Blanket up to the chin with the sheet folded over it, the bed frame in front; `herz` sits
    /// between two heads.
    static func bettVorn(_ g: GraphicsContext, _ i: Int, herz: Bool) {
        let s = stil(i)
        let d = FigurFarbe(s.decke)
        let kante = Path { p in
            p.move(to: P(4, 156))
            p.addCurve(to: P(150, 150), control1: P(40, 140), control2: P(110, 142))
            p.addCurve(to: P(296, 156), control1: P(190, 142), control2: P(260, 140))
        }
        var decke = kante
        decke.addLine(to: P(298, 204))
        decke.addLine(to: P(2, 204))
        decke.closeSubpath()
        teil(g, decke, d)
        var innen = g
        innen.clip(to: decke)
        for x in stride(from: CGFloat(-40), to: 320, by: 28) {
            linie(innen, strich(P(x, 150), P(x + 56, 206)), d.mal(0.9).farbe, 1.5)
            linie(innen, strich(P(x + 56, 150), P(x, 206)), d.mal(0.9).farbe, 1.5)
        }
        if i == 2 {
            for x in stride(from: CGFloat(16), to: 290, by: 28) { innen.fill(kreis(P(x, 180), 2.5), with: .color(.white.opacity(0.7))) }
        }
        linie(g, kante, Pal.weiss.kontur, 17)
        linie(g, kante, Pal.weiss.farbe, 13)
        let gestell = FigurFarbe(s.gestell)
        teil(g, box(0, 198, 300, 14, 5), gestell)
        for x in [CGFloat(12), 276] { teil(g, box(x, 210, 12, 10, 2), gestell.mal(0.85), 2.5) }
        if herz { teil(g, herzPfad(P(150, 60), 11), Pal.rose, 2.5) }
    }

    // MARK: Gym

    static func gym(_ g: GraphicsContext) {
        g.fill(alles, with: .linearGradient(Gradient(colors: [farbe(0x3C4048), farbe(0x5A5F68)]), startPoint: P(0, -60), endPoint: P(0, 300)))
        for x in [CGFloat(70), 195, 320] {
            g.fill(kreis(P(x, 30), 60), with: .radialGradient(Gradient(colors: [.white.opacity(0.12), .clear]), center: P(x, 30), startRadius: 4, endRadius: 60))
            g.fill(oval(P(x, 22), 44, 7), with: .color(.white.opacity(0.75)))
        }
        let spiegel = box(168, 64, 206, 132, 6)
        teil(g, spiegel, FigurFarbe(0xB9C7D3), 3)
        var glas = g
        glas.clip(to: spiegel)
        for k in 0..<3 { linie(glas, strich(P(200 + CGFloat(k) * 64, 196), P(250 + CGFloat(k) * 64, 64)), .white.opacity(0.25), 10) }
        g.fill(box(0, 206, breite, 10), with: .color(Pal.rose.farbe))
        g.draw(Text("LOVEA GYM").font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(Color.white.opacity(0.2)), at: P(84, 110))
        g.fill(box(0, 300, breite, 500), with: .color(farbe(0x2A2B30)))
        for k in 0..<70 { g.fill(kreis(P(zufall(k * 2) * breite, 304 + zufall(k * 2 + 1) * 126), 1.2), with: .color(.white.opacity(0.12))) }
        linie(g, strich(P(0, 300), P(breite, 300)), .black.opacity(0.4), 3)
        // Dumbbell rack.
        for x in [CGFloat(14), 132] { teil(g, box(x, 222, 8, 98, 3), Pal.dunkel, 2.5) }
        for y in [CGFloat(250), 290] {
            teil(g, box(8, y, 136, 7, 3), Pal.silber, 2.5)
            for k in 0..<4 {
                let c = P(30 + CGFloat(k) * 30, y - 8)
                linie(g, strich(P(c.x - 9, c.y), P(c.x + 9, c.y)), Pal.silber.farbe, 3)
                teil(g, box(c.x - 13, c.y - 7, 6, 14, 2), Pal.dunkel, 2)
                teil(g, box(c.x + 7, c.y - 7, 6, 14, 2), Pal.dunkel, 2)
            }
        }
        // Kettlebell, bottle and a plate leaning on the wall.
        linie(g, bogen(P(146, 312), P(166, 312), P(156, 290)), farbe(0x2F3136), 5)
        teil(g, kreis(P(156, 320), 14), FigurFarbe(0x2F3136), 2.5)
        teil(g, box(184, 296, 12, 28, 4), FigurFarbe(0x5CC6D0), 2)
        teil(g, box(186, 290, 8, 7, 2), Pal.weiss, 1.5)
        teil(g, kreis(P(356, 296), 30), FigurFarbe(0x1F2024), 3)
        linie(g, kreis(P(356, 296), 20), .white.opacity(0.15), 2)
        teil(g, kreis(P(356, 296), 5), Pal.silber, 1.5)
    }

    // MARK: Outside

    static func draussen(_ g: GraphicsContext, wetter: ProfilSzene.Wetter, nacht: Bool, t: Double) {
        let himmel: (oben: UInt32, unten: UInt32)
        switch (wetter, nacht) {
        case (.sonne, false): himmel = (0x5FB7EE, 0xCFEBFA)
        case (.wolken, false): himmel = (0x8FB2CE, 0xDCE7EF)
        case (.regen, false): himmel = (0x6A7888, 0xA9B4BF)
        case (.schnee, false): himmel = (0xAEBCCB, 0xEDF1F5)
        case (.sonne, true): himmel = (0x0B1230, 0x2A3468)
        case (_, true): himmel = (0x161D2E, 0x3A4458)
        }
        g.fill(alles, with: .linearGradient(Gradient(colors: [farbe(himmel.oben), farbe(himmel.unten)]), startPoint: P(0, -100), endPoint: P(0, 290)))
        if nacht {
            if wetter == .sonne || wetter == .wolken { sterne(g, in: CGRect(x: 0, y: -80, width: breite, height: 300), anzahl: 30, t: t) }
            mond(g, P(316, 92), 24)
        } else if wetter == .sonne {
            sonne(g, P(316, 92), t: t)
        }
        wolken(g, wetter: wetter, nacht: nacht, t: t)
        landschaft(g, wetter: wetter, nacht: nacht)
        laterne(g, P(40, 334), nacht: nacht)
        if wetter == .regen {
            g.fill(oval(P(232, 392), 34, 6), with: .color(farbe(0xBFD9EE).opacity(0.55)))
            regen(g, t: t)
        }
        if wetter == .schnee { schnee(g, t: t) }
    }

    /// Clouds drift slowly to the right and wrap around.
    private static func wolken(_ g: GraphicsContext, wetter: ProfilSzene.Wetter, nacht: Bool, t: Double) {
        let zug = CGFloat((t * 4).truncatingRemainder(dividingBy: 520))
        func x(_ start: CGFloat) -> CGFloat { (start + zug).truncatingRemainder(dividingBy: 520) - 65 }
        switch wetter {
        case .sonne:
            if !nacht { wolke(g, P(x(90), 66), 0.7, Pal.weiss) }
        case .wolken:
            let f = nacht ? FigurFarbe(0x5A6478) : Pal.weiss
            wolke(g, P(x(60), 70), 0.9, f)
            wolke(g, P(x(250), 50), 0.7, f)
            wolke(g, P(x(420), 120), 0.6, f)
        case .regen, .schnee:
            let f = nacht ? FigurFarbe(0x3E4656) : FigurFarbe(0x8D97A3)
            for (n, start) in [CGFloat(40), 170, 300, 430].enumerated() { wolke(g, P(x(start), 50 + CGFloat(n % 2) * 26), 1.1, f) }
        }
    }

    private static func landschaft(_ g: GraphicsContext, wetter: ProfilSzene.Wetter, nacht: Bool) {
        let schnee = wetter == .schnee
        func ton(_ hex: UInt32) -> FigurFarbe { nacht ? FigurFarbe(hex).mix(FigurFarbe(0x1A2244), 0.55) : FigurFarbe(hex) }
        let huegel = Path { p in
            p.move(to: P(-10, 300))
            p.addQuadCurve(to: P(200, 262), control: P(80, 246))
            p.addQuadCurve(to: P(400, 288), control: P(320, 262))
            p.addLine(to: P(400, 700))
            p.addLine(to: P(-10, 700))
            p.closeSubpath()
        }
        teil(g, huegel, ton(schnee ? 0xEEF3F7 : 0x8CCB7E), 3)
        let krone = ton(schnee ? 0xDCE6EE : 0x5DAA5A)
        let stamm = ton(0x9A6B47)
        baum(g, P(78, 268), 1, krone, stamm)
        baum(g, P(128, 272), 0.72, krone, stamm)
        baum(g, P(352, 282), 0.8, krone, stamm)
        let boden = Path { p in
            p.move(to: P(-10, 318))
            p.addQuadCurve(to: P(400, 312), control: P(200, 296))
            p.addLine(to: P(400, 700))
            p.addLine(to: P(-10, 700))
            p.closeSubpath()
        }
        teil(g, boden, ton(schnee ? 0xE2E9F0 : 0x69B25D), 3)
        let weg = Path { p in
            p.move(to: P(190, 305))
            p.addLine(to: P(224, 305))
            p.addLine(to: P(320, 700))
            p.addLine(to: P(110, 700))
            p.closeSubpath()
        }
        g.fill(weg, with: .color(ton(schnee ? 0xF6F8FA : 0xE9D8B4).farbe))
        if wetter == .sonne && !nacht {
            let blueten: [UInt32] = [0xFF8FA3, 0xFFD34E, 0xFFFFFF, 0xB9A7E0]
            for k in 0..<14 {
                let bx = zufall(k * 5) * breite
                guard bx < 110 || bx > 330 else { continue }
                g.fill(kreis(P(bx, 330 + zufall(k * 5 + 1) * 90), 3), with: .color(farbe(blueten[k % blueten.count])))
            }
        }
    }

    private static func baum(_ g: GraphicsContext, _ fuss: CGPoint, _ s: CGFloat, _ krone: FigurFarbe, _ stamm: FigurFarbe) {
        teil(g, box(fuss.x - 5 * s, fuss.y - 40 * s, 10 * s, 40 * s, 3 * s), stamm, 2.5)
        verbunden(g, [
            kreis(P(fuss.x, fuss.y - 64 * s), 24 * s),
            kreis(P(fuss.x - 17 * s, fuss.y - 46 * s), 18 * s),
            kreis(P(fuss.x + 17 * s, fuss.y - 46 * s), 18 * s),
        ], krone, 3)
    }

    private static func laterne(_ g: GraphicsContext, _ fuss: CGPoint, nacht: Bool) {
        let mast = strich(fuss, P(fuss.x, fuss.y - 150))
        linie(g, mast, Pal.dunkel.kontur, 8)
        linie(g, mast, Pal.dunkel.farbe, 5)
        let kopf = P(fuss.x, fuss.y - 162)
        if nacht {
            g.fill(kreis(kopf, 70), with: .radialGradient(Gradient(colors: [farbe(0xFFD27A).opacity(0.5), .clear]), center: kopf, startRadius: 6, endRadius: 70))
        }
        teil(g, box(kopf.x - 9, kopf.y - 10, 18, 22, 4), FigurFarbe(nacht ? 0xFFE7A8 : 0xF4F1E8), 3)
        teil(g, box(kopf.x - 12, kopf.y - 17, 24, 7, 3), Pal.dunkel, 2.5)
    }

    private static func sonne(_ g: GraphicsContext, _ c: CGPoint, t: Double) {
        g.fill(kreis(c, 64), with: .radialGradient(Gradient(colors: [farbe(0xFFE58A).opacity(0.6), .clear]), center: c, startRadius: 20, endRadius: 64))
        for k in 0..<12 {
            let a = Double(k) * Double.pi / 6 + t * 0.15
            let dx = CGFloat(cos(a))
            let dy = CGFloat(sin(a))
            let laenge: CGFloat = k % 2 == 0 ? 50 : 44
            linie(g, strich(P(c.x + dx * 36, c.y + dy * 36), P(c.x + dx * laenge, c.y + dy * laenge)), Pal.gelb.farbe, 4)
        }
        teil(g, kreis(c, 28), Pal.gelb)
    }

    private static func mond(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat) {
        g.fill(kreis(c, r * 2), with: .radialGradient(Gradient(colors: [farbe(0xFFF1B8).opacity(0.25), .clear]), center: c, startRadius: r * 0.8, endRadius: r * 2))
        var h = g
        h.clip(to: kreis(P(c.x + r * 0.55, c.y - r * 0.35), r * 0.9), options: .inverse)
        h.fill(kreis(c, r), with: .color(farbe(0xFFF1B8)))
    }

    private static func sterne(_ g: GraphicsContext, in r: CGRect, anzahl: Int, t: Double) {
        for k in 0..<anzahl {
            let p = P(r.minX + zufall(k * 3) * r.width, r.minY + zufall(k * 3 + 1) * r.height)
            let gross = zufall(k * 3 + 2) > 0.7
            var h = g
            h.opacity = 0.55 + 0.45 * sin(t * (1.2 + Double(zufall(k * 3 + 2)) * 1.5) + Double(k))
            h.fill(stern(p, gross ? 4.5 : 2.2), with: .color(farbe(0xFFF6D5)))
        }
    }

    private static func wolke(_ g: GraphicsContext, _ c: CGPoint, _ s: CGFloat, _ f: FigurFarbe) {
        verbunden(g, [
            kreis(P(c.x - 26 * s, c.y + 4 * s), 18 * s), kreis(P(c.x, c.y - 8 * s), 26 * s),
            kreis(P(c.x + 28 * s, c.y + 2 * s), 20 * s), box(c.x - 44 * s, c.y + 4 * s, 92 * s, 18 * s, 9 * s),
        ], f, 3)
    }

    private static func regen(_ g: GraphicsContext, t: Double) {
        for k in 0..<70 {
            let p = CGFloat((t * (0.9 + Double(zufall(k + 100)) * 0.4) + Double(zufall(k + 200))).truncatingRemainder(dividingBy: 1))
            let x = zufall(k) * (breite + 60) - p * 40
            let y = -40 + p * 480
            linie(g, strich(P(x, y), P(x - 4, y + 14)), .white.opacity(0.55), 1.6)
        }
    }

    private static func schnee(_ g: GraphicsContext, t: Double) {
        for k in 0..<45 {
            let p = CGFloat((t * (0.08 + Double(zufall(k + 100)) * 0.05) + Double(zufall(k + 200))).truncatingRemainder(dividingBy: 1))
            let x = zufall(k) * breite + CGFloat(sin(t * 0.8 + Double(k))) * 8
            g.fill(kreis(P(x, -40 + p * 480), 2 + zufall(k + 300) * 1.8), with: .color(.white.opacity(0.9)))
        }
    }

    // MARK: Helpers

    private static func farbe(_ hex: UInt32) -> Color { FigurFarbe(hex).farbe }

    /// Stable 0..<1 per index, so a still frame always looks the same.
    private static func zufall(_ i: Int) -> CGFloat {
        let x = sin(Double(i) * 12.9898 + 78.233) * 43758.5453
        return CGFloat(x - x.rounded(.down))
    }

    private static func stern(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path { p in
            p.move(to: P(c.x, c.y - r))
            p.addQuadCurve(to: P(c.x + r, c.y), control: c)
            p.addQuadCurve(to: P(c.x, c.y + r), control: c)
            p.addQuadCurve(to: P(c.x - r, c.y), control: c)
            p.addQuadCurve(to: P(c.x, c.y - r), control: c)
            p.closeSubpath()
        }
    }
}
