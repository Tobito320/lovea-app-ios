import SwiftUI

/// Bitmoji-style figure. `groesse` is the height. Half figure (chat, stickers): width is 5/6 of the height.
/// `ganzkoerper` (map, profile): head, body, legs and shoes with standing/walking/sitting poses; width is 1/2 of the height.
/// Abzeichen: "partyhut", "herzaugen", "outfit", "uhrwerk", "schnecke", "krone".
struct FigurView: View {
    private let aussehen: FigurAussehen
    private let zustand: FigurZustand
    private let abzeichen: [String]
    private let groesse: CGFloat
    private let animiert: Bool
    private let bildrate: Double
    private let ganzkoerper: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var sichtbar = false

    /// `bildrate`: frames per second of the loop; lower it where many figures or a map redraw.
    init(_ aussehen: FigurAussehen, zustand: FigurZustand, abzeichen: [String] = [], groesse: CGFloat, animiert: Bool = true, bildrate: Double = 30, ganzkoerper: Bool = false) {
        self.aussehen = aussehen
        self.zustand = zustand
        self.abzeichen = abzeichen
        self.groesse = groesse
        self.animiert = animiert
        self.bildrate = bildrate
        self.ganzkoerper = ganzkoerper
    }

    var body: some View {
        Group {
            if animiert && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / bildrate, paused: !sichtbar || scenePhase != .active)) { kontext in
                    leinwand(kontext.date.timeIntervalSinceReferenceDate, statisch: false)
                }
            } else {
                leinwand(0.4, statisch: true)
            }
        }
        .frame(width: ganzkoerper ? groesse / 2 : groesse * 5 / 6, height: groesse)
        .saturation(zustand == .offline ? 0.15 : 1)
        .opacity(zustand == .offline ? 0.7 : 1)
        .onAppear { sichtbar = true }
        .onDisappear { sichtbar = false }
        // Non-lazy scroll views (Home, Profil) never call onDisappear while scrolling.
        .onScrollVisibilityChange(threshold: 0.05) { sichtbar = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Figur")
        .accessibilityValue(zustand.titel)
    }

    private func leinwand(_ t: Double, statisch: Bool) -> some View {
        let zeichner = Zeichner(aussehen, zustand, abzeichen, t: t, statisch: statisch, ganz: ganzkoerper)
        return Canvas { g, size in zeichner.zeichne(g, size) }
    }
}

// MARK: - Helpers

/// ponytail: these primitives were fileprivate (single-file drawing engine); widened to internal
/// so the new Shop-Zubehör drawers (Zubehoer/) can reuse them instead of duplicating geometry helpers.
func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

func kreis(_ c: CGPoint, _ r: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
}

func oval(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
}

func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat = 0) -> Path {
    Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
}

func strich(_ a: CGPoint, _ b: CGPoint) -> Path {
    Path { p in
        p.move(to: a)
        p.addLine(to: b)
    }
}

func bogen(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Path {
    Path { p in
        p.move(to: a)
        p.addQuadCurve(to: b, control: c)
    }
}

func gespiegelt(_ p: Path) -> Path {
    p.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 200, ty: 0))
}

func herzPfad(_ c: CGPoint, _ s: CGFloat) -> Path {
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
func teil(_ g: GraphicsContext, _ p: Path, _ f: FigurFarbe, _ breite: CGFloat = 3.5) {
    g.fill(p, with: .color(f.farbe))
    g.stroke(p, with: .color(f.kontur), style: StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round))
}

func linie(_ g: GraphicsContext, _ p: Path, _ c: Color, _ breite: CGFloat) {
    g.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round))
}

fileprivate func text(_ g: GraphicsContext, _ s: String, _ c: CGPoint, _ groesse: CGFloat, _ farbe: Color) {
    g.draw(Text(s).font(.system(size: groesse, weight: .heavy, design: .rounded)).foregroundStyle(farbe), at: c)
}

fileprivate extension Array {
    func wahl(_ i: Int) -> Element { self[Swift.min(Swift.max(i, 0), count - 1)] }
}

fileprivate func grenze(_ i: Int, _ n: Int) -> Int { min(max(i, 0), n - 1) }

fileprivate func zwischen(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    P(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
}

/// Fills several overlapping parts as one piece: all outlines first, then all fills.
func verbunden(_ g: GraphicsContext, _ teile: [Path], _ f: FigurFarbe, _ breite: CGFloat = 3.5) {
    for p in teile { g.stroke(p, with: .color(f.kontur), style: StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round)) }
    for p in teile { g.fill(p, with: .color(f.farbe)) }
}

enum Pal {
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

fileprivate struct Bein {
    let h: CGPoint
    let k: CGPoint
    let f: CGPoint
}

fileprivate enum Mund { case laecheln, grinsen, offen(CGFloat), neutral, traurig, kuss }
fileprivate enum Auge { case offen(gross: Bool), zu, froh, muede }
fileprivate enum Aermel { case lang, kurz, keine }
fileprivate enum Haltung { case stehen, gehen, rennen, rad, fahren, sitzen }

/// Full-body proportions in the 200 x 400 space. Feet stand at `fussY`, taller figures have longer legs.
fileprivate struct Masse {
    let s: CGFloat          // shoulder half width
    let t: CGFloat          // waist half width
    let h: CGFloat          // hip half width
    let arm: CGFloat        // arm thickness relative to the half figure
    let bein: CGFloat       // leg thickness
    let hueftY: CGFloat
    let schulterY: CGFloat
    let knieY: CGFloat
    static let fussY: CGFloat = 372
}

// MARK: - Drawing (half figure 200 x 240, full body 200 x 400 with the head drawn in the half space)

private struct Zeichner {
    let z: FigurZustand
    let abz: Set<String>
    let t: Double
    let statisch: Bool
    let ganz: Bool
    let haut, haar, iris, top, jackeF, hoseF, schuhF, muetzeF: FigurFarbe
    let straehne: FigurFarbe?
    let frisur, oberteil, brille, bart, gesichtsform, augenform, brauenStil, nasenStil, mundStil: Int
    let ohrring, muetze, jacke, hose, schuhe, koerperform, groesseStufe: Int
    let wimpern, sommersprossen, muttermal, rouge: Bool
    // v3 (Z-24.2): worn shop parts, forwarded to the Zubehoer/ drawers as-is (nil = nothing).
    let tascheId, uhrId, schmuckId, poseId, tierId: String?
    /// `hosenFarbe` below hardcodes a denim wash for hose 0/1/2 unless a free color was picked.
    let hosenHexAktiv: Bool

    init(_ a: FigurAussehen, _ z: FigurZustand, _ abz: [String], t: Double, statisch: Bool, ganz: Bool) {
        typealias A = FigurAussehen
        self.z = z
        self.abz = Set(abz)
        self.t = t
        self.statisch = statisch
        self.ganz = ganz
        haut = A.hautToene.wahl(a.haut).farbe
        let hf = A.haarfarben.wahl(a.haarfarbe)
        if let hex = a.haarfarbeHex, let frei = FigurFarbe(hex: hex) {
            haar = frei
            straehne = nil // free color replaces the swatch, including its highlight streak
        } else {
            haar = hf.farbe
            straehne = hf.straehne
        }
        iris = A.augenfarben.wahl(a.augen).farbe
        tascheId = a.tasche
        uhrId = a.uhr
        schmuckId = a.schmuck
        poseId = a.pose
        tierId = a.tier
        frisur = grenze(a.frisur, A.frisuren.count)
        brille = grenze(a.brille, A.brillen.count)
        bart = grenze(a.bart, A.baerte.count)
        gesichtsform = grenze(a.gesichtsform, A.gesichtsformen.count)
        augenform = grenze(a.augenform, A.augenformen.count)
        brauenStil = grenze(a.brauen, A.augenbrauen.count)
        nasenStil = grenze(a.nase, A.nasen.count)
        mundStil = grenze(a.mund, A.muender.count)
        ohrring = grenze(a.ohrringe, A.ohrringArten.count)
        wimpern = a.wimpern
        sommersprossen = a.sommersprossen
        muttermal = a.muttermal
        rouge = a.rouge
        koerperform = grenze(a.koerperform, A.koerperformen.count)
        groesseStufe = grenze(a.groesse, A.groessen.count)
        schuhe = grenze(a.schuhe, A.schuhArten.count)
        schuhF = a.schuhfarbeHex.flatMap { FigurFarbe(hex: $0) } ?? A.farben.wahl(a.schuhfarbe).farbe
        muetzeF = A.farben.wahl(a.muetzenfarbe).farbe
        jackeF = a.jackenfarbeHex.flatMap { FigurFarbe(hex: $0) } ?? A.farben.wahl(a.jackenfarbe).farbe
        let schlafanzug = z == .abend
        let oberteilFarbe = schlafanzug ? FigurFarbe(0xAFC8EE) : (a.oberteilfarbeHex.flatMap { FigurFarbe(hex: $0) } ?? A.farben.wahl(a.oberteilfarbe).farbe)
        top = oberteilFarbe
        oberteil = schlafanzug ? 2 : grenze(a.oberteil, A.oberteile.count)
        jacke = schlafanzug ? 0 : grenze(a.jacke, A.jacken.count)
        hose = schlafanzug ? 3 : grenze(a.hose, A.hosen.count)
        hoseF = schlafanzug ? oberteilFarbe : (a.hosenfarbeHex.flatMap { FigurFarbe(hex: $0) } ?? A.farben.wahl(a.hosenfarbe).farbe)
        hosenHexAktiv = !schlafanzug && a.hosenfarbeHex.flatMap { FigurFarbe(hex: $0) } != nil
        let ohneHut = schlafanzug || z == .rad || z == .schlaeft
        muetze = ohneHut ? 0 : grenze(a.kopfbedeckung, A.kopfbedeckungen.count)
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
        if ganz {
            zeichneGanz(ctx, size)
            return
        }
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
        haareHinten(haarKontext(g))
        koerper(g)
        kopfGruppe(g)
        mitte(g)
        let arme = pose()
        let schulter: CGFloat = 40 * breite
        if let l = arme.l { arm(g, P(100 - schulter, 184), l) }
        if let r = arme.r { arm(g, P(100 + schulter, 184), r) }
        requisite(g, arme.r?.hand ?? P(142, 252))
        if let l = arme.l { teil(g, kreis(l.hand, 9.5), haut) }
        if let r = arme.r { teil(g, kreis(r.hand, 9.5), haut) }
        zubehoer(g, arme)
        effekte(g)
        abzeichenVorn(g)
    }

    /// Z-24.2: worn shop parts (bag on the free hand, watch on the other wrist, necklace at the collar).
    func zubehoer(_ g: GraphicsContext, _ arme: (l: Arm?, r: Arm?)) {
        if let id = tascheId { zeichneTasche(g, id: id, an: arme.r?.hand ?? P(142, 252)) }
        if let id = uhrId {
            // Wrist, not the hand itself — a hand-centered watch would just replace the hand circle.
            let handgelenk = arme.l.map { zwischen($0.ellbogen, $0.hand, 0.72) } ?? P(54, 235)
            zeichneUhr(g, id: id, an: handgelenk)
        }
        if let id = schmuckId { zeichneSchmuck(g, id: id, hals: P(100, 162)) }
    }

    /// Head, face, hair and everything worn on the head, in the half-figure space.
    func kopfGruppe(_ g: GraphicsContext) {
        kopf(g)
        gesicht(g)
        haareVorn(haarKontext(g))
        ohrringeZeichnen(g)
        muetzeZeichnen(g)
        kopfschmuck(g)
        brillen(g)
    }

    /// Under a covering hat the hair stops at the hat line, so tall styles never poke through.
    func haarKontext(_ g: GraphicsContext) -> GraphicsContext {
        guard (1...4).contains(muetze) else { return g }
        var h = g
        h.clip(to: Path(CGRect(x: -100, y: 34, width: 400, height: 400)))
        return h
    }

