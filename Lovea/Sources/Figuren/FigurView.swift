import SwiftUI

/// Bitmoji-style half figure. `groesse` is the height; the width is 5/6 of it.
/// Abzeichen: "partyhut", "herzaugen", "outfit", "uhrwerk", "schnecke", "krone".
struct FigurView: View {
    private let aussehen: FigurAussehen
    private let zustand: FigurZustand
    private let abzeichen: [String]
    private let groesse: CGFloat
    private let animiert: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var sichtbar = false

    init(_ aussehen: FigurAussehen, zustand: FigurZustand, abzeichen: [String] = [], groesse: CGFloat, animiert: Bool = true) {
        self.aussehen = aussehen
        self.zustand = zustand
        self.abzeichen = abzeichen
        self.groesse = groesse
        self.animiert = animiert
    }

    var body: some View {
        Group {
            if animiert && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !sichtbar || scenePhase != .active)) { kontext in
                    leinwand(kontext.date.timeIntervalSinceReferenceDate, statisch: false)
                }
            } else {
                leinwand(0.4, statisch: true)
            }
        }
        .frame(width: groesse * 5 / 6, height: groesse)
        .saturation(zustand == .offline ? 0.15 : 1)
        .opacity(zustand == .offline ? 0.7 : 1)
        .onAppear { sichtbar = true }
        .onDisappear { sichtbar = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Figur")
        .accessibilityValue(zustand.titel)
    }

    private func leinwand(_ t: Double, statisch: Bool) -> some View {
        let zeichner = Zeichner(aussehen, zustand, abzeichen, t: t, statisch: statisch)
        return Canvas { g, size in zeichner.zeichne(g, size) }
    }
}

// MARK: - Helpers

fileprivate func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

fileprivate func kreis(_ c: CGPoint, _ r: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
}

fileprivate func oval(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
}

fileprivate func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat = 0) -> Path {
    Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
}

fileprivate func strich(_ a: CGPoint, _ b: CGPoint) -> Path {
    Path { p in
        p.move(to: a)
        p.addLine(to: b)
    }
}

fileprivate func bogen(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Path {
    Path { p in
        p.move(to: a)
        p.addQuadCurve(to: b, control: c)
    }
}

fileprivate func gespiegelt(_ p: Path) -> Path {
    p.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 200, ty: 0))
}

fileprivate func herzPfad(_ c: CGPoint, _ s: CGFloat) -> Path {
    Path { p in
        p.move(to: P(c.x, c.y + s * 0.85))
        p.addCurve(to: P(c.x - s, c.y - s * 0.2), control1: P(c.x - s * 0.5, c.y + s * 0.5), control2: P(c.x - s, c.y + s * 0.15))
        p.addCurve(to: P(c.x, c.y - s * 0.5), control1: P(c.x - s, c.y - s * 0.8), control2: P(c.x - s * 0.2, c.y - s * 0.95))
        p.addCurve(to: P(c.x + s, c.y - s * 0.2), control1: P(c.x + s * 0.2, c.y - s * 0.95), control2: P(c.x + s, c.y - s * 0.8))
        p.addCurve(to: P(c.x, c.y + s * 0.85), control1: P(c.x + s, c.y + s * 0.15), control2: P(c.x + s * 0.5, c.y + s * 0.5))
        p.closeSubpath()
    }
}

fileprivate func funkel(_ c: CGPoint, _ r: CGFloat) -> Path {
    Path { p in
        p.move(to: P(c.x, c.y - r))
        p.addQuadCurve(to: P(c.x + r, c.y), control: c)
        p.addQuadCurve(to: P(c.x, c.y + r), control: c)
        p.addQuadCurve(to: P(c.x - r, c.y), control: c)
        p.addQuadCurve(to: P(c.x, c.y - r), control: c)
        p.closeSubpath()
    }
}

fileprivate func tropfenPfad(_ c: CGPoint) -> Path {
    Path { p in
        p.move(to: P(c.x, c.y - 8))
        p.addCurve(to: P(c.x, c.y + 5), control1: P(c.x + 9, c.y + 1), control2: P(c.x + 5, c.y + 5))
        p.addCurve(to: P(c.x, c.y - 8), control1: P(c.x - 5, c.y + 5), control2: P(c.x - 9, c.y + 1))
        p.closeSubpath()
    }
}

/// Fill plus the thick soft outline derived from the fill.
fileprivate func teil(_ g: GraphicsContext, _ p: Path, _ f: FigurFarbe, _ breite: CGFloat = 3.5) {
    g.fill(p, with: .color(f.farbe))
    g.stroke(p, with: .color(f.kontur), style: StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round))
}

fileprivate func linie(_ g: GraphicsContext, _ p: Path, _ c: Color, _ breite: CGFloat) {
    g.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round))
}

fileprivate func text(_ g: GraphicsContext, _ s: String, _ c: CGPoint, _ groesse: CGFloat, _ farbe: Color) {
    g.draw(Text(s).font(.system(size: groesse, weight: .heavy, design: .rounded)).foregroundStyle(farbe), at: c)
}

fileprivate extension Array {
    func wahl(_ i: Int) -> Element { self[Swift.min(Swift.max(i, 0), count - 1)] }
}