    var breite: CGFloat {
        let werte: [CGFloat] = [0.93, 1, 1.07]
        return werte[koerperform]
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
        if jacke > 0 { return .lang }
        switch oberteil {
        case 1, 2, 3, 5, 10, 13, 14, 16: return .lang
        case 6: return .keine
        default: return .kurz
        }
    }

    var aermelFarbe: FigurFarbe { jacke > 0 ? jackeF : top }

    /// Face shapes keep the cheekbone width, so hair, ears, glasses and hats fit every shape.
    static let formen: [(stirn: CGFloat, kieferX: CGFloat, kieferY: CGFloat, kinnB: CGFloat, kinnY: CGFloat)] = [
        (44, 58, 128, 34, 152),  // Oval
        (50, 58, 138, 44, 148),  // Rund
        (54, 50, 124, 18, 154),  // Herz
        (54, 58, 146, 42, 150),  // Eckig
        (40, 56, 134, 30, 158),  // Länglich
        (30, 50, 122, 22, 154),  // Diamant
    ]

    var kopfPfad: Path {
        let f = Self.formen[gesichtsform]
        return Path { p in
            p.move(to: P(100, 30))
            p.addCurve(to: P(158, 94), control1: P(100 + f.stirn, 30), control2: P(158, 56))
            p.addCurve(to: P(100, f.kinnY), control1: P(100 + f.kieferX, f.kieferY), control2: P(100 + f.kinnB, f.kinnY))
            p.addCurve(to: P(42, 94), control1: P(100 - f.kinnB, f.kinnY), control2: P(100 - f.kieferX, f.kieferY))
            p.addCurve(to: P(100, 30), control1: P(42, 56), control2: P(100 - f.stirn, 30))
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

    var ausschnitt: Int {
        switch oberteil {
        case 2, 12, 13: 1
        case 4, 8, 11: 2
        default: 0
        }
    }

    func koerper(_ g: GraphicsContext) {
        teil(g, box(86, 132, 28, 58, 10), haut)
        g.fill(box(78, 156, 44, 36), with: .color(haut.farbe))
        g.fill(oval(P(100, 152), 15, 6), with: .color(haut.mal(0.8).farbe.opacity(0.6)))
        var k = g
        k.translateBy(x: 100, y: 0)
        k.scaleBy(x: breite, y: 1)
        k.translateBy(x: -100, y: 0)

        if oberteil == 6 {
            let form = rumpf(0)
            teil(k, form, haut)
            k.fill(box(80, 150, 40, 28), with: .color(haut.farbe))
            let kleid = Path { p in
                p.move(to: P(20, 250))
                p.addLine(to: P(24, 190))
                p.addQuadCurve(to: P(176, 190), control: P(100, 204))
                p.addLine(to: P(180, 250))
                p.closeSubpath()
            }
            var h = k
            h.clip(to: form)
            teil(h, kleid, top)
            linie(k, form, haut.kontur, 3.5)
            for seite in [CGFloat(-1), 1] {
                let traeger = strich(P(100 + seite * 26, 164), P(100 + seite * 30, 194))
                linie(k, traeger, top.kontur, 6.5)
                linie(k, traeger, top.farbe, 3.5)
            }
        } else {
            let form = rumpf(ausschnitt)
            teil(k, form, top)
            var h = k
            h.clip(to: form)
            if oberteil == 11 {
                teil(h, box(0, 226, 200, 40), haut, 2.5)
                h.fill(oval(P(100, 234), 1.6, 2.4), with: .color(haut.kontur))
            }
            oberteilDetails(k, h)
            if [7, 12, 13].contains(oberteil) { linie(k, form, top.kontur, 3.5) }
        }
        if jacke > 0 { jackeZeichnen(k, form: rumpf(0), oben: 161, unten: 240, s: 1) }
    }

    func hemdKragen(_ g: GraphicsContext) {
        let kragen = top.mix(Pal.weiss, 0.4)
        let links = Path { p in
            p.move(to: P(86, 160))
            p.addLine(to: P(100, 186))
            p.addLine(to: P(78, 178))
            p.closeSubpath()
        }
        teil(g, links, kragen, 2.5)
        teil(g, gespiegelt(links), kragen, 2.5)
        for y in [CGFloat(198), 214, 230, 246, 262] { g.fill(kreis(P(100, y), 2.2), with: .color(top.kontur)) }
    }

    /// Top details in the half-figure space. `g` draws freely, `h` is clipped to the torso.
    /// Patterns run past y 240 so the full body (which maps this space onto its torso) is covered too.
    func oberteilDetails(_ g: GraphicsContext, _ h: GraphicsContext) {
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
                    for y in stride(from: CGFloat(180), to: 290, by: 18) {
                        h.fill(kreis(P(x, y), 3), with: .color(.white.opacity(0.7)))
                    }
                }
            }
            hemdKragen(g)
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
            h.fill(box(88, 150, 24, 160), with: .color(Pal.weiss.farbe))
            linie(h, strich(P(88, 166), P(88, 300)), top.kontur, 3)
            linie(h, strich(P(112, 166), P(112, 300)), top.kontur, 3)
            let revers = Path { p in
                p.move(to: P(86, 161))
                p.addLine(to: P(96, 200))
                p.addLine(to: P(76, 180))
                p.closeSubpath()
            }
            teil(g, revers, top.mal(0.9), 2.5)
            teil(g, gespiegelt(revers), top.mal(0.9), 2.5)
        case 7:
            for y in stride(from: CGFloat(178), to: 300, by: 14) {
                h.fill(box(20, y, 160, 6), with: .color(.white.opacity(0.75)))
            }
        case 8:
            let guertel = strich(P(20, 232), P(180, 232))
            linie(h, guertel, top.kontur, 8)
            linie(h, guertel, top.mal(0.8).farbe, 5)
            teil(g, kreis(P(100, 232), 5), top.mal(0.75), 2)
            g.fill(herzPfad(P(100, 186), 5), with: .color(top.mix(Pal.weiss, 0.5).farbe))
        case 9:
            let kragen = top.mix(Pal.weiss, 0.2)
            let links = Path { p in
                p.move(to: P(86, 160))
                p.addLine(to: P(99, 174))
                p.addLine(to: P(80, 176))
                p.closeSubpath()
            }
            teil(g, links, kragen, 2.5)
            teil(g, gespiegelt(links), kragen, 2.5)
            linie(g, strich(P(100, 170), P(100, 196)), top.kontur, 2)
            for y in [CGFloat(182), 192] { g.fill(kreis(P(100, y), 2), with: .color(top.kontur)) }
        case 10:
            let kragen = box(82, 138, 36, 30, 12)
            teil(g, kragen, top.mal(0.92))
            var r = g
            r.clip(to: kragen)
            for x in stride(from: CGFloat(86), to: 118, by: 6) { linie(r, strich(P(x, 138), P(x, 168)), top.kontur.opacity(0.5), 1.5) }
        case 12:
            h.fill(box(30, 160, 12, 160), with: .color(.white.opacity(0.85)))
            h.fill(box(158, 160, 12, 160), with: .color(.white.opacity(0.85)))
            let v = Path { p in
                p.move(to: P(86, 161))
                p.addLine(to: P(100, 186))
                p.addLine(to: P(114, 161))
            }
            linie(g, v, .white, 3.5)
            text(g, "10", P(100, 216), 26, .white)
        case 13:
            let streifen = top.mal(0.62).farbe.opacity(0.45)
            for x in stride(from: CGFloat(28), to: 180, by: 16) { h.fill(box(x, 150, 6, 170), with: .color(streifen)) }
            for y in stride(from: CGFloat(172), to: 320, by: 16) { h.fill(box(20, y, 160, 6), with: .color(streifen)) }
            hemdKragen(g)
        case 14:
            // Logo-Hoodie: reuses the hoodie hood (case 1) plus a small round chest patch.
            let kapuze = bogen(P(70, 164), P(130, 164), P(100, 196))
            linie(g, kapuze, top.kontur, 13)
            linie(g, kapuze, top.mal(0.88).farbe, 8.5)
            teil(h, kreis(P(100, 210), 9), Pal.gold, 2)
        case 15:
            // Statement-Shirt: bold diagonal brand stripe across the chest.
            var streifenH = h
            streifenH.rotate(by: .degrees(-18))
            streifenH.fill(box(50, 180, 100, 16, 4), with: .color(top.mix(Pal.weiss, 0.7).farbe))
        case 16:
            // Seidenbluse: soft sheen band plus a tie-neck bow.
            for y in stride(from: CGFloat(176), to: 300, by: 20) { h.fill(box(20, y, 160, 4), with: .color(.white.opacity(0.18))) }
            let schleife = Path { p in
                p.move(to: P(100, 178))
                p.addLine(to: P(88, 170))
                p.addLine(to: P(88, 186))
                p.closeSubpath()
            }
            teil(g, schleife, top.mal(0.85), 2)
            teil(g, gespiegelt(schleife), top.mal(0.85), 2)
        default:
            break
        }
    }