fileprivate enum Pal {
    static let weiss = FigurFarbe(0xFFFFFF)
    static let tinte = FigurFarbe(0x3A2630)
    static let rose = FigurFarbe(0xFF3B5C)
    static let gold = FigurFarbe(0xF5C542)
    static let silber = FigurFarbe(0xC9CCD3)
    static let dunkel = FigurFarbe(0x3B3A44)
    static let holz = FigurFarbe(0xC69C6D)
    static let gelb = FigurFarbe(0xFFD34E)
    static let himmel = FigurFarbe(0x8CC8F2)
    static let gruen = FigurFarbe(0x5DBB7A)
    static let mint = FigurFarbe(0x8ED8BE)
    static let blau = FigurFarbe(0x7FB6E8)
    static let kissen = FigurFarbe(0xEDE7F6)
    static let sofa = FigurFarbe(0xC9876B)
    static let decke = FigurFarbe(0xB9A7E0)
    static let teddy = FigurFarbe(0xB07A4F)
    static let popcorn = FigurFarbe(0xFFF1C1)
    static let brot = FigurFarbe(0xE0A458)
    static let sekt = FigurFarbe(0xF6D77A)
    static let wolke = FigurFarbe(0xB8C0CC)
    static let nacht = FigurFarbe(0x6B5FA8)
    static let mundInnen = FigurFarbe(0x6B2335)
    static let zunge = FigurFarbe(0xF07A8A)
    static let band = FigurFarbe(0x3F74B5)
    static let schnecke = FigurFarbe(0xC98A5A)
    static let schneckeKoerper = FigurFarbe(0x9CC7A4)
}

fileprivate struct Arm {
    let ellbogen: CGPoint
    let hand: CGPoint
    init(_ ellbogen: CGPoint, _ hand: CGPoint) {
        self.ellbogen = ellbogen
        self.hand = hand
    }
}

fileprivate enum Mund { case laecheln, grinsen, offen(CGFloat), neutral, traurig, kuss }
fileprivate enum Auge { case offen(gross: Bool), zu, froh, muede }
fileprivate enum Aermel { case lang, kurz, keine }

// MARK: - Drawing (figure space 200 x 240)

private struct Zeichner {
    let z: FigurZustand
    let abz: Set<String>
    let t: Double
    let statisch: Bool
    let haut: FigurFarbe
    let haar: FigurFarbe
    let iris: FigurFarbe
    let top: FigurFarbe
    let frisur: Int
    let oberteil: Int
    let brille: Int
    let bart: Int

    init(_ a: FigurAussehen, _ z: FigurZustand, _ abz: [String], t: Double, statisch: Bool) {
        self.z = z
        self.abz = Set(abz)
        self.t = t
        self.statisch = statisch
        haut = FigurAussehen.hautToene.wahl(a.haut).farbe
        haar = FigurAussehen.haarfarben.wahl(a.haarfarbe).farbe
        iris = FigurAussehen.augenfarben.wahl(a.augen).farbe
        frisur = min(max(a.frisur, 0), FigurAussehen.frisuren.count - 1)
        brille = min(max(a.brille, 0), FigurAussehen.brillen.count - 1)
        bart = min(max(a.bart, 0), FigurAussehen.baerte.count - 1)
        if z == .abend {
            top = FigurFarbe(0xAFC8EE)  // Schlafanzug
            oberteil = 2
        } else {
            top = FigurAussehen.oberteilfarben.wahl(a.oberteilfarbe).farbe
            oberteil = min(max(a.oberteil, 0), FigurAussehen.oberteile.count - 1)
        }
    }

    // MARK: Time

    func w(_ tempo: Double, _ versatz: Double = 0) -> CGFloat { CGFloat(sin(t * tempo + versatz)) }

    func zyklus(_ periode: Double, _ versatz: Double = 0) -> CGFloat {
        CGFloat((t + versatz).truncatingRemainder(dividingBy: periode) / periode)
    }

    /// True during the first `anteil` of each period; always true when static, so short effects still show.
    func an(_ periode: Double, _ anteil: CGFloat) -> Bool { statisch || zyklus(periode) < anteil }

    // MARK: Frame

    func zeichne(_ ctx: GraphicsContext, _ size: CGSize) {
        var g = ctx
        g.scaleBy(x: size.width / 200, y: size.height / 240)
        g.clip(to: Path(CGRect(x: 0, y: 0, width: 200, height: 240)))
        let bew = bewegung()
        let atem: CGFloat = z == .offline ? 1 : 1.01 + 0.01 * w(2 * Double.pi / 3.6)
        g.translateBy(x: 100, y: 240)
        g.rotate(by: .degrees(bew.winkel))
        g.scaleBy(x: atem, y: atem)
        g.translateBy(x: -100, y: bew.hoch - 240)

        hintergrund(g)
        haareHinten(g)
        koerper(g)
        kopf(g)
        gesicht(g)
        haareVorn(g)
        kopfschmuck(g)
        brillen(g)
        mitte(g)
        let arme = pose()
        if let l = arme.l { arm(g, P(60, 184), l) }
        if let r = arme.r { arm(g, P(140, 184), r) }
        requisite(g, arme.r?.hand ?? P(142, 252))
        if let l = arme.l { teil(g, kreis(l.hand, 9.5), haut) }
        if let r = arme.r { teil(g, kreis(r.hand, 9.5), haut) }
        effekte(g)
        abzeichenVorn(g)
    }

    func bewegung() -> (winkel: Double, hoch: CGFloat) {
        switch z {
        case .anstupsen: return (zyklus(1.4) < 0.5 ? Double(w(22)) * 6 : 0, 0)
        case .schlaeft: return (-5, 0)
        case .karte: return (Double(w(1.2)) * 3, 0)
        case .nichtStoeren: return (Double(w(4)) * 2.5, 0)
        case .laeuft: return (0, -abs(w(7)) * 3)
        case .rennt: return (3, -abs(w(12)) * 5)
        case .rad: return (0, -abs(w(5)) * 1.5)
        case .zuhause, .mittel, .ruhe: return (Double(w(0.9)) * 1.5, 0)
        case .lacht: return (0, w(20) * 1.5)
        case .gut, .pokal: return (0, -abs(w(3.4)) * 3)
        case .supermarkt: return (0, -abs(w(4)) * 1.5)
        case .faehrt, .fahrschule: return (Double(w(1.8)) * 1.5, 0)
        default: return (0, 0)
        }
    }

    var lenkWinkel: Double { Double(w(1.8)) * 12 }

    func amLenkrad(_ grad: Double) -> CGPoint {
        let r = (grad + lenkWinkel) * Double.pi / 180
        return P(100 + 34 * CGFloat(cos(r)), 216 + 34 * CGFloat(sin(r)))
    }

    // MARK: Body

    var aermel: Aermel {
        switch oberteil {
        case 1, 2, 3, 5: .lang
        case 6: .keine
        default: .kurz
        }
    }

    var kopfPfad: Path {
        Path { p in
            p.move(to: P(100, 30))
            p.addCurve(to: P(158, 94), control1: P(144, 30), control2: P(158, 56))
            p.addCurve(to: P(100, 152), control1: P(158, 128), control2: P(134, 152))
            p.addCurve(to: P(42, 94), control1: P(66, 152), control2: P(42, 128))
            p.addCurve(to: P(100, 30), control1: P(42, 56), control2: P(56, 30))
            p.closeSubpath()
        }
    }

    func rumpf(_ ausschnitt: Int) -> Path {
        Path { p in
            p.move(to: P(30, 240))
            p.addLine(to: P(33, 200))
            p.addCurve(to: P(72, 164), control1: P(35, 178), control2: P(50, 166))
            switch ausschnitt {
            case 1:
                p.addLine(to: P(86, 161))
                p.addLine(to: P(100, 186))
                p.addLine(to: P(114, 161))
            case 2:
                p.addLine(to: P(80, 162))
                p.addQuadCurve(to: P(120, 162), control: P(100, 192))
            default:
                p.addLine(to: P(86, 161))
                p.addQuadCurve(to: P(114, 161), control: P(100, 178))
            }
            p.addLine(to: P(128, 164))
            p.addCurve(to: P(167, 200), control1: P(150, 166), control2: P(165, 178))
            p.addLine(to: P(170, 240))
            p.closeSubpath()
        }
    }

    func koerper(_ g: GraphicsContext) {
        teil(g, box(86, 132, 28, 58, 10), haut)
        g.fill(box(78, 156, 44, 36), with: .color(haut.farbe))
        g.fill(oval(P(100, 152), 15, 6), with: .color(haut.mal(0.8).farbe.opacity(0.6)))

        if oberteil == 6 {
            let form = rumpf(0)
            teil(g, form, haut)
            g.fill(box(80, 150, 40, 28), with: .color(haut.farbe))
            let kleid = Path { p in
                p.move(to: P(20, 250))
                p.addLine(to: P(24, 190))
                p.addQuadCurve(to: P(176, 190), control: P(100, 204))
                p.addLine(to: P(180, 250))
                p.closeSubpath()
            }
            var h = g
            h.clip(to: form)
            teil(h, kleid, top)
            linie(g, form, haut.kontur, 3.5)
            for seite in [CGFloat(-1), 1] {
                let traeger = strich(P(100 + seite * 26, 164), P(100 + seite * 30, 194))
                linie(g, traeger, top.kontur, 6.5)
                linie(g, traeger, top.farbe, 3.5)
            }
            return
        }

        let form = rumpf(oberteil == 2 ? 1 : oberteil == 4 ? 2 : 0)
        teil(g, form, top)
        var h = g
        h.clip(to: form)
        switch oberteil {
        case 1:
            let kapuze = bogen(P(70, 164), P(130, 164), P(100, 196))
            linie(g, kapuze, top.kontur, 13)
            linie(g, kapuze, top.mal(0.88).farbe, 8.5)
            linie(g, strich(P(93, 180), P(91, 202)), .white.opacity(0.9), 2.5)
            linie(g, strich(P(107, 180), P(109, 202)), .white.opacity(0.9), 2.5)
            teil(h, box(68, 216, 64, 40, 14), top.mal(0.92), 2.5)
        case 2:
            if z == .abend {
                for x in stride(from: CGFloat(36), to: 170, by: 18) {
                    for y in stride(from: CGFloat(180), to: 240, by: 18) {
                        h.fill(kreis(P(x, y), 3), with: .color(.white.opacity(0.7)))
                    }
                }
            }
            let kragen = top.mix(Pal.weiss, 0.4)
            let links = Path { p in
                p.move(to: P(86, 160))
                p.addLine(to: P(100, 186))
                p.addLine(to: P(78, 178))
                p.closeSubpath()
            }
            teil(g, links, kragen, 2.5)
            teil(g, gespiegelt(links), kragen, 2.5)
            for y in [CGFloat(198), 214, 230] { g.fill(kreis(P(100, y), 2.2), with: .color(top.kontur)) }
        case 3:
            let bund = bogen(P(86, 161), P(114, 161), P(100, 178))
            linie(g, bund, top.kontur, 8)
            linie(g, bund, top.mal(0.85).farbe, 5)
            g.fill(herzPfad(P(100, 208), 9), with: .color(top.mix(Pal.weiss, 0.45).farbe))
        case 4:
            let schleife = Path { p in
                p.move(to: P(100, 178))
                p.addLine(to: P(91, 173))
                p.addLine(to: P(91, 183))
                p.closeSubpath()
            }
            teil(g, schleife, top.mal(0.8), 2)
            teil(g, gespiegelt(schleife), top.mal(0.8), 2)
        case 5:
            h.fill(box(88, 150, 24, 100), with: .color(Pal.weiss.farbe))
            linie(h, strich(P(88, 166), P(88, 240)), top.kontur, 3)
            linie(h, strich(P(112, 166), P(112, 240)), top.kontur, 3)
            let revers = Path { p in
                p.move(to: P(86, 161))
                p.addLine(to: P(96, 200))
                p.addLine(to: P(76, 180))
                p.closeSubpath()
            }
            teil(g, revers, top.mal(0.9), 2.5)
            teil(g, gespiegelt(revers), top.mal(0.9), 2.5)
        case 7:
            for y in stride(from: CGFloat(178), to: 240, by: 14) {
                h.fill(box(20, y, 160, 6), with: .color(.white.opacity(0.75)))
            }
            linie(g, form, top.kontur, 3.5)
        default:
            break
        }
    }