    /// Open jacket: two front panels cut from the torso `form`, the top shows in the middle.
    /// `s` scales details (1 in the half figure, smaller on the full-body torso).
    func jackeZeichnen(_ g: GraphicsContext, form: Path, oben: CGFloat, unten: CGFloat, s: CGFloat) {
        let f = jackeF
        let innenO: CGFloat = 100 - 12 * s
        let innenU: CGFloat = 100 - 20 * s
        let links = Path { p in
            p.move(to: P(-20, oben - 60))
            p.addLine(to: P(innenO, oben - 60))
            p.addLine(to: P(innenO, oben))
            p.addLine(to: P(innenU, unten + 30))
            p.addLine(to: P(-20, unten + 30))
            p.closeSubpath()
        }
        let rechts = gespiegelt(links)
        for seite in [links, rechts] {
            var h = g
            h.clip(to: seite)
            teil(h, form, f)
        }
        var innen = g
        innen.clip(to: form)
        linie(innen, links, f.kontur, 3)
        linie(innen, rechts, f.kontur, 3)

        switch jacke {
        case 1, 4:
            let revers = Path { p in
                p.move(to: P(innenO, oben))
                p.addLine(to: P(100 - 34 * s, oben + 8 * s))
                p.addLine(to: P(100 - 17 * s, oben + 46 * s))
                p.closeSubpath()
            }
            let rf = jacke == 4 ? f.mix(Pal.weiss, 0.12) : f.mal(0.8)
            teil(g, revers, rf, 2.5)
            teil(g, gespiegelt(revers), rf, 2.5)
            if jacke == 1 {
                linie(g, strich(P(innenO - 3 * s, oben + 48 * s), P(innenU - 3 * s, unten - 4)), Pal.silber.farbe, 2.2)
                for seite in [CGFloat(-1), 1] {
                    let x: CGFloat = 100 + seite * 44 * s
                    linie(innen, strich(P(x, oben + 30 * s), P(x, unten - 10)), .white.opacity(0.22), 4 * s)
                }
            } else {
                teil(g, kreis(P(innenU + 2 * s, unten - 30 * s), 3.5 * s), f.mal(0.7), 1.5)
            }
        case 2:
            let kragen = Path { p in
                p.move(to: P(innenO, oben))
                p.addLine(to: P(100 - 32 * s, oben - 4 * s))
                p.addLine(to: P(100 - 24 * s, oben + 20 * s))
                p.closeSubpath()
            }
            teil(g, kragen, f.mix(Pal.weiss, 0.12), 2)
            teil(g, gespiegelt(kragen), f.mix(Pal.weiss, 0.12), 2)
            for seite in [CGFloat(-1), 1] {
                let x: CGFloat = 100 + seite * 32 * s - 9 * s
                teil(innen, box(x, oben + 34 * s, 18 * s, 13 * s, 3 * s), f.mal(0.88), 1.8)
            }
        case 3:
            let bund = bogen(P(100 - 26 * s, oben + 1), P(100 + 26 * s, oben + 1), P(100, oben + 24 * s))
            linie(g, bund, f.kontur, 9 * s)
            linie(g, bund, f.mal(0.75).farbe, 6.5 * s)
            teil(innen, box(0, unten - 12 * s, 200, 40), f.mal(0.75), 2)
            linie(g, strich(P(innenO - 2 * s, oben + 20 * s), P(innenU - 2 * s, unten)), Pal.silber.farbe, 2)
        case 5:
            for seite in [links, rechts] {
                var h = innen
                h.clip(to: seite)
                for i in 0..<9 {
                    let y: CGFloat = oben + (18 + CGFloat(i) * 17) * s
                    linie(h, bogen(P(0, y), P(200, y), P(100, y + 6 * s)), f.kontur, 2)
                }
            }
        case 6:
            // Pelzkragen-Jacke: puffer trim (case 5) plus a fluffy dotted collar.
            for seite in [links, rechts] {
                var h = innen
                h.clip(to: seite)
                for i in 0..<9 {
                    let y: CGFloat = oben + (18 + CGFloat(i) * 17) * s
                    linie(h, bogen(P(0, y), P(200, y), P(100, y + 6 * s)), f.kontur, 2)
                }
            }
            for dx in stride(from: CGFloat(-26), through: 26, by: 9) {
                teil(g, kreis(P(100 + dx * s, oben + 2 * s), 4 * s), Pal.weiss, 1)
            }
        case 7:
            // Cape: poncho bund (case 3) with a gem clasp instead of the zip strap.
            let bund = bogen(P(100 - 30 * s, oben + 1), P(100 + 30 * s, oben + 1), P(100, oben + 30 * s))
            linie(g, bund, f.kontur, 9 * s)
            linie(g, bund, f.mal(0.75).farbe, 6.5 * s)
            teil(innen, box(0, unten - 12 * s, 200, 40), f.mal(0.75), 2)
            teil(g, kreis(P(100, oben + 6 * s), 4 * s), Pal.gold, 1.5)
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

    /// `d` scales the thickness (1 for the half figure, thinner on the full body).
    func arm(_ g: GraphicsContext, _ schulter: CGPoint, _ a: Arm, _ d: CGFloat = 1) {
        let oben = strich(schulter, a.ellbogen)
        let unten = strich(a.ellbogen, a.hand)
        let obenFarbe = aermel == .keine ? haut : aermelFarbe
        let untenFarbe = aermel == .lang ? aermelFarbe : haut
        linie(g, oben, obenFarbe.kontur, 25 * d)
        linie(g, unten, untenFarbe.kontur, 21 * d)
        linie(g, unten, untenFarbe.farbe, 15.5 * d)
        linie(g, oben, obenFarbe.farbe, 19 * d)
    }

    // MARK: Face

    var augenAusdruck: Auge {
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
        let staerke = (z == .kuss || z == .herz || z == .naehe || rouge) ? 0.5 : 0.28
        let wange = Pal.rose.farbe.opacity(staerke)
        g.fill(oval(P(68, 120), 10, 6), with: .color(wange))
        g.fill(oval(P(132, 120), 10, 6), with: .color(wange))
        if sommersprossen {
            let punkte: [CGPoint] = [P(62, 114), P(69, 110), P(74, 117), P(66, 121), P(92, 110), P(97, 106)]
            for c in punkte {
                g.fill(kreis(c, 1.4), with: .color(haut.mal(0.72).farbe))
                g.fill(kreis(P(200 - c.x, c.y), 1.4), with: .color(haut.mal(0.72).farbe))
            }
        }
        if muttermal { g.fill(kreis(P(122, 127), 1.9), with: .color(Pal.tinte.farbe.opacity(0.8))) }
        bartZeichnen(g)
        brauen(g)
        augen(g)
        nase(g)
        mund(g)
    }

    func brauen(_ g: GraphicsContext) {
        let farbe = haar.mal(0.8)
        let hoch: CGFloat = (z == .schautBild || z == .schautVideo || z == .anstupsen) ? -5 : 0
        let traurig: CGFloat = (z == .schlecht || z == .akkuLeer) ? -6 : 0
        let dicken: [CGFloat] = [4.5, 2.6, 7, 5, 4.5, 4.5, 4.5, 4]
        for seite in [CGFloat(-1), 1] {
            var aussen = P(100 + seite * 30, 81 + hoch)
            var innen = P(100 + seite * 10, 80 + hoch + traurig)
            var ctrl = P(100 + seite * 20, 75 + hoch)
            switch brauenStil {
            case 3:
                ctrl.y = 79 + hoch
                aussen.y = 80 + hoch
            case 4:
                ctrl.y = 68 + hoch
                aussen.y = 80 + hoch
            case 7:
                aussen = P(100 + seite * 26, 80 + hoch)
                innen.x = 100 + seite * 13
                ctrl.y = 76 + hoch
            default:
                break
            }
            switch brauenStil {
            case 5:
                let busch = Path { p in
                    p.move(to: P(innen.x, innen.y + 3))
                    p.addQuadCurve(to: aussen, control: P(ctrl.x, ctrl.y + 5))
                    p.addQuadCurve(to: P(innen.x, innen.y - 5), control: P(ctrl.x, ctrl.y - 3))
                    p.closeSubpath()
                }
                teil(g, busch, farbe, 2)
            case 6:
                let spitze = P(100 + seite * 23, 74 + hoch)
                let knick = Path { p in
                    p.move(to: innen)
                    p.addLine(to: spitze)
                    p.addLine(to: aussen)
                }
                linie(g, knick, farbe.farbe, 4.5)
            default:
                linie(g, bogen(aussen, innen, ctrl), farbe.farbe.opacity(brauenStil == 7 ? 0.85 : 1), dicken[brauenStil])
            }
        }
    }

    func augen(_ g: GraphicsContext) {
        let form = augenAusdruck
        var offen = true
        if case .zu = form { offen = false }
        if case .froh = form { offen = false }
        if offen && abz.contains("herzaugen") {
            let s: CGFloat = 10 + 1.5 * w(8)
            for x in [CGFloat(80), 120] { teil(g, herzPfad(P(x, 98), s), Pal.rose, 2.5) }
            return
        }
        let blinzelt = !statisch && zyklus(4.2, 1.3) < 0.035
        let seiten: [(x: CGFloat, aussen: CGFloat)] = [(80, -1), (120, 1)]
        for s in seiten {
            let c = P(s.x, 98)
            if blinzelt && offen {
                geschlossen(g, c, s.aussen, froh: false)
                continue
            }
            switch form {
            case .zu: geschlossen(g, c, s.aussen, froh: false)
            case .froh: geschlossen(g, c, s.aussen, froh: true)
            case .offen(let gross): offenesAuge(g, c, s.aussen, gross: gross, lid: false)
            case .muede: offenesAuge(g, c, s.aussen, gross: false, lid: true)
            }
        }
    }

    func geschlossen(_ g: GraphicsContext, _ c: CGPoint, _ aussen: CGFloat, froh: Bool) {
        let dy: CGFloat = froh ? -8 : 6
        linie(g, bogen(P(c.x - 9, c.y + 1), P(c.x + 9, c.y + 1), P(c.x, c.y + 1 + dy)), Pal.tinte.farbe, 3.2)
        if wimpern {
            let ende = P(c.x + aussen * 9, c.y + 1)
            linie(g, strich(ende, P(ende.x + aussen * 4, ende.y - 3)), Pal.tinte.farbe, 2.2)
        }
    }

    /// Eye shapes: size, tilt of the outer corner, lid cover and a liner wing.
    static let augenMasse: [(sx: CGFloat, sy: CGFloat, kipp: Double, deckel: CGFloat, strich: Bool)] = [
        (1, 1, 0, 0, false),          // Rund
        (1.12, 0.78, 6, 0, false),    // Mandel
        (1.15, 1.15, 0, 0, false),    // Groß
        (1.05, 0.6, 0, 0, false),     // Schmal
        (1.05, 0.95, 0, 0.38, false), // Verträumt
        (1.05, 0.85, -9, 0.12, false),// Hängend
        (1.1, 0.8, 12, 0, true),      // Katzenauge
        (0.8, 0.8, 0, 0, false),      // Klein
    ]

    /// `aussen` is -1 for the left eye and 1 for the right one (side of the outer corner).
    func offenesAuge(_ g: GraphicsContext, _ c: CGPoint, _ aussen: CGFloat, gross: Bool, lid: Bool) {
        let f = Self.augenMasse[augenform]
        let tinte = Pal.tinte.farbe
        let rx: CGFloat = (gross ? 11 : 9.5) * f.sx
        let ry: CGFloat = (gross ? 14 : 12) * f.sy
        var e = g
        e.translateBy(x: c.x, y: c.y)
        e.rotate(by: .degrees(-f.kipp * Double(aussen)))
        let weiss = oval(.zero, rx, ry)
        e.fill(weiss, with: .color(.white))
        var h = e
        h.clip(to: weiss)
        let b = blick
        let ic = P(b.x * 3, 2 + b.y * 3)
        let ir: CGFloat = 7.5 * min(f.sx, 1.05)
        h.fill(kreis(ic, ir), with: .color(iris.farbe))
        h.fill(kreis(ic, ir * 0.5), with: .color(tinte))
        h.fill(kreis(P(ic.x - 2.5, ic.y - 3), 2.3), with: .color(.white))
        let deckel: CGFloat = lid ? 1.05 : f.deckel * 2
        if deckel > 0 { h.fill(box(-rx, -ry, rx * 2, ry * deckel), with: .color(haut.farbe)) }
        linie(e, weiss, tinte.opacity(0.5), 1.6)
        let kante: CGFloat = deckel > 0 ? -ry + ry * deckel : -1
        let bogenY: CGFloat = deckel > 0 ? kante + 1 : -2 * ry + 1
        linie(e, bogen(P(-rx, kante), P(rx, kante), P(0, bogenY)), tinte, 3.2)
        let ax: CGFloat = aussen * rx
        if wimpern {
            let y1: CGFloat = min(-ry * 0.45, kante)
            linie(e, strich(P(ax * 0.92, y1), P(ax * 0.92 + aussen * 5, y1 - 4)), tinte, 2.2)
            let y2: CGFloat = min(-ry * 0.78, kante)
            linie(e, strich(P(ax * 0.66, y2), P(ax * 0.66 + aussen * 4, y2 - 5)), tinte, 2.2)
        }
        if f.strich {
            let y: CGFloat = -ry * 0.3
            linie(e, strich(P(ax * 0.9, y), P(ax + aussen * 7, y - 5)), tinte, 3)
        }
    }

    func nase(_ g: GraphicsContext) {
        let k = haut.kontur
        switch nasenStil {
        case 1:
            g.fill(oval(P(100, 114), 5.5, 4.5), with: .color(haut.mal(0.84).farbe))
            g.fill(kreis(P(98, 112), 1.5), with: .color(.white.opacity(0.6)))
        case 2:
            let p = Path { p in
                p.move(to: P(101, 100))
                p.addLine(to: P(104, 113))
                p.addQuadCurve(to: P(96, 116), control: P(106, 118))
            }
            linie(g, p, k, 2.5)
        case 3:
            linie(g, bogen(P(91, 114), P(109, 114), P(100, 121)), k, 2.5)
            for x in [CGFloat(95), 105] { g.fill(kreis(P(x, 115), 1.5), with: .color(k)) }
        case 4:
            linie(g, kreis(P(100, 112), 3.5), k, 2)
            for x in [CGFloat(97), 103] { g.fill(kreis(P(x, 116.5), 1.2), with: .color(k)) }
        case 5:
            let p = Path { p in
                p.move(to: P(99, 98))
                p.addLine(to: P(97, 114))
                p.addQuadCurve(to: P(104, 115), control: P(98, 119))
            }
            linie(g, p, k, 2.5)
        default:
            linie(g, bogen(P(96, 115), P(104, 115), P(100, 119)), k, 2.5)
        }
    }

    var lippe: FigurFarbe? {
        switch mundStil {
        case 3: haut.mix(Pal.rose, 0.4).mal(0.9)
        case 6: FigurFarbe(0xE56B8A)
        case 7: FigurFarbe(0xC8283F)
        default: nil
        }
    }

    func volleLippen(_ g: GraphicsContext, _ f: FigurFarbe) {
        let oben = Path { p in
            p.move(to: P(88, 128))
            p.addQuadCurve(to: P(100, 126), control: P(94, 121))
            p.addQuadCurve(to: P(112, 128), control: P(106, 121))
            p.addQuadCurve(to: P(88, 128), control: P(100, 131))
            p.closeSubpath()
        }
        let unten = Path { p in
            p.move(to: P(89, 129))
            p.addQuadCurve(to: P(111, 129), control: P(100, 141))
            p.addQuadCurve(to: P(89, 129), control: P(100, 132))
            p.closeSubpath()
        }
        teil(g, unten, f, 1.5)
        teil(g, oben, f, 1.5)
        linie(g, bogen(P(88, 128), P(112, 128), P(100, 132)), Pal.tinte.farbe, 2)
        g.fill(oval(P(103, 134), 3, 1.5), with: .color(.white.opacity(0.4)))
    }

    func mund(_ g: GraphicsContext) {
        let tinte = Pal.tinte.farbe
        let rand: Color = lippe?.mal(0.75).farbe ?? tinte
        switch mundForm {
        case .laecheln:
            if let l = lippe {
                volleLippen(g, l)
                return
            }
            switch mundStil {
            case 1:
                let m = Path { p in
                    p.move(to: P(90, 127))
                    p.addLine(to: P(110, 127))
                    p.addQuadCurve(to: P(90, 127), control: P(100, 140))
                    p.closeSubpath()
                }
                g.fill(m, with: .color(.white))
                linie(g, m, tinte, 2.5)
            case 2:
                linie(g, bogen(P(91, 130), P(111, 126), P(101, 136)), tinte, 3)
                linie(g, strich(P(112, 124), P(113, 128)), tinte, 2)
            case 4:
                linie(g, bogen(P(93, 129), P(107, 129), P(100, 133)), tinte, 2.5)
            case 5:
                linie(g, bogen(P(84, 126), P(116, 126), P(100, 141)), tinte, 3)
                linie(g, bogen(P(82, 123), P(83, 130), P(80, 126)), tinte, 2)
                linie(g, bogen(P(118, 123), P(117, 130), P(120, 126)), tinte, 2)
            default:
                linie(g, bogen(P(90, 128), P(110, 128), P(100, 137)), tinte, 3)
            }
        case .grinsen:
            let breit: CGFloat = mundStil == 5 ? 4 : 0
            let m = Path { p in
                p.move(to: P(86 - breit, 126))
                p.addLine(to: P(114 + breit, 126))
                p.addQuadCurve(to: P(86 - breit, 126), control: P(100, 150))
                p.closeSubpath()
            }
            g.fill(m, with: .color(Pal.mundInnen.farbe))
            var h = g
            h.clip(to: m)
            h.fill(oval(P(100, 142), 9, 6), with: .color(Pal.zunge.farbe))
            h.fill(box(80, 124, 40, 5), with: .color(.white))
            linie(g, m, rand, lippe == nil ? 2.5 : 3.5)
        case .offen(let r):
            let o = oval(P(100, 132), r * 0.8, r)
            g.fill(o, with: .color(Pal.mundInnen.farbe))
            linie(g, o, rand, lippe == nil ? 2.5 : 3.5)
        case .neutral:
            linie(g, strich(P(92, 131), P(108, 131)), rand, lippe == nil ? 3 : 4)
        case .traurig:
            linie(g, bogen(P(91, 134), P(109, 134), P(100, 125)), rand, lippe == nil ? 3 : 4)
        case .kuss:
            let f = lippe ?? Pal.rose
            teil(g, oval(P(101, 131), 6, 5), f, 2.5)
            linie(g, strich(P(96, 131), P(106, 131)), f.kontur, 1.5)
        }
    }

    /// Beard area: the head minus the face above `innen` (works for every face shape).
    func bartZone(_ g: GraphicsContext, innen: CGFloat, deckung: Double) {
        let gesichtsFeld = Path { p in
            p.move(to: P(52, 40))
            p.addLine(to: P(148, 40))
            p.addLine(to: P(148, 100))
            p.addCurve(to: P(100, innen + 12), control1: P(146, innen), control2: P(124, innen + 12))
            p.addCurve(to: P(52, 100), control1: P(76, innen + 12), control2: P(54, innen))
            p.closeSubpath()
        }
        var h = g
        h.clip(to: gesichtsFeld, options: .inverse)
        h.opacity = deckung
        h.fill(Path(CGRect(x: 20, y: 92, width: 160, height: 90)), with: .color(haar.farbe))
        if deckung >= 1 {
            linie(h, gesichtsFeld, haar.kontur, 5)
            linie(h, kopfPfad, haar.kontur, 7)
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
            bartZone(h, innen: 130, deckung: 0.22)
            h.fill(schnurr, with: .color(haar.farbe.opacity(0.22)))
        case 2:
            teil(h, schnurr, haar, 2)
        case 3:
            teil(h, oval(P(100, 144), 11, 8), haar, 2)
            teil(h, schnurr, haar, 2)
        case 4:
            bartZone(h, innen: 118, deckung: 1)
            teil(h, schnurr, haar, 2)
        case 5:
            let spitz = Path { p in
                p.move(to: P(92, 139))
                p.addQuadCurve(to: P(100, 156), control: P(92, 150))
                p.addQuadCurve(to: P(108, 139), control: P(108, 150))
                p.closeSubpath()
            }
            teil(h, spitz, haar, 2)
        case 6:
            bartZone(h, innen: 136, deckung: 1)
        case 7:
            bartZone(h, innen: 118, deckung: 1)
            let lang = Path { p in
                p.move(to: P(66, 136))
                p.addQuadCurve(to: P(100, 186), control: P(70, 182))
                p.addQuadCurve(to: P(134, 136), control: P(130, 182))
                p.closeSubpath()
            }
            teil(g, lang, haar, 2.5)
            teil(h, schnurr, haar, 2)
        case 9:
            // Fu-Manchu: mustache with two long strands drooping past the jaw.
            teil(h, schnurr, haar, 2)
            for seite in [CGFloat(-1), 1] {
                let strang = strich(P(100 + seite * 15, 128), P(100 + seite * 12, 152))
                linie(h, strang, haar.kontur, 4.5)
                linie(h, strang, haar.farbe, 2.5)
            }
        case 10:
            // Anker-Bart: mustache plus a thin chin stripe (anchor beard).
            teil(h, schnurr, haar, 2)
            teil(h, box(97, 128, 6, 24, 3), haar, 1.5)
        case 11:
            bartZone(h, innen: 126, deckung: 0.55)
            teil(h, schnurr, haar, 2)
        case 12:
            // Backenbart mit Schnurrbart: sideburns connected to the mustache, no chin.
            for x in [CGFloat(42), 146] { h.fill(box(x, 80, 14, 46, 4), with: .color(haar.farbe)) }
            teil(h, schnurr, haar, 2)
        default:
            for x in [CGFloat(42), 146] { h.fill(box(x, 80, 12, 40, 4), with: .color(haar.farbe)) }
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

    /// Hair part with outline, plus highlight streaks when the hair color has them.
    func haarTeil(_ g: GraphicsContext, _ p: Path, _ breite: CGFloat = 3.5) {
        teil(g, p, haar, breite)
        guard let s = straehne else { return }
        var h = g
        h.clip(to: p)
        for i in 0..<7 {
            let x = CGFloat(34 + i * 22)
            linie(h, bogen(P(x, 0), P(x + 10, 240), P(x - 14, 110)), s.farbe.opacity(0.85), 4)
        }
    }

    func lockenKette(_ g: GraphicsContext, _ punkte: [CGPoint], _ r: CGFloat) {
        for c in punkte { g.fill(kreis(c, r + 2), with: .color(haar.kontur)) }
        for c in punkte { g.fill(kreis(c, r), with: .color(haar.farbe)) }
    }

    func langHinten(_ u: CGFloat) -> Path {
        Path { p in
            p.move(to: P(100, 22))
            p.addCurve(to: P(34, 92), control1: P(56, 22), control2: P(34, 50))
            p.addLine(to: P(30, u - 8))
            p.addQuadCurve(to: P(60, u), control: P(40, u + 2))
            p.addLine(to: P(140, u))
            p.addQuadCurve(to: P(170, u - 8), control: P(160, u + 2))
            p.addLine(to: P(166, 92))
            p.addCurve(to: P(100, 22), control1: P(166, 50), control2: P(144, 22))
            p.closeSubpath()
        }
    }

    func seitenLocken(_ bis: CGFloat) -> [CGPoint] {
        var punkte: [CGPoint] = []
        for y in stride(from: CGFloat(104), through: bis, by: 18) {
            punkte.append(P(40, y))
            punkte.append(P(160, y))
        }
        return punkte
    }

    func haareHinten(_ g: GraphicsContext) {
        switch frisur {
        case 6, 28:
            haarTeil(g, box(32, 30, 136, 124, 50))
        case 7, 8, 20, 29:
            haarTeil(g, langHinten(222))
        case 26:
            haarTeil(g, kreis(P(100, 12), 13))
            haarTeil(g, langHinten(222))
        case 21:
            haarTeil(g, langHinten(222))
            lockenKette(g, seitenLocken(212), 13)
        case 22:
            haarTeil(g, langHinten(168))
        case 31:
            haarTeil(g, langHinten(170))
            lockenKette(g, seitenLocken(164), 13)
        case 9:
            let zopf = Path { p in
                p.move(to: P(132, 40))
                p.addCurve(to: P(178, 168), control1: P(190, 50), control2: P(194, 130))
                p.addCurve(to: P(150, 100), control1: P(162, 176), control2: P(150, 136))
                p.closeSubpath()
            }
            haarTeil(g, zopf)
        case 10:
            haarTeil(g, kreis(P(100, 24), 18))
        case 17:
            var bumps: [CGPoint] = []
            for i in 0..<14 {
                let a = Double(i) / 14 * 2 * Double.pi
                bumps.append(P(100 + 66 * CGFloat(cos(a)), 78 + 62 * CGFloat(sin(a))))
            }
            for b in bumps { g.fill(kreis(b, 16), with: .color(haar.kontur)) }
            g.fill(oval(P(100, 78), 68, 64), with: .color(haar.kontur))
            for b in bumps { g.fill(kreis(b, 13.5), with: .color(haar.farbe)) }
            g.fill(oval(P(100, 78), 66, 62), with: .color(haar.farbe))
        case 18:
            haarTeil(g, kreis(P(100, 16), 13))
            g.fill(box(88, 25, 24, 5, 2), with: .color(haar.mal(0.6).farbe))
        case 19:
            for x in stride(from: CGFloat(36), through: 164, by: 14) {
                let lang: CGFloat = abs(x - 100) > 40 ? 132 : 70
                let strang = box(x - 6, 40, 12, lang - 40, 6)
                linie(g, strang, haar.kontur, 3)
                g.fill(strang, with: .color(haar.farbe))
            }
        case 23:
            let schweif = Path { p in
                p.move(to: P(96, 20))
                p.addCurve(to: P(172, 150), control1: P(150, -10), control2: P(186, 80))
                p.addCurve(to: P(146, 90), control1: P(160, 150), control2: P(150, 120))
                p.addCurve(to: P(112, 22), control1: P(146, 60), control2: P(130, 30))
                p.closeSubpath()
            }
            haarTeil(g, schweif)
        case 24:
            haarTeil(g, kreis(P(52, 34), 20))
            haarTeil(g, kreis(P(148, 34), 20))
        case 32:
            let schwanz = Path { p in
                p.move(to: P(50, 60))
                p.addCurve(to: P(16, 150), control1: P(14, 60), control2: P(6, 110))
                p.addCurve(to: P(40, 118), control1: P(28, 150), control2: P(40, 136))
                p.addCurve(to: P(56, 76), control1: P(40, 96), control2: P(50, 84))
                p.closeSubpath()
            }
            haarTeil(g, schwanz)
            haarTeil(g, gespiegelt(schwanz))
        default:
            break
        }
    }

    func lockenKopf(_ g: GraphicsContext) {
        g.fill(kappe(top: 22, scheitel: 100, ansatz: 62, unten: 96), with: .color(haar.farbe))
        var locken: [CGPoint] = []
        for grad in stride(from: 190.0, through: 350.0, by: 20.0) {
            let r = grad * Double.pi / 180
            locken.append(P(100 + 60 * CGFloat(cos(r)), 84 + 60 * CGFloat(sin(r))))
        }
        locken += [P(66, 60), P(84, 54), P(100, 52), P(116, 54), P(134, 60)]
        lockenKette(g, locken, 11.8)
    }

    func haareVorn(_ g: GraphicsContext) {
        switch frisur {
        case 0:
            haarTeil(g, kappe(top: 18, scheitel: 100, ansatz: 58, unten: 92))
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
            haarTeil(g, kappe(top: 18, scheitel: 72, ansatz: 56, unten: 92))
            let welle = Path { p in
                p.move(to: P(70, 46))
                p.addCurve(to: P(152, 86), control1: P(112, 30), control2: P(150, 52))
                p.addCurve(to: P(104, 62), control1: P(140, 70), control2: P(122, 60))
                p.addCurve(to: P(70, 46), control1: P(88, 64), control2: P(74, 56))
                p.closeSubpath()
            }
            haarTeil(g, welle, 3)
        case 3:
            lockenKopf(g)
        case 4:
            haarTeil(g, kappe(top: 22, scheitel: 100, ansatz: 58, unten: 92))
            let tolle = Path { p in
                p.move(to: P(64, 50))
                p.addCurve(to: P(118, 6), control1: P(60, 20), control2: P(88, 4))
                p.addCurve(to: P(142, 40), control1: P(140, 8), control2: P(150, 26))
                p.addCurve(to: P(100, 50), control1: P(130, 50), control2: P(112, 46))
                p.addCurve(to: P(64, 50), control1: P(86, 56), control2: P(72, 56))
                p.closeSubpath()
            }
            haarTeil(g, tolle, 3)
        case 5:
            linie(g, bogen(P(62, 56), P(84, 38), P(66, 42)), .white.opacity(0.35), 5)
            return
        case 6:
            haarTeil(g, kappe(top: 16, scheitel: 100, ansatz: 70, unten: 106))
        case 7, 8, 26:
            haarTeil(g, kappe(top: 16, scheitel: frisur == 8 ? 80 : 100, ansatz: 50, unten: 106))
            let strang = frisur == 8 ? straehneWellig : straehneGlatt()
            haarTeil(g, strang)
            haarTeil(g, gespiegelt(strang))
            if frisur == 26 { teil(g, box(89, 13, 22, 6, 3), Pal.rose, 1.5) }
        case 9, 10, 24:
            haarTeil(g, kappe(top: 20, scheitel: 100, ansatz: 54, unten: 96))
        case 11:
            haarTeil(g, kappe(top: 18, scheitel: 100, ansatz: 52, unten: 100))
            for seite in [CGFloat(-1), 1] {
                var glieder: [CGPoint] = []
                for i in 0..<6 { glieder.append(P(100 + seite * (54 + CGFloat(i) * 1.5), 112 + CGFloat(i) * 16)) }
                for c in glieder { g.fill(oval(c, 11, 12), with: .color(haar.kontur)) }
                for c in glieder { g.fill(oval(c, 9, 10), with: .color(haar.farbe)) }
                let ende = P(100 + seite * 63, 206)
                teil(g, kreis(ende, 5), Pal.rose, 2)
            }
        case 12:
            let k = kappe(top: 18, scheitel: 100, ansatz: 60, unten: 94)
            haarTeil(g, k)
            var buschel: [Path] = []
            for i in 0..<6 {
                let x0 = CGFloat(48 + i * 17)
                let dx: CGFloat = i % 2 == 0 ? 6 : 12
                let sy: CGFloat = i % 2 == 0 ? 72 : 66
                let spitze = P(x0 + dx, sy)
                buschel.append(Path { p in
                    p.move(to: P(x0, 52))
                    p.addQuadCurve(to: spitze, control: P(x0 + 1, 66))
                    p.addQuadCurve(to: P(x0 + 19, 52), control: P(x0 + 16, 62))
                    p.closeSubpath()
                })
            }
            for p in buschel { linie(g, p, haar.kontur, 5) }
            for p in buschel { g.fill(p, with: .color(haar.farbe)) }
            g.fill(k, with: .color(haar.farbe))
        case 13:
            teil(g, kappe(top: 24, scheitel: 100, ansatz: 60, unten: 92), haar.mix(haut, 0.45), 2.5)
            let oben = Path { p in
                p.move(to: P(48, 62))
                p.addCurve(to: P(100, 8), control1: P(42, 26), control2: P(68, 8))
                p.addCurve(to: P(154, 54), control1: P(134, 8), control2: P(158, 30))
                p.addCurve(to: P(48, 62), control1: P(122, 44), control2: P(78, 34))
                p.closeSubpath()
            }
            haarTeil(g, oben, 3)
            linie(g, bogen(P(70, 40), P(140, 30), P(100, 20)), haar.kontur, 2)
        case 14:
            teil(g, kappe(top: 22, scheitel: 100, ansatz: 60, unten: 94), haar.mix(haut, 0.6), 2.5)
            let oben = Path { p in
                p.move(to: P(52, 60))
                p.addCurve(to: P(100, 18), control1: P(50, 32), control2: P(70, 18))
                p.addCurve(to: P(148, 60), control1: P(130, 18), control2: P(150, 32))
                p.addQuadCurve(to: P(52, 60), control: P(100, 50))
                p.closeSubpath()
            }
            haarTeil(g, oben, 3)
        case 15:
            haarTeil(g, kappe(top: 18, scheitel: 100, ansatz: 50, unten: 94))
            let vorhang = Path { p in
                p.move(to: P(100, 34))
                p.addCurve(to: P(50, 92), control1: P(74, 36), control2: P(52, 58))
                p.addLine(to: P(60, 94))
                p.addCurve(to: P(98, 46), control1: P(64, 64), control2: P(80, 48))
                p.closeSubpath()
            }
            haarTeil(g, vorhang, 3)
            haarTeil(g, gespiegelt(vorhang), 3)
        case 16:
            haarTeil(g, kappe(top: 18, scheitel: 100, ansatz: 72, unten: 98))
            for x in [CGFloat(72), 88, 112, 128] { linie(g, strich(P(x, 58), P(x + 1, 70)), haar.kontur, 2) }
        case 17:
            g.fill(kappe(top: 14, scheitel: 100, ansatz: 56, unten: 96), with: .color(haar.farbe))
            var punkte: [CGPoint] = []
            for x in stride(from: CGFloat(58), through: 142, by: 14) { punkte.append(P(x, 56 + abs(x - 100) * 0.3)) }
            lockenKette(g, punkte, 9)
        case 18:
            teil(g, kappe(top: 22, scheitel: 100, ansatz: 54, unten: 90), haar.mix(haut, 0.3), 2.5)
            let oben = Path { p in
                p.move(to: P(56, 58))
                p.addCurve(to: P(100, 22), control1: P(54, 34), control2: P(72, 22))
                p.addCurve(to: P(144, 58), control1: P(128, 22), control2: P(146, 34))
                p.addQuadCurve(to: P(56, 58), control: P(100, 46))
                p.closeSubpath()
            }
            haarTeil(g, oben, 3)
            for x in [CGFloat(78), 100, 122] { linie(g, bogen(P(x, 50), P(100, 26), P(x, 34)), haar.kontur, 1.8) }
        case 19:
            haarTeil(g, kappe(top: 20, scheitel: 100, ansatz: 58, unten: 94))
            for x in stride(from: CGFloat(58), through: 142, by: 12) {
                let lang: CGFloat = x.truncatingRemainder(dividingBy: 24) == 10 ? 34 : 28
                let strang = box(x - 5, 40, 10, lang, 5)
                linie(g, strang, haar.kontur, 3)
                g.fill(strang, with: .color(haar.farbe))
            }
        case 20:
            haarTeil(g, kappe(top: 16, scheitel: 100, ansatz: 72, unten: 106))
            haarTeil(g, straehneGlatt())
            haarTeil(g, gespiegelt(straehneGlatt()))
        case 21:
            haarTeil(g, kappe(top: 16, scheitel: 88, ansatz: 52, unten: 104))
            lockenKette(g, seitenLocken(200), 11)
        case 22:
            haarTeil(g, kappe(top: 16, scheitel: 100, ansatz: 50, unten: 106))
            haarTeil(g, straehneGlatt(166))
            haarTeil(g, gespiegelt(straehneGlatt(166)))
        case 23:
            haarTeil(g, kappe(top: 18, scheitel: 100, ansatz: 50, unten: 92))
            teil(g, kreis(P(104, 18), 7), Pal.rose, 2)
        case 25:
            haarTeil(g, kappe(top: 18, scheitel: 76, ansatz: 52, unten: 100))
            haarTeil(g, gespiegelt(straehneGlatt(120)))
            var glieder: [CGPoint] = []
            for i in 0..<7 { glieder.append(P(152 - CGFloat(i) * 2.5, 112 + CGFloat(i) * 16)) }
            for c in glieder { g.fill(oval(c, 13, 12), with: .color(haar.kontur)) }
            for c in glieder { g.fill(oval(c, 11, 10), with: .color(haar.farbe)) }
            teil(g, kreis(P(136, 222), 5), Pal.rose, 2)
        case 27:
            haarTeil(g, kappe(top: 20, scheitel: 70, ansatz: 60, unten: 92))
            let schwung = Path { p in
                p.move(to: P(58, 46))
                p.addCurve(to: P(144, 66), control1: P(98, 30), control2: P(138, 40))
                p.addCurve(to: P(96, 64), control1: P(130, 74), control2: P(112, 64))
                p.addCurve(to: P(58, 46), control1: P(80, 64), control2: P(60, 60))
                p.closeSubpath()
            }
            haarTeil(g, schwung, 3)
        case 28:
            haarTeil(g, kappe(top: 16, scheitel: 100, ansatz: 74, unten: 106))
        case 29:
            haarTeil(g, kappe(top: 16, scheitel: 70, ansatz: 50, unten: 106))
            haarTeil(g, straehneGlatt())
            haarTeil(g, gespiegelt(straehneGlatt()))
            let schwung = Path { p in
                p.move(to: P(70, 36))
                p.addCurve(to: P(156, 110), control1: P(120, 34), control2: P(160, 70))
                p.addLine(to: P(146, 112))
                p.addCurve(to: P(72, 50), control1: P(140, 76), control2: P(110, 50))
                p.closeSubpath()
            }
            haarTeil(g, schwung, 3)
        case 30:
            teil(g, kappe(top: 26, scheitel: 100, ansatz: 60, unten: 92), haar.mix(haut, 0.6), 2.5)
            let kamm = Path { p in
                p.move(to: P(86, 58))
                p.addCurve(to: P(100, 2), control1: P(84, 22), control2: P(92, 6))
                p.addCurve(to: P(114, 58), control1: P(108, 6), control2: P(116, 22))
                p.closeSubpath()
            }
            haarTeil(g, kamm, 3)
        case 31:
            lockenKopf(g)
            lockenKette(g, seitenLocken(150), 11)
        case 32:
            haarTeil(g, kappe(top: 18, scheitel: 100, ansatz: 54, unten: 96))
            teil(g, kreis(P(46, 70), 6), Pal.rose, 2)
            teil(g, kreis(P(154, 70), 6), Pal.rose, 2)
        case 33:
            haarTeil(g, kappe(top: 20, scheitel: 100, ansatz: 44, unten: 88))
            for x in [CGFloat(78), 100, 122] { linie(g, bogen(P(x, 46), P(x + 4, 20), P(x - 6, 32)), .white.opacity(0.35), 3) }
        default:
            break
        }
        if ![1, 14, 17, 30].contains(frisur) {
            linie(g, bogen(P(58, 62), P(86, 30), P(62, 36)), .white.opacity(0.45), 5)
        }
    }

    func straehneGlatt(_ u: CGFloat = 212) -> Path {
        Path { p in
            p.move(to: P(42, 92))
            p.addCurve(to: P(32, u - 6), control1: P(34, 130), control2: P(30, u - 32))
            p.addQuadCurve(to: P(58, u), control: P(42, u + 4))
            p.addCurve(to: P(54, 104), control1: P(60, u - 42), control2: P(58, 130))
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
        let sonne = [3, 8, 9, 10, 11].contains(brille)
        let rahmen: Color
        switch brille {
        case 7, 12: rahmen = Pal.tinte.farbe.opacity(0.5)
        case 8, 11: rahmen = Pal.gold.mal(0.8).farbe
        case 9: rahmen = Pal.rose.kontur
        default: rahmen = Pal.tinte.farbe
        }
        let links: Path
        switch brille {
        case 1:
            links = kreis(P(80, 98), 14)
        case 4:
            links = oval(P(80, 98), 16, 11)
        case 5:
            links = Path { p in
                p.move(to: P(60, 84))
                p.addQuadCurve(to: P(96, 90), control: P(80, 84))
                p.addQuadCurve(to: P(82, 110), control: P(98, 108))
                p.addQuadCurve(to: P(60, 84), control: P(64, 106))
                p.closeSubpath()
            }
        case 6:
            links = box(62, 84, 36, 28, 5)
        case 7:
            links = box(66, 88, 30, 22, 8)
        case 8:
            links = Path { p in
                p.move(to: P(64, 88))
                p.addLine(to: P(96, 88))
                p.addQuadCurve(to: P(82, 112), control: P(98, 110))
                p.addQuadCurve(to: P(64, 88), control: P(62, 108))
                p.closeSubpath()
            }
        case 9:
            links = herzPfad(P(80, 97), 15)
        case 10:
            links = Path { p in
                p.move(to: P(56, 88))
                p.addQuadCurve(to: P(144, 88), control: P(100, 80))
                p.addLine(to: P(140, 106))
                p.addQuadCurve(to: P(60, 106), control: P(100, 116))
                p.closeSubpath()
            }
        case 11:
            links = oval(P(80, 97), 20, 15)
        case 12:
            links = kreis(P(80, 98), 11)
        default:
            links = box(64, 86, 32, 25, 7)
        }
        let glaeser = brille == 10 ? [links] : [links, gespiegelt(links)]
        let glas: Color
        switch brille {
        case 9: glas = Pal.rose.farbe.opacity(0.85)
        case 10: glas = Pal.himmel.mal(0.7).farbe.opacity(0.9)
        default: glas = sonne ? Pal.tinte.farbe.opacity(0.9) : .white.opacity(0.15)
        }
        let dicke: CGFloat = brille == 6 ? 5 : (brille == 7 || brille == 12) ? 1.4 : 3
        for l in glaeser { g.fill(l, with: .color(glas)) }
        if sonne {
            linie(g, strich(P(70, 92), P(78, 90)), .white.opacity(0.6), 2.5)
            if brille != 10 { linie(g, strich(P(110, 92), P(118, 90)), .white.opacity(0.6), 2.5) }
        }
        for l in glaeser { linie(g, l, rahmen, dicke) }
        if brille != 10 { linie(g, bogen(P(94, 96), P(106, 96), P(100, 91)), rahmen, dicke) }
        linie(g, strich(P(62, 95), P(44, 92)), rahmen, dicke)
        linie(g, strich(P(138, 95), P(156, 92)), rahmen, dicke)
    }

    func ohrringeZeichnen(_ g: GraphicsContext) {
        guard ohrring > 0 else { return }
        for x in [CGFloat(42), 158] {
            switch ohrring {
            case 1:
                teil(g, kreis(P(x, 110), 3), Pal.gold, 1.5)
            case 2:
                linie(g, kreis(P(x, 119), 8), Pal.gold.kontur, 4.5)
                linie(g, kreis(P(x, 119), 8), Pal.gold.farbe, 2.5)
            case 3:
                linie(g, strich(P(x, 110), P(x, 121)), Pal.gold.farbe, 2)
                teil(g, oval(P(x, 126), 3.5, 5), Pal.gold, 1.5)
            default:
                teil(g, kreis(P(x, 112), 4.2), FigurFarbe(0xF4EEE6), 1.5)
                g.fill(kreis(P(x - 1.3, 110.7), 1.3), with: .color(.white))
            }
        }
    }

    func muetzeZeichnen(_ g: GraphicsContext) {
        let f = muetzeF
        switch muetze {
        case 1, 2:
            let krone = Path { p in
                p.move(to: P(40, 66))
                p.addCurve(to: P(100, 6), control1: P(36, 22), control2: P(64, 6))
                p.addCurve(to: P(160, 66), control1: P(136, 6), control2: P(164, 22))
                p.addQuadCurve(to: P(40, 66), control: P(100, 54))
                p.closeSubpath()
            }
            teil(g, krone, f)
            var h = g
            h.clip(to: krone)
            for x in [CGFloat(72), 128] { linie(h, bogen(P(x, 62), P(100, 6), P(x, 20)), f.kontur, 1.5) }
            teil(g, kreis(P(100, 8), 4.5), f.mal(0.85), 2)
            if muetze == 1 {
                teil(g, oval(P(100, 64), 58, 10), f.mal(0.85))
                g.fill(herzPfad(P(100, 38), 8), with: .color(f.mix(Pal.weiss, 0.7).farbe))
            } else {
                teil(g, box(84, 46, 32, 14, 6), haar, 2)
                linie(g, strich(P(86, 53), P(114, 53)), f.mal(0.7).farbe, 3)
            }
        case 3:
            let form = Path { p in
                p.move(to: P(38, 70))
                p.addCurve(to: P(100, 2), control1: P(34, 20), control2: P(64, 2))
                p.addCurve(to: P(162, 70), control1: P(136, 2), control2: P(166, 20))
                p.closeSubpath()
            }
            teil(g, form, f)
            let bund = box(34, 50, 132, 22, 10)
            teil(g, bund, f.mal(0.85))
            var h = g
            h.clip(to: bund)
            for x in stride(from: CGFloat(42), to: 164, by: 9) { linie(h, strich(P(x, 50), P(x, 72)), f.kontur, 1.5) }
        case 4:
            let krone = Path { p in
                p.move(to: P(50, 58))
                p.addCurve(to: P(100, 6), control1: P(48, 18), control2: P(70, 6))
                p.addCurve(to: P(150, 58), control1: P(130, 6), control2: P(152, 18))
                p.closeSubpath()
            }
            let krempe = Path { p in
                p.move(to: P(40, 52))
                p.addLine(to: P(160, 52))
                p.addLine(to: P(178, 76))
                p.addQuadCurve(to: P(22, 76), control: P(100, 88))
                p.closeSubpath()
            }
            teil(g, krone, f)
            teil(g, krempe, f.mal(0.9))
            linie(g, strich(P(50, 53), P(150, 53)), f.mal(0.7).farbe, 4)
        case 5:
            let band = bogen(P(42, 72), P(158, 72), P(100, 42))
            linie(g, band, f.kontur, 14)
            linie(g, band, f.farbe, 10)
        case 6:
            let reif = bogen(P(44, 84), P(156, 84), P(100, -6))
            linie(g, reif, f.kontur, 7)
            linie(g, reif, f.farbe, 4)
        default:
            break
        }
    }

    // MARK: Poses

    /// Z-23.3/Z-24.2: a bought pose/dance shows while the figure is just idling (Profil, Karte) —
    /// it never fights a meaningful activity pose (typing, sleeping, …).
    func poseUeberschreibung() -> (l: Arm?, r: Arm?)? {
        guard let id = poseId else { return nil }
        switch id {
        case "pose.tanz1":
            let s = w(6)
            return (Arm(P(42, 216), P(46 + s * 10, 250)), Arm(P(158, 200), P(154 - s * 14, 150)))
        case "pose.tanz2":
            let s = w(5)
            return (Arm(P(42, 200), P(30, 150 + s * 10)), Arm(P(158, 200), P(170, 150 - s * 10)))
        case "pose.tanz3":
            let s = w(7, 1.5)
            return (Arm(P(50, 210), P(70 + s * 10, 190)), Arm(P(150, 210), P(130 - s * 10, 190)))
        case "pose.tanz4":
            let s = w(4)
            return (Arm(P(40, 190 - s * 6), P(30, 140 - s * 10)), Arm(P(160, 190 + s * 6), P(170, 140 + s * 10)))
        case "pose.model":
            return (Arm(P(46, 216), P(66, 206)), Arm(P(160, 176), P(178, 130)))
        default:
            return nil
        }
    }

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
            // Z-23.3/Z-24.2: a bought pose/dance shows whenever nothing more specific is going on
            // (Profil, Karte, "zuhause", …) — it never overrides a real activity pose above.
            return poseUeberschreibung() ?? (restL, restR)
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
            if p < 0.5 && !statisch {
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

// MARK: - Full body (200 x 400; the head is the half-figure head scaled by 0.8)

extension Zeichner {
    func zeichneGanz(_ ctx: GraphicsContext, _ size: CGSize) {
        var g = ctx
        g.scaleBy(x: size.width / 200, y: size.height / 400)
        g.clip(to: Path(CGRect(x: 0, y: 0, width: 200, height: 400)))
        let m = masse()
        let hal = haltung
        let bew = bewegung()
        // Scenes with furniture or vehicles only bob; standing figures may also sway.
        let winkel: Double = [.stehen, .gehen, .rennen].contains(hal) ? bew.winkel : 0
        let atem: CGFloat = z == .offline ? 1 : 1.005 + 0.005 * w(2 * Double.pi / 3.6)
        g.translateBy(x: 100, y: 392)
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

        if z == .morgen || z == .abend { hintergrund(k) }
        szeneHinten(g, m, oben)
        haareHinten(haarKontext(k))
        if hal != .fahren { beine(g, m, hal, oben) }
        rumpfGanz(u, m)
        kopfGruppe(k)
        vorArmen(g, u, m, oben)
        let arme = poseGanz(m)
        arm(u, P(100 - m.s + 6, m.schulterY + 10), arme.l, m.arm)
        arm(u, P(100 + m.s - 6, m.schulterY + 10), arme.r, m.arm)
        handRequisite(u, arme, m)
        let hand: CGFloat = 10 * m.arm
        teil(u, kreis(arme.l.hand, hand), haut, 2.5)
        teil(u, kreis(arme.r.hand, hand), haut, 2.5)
        zubehoerGanz(u, arme, m)
        if let id = tierId { zeichneHaustier(g, id: id, boden: P(174, Masse.fussY), groesse: 0.8) }
        auto(g, m, oben)
        switch z {
        case .laeuft, .rennt, .rad: tempoStriche(g, m.schulterY + oben)
        case .schautVideo: break
        default: effekte(k)
        }
        abzeichenVorn(k)
    }

    /// Z-24.2: worn shop parts, scaled like `jackeZeichnen`'s `s: 0.66` onto the full-body torso.
    func zubehoerGanz(_ g: GraphicsContext, _ arme: (l: Arm, r: Arm), _ m: Masse) {
        let s: CGFloat = 0.66
        if let id = tascheId { zeichneTasche(g, id: id, an: arme.r.hand, groesse: s) }
        if let id = uhrId {
            // Wrist, not the hand itself — a hand-centered watch would just replace the hand circle.
            zeichneUhr(g, id: id, an: zwischen(arme.l.ellbogen, arme.l.hand, 0.72), groesse: s)
        }
        if let id = schmuckId { zeichneSchmuck(g, id: id, hals: P(100, m.schulterY - 6), groesse: s) }
    }

    func masse() -> Masse {
        let beinLaengen: [CGFloat] = [112, 124, 136]
        let schultern: [CGFloat] = [37, 41, 46]
        let taillen: [CGFloat] = [26, 30, 37]
        let hueften: [CGFloat] = [29, 32, 38]
        let arme: [CGFloat] = [0.6, 0.66, 0.74]
        let beine: [CGFloat] = [15, 17, 20]
        let f = koerperform
        let beinL = beinLaengen[groesseStufe]
        let hueftY = Masse.fussY - beinL
        return Masse(s: schultern[f], t: taillen[f], h: hueften[f], arm: arme[f], bein: beine[f],
                     hueftY: hueftY, schulterY: hueftY - 96, knieY: hueftY + beinL * 0.5)
    }

    var haltung: Haltung {
        switch z {
        case .laeuft: .gehen
        case .rennt: .rennen
        case .rad: .rad
        case .faehrt, .fahrschule: .fahren
        case .zuhause, .schule, .arbeit, .schautVideo, .ruhe: .sitzen
        default: .stehen
        }
    }

    /// How far the upper body drops: sitting puts the hips at knee height.
    func obenVersatz(_ hal: Haltung, _ m: Masse) -> CGFloat {
        switch hal {
        case .sitzen, .fahren: m.knieY - m.hueftY - 4
        case .rad: 40
        default: 0
        }
    }

    // MARK: Legs, pants, shoes

    func beinGelenke(_ hal: Haltung, _ m: Masse, _ oben: CGFloat) -> (l: Bein, r: Bein) {
        let hx: CGFloat = m.h * 0.52
        let hy: CGFloat = m.hueftY + oben
        let fy = Masse.fussY
        func bein(_ seite: CGFloat, _ phase: CGFloat) -> Bein {
            let x: CGFloat = 100 + seite * hx
            let hebt: CGFloat = max(0, phase)
            switch hal {
            case .gehen:
                return Bein(h: P(x, hy), k: P(x + phase * 3, m.knieY - hebt * 5), f: P(x + phase * 7, fy - hebt * 12))
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
            }
        }
        let s: CGFloat
        switch hal {
        case .gehen: s = w(7)
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
        case 0, 2: FigurFarbe(0x9DB8D9)
        case 1: FigurFarbe(0x34507A)
        default: hoseF
        }
    }

    func beine(_ g: GraphicsContext, _ m: Masse, _ hal: Haltung, _ oben: CGFloat) {
        let (l, r) = beinGelenke(hal, m, oben)
        let b = m.bein
        let kleid = oberteil == 8
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
        case 4: breiten = (0.66, 0.56, 0.42)
        case 9: breiten = (0.54, 0.42, 0.34)
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
            for s in seiten {
                let mp = zwischen(s.bein.h, s.bein.k, 0.75)
                let x: CGFloat = mp.x + s.seite * b * 0.25 - 6
                teil(g, box(x, mp.y - 8, 12, 16, 3), farbe.mal(0.88), 1.8)
            }
        case 10:
            // Anzughose: crease line plus a thin belt at the waist.
            for bn in [l, r] { linie(g, strich(P(bn.h.x, bn.h.y + 14), P(bn.f.x, bn.f.y - 4)), farbe.kontur.opacity(0.4), 1.2) }
            linie(g, strich(P(100 - m.h, hy - 8), P(100 + m.h, hy - 8)), Pal.dunkel.farbe, 3)
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
            // Logo-Sneaker: base sneaker plus a diagonal side swoosh.
            teil(g, box(x - 12, y - 5, 24, 15, 7), c, 3)
            g.fill(box(x - 12, y + 6, 24, 4, 2), with: .color(sohle.farbe))
            linie(g, bogen(P(x - 9, y + 3), P(x + 6, y - 4), P(x - 3, y - 2)), Pal.gold.farbe, 2.5)
        case 9:
            // Two-Tone-Sneaker: base sneaker with a contrasting toe cap.
            teil(g, box(x - 12, y - 5, 24, 15, 7), c, 3)
            teil(g, box(x - 12, y - 5, 11, 15, 7), c.mix(Pal.weiss, 0.35), 2)
            g.fill(box(x - 12, y + 6, 24, 4, 2), with: .color(sohle.farbe))
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
        return Path { p in
            p.move(to: P(89, sY - 2))
            p.addQuadCurve(to: P(100 - m.s, sY + 14), control: P(104 - m.s, sY - 2))
            p.addLine(to: P(100 - m.t, taille))
            p.addLine(to: P(100 - saum, unten))
            p.addQuadCurve(to: P(100 + saum, unten), control: P(100, unten + 4))
            p.addLine(to: P(100 + m.t, taille))
            p.addLine(to: P(100 + m.s, sY + 14))
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
            teil(g, form, top)
        }
        if oberteil != 6 {
            // Top details are drawn in the half-figure torso space, mapped onto this torso.
            var dg = g
            dg.translateBy(x: 100, y: sY - 2)
            dg.scaleBy(x: 0.66, y: 0.8)
            dg.translateBy(x: -100, y: -161)
            var d = g
            d.clip(to: form)
            d.translateBy(x: 100, y: sY - 2)
            d.scaleBy(x: 0.66, y: 0.8)
            d.translateBy(x: -100, y: -161)
            oberteilDetails(dg, d)
            if [7, 12, 13].contains(oberteil) { linie(g, form, top.kontur, 3.5) }
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
        if jacke > 0 { jackeZeichnen(g, form: voll, oben: sY - 2, unten: unten, s: 0.66) }
    }

    // MARK: Arms and props

    /// Full-body counterpart to `poseUeberschreibung()` — same pose ids, coordinates in body space.
    func poseGanzUeberschreibung(_ m: Masse) -> (l: Arm, r: Arm)? {
        guard let id = poseId else { return nil }
        let lx: CGFloat = 100 - m.s + 6, rx: CGFloat = 100 + m.s - 6, y = m.schulterY
        switch id {
        case "pose.tanz1":
            let s = w(6)
            return (Arm(P(lx - 6, y + 50), P(lx - 4, y + 92)), Arm(P(rx + 10, y + 10 - s * 10), P(rx + 30, y - 30 + s * 14)))
        case "pose.tanz2":
            let s = w(5)
            return (Arm(P(lx - 20, y + 10 - s * 8), P(lx - 40, y - 20 + s * 10)), Arm(P(rx + 20, y + 10 + s * 8), P(rx + 40, y - 20 - s * 10)))
        case "pose.tanz3":
            let s = w(7, 1.5)
            return (Arm(P(lx - 10, y + 40), P(lx - 30 + s * 10, y + 10)), Arm(P(rx + 10, y + 40), P(rx + 30 - s * 10, y + 10)))
        case "pose.tanz4":
            let s = w(4)
            return (Arm(P(lx - 10, y + 10 - s * 6), P(lx - 30, y - 30 - s * 10)), Arm(P(rx + 10, y + 10 + s * 6), P(rx + 30, y - 30 + s * 10)))
        case "pose.model":
            return (Arm(P(lx - 4, y + 48), P(86, y + 84)), Arm(P(rx + 20, y - 4), P(rx + 34, y - 40)))
        default:
            return nil
        }
    }

    func poseGanz(_ m: Masse) -> (l: Arm, r: Arm) {
        let lx: CGFloat = 100 - m.s + 6
        let rx: CGFloat = 100 + m.s - 6
        let y = m.schulterY
        let wiege: CGFloat = statisch ? 0 : w(1.3) * 1.5
        let restL = Arm(P(lx - 6, y + 50), P(lx - 4 + wiege, y + 92))
        let restR = Arm(P(rx + 6, y + 50), P(rx + 4 - wiege, y + 92))
        switch z {
        case .imChat:
            let welle: CGFloat = zyklus(5) < 0.45 ? w(9) * 7 : 0
            return (restL, Arm(P(rx + 18, y + 2), P(rx + 22 + welle, y - 36)))
        case .tippt, .liest, .spielt, .karte, .schautBild, .zeichnet, .laedt:
            let tipp: CGFloat = z == .tippt ? w(16) * 1.5 : 0
            return (Arm(P(lx - 4, y + 48), P(94, y + 50 + tipp)), Arm(P(rx + 4, y + 48), P(106, y + 50 - tipp)))
        case .kamera:
            return (restL, Arm(P(rx + 16, y + 16), P(rx + 14, y - 30)))
        case .sprache:
            return (restL, Arm(P(rx + 6, y + 40), P(112, y - 18)))
        case .gut, .pokal, .morgen, .lacht, .anstossen:
            let s: CGFloat = z == .morgen ? w(1.6) * 4 : 0
            return (Arm(P(lx - 18, y - 2 - s), P(lx - 22, y - 40 - s)), Arm(P(rx + 18, y - 2 - s), P(rx + 22, y - 40 - s)))
        case .naehe:
            let o: CGFloat = w(2.4) * 4
            return (Arm(P(lx - 24, y + 26 - o), P(lx - 44, y + 10 - o)), Arm(P(rx + 24, y + 26 - o), P(rx + 44, y + 10 - o)))
        case .kuss:
            return (restL, Arm(P(rx + 8, y + 36), P(108, y - 24)))
        case .herz:
            return (Arm(P(lx - 6, y + 44), P(93, y + 32)), Arm(P(rx + 6, y + 44), P(107, y + 32)))
        case .gym:
            let c: CGFloat = (1 + w(3.2)) / 2
            return (restL, Arm(P(rx + 4, y + 50), P(rx + 8 - c * 10, y + 92 - c * 52)))
        case .supermarkt:
            return (Arm(P(lx - 4, y + 50), P(78, y + 70)), Arm(P(rx + 4, y + 50), P(122, y + 70)))
        case .laeuft:
            let s = w(7)
            let vl: CGFloat = max(0, -s)
            let vr: CGFloat = max(0, s)
            return (Arm(P(lx - 6, y + 50), P(lx - 4 + vl * 7, y + 90 - vl * 10)), Arm(P(rx + 6, y + 50), P(rx + 4 - vr * 7, y + 90 - vr * 10)))
        case .rennt:
            let s = w(12)
            return (Arm(P(lx - 12, y + 40), P(lx + 4, y + 30 + s * 14)), Arm(P(rx + 12, y + 40), P(rx - 4, y + 30 - s * 14)))
        case .rad:
            return (Arm(P(lx - 8, y + 40), P(66, y + 58)), Arm(P(rx + 8, y + 40), P(134, y + 58)))
        case .faehrt, .fahrschule:
            return (Arm(P(lx - 6, y + 44), amSteuer(200, y)), Arm(P(rx + 6, y + 44), amSteuer(340, y)))
        case .arbeit:
            let tipp: CGFloat = w(16) * 1.5
            return (Arm(P(lx - 6, y + 48), P(90, y + 78 + tipp)), Arm(P(rx + 6, y + 48), P(110, y + 78 - tipp)))
        case .zuhause, .schule, .schautVideo, .ruhe:
            return (Arm(P(lx - 6, y + 48), P(86, y + 84)), Arm(P(rx + 6, y + 48), P(114, y + 84)))
        default:
            // Z-23.3/Z-24.2: a bought pose/dance shows whenever nothing more specific is going on
            // (Profil, Karte, "ruhig", …) — it never overrides a real activity pose above.
            return poseGanzUeberschreibung(m) ?? (restL, restR)
        }
    }

    func amSteuer(_ grad: Double, _ y: CGFloat) -> CGPoint {
        let r = (grad + lenkWinkel) * Double.pi / 180
        return P(100 + 24 * CGFloat(cos(r)), y + 62 + 24 * CGFloat(sin(r)))
    }

    func kleinesHandy(_ g: GraphicsContext, _ c: CGPoint) {
        var h = g
        h.translateBy(x: c.x, y: c.y)
        h.scaleBy(x: 0.55, y: 0.55)
        handy(h, .zero, rueckseite: true)
    }

    func handRequisite(_ g: GraphicsContext, _ arme: (l: Arm, r: Arm), _ m: Masse) {
        let y = m.schulterY
        switch z {
        case .tippt, .liest, .spielt, .karte, .schautBild, .zeichnet, .laedt:
            kleinesHandy(g, P(100, y + 40))
        case .kamera:
            kleinesHandy(g, P(arme.r.hand.x, arme.r.hand.y - 12))
        case .sprache:
            kleinesHandy(g, P(arme.r.hand.x + 2, arme.r.hand.y - 8))
        case .gym:
            let h = arme.r.hand
            let stange = strich(P(h.x - 13, h.y), P(h.x + 13, h.y))
            linie(g, stange, Pal.silber.kontur, 5)
            linie(g, stange, Pal.silber.farbe, 3)
            teil(g, box(h.x - 19, h.y - 8, 6, 16, 2), Pal.dunkel, 2)
            teil(g, box(h.x + 13, h.y - 8, 6, 16, 2), Pal.dunkel, 2)
        case .herz:
            let p = Double(zyklus(1.0))
            let a1 = exp(-pow((p - 0.1) / 0.06, 2))
            let a2 = exp(-pow((p - 0.3) / 0.06, 2))
            let schlag = CGFloat(1 + 0.14 * a1 + 0.09 * a2)
            teil(g, herzPfad(P(100, y + 24), 14 * schlag), Pal.rose, 2.5)
        default:
            break
        }
    }

    // MARK: Scenes

    func szeneHinten(_ g: GraphicsContext, _ m: Masse, _ oben: CGFloat) {
        let sitz = m.hueftY + oben
        switch z {
        case .zuhause, .schautVideo, .ruhe:
            teil(g, box(6, sitz - 112, 188, 118, 30), Pal.sofa)
            teil(g, box(16, sitz - 102, 82, 98, 22), Pal.sofa.mix(Pal.weiss, 0.15))
            teil(g, box(102, sitz - 102, 82, 98, 22), Pal.sofa.mix(Pal.weiss, 0.15))
            for x in [CGFloat(22), 178] { linie(g, strich(P(x, sitz + 40), P(x, 384)), Pal.holz.kontur, 6) }
            teil(g, box(0, sitz - 6, 200, 48, 16), Pal.sofa.mal(0.92))
            teil(g, box(-10, sitz - 54, 36, 92, 14), Pal.sofa.mal(0.85))
            teil(g, box(174, sitz - 54, 36, 92, 14), Pal.sofa.mal(0.85))
        case .schule, .arbeit:
            for x in [CGFloat(74), 126] {
                let fuss: CGFloat = x < 100 ? x - 6 : x + 6
                linie(g, strich(P(x, sitz + 8), P(fuss, 384)), Pal.holz.kontur, 5)
            }
            teil(g, box(64, sitz - 2, 72, 12, 6), Pal.holz)
        default:
            break
        }
    }

    func vorArmen(_ g: GraphicsContext, _ u: GraphicsContext, _ m: Masse, _ oben: CGFloat) {
        let sY = m.schulterY
        let sitz = m.hueftY + oben
        switch z {
        case .rad:
            let lenkY: CGFloat = sY + oben + 58
            let reifen = oval(P(100, 336), 8, 38)
            linie(g, reifen, Pal.dunkel.kontur, 10)
            linie(g, reifen, Pal.dunkel.farbe, 6)
            let gabel = strich(P(100, lenkY + 4), P(100, 336))
            linie(g, gabel, Pal.silber.kontur, 7)
            linie(g, gabel, Pal.silber.farbe, 4)
            let lenker = bogen(P(56, lenkY - 6), P(144, lenkY - 6), P(100, lenkY + 10))
            linie(g, lenker, Pal.dunkel.kontur, 8)
            linie(g, lenker, Pal.silber.farbe, 4.5)
            teil(g, kreis(P(100, lenkY + 12), 6), Pal.gelb, 2)
        case .faehrt, .fahrschule:
            var h = u
            h.translateBy(x: 100, y: sY + 62)
            h.rotate(by: .degrees(lenkWinkel))
            linie(h, kreis(.zero, 24), Pal.dunkel.kontur, 9)
            linie(h, kreis(.zero, 24), Pal.dunkel.farbe, 5.5)
            for grad in [90.0, 210, 330] {
                let r = grad * Double.pi / 180
                linie(h, strich(.zero, P(24 * CGFloat(cos(r)), 24 * CGFloat(sin(r)))), Pal.dunkel.farbe, 4)
            }
            teil(h, kreis(.zero, 7), Pal.dunkel, 2)
        case .supermarkt:
            einkaufswagen(g, griffY: sY + 70)
        case .arbeit:
            teil(g, box(66, sitz - 60, 68, 48, 6), Pal.silber)
            g.fill(herzPfad(P(100, sitz - 36), 6), with: .color(Pal.rose.farbe))
            teil(g, box(60, sitz - 14, 80, 8, 3), Pal.silber.mal(0.85), 2.5)
        case .schule:
            teil(g, box(72, sitz - 22, 56, 16, 3), Pal.rose, 2.5)
            teil(g, box(75, sitz - 25, 25, 14, 2), Pal.weiss, 1.5)
            teil(g, box(100, sitz - 25, 25, 14, 2), Pal.weiss, 1.5)
        case .ruhe:
            teil(g, box(34, sitz - 34, 132, 72, 24), Pal.decke)
        default:
            break
        }
    }

    func einkaufswagen(_ g: GraphicsContext, griffY: CGFloat) {
        let rand = griffY + 6
        let korb = Path { p in
            p.move(to: P(44, rand))
            p.addLine(to: P(156, rand))
            p.addLine(to: P(146, rand + 64))
            p.addLine(to: P(54, rand + 64))
            p.closeSubpath()
        }
        for x in [CGFloat(60), 140] { linie(g, strich(P(x, rand + 64), P(x, 372)), Pal.silber.kontur, 3.5) }
        for x in [CGFloat(60), 140] { teil(g, kreis(P(x, 376), 6), Pal.dunkel, 2) }
        teil(g, kreis(P(76, rand - 2), 8), Pal.gruen, 2)
        var brot = g
        brot.translateBy(x: 108, y: rand - 8)
        brot.rotate(by: .degrees(18))
        teil(brot, oval(.zero, 7, 18), Pal.brot, 2.5)
        teil(g, kreis(P(132, rand - 2), 8), Pal.rose, 2)
        g.fill(korb, with: .color(Pal.silber.farbe.opacity(0.45)))
        var k = g
        k.clip(to: korb)
        for x in stride(from: CGFloat(48), to: 156, by: 12) { linie(k, strich(P(x, rand), P(x, rand + 64)), Pal.silber.kontur, 2) }
        for y in stride(from: rand + 12, to: rand + 64, by: 12) { linie(k, strich(P(40, y), P(160, y)), Pal.silber.kontur, 2) }
        linie(g, korb, Pal.silber.kontur, 3)
        let griff = strich(P(40, griffY), P(160, griffY))
        linie(g, griff, Pal.rose.kontur, 8)
        linie(g, griff, Pal.rose.farbe, 5)
    }

    /// Convertible seen from the front; drawn over the lower body, the hands stay on the wheel.
    func auto(_ g: GraphicsContext, _ m: Masse, _ oben: CGFloat) {
        guard z == .faehrt || z == .fahrschule else { return }
        let dach: CGFloat = m.schulterY + oben + 80
        for x in [CGFloat(16), 150] { teil(g, box(x, 356, 34, 30, 9), Pal.dunkel) }
        let karosserie = Path { p in
            p.move(to: P(10, 372))
            p.addLine(to: P(10, dach + 28))
            p.addQuadCurve(to: P(40, dach), control: P(12, dach))
            p.addLine(to: P(160, dach))
            p.addQuadCurve(to: P(190, dach + 28), control: P(188, dach))
            p.addLine(to: P(190, 372))
            p.closeSubpath()
        }
        teil(g, karosserie, Pal.rose)
        for x in [CGFloat(42), 158] {
            teil(g, kreis(P(x, dach + 38), 12), Pal.weiss, 2.5)
            g.fill(kreis(P(x, dach + 38), 6), with: .color(Pal.gelb.farbe))
        }
        teil(g, box(72, dach + 44, 56, 18, 7), Pal.dunkel, 2.5)
        teil(g, box(4, 356, 192, 18, 9), Pal.silber)
        if z == .fahrschule {
            teil(g, box(88, dach + 6, 24, 24, 4), Pal.weiss, 2.5)
            text(g, "L", P(100, dach + 18), 18, Pal.rose.farbe)
        }
    }

    func tempoStriche(_ g: GraphicsContext, _ y0: CGFloat) {
        for i in 0..<3 {
            let y: CGFloat = y0 + 30 + CGFloat(i) * 22
            let x: CGFloat = 6 + zyklus(0.5, Double(i) * 0.17) * 10
            linie(g, strich(P(x, y), P(x + 20, y)), Pal.silber.kontur.opacity(0.7), 3.5)
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
        let reihen: [(String, WritableKeyPath<FigurAussehen, Int>, Int, Bool)] = [
            ("Gesichtsform", \.gesichtsform, FigurAussehen.gesichtsformen.count, false),
            ("Haut", \.haut, FigurAussehen.hautToene.count, false),
            ("Frisur", \.frisur, FigurAussehen.frisuren.count, false),
            ("Haarfarbe", \.haarfarbe, FigurAussehen.haarfarben.count, false),
            ("Augenform", \.augenform, FigurAussehen.augenformen.count, false),
            ("Augenbrauen", \.brauen, FigurAussehen.augenbrauen.count, false),
            ("Nase", \.nase, FigurAussehen.nasen.count, false),
            ("Mund", \.mund, FigurAussehen.muender.count, false),
            ("Brille", \.brille, FigurAussehen.brillen.count, false),
            ("Bart", \.bart, FigurAussehen.baerte.count, false),
            ("Ohrringe", \.ohrringe, FigurAussehen.ohrringArten.count, false),
            ("Kopfbedeckung", \.kopfbedeckung, FigurAussehen.kopfbedeckungen.count, false),
            ("Oberteil", \.oberteil, FigurAussehen.oberteile.count, true),
            ("Jacke", \.jacke, FigurAussehen.jacken.count, true),
            ("Hose", \.hose, FigurAussehen.hosen.count, true),
            ("Schuhe", \.schuhe, FigurAussehen.schuhArten.count, true),
            ("Körperform", \.koerperform, FigurAussehen.koerperformen.count, true),
            ("Größe", \.groesse, FigurAussehen.groessen.count, true),
        ]
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(reihen.indices, id: \.self) { i in
                    Text(reihen[i].0).font(.headline)
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(0..<reihen[i].2, id: \.self) { n in
                                FigurView(variante(basis, reihen[i].1, n), zustand: .ruhig, groesse: reihen[i].3 ? 160 : 96, animiert: false, ganzkoerper: reihen[i].3)
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

#Preview("Ganzkörper") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
            ForEach(FigurZustand.allCases, id: \.self) { z in
                VStack {
                    FigurView(.standard(for: .annika), zustand: z, groesse: 200, ganzkoerper: true)
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