    func kopf(_ g: GraphicsContext) {
        for x in [CGFloat(42), 158] {
            teil(g, kreis(P(x, 100), 11), haut)
            g.fill(kreis(P(x, 100), 5), with: .color(haut.mal(0.85).farbe))
        }
        teil(g, kopfPfad, haut)
    }

    func arm(_ g: GraphicsContext, _ schulter: CGPoint, _ a: Arm) {
        let oben = strich(schulter, a.ellbogen)
        let unten = strich(a.ellbogen, a.hand)
        let obenFarbe = aermel == .keine ? haut : top
        let untenFarbe = aermel == .lang ? top : haut
        linie(g, oben, obenFarbe.kontur, 25)
        linie(g, unten, untenFarbe.kontur, 21)
        linie(g, unten, untenFarbe.farbe, 15.5)
        linie(g, oben, obenFarbe.farbe, 19)
    }

    // MARK: Face

    var augenForm: Auge {
        switch z {
        case .schlaeft, .morgen: .zu
        case .lacht, .kuss, .gut, .naehe: .froh
        case .akkuLeer, .abend, .ruhe: .muede
        case .schautBild, .schautVideo, .anstupsen: .offen(gross: true)
        default: .offen(gross: false)
        }
    }

    var mundForm: Mund {
        switch z {
        case .gut, .lacht, .pokal, .anstossen, .imChat: .grinsen
        case .schautBild, .schautVideo, .rennt: .offen(6)
        case .morgen: .offen(9)
        case .sprache: .offen(4 + 3 * abs(w(11)))
        case .schlaeft: .offen(3)
        case .mittel, .offline, .nichtStoeren: .neutral
        case .schlecht, .akkuLeer: .traurig
        case .kuss: .kuss
        default: .laecheln
        }
    }

    var blick: CGPoint {
        switch z {
        case .liest: P(w(1.6), 0.7)
        case .tippt, .arbeit, .schule, .zeichnet, .laedt: P(0, 0.7)
        case .kamera, .spielt: P(0.6, -0.7)
        case .anstupsen: P(0.8, 0)
        default: P(0, 0)
        }
    }

    func gesicht(_ g: GraphicsContext) {
        let staerke = (z == .kuss || z == .herz || z == .naehe) ? 0.5 : 0.28
        let wange = Pal.rose.farbe.opacity(staerke)
        g.fill(oval(P(68, 120), 10, 6), with: .color(wange))
        g.fill(oval(P(132, 120), 10, 6), with: .color(wange))
        bartZeichnen(g)
        brauen(g)
        augen(g)
        linie(g, bogen(P(96, 115), P(104, 115), P(100, 119)), haut.kontur, 2.5)
        mund(g)
    }

    func brauen(_ g: GraphicsContext) {
        let farbe = haar.mal(0.8).farbe
        let hoch: CGFloat = (z == .schautBild || z == .schautVideo || z == .anstupsen) ? -5 : 0
        let innenY: CGFloat = (z == .schlecht || z == .akkuLeer) ? 74 : 80
        for seite in [CGFloat(-1), 1] {
            let aussen = P(100 + seite * 30, 81 + hoch)
            let innen = P(100 + seite * 10, innenY + hoch)
            let ctrl = P(100 + seite * 20, 75 + hoch)
            linie(g, bogen(aussen, innen, ctrl), farbe, 4.5)
        }
    }

    func augen(_ g: GraphicsContext) {
        let form = augenForm
        var offen = true
        if case .zu = form { offen = false }
        if case .froh = form { offen = false }
        if offen && abz.contains("herzaugen") {
            let s: CGFloat = 10 + 1.5 * w(8)
            for x in [CGFloat(80), 120] { teil(g, herzPfad(P(x, 98), s), Pal.rose, 2.5) }
            return
        }
        let blinzelt = !statisch && zyklus(4.2, 1.3) < 0.035
        for x in [CGFloat(80), 120] {
            let c = P(x, 98)
            if blinzelt && offen {
                geschlossen(g, c, froh: false)
                continue
            }
            switch form {
            case .zu: geschlossen(g, c, froh: false)
            case .froh: geschlossen(g, c, froh: true)
            case .offen(let gross): offenesAuge(g, c, gross: gross, lid: false)
            case .muede: offenesAuge(g, c, gross: false, lid: true)
            }
        }
    }

    func geschlossen(_ g: GraphicsContext, _ c: CGPoint, froh: Bool) {
        let dy: CGFloat = froh ? -8 : 6
        linie(g, bogen(P(c.x - 9, c.y + 1), P(c.x + 9, c.y + 1), P(c.x, c.y + 1 + dy)), Pal.tinte.farbe, 3.2)
    }

    func offenesAuge(_ g: GraphicsContext, _ c: CGPoint, gross: Bool, lid: Bool) {
        let rx: CGFloat = gross ? 11 : 9.5
        let ry: CGFloat = gross ? 14 : 12
        let weiss = oval(c, rx, ry)
        g.fill(weiss, with: .color(.white))
        var h = g
        h.clip(to: weiss)
        let b = blick
        let ic = P(c.x + b.x * 3, c.y + 2 + b.y * 3)
        h.fill(kreis(ic, 7.5), with: .color(iris.farbe))
        h.fill(kreis(ic, 3.8), with: .color(Pal.tinte.farbe))
        h.fill(kreis(P(ic.x - 2.5, ic.y - 3), 2.3), with: .color(.white))
        if lid { h.fill(box(c.x - rx, c.y - ry, rx * 2, ry * 1.05), with: .color(haut.farbe)) }
        linie(g, weiss, Pal.tinte.farbe.opacity(0.5), 1.6)
        let lidY: CGFloat = lid ? c.y + 1 : c.y - 2 * ry + 1
        let kante: CGFloat = lid ? c.y : c.y - 1
        linie(g, bogen(P(c.x - rx, kante), P(c.x + rx, kante), P(c.x, lidY)), Pal.tinte.farbe, 3.2)
    }

    func mund(_ g: GraphicsContext) {
        let tinte = Pal.tinte.farbe
        switch mundForm {
        case .laecheln:
            linie(g, bogen(P(90, 128), P(110, 128), P(100, 137)), tinte, 3)
        case .grinsen:
            let m = Path { p in
                p.move(to: P(86, 126))
                p.addLine(to: P(114, 126))
                p.addQuadCurve(to: P(86, 126), control: P(100, 150))
                p.closeSubpath()
            }
            g.fill(m, with: .color(Pal.mundInnen.farbe))
            var h = g
            h.clip(to: m)
            h.fill(oval(P(100, 142), 9, 6), with: .color(Pal.zunge.farbe))
            h.fill(box(86, 124, 28, 5), with: .color(.white))
            linie(g, m, tinte, 2.5)
        case .offen(let r):
            let o = oval(P(100, 132), r * 0.8, r)
            g.fill(o, with: .color(Pal.mundInnen.farbe))
            linie(g, o, tinte, 2.5)
        case .neutral:
            linie(g, strich(P(92, 131), P(108, 131)), tinte, 3)
        case .traurig:
            linie(g, bogen(P(91, 134), P(109, 134), P(100, 125)), tinte, 3)
        case .kuss:
            teil(g, oval(P(101, 131), 6, 5), Pal.rose, 2.5)
            linie(g, strich(P(96, 131), P(106, 131)), Pal.rose.kontur, 1.5)
        }
    }

    func kinnband(innen: CGFloat) -> Path {
        Path { p in
            p.move(to: P(42, 96))
            p.addCurve(to: P(100, 152), control1: P(42, 128), control2: P(66, 152))
            p.addCurve(to: P(158, 96), control1: P(134, 152), control2: P(158, 128))
            p.addLine(to: P(148, 100))
            p.addCurve(to: P(100, innen + 12), control1: P(146, innen), control2: P(124, innen + 12))
            p.addCurve(to: P(52, 100), control1: P(76, innen + 12), control2: P(54, innen))
            p.closeSubpath()
        }
    }

    func bartZeichnen(_ g: GraphicsContext) {
        guard bart > 0 else { return }
        var h = g
        h.clip(to: kopfPfad)
        let schnurr = Path { p in
            p.move(to: P(100, 122))
            p.addQuadCurve(to: P(82, 130), control: P(88, 118))
            p.addQuadCurve(to: P(100, 126), control: P(90, 128))
            p.addQuadCurve(to: P(118, 130), control: P(110, 128))
            p.addQuadCurve(to: P(100, 122), control: P(112, 118))
            p.closeSubpath()
        }
        switch bart {
        case 1:
            h.fill(kinnband(innen: 130), with: .color(haar.farbe.opacity(0.22)))
            h.fill(schnurr, with: .color(haar.farbe.opacity(0.22)))
        case 2:
            teil(h, schnurr, haar, 2)
        case 3:
            teil(h, oval(P(100, 144), 11, 8), haar, 2)
            teil(h, schnurr, haar, 2)
        default:
            teil(h, kinnband(innen: 118), haar, 2.5)
            teil(h, schnurr, haar, 2)
        }
    }

    // MARK: Hair

    func kappe(top: CGFloat, scheitel: CGFloat, ansatz: CGFloat, unten: CGFloat) -> Path {
        Path { p in
            p.move(to: P(40, unten))
            p.addCurve(to: P(100, top), control1: P(34, 50), control2: P(60, top))
            p.addCurve(to: P(160, unten), control1: P(140, top), control2: P(166, 50))
            p.addLine(to: P(152, unten - 2))
            p.addCurve(to: P(scheitel, ansatz), control1: P(152, 76), control2: P(scheitel + 30, ansatz))
            p.addCurve(to: P(48, unten - 2), control1: P(scheitel - 30, ansatz), control2: P(48, 76))
            p.closeSubpath()
        }
    }

    func haareHinten(_ g: GraphicsContext) {
        switch frisur {
        case 6:
            teil(g, box(32, 30, 136, 124, 50), haar)
        case 7, 8:
            let lang = Path { p in
                p.move(to: P(100, 22))
                p.addCurve(to: P(34, 92), control1: P(56, 22), control2: P(34, 50))
                p.addLine(to: P(30, 214))
                p.addQuadCurve(to: P(60, 222), control: P(40, 224))
                p.addLine(to: P(140, 222))
                p.addQuadCurve(to: P(170, 214), control: P(160, 224))
                p.addLine(to: P(166, 92))
                p.addCurve(to: P(100, 22), control1: P(166, 50), control2: P(144, 22))
                p.closeSubpath()
            }
            teil(g, lang, haar)
        case 9:
            let zopf = Path { p in
                p.move(to: P(132, 40))
                p.addCurve(to: P(178, 168), control1: P(190, 50), control2: P(194, 130))
                p.addCurve(to: P(150, 100), control1: P(162, 176), control2: P(150, 136))
                p.closeSubpath()
            }
            teil(g, zopf, haar)
        case 10:
            teil(g, kreis(P(100, 24), 18), haar)
        default:
            break
        }
    }

    func haareVorn(_ g: GraphicsContext) {
        switch frisur {
        case 0:
            teil(g, kappe(top: 18, scheitel: 100, ansatz: 58, unten: 92), haar)
            let bueschel = Path { p in
                p.move(to: P(76, 40))
                p.addQuadCurve(to: P(90, 12), control: P(76, 20))
                p.addQuadCurve(to: P(100, 30), control: P(96, 18))
                p.addQuadCurve(to: P(116, 12), control: P(108, 20))
                p.addQuadCurve(to: P(126, 40), control: P(128, 22))
            }
            g.fill(bueschel, with: .color(haar.farbe))
            linie(g, bueschel, haar.kontur, 3)
        case 1:
            teil(g, kappe(top: 24, scheitel: 100, ansatz: 54, unten: 88), haar.mix(haut, 0.35), 2.5)
        case 2:
            teil(g, kappe(top: 18, scheitel: 72, ansatz: 56, unten: 92), haar)
            let welle = Path { p in
                p.move(to: P(70, 46))
                p.addCurve(to: P(152, 86), control1: P(112, 30), control2: P(150, 52))
                p.addCurve(to: P(104, 62), control1: P(140, 70), control2: P(122, 60))
                p.addCurve(to: P(70, 46), control1: P(88, 64), control2: P(74, 56))
                p.closeSubpath()
            }
            teil(g, welle, haar, 3)
        case 3:
            g.fill(kappe(top: 22, scheitel: 100, ansatz: 62, unten: 96), with: .color(haar.farbe))
            var locken: [CGPoint] = []
            for grad in stride(from: 190.0, through: 350.0, by: 20.0) {
                let r = grad * Double.pi / 180
                locken.append(P(100 + 60 * CGFloat(cos(r)), 84 + 60 * CGFloat(sin(r))))
            }
            locken += [P(66, 60), P(84, 54), P(100, 52), P(116, 54), P(134, 60)]
            for c in locken { g.fill(kreis(c, 13.8), with: .color(haar.kontur)) }
            for c in locken { g.fill(kreis(c, 11.8), with: .color(haar.farbe)) }
        case 4:
            teil(g, kappe(top: 22, scheitel: 100, ansatz: 58, unten: 92), haar)
            let tolle = Path { p in
                p.move(to: P(64, 50))
                p.addCurve(to: P(118, 6), control1: P(60, 20), control2: P(88, 4))
                p.addCurve(to: P(142, 40), control1: P(140, 8), control2: P(150, 26))
                p.addCurve(to: P(100, 50), control1: P(130, 50), control2: P(112, 46))
                p.addCurve(to: P(64, 50), control1: P(86, 56), control2: P(72, 56))
                p.closeSubpath()
            }
            teil(g, tolle, haar, 3)
        case 5:
            linie(g, bogen(P(62, 56), P(84, 38), P(66, 42)), .white.opacity(0.35), 5)
            return
        case 6:
            teil(g, kappe(top: 16, scheitel: 100, ansatz: 70, unten: 106), haar)
        case 7, 8:
            teil(g, kappe(top: 16, scheitel: frisur == 7 ? 100 : 80, ansatz: 50, unten: 106), haar)
            let straehne = frisur == 7 ? straehneGlatt : straehneWellig
            teil(g, straehne, haar)
            teil(g, gespiegelt(straehne), haar)
        case 9, 10:
            teil(g, kappe(top: 20, scheitel: 100, ansatz: 54, unten: 96), haar)
        default:
            teil(g, kappe(top: 18, scheitel: 100, ansatz: 52, unten: 100), haar)
            for seite in [CGFloat(-1), 1] {
                var glieder: [CGPoint] = []
                for i in 0..<6 { glieder.append(P(100 + seite * (54 + CGFloat(i) * 1.5), 112 + CGFloat(i) * 16)) }
                for c in glieder { g.fill(oval(c, 11, 12), with: .color(haar.kontur)) }
                for c in glieder { g.fill(oval(c, 9, 10), with: .color(haar.farbe)) }
                let ende = P(100 + seite * 63, 206)
                teil(g, kreis(ende, 5), Pal.rose, 2)
            }
        }
        if frisur != 1 {
            linie(g, bogen(P(58, 62), P(86, 30), P(62, 36)), .white.opacity(0.45), 5)
        }
    }

    var straehneGlatt: Path {
        Path { p in
            p.move(to: P(42, 92))
            p.addCurve(to: P(32, 206), control1: P(34, 130), control2: P(30, 180))
            p.addQuadCurve(to: P(58, 212), control: P(42, 216))
            p.addCurve(to: P(54, 104), control1: P(60, 170), control2: P(58, 130))
            p.closeSubpath()
        }
    }

    var straehneWellig: Path {
        Path { p in
            p.move(to: P(42, 92))
            p.addCurve(to: P(34, 150), control1: P(28, 112), control2: P(44, 130))
            p.addCurve(to: P(34, 206), control1: P(24, 170), control2: P(40, 190))
            p.addQuadCurve(to: P(60, 212), control: P(46, 218))
            p.addCurve(to: P(56, 150), control1: P(66, 190), control2: P(50, 170))
            p.addCurve(to: P(54, 104), control1: P(64, 130), control2: P(52, 118))
            p.closeSubpath()
        }
    }

    // MARK: Headwear and glasses

    func kopfschmuck(_ g: GraphicsContext) {
        if z == .nichtStoeren {
            let buegel = Path { p in
                p.move(to: P(40, 100))
                p.addCurve(to: P(160, 100), control1: P(36, 0), control2: P(164, 0))
            }
            linie(g, buegel, Pal.dunkel.kontur, 11)
            linie(g, buegel, Pal.dunkel.farbe, 7)
            teil(g, box(28, 82, 22, 38, 10), Pal.rose)
            teil(g, box(150, 82, 22, 38, 10), Pal.rose)
        }
        if z == .rad {
            let helm = Path { p in
                p.move(to: P(36, 84))
                p.addCurve(to: P(164, 84), control1: P(36, 0), control2: P(164, 0))
                p.closeSubpath()
            }
            teil(g, helm, Pal.mint)
            for x in [CGFloat(78), 100, 122] { g.fill(box(x - 4, 28, 8, 20, 4), with: .color(.white.opacity(0.5))) }
            linie(g, strich(P(46, 84), P(66, 136)), Pal.dunkel.farbe, 2.5)
            linie(g, strich(P(154, 84), P(134, 136)), Pal.dunkel.farbe, 2.5)
        }
        if abz.contains("partyhut") {
            let hut = Path { p in
                p.move(to: P(74, 34))
                p.addLine(to: P(92, 6))
                p.addLine(to: P(118, 26))
                p.closeSubpath()
            }
            teil(g, hut, Pal.blau)
            var h = g
            h.clip(to: hut)
            for i in 0..<3 {
                let x = 66 + CGFloat(i) * 14
                linie(h, strich(P(x, 40), P(x + 26, 4)), Pal.gelb.farbe, 4)
            }
            teil(g, kreis(P(92, 6), 6), Pal.rose, 2.5)
        }
        if abz.contains("krone") { krone(g, P(100, 18), Pal.gold) }
        if abz.contains("schnecke") {
            krone(g, P(90, 20), Pal.silber)
            teil(g, box(118, 28, 30, 7, 3.5), Pal.schneckeKoerper, 2)
            linie(g, strich(P(144, 29), P(148, 19)), Pal.schneckeKoerper.kontur, 2)
            teil(g, kreis(P(130, 24), 9), Pal.schnecke, 2.5)
            linie(g, bogen(P(130, 24), P(134, 20), P(136, 26)), Pal.schnecke.kontur, 2)
        }
    }

    func krone(_ g: GraphicsContext, _ c: CGPoint, _ f: FigurFarbe) {
        var h = g
        h.translateBy(x: c.x, y: c.y)
        h.rotate(by: .degrees(-8))
        let k = Path { p in
            p.move(to: P(-20, 10))
            p.addLine(to: P(-20, -8))
            p.addLine(to: P(-10, 0))
            p.addLine(to: P(0, -14))
            p.addLine(to: P(10, 0))
            p.addLine(to: P(20, -8))
            p.addLine(to: P(20, 10))
            p.closeSubpath()
        }
        teil(h, k, f, 2.5)
        h.fill(kreis(P(0, 4), 3), with: .color(Pal.rose.farbe))
    }

    func brillen(_ g: GraphicsContext) {
        guard brille > 0 else { return }
        let rahmen = Pal.tinte.farbe
        let links = brille == 1 ? kreis(P(80, 98), 14) : box(64, 86, 32, 25, 7)
        let rechts = brille == 1 ? kreis(P(120, 98), 14) : box(104, 86, 32, 25, 7)
        let glas: Color = brille == 3 ? rahmen.opacity(0.9) : .white.opacity(0.15)
        g.fill(links, with: .color(glas))
        g.fill(rechts, with: .color(glas))
        if brille == 3 {
            linie(g, strich(P(70, 92), P(78, 90)), .white.opacity(0.6), 2.5)
            linie(g, strich(P(110, 92), P(118, 90)), .white.opacity(0.6), 2.5)
        }
        linie(g, links, rahmen, 3)
        linie(g, rechts, rahmen, 3)
        linie(g, bogen(P(94, 96), P(106, 96), P(100, 91)), rahmen, 3)
        linie(g, strich(P(66, 95), P(44, 92)), rahmen, 3)
        linie(g, strich(P(134, 95), P(156, 92)), rahmen, 3)
    }

    // MARK: Poses

    func pose() -> (l: Arm?, r: Arm?) {
        let restL = Arm(P(42, 216), P(46, 252))
        let restR = Arm(P(158, 216), P(154, 252))
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
            let s = w(7)
            return (Arm(P(50, 210 - s * 4), P(58 + s * 4, 238 - s * 12)), Arm(P(150, 210 + s * 4), P(142 - s * 4, 238 + s * 12)))
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
        default:
            break
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
            for seite in [CGFloat(-1), 1] {
                linie(h, strich(P(100 + seite * 64, 78), P(100 + seite * 76, 70)), tinte, 3)
                linie(h, strich(P(100 + seite * 68, 96), P(100 + seite * 82, 96)), tinte, 3)
            }
            teil(g, tropfenPfad(P(64, 110)), Pal.himmel, 1.5)
            teil(g, tropfenPfad(P(136, 110)), Pal.himmel, 1.5)
        case .anstossen:
            if an(2.0, 0.25) { g.fill(funkel(P(160, 84), 10), with: .color(Pal.gelb.farbe)) }
        case .pokal:
            for (i, c) in [P(52, 146), P(108, 144), P(184, 84)].enumerated() {
                g.fill(funkel(c, 5 + 3 * abs(w(4, Double(i)))), with: .color(Pal.gelb.farbe))
            }
        case .ruhig:
            let p = zyklus(5)
            if p < 0.5 {
                var h = g
                h.opacity = Double(1 - p * 2)
                h.fill(herzPfad(P(152, 70 - p * 60), 6), with: .color(Pal.rose.farbe))
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

// MARK: - Previews

private func variante(_ a: FigurAussehen, _ k: WritableKeyPath<FigurAussehen, Int>, _ n: Int) -> FigurAussehen {
    var b = a
    b[keyPath: k] = n
    return b
}

private struct AlleOptionenVorschau: View {
    var body: some View {
        let basis = FigurAussehen.standard(for: .annika)
        let reihen: [(String, WritableKeyPath<FigurAussehen, Int>, Int)] = [
            ("Haut", \.haut, FigurAussehen.hautToene.count),
            ("Frisur", \.frisur, FigurAussehen.frisuren.count),
            ("Haarfarbe", \.haarfarbe, FigurAussehen.haarfarben.count),
            ("Augen", \.augen, FigurAussehen.augenfarben.count),
            ("Brille", \.brille, FigurAussehen.brillen.count),
            ("Bart", \.bart, FigurAussehen.baerte.count),
            ("Oberteil", \.oberteil, FigurAussehen.oberteile.count),
            ("Oberteil-Farbe", \.oberteilfarbe, FigurAussehen.oberteilfarben.count),
        ]
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(reihen.indices, id: \.self) { i in
                    Text(reihen[i].0).font(.headline)
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(0..<reihen[i].2, id: \.self) { n in
                                FigurView(variante(basis, reihen[i].1, n), zustand: .ruhig, groesse: 96, animiert: false)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

#Preview("Aussehen-Optionen") {
    AlleOptionenVorschau()
}

#Preview("Alle Zustände") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 16) {
            ForEach(FigurZustand.allCases, id: \.self) { z in
                VStack {
                    FigurView(.standard(for: .ahmed), zustand: z, groesse: 132)
                    Text(z.titel).font(.caption)
                }
            }
        }
        .padding()
    }
}

#Preview("Abzeichen") {
    HStack {
        FigurView(.standard(for: .annika), zustand: .gut, abzeichen: ["partyhut", "herzaugen"], groesse: 220)
        FigurView(.standard(for: .ahmed), zustand: .ruhig, abzeichen: ["outfit", "uhrwerk", "krone"], groesse: 220)
    }
}
