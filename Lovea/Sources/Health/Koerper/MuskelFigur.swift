import SwiftUI
import UIKit

/// Path data of the cartoon muscle figure, ported 1:1 from `design/erholung/erholung.html` (`R`,
/// `BASIS_MITTE`, `BASIS_SEITE`, `HOSE`, `glatt`, `spiegel`, `faktor`, `kurz`). The numbers are the
/// left half as x, y pairs; the right half is mirrored. Built once per person type (`ahmed`, `annika`).
enum MuskelPfade {
    enum Seite: Sendable { case vorne, hinten }

    /// One muscle surface, both halves in one path, already in figure space.
    struct Flaeche: Sendable {
        let teil: MuskelTeil
        let seite: Seite
        let pfad: Path
    }

    /// Everything one person type needs to draw and hit-test.
    struct Figur: Sendable {
        let koerper: [Path]
        let schuhe: [Path]
        let hose: Path
        let flaechen: [Flaeche]

        init(frau: Bool) {
            let tf: (CGPoint) -> CGPoint = { p in
                MuskelPfade.kurz(frau ? P(120 + (p.x - 120) * MuskelPfade.faktor(p.y), p.y) : p)
            }
            let pfad: ([CGPoint]) -> Path = { MuskelPfade.glatt($0.map(tf)) }
            let paar: ([CGPoint]) -> [Path] = { [pfad($0), pfad($0.map(MuskelPfade.spiegel))] }
            func sammle(_ roh: [MuskelPfade.Roh], _ seite: Seite) -> [Flaeche] {
                roh.map { r in
                    var p = pfad(r.punkte)
                    p.addPath(pfad(r.punkte.map(MuskelPfade.spiegel)))
                    return Flaeche(teil: r.teil, seite: seite, pfad: p)
                }
            }
            koerper = MuskelPfade.basisMitte.map(pfad) + MuskelPfade.basisSeite.dropLast().flatMap(paar)
            schuhe = paar(MuskelPfade.basisSeite[4])
            hose = pfad(MuskelPfade.hose)
            flaechen = sammle(MuskelPfade.roheVorne, .vorne) + sammle(MuskelPfade.roheHinten, .hinten)
        }

        /// The topmost muscle at a point in figure space (drawn last = on top), either half.
        func teil(bei p: CGPoint, hinten: Bool) -> MuskelTeil? {
            let seite = hinten ? Seite.hinten : Seite.vorne
            return flaechen.last(where: { $0.seite == seite && $0.pfad.contains(p) })?.teil
        }

        /// Which side shows a group: the one that holds `teil` (front if both do), else the one with more of the group.
        func hinten(fuer g: MuskelGruppe, teil: MuskelTeil?) -> Bool {
            if let teil, teil.gruppe == g {
                return !flaechen.contains(where: { $0.seite == .vorne && $0.teil == teil })
            }
            let vorne = flaechen.filter { $0.seite == .vorne && $0.teil.gruppe == g }.count
            return flaechen.filter { $0.seite == .hinten && $0.teil.gruppe == g }.count > vorne
        }
    }

    static let ahmed = Figur(frau: false)
    static let annika = Figur(frau: true)

    static func figur(_ p: Person) -> Figur { p == .annika ? annika : ahmed }

    /// The drawn area (SVG viewBox `8 -4 224 428` of the draft, plus 8 above for the curls).
    static let rahmen = CGRect(x: 8, y: -12, width: 224, height: 436)

    /// Chibi head width in figure space (front), Annika's is narrower.
    static func kopfBreite(_ p: Person) -> CGFloat { p == .annika ? 118 : 124 }

    // MARK: Helpers from the draft

    static func spiegel(_ p: CGPoint) -> CGPoint { P(240 - p.x, p.y) }

    /// Chibi: torso 0.86, legs 0.5 (from y 250 on), 1.1 wider, whole figure moved down by 48.
    static func kurz(_ p: CGPoint) -> CGPoint {
        let y = p.y <= 90 ? p.y : p.y <= 250 ? 90 + (p.y - 90) * 0.86 : 227.6 + (p.y - 250) * 0.5
        return P(120 + (p.x - 120) * 1.1, y + 48)
    }

    /// Woman figure: width factor per height.
    static func faktor(_ y: CGFloat) -> CGFloat {
        for i in 1..<frauenBreite.count {
            let (a, fa) = frauenBreite[i - 1]
            let (b, fb) = frauenBreite[i]
            if y <= b { return fa + (fb - fa) * (y - a) / (b - a) }
        }
        return 1
    }

    /// Closed Catmull-Rom curve through the points, as Bézier segments.
    static func glatt(_ p: [CGPoint]) -> Path {
        let n = p.count
        return Path { pfad in
            pfad.move(to: p[0])
            for i in 0..<n {
                let p0 = p[(i - 1 + n) % n], p1 = p[i], p2 = p[(i + 1) % n], p3 = p[(i + 2) % n]
                pfad.addCurve(
                    to: p2,
                    control1: P(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6),
                    control2: P(p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6)
                )
            }
            pfad.closeSubpath()
        }
    }

    private static let frauenBreite: [(CGFloat, CGFloat)] = [
        (0, 0.94), (60, 0.94), (92, 0.85), (140, 0.86), (215, 0.88), (262, 1.14), (330, 1.1), (400, 1), (540, 0.96),
    ]

    private static func punkte(_ f: [CGFloat]) -> [CGPoint] {
        stride(from: 0, to: f.count - 1, by: 2).map { P(f[$0], f[$0 + 1]) }
    }

    /// Left half plus its mirror, without the two points on the middle line.
    private static func sym(_ l: [CGPoint]) -> [CGPoint] {
        l + l.dropFirst().dropLast().reversed().map(spiegel)
    }

    private typealias Roh = (teil: MuskelTeil, punkte: [CGPoint])

    private static func poly(_ t: MuskelTeil, _ f: [CGFloat]) -> Roh { (t, punkte(f)) }

    /// Rounded rectangle as eight points (`rrect` of the draft).
    private static func rect(_ t: MuskelTeil, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ r: CGFloat) -> Roh {
        (t, [P(x1 + r, y1), P(x2 - r, y1), P(x2, y1 + r), P(x2, y2 - r), P(x2 - r, y2), P(x1 + r, y2), P(x1, y2 - r), P(x1, y1 + r)])
    }

    // MARK: Data

    // ponytail: `BASIS_MITTE[0]` (Kopf-Oval) und `BASIS_SEITE[0]` (Ohr) entfallen, der Kopf kommt aus FigurView (MuskelSeite.kopf).
    /// BASIS_MITTE: Hals, Rumpf.
    private static let basisMitte: [[CGPoint]] = [
        sym(punkte([120, 54, 108, 54, 106, 82, 120, 84])),
        sym(punkte([120, 78, 104, 79, 86, 86, 70, 96, 64, 110, 72, 128, 82, 142, 86, 180, 88, 214, 86, 240, 82, 262, 90, 280, 108, 290, 120, 292])),
    ]

    /// BASIS_SEITE: Oberarm, Unterarm, Hand, Bein, Schuh (linke Seite).
    private static let basisSeite: [[CGPoint]] = [
        punkte([66, 98, 56, 104, 48, 122, 46, 150, 50, 186, 58, 198, 72, 196, 80, 172, 82, 140, 80, 116, 74, 102]),
        punkte([48, 190, 42, 214, 42, 244, 48, 282, 56, 290, 66, 288, 72, 254, 76, 222, 74, 196, 62, 190]),
        punkte([48, 282, 44, 298, 46, 318, 54, 332, 62, 330, 68, 312, 68, 292, 60, 284]),
        punkte([82, 258, 76, 288, 76, 330, 82, 370, 86, 394, 82, 420, 84, 452, 92, 488, 96, 502, 112, 504, 112, 488, 110, 456, 114, 420, 114, 396, 118, 360, 120, 322, 120, 290, 104, 280]),
        punkte([94, 492, 86, 508, 92, 518, 112, 518, 114, 500, 112, 490]),
    ]

    /// HOSE: Shorts, als Umriss über die Mittellinie gespiegelt.
    private static let hose: [CGPoint] = sym(punkte([120, 232, 100, 233, 88, 236, 84, 262, 80, 290, 98, 297, 114, 301, 120, 301]))

    /// R, Vorderseite. Reihenfolge = Zeichenreihenfolge, das Letzte liegt oben.
    private static let roheVorne: [Roh] = [
        poly(.nVorne, [108, 62, 112, 60, 119, 84, 114, 86]),
        poly(.rTrapezOben, [106, 70, 108, 80, 96, 88, 78, 94, 86, 86]),
        poly(.sVorne, [86, 92, 76, 94, 68, 104, 68, 122, 74, 128, 82, 116, 88, 102]),
        poly(.sSeitlich, [72, 94, 62, 98, 52, 110, 50, 128, 56, 136, 64, 124, 66, 106]),
        poly(.bOben, [118, 90, 102, 88, 90, 96, 88, 108, 102, 112, 118, 110]),
        poly(.bUnten, [118, 113, 102, 115, 88, 111, 85, 124, 92, 138, 106, 143, 118, 141]),
        poly(.baSeitlich, [86, 142, 96, 146, 102, 152, 102, 196, 100, 230, 92, 238, 88, 212, 86, 176]),
        rect(.baGerade, 104, 146, 118, 164, 4),
        rect(.baGerade, 104, 167, 118, 186, 4),
        rect(.baGerade, 104, 189, 118, 208, 4),
        rect(.baGerade, 104, 211, 118, 248, 6),
        poly(.biLang, [58, 138, 64, 132, 67, 160, 65, 188, 59, 186, 55, 164]),
        poly(.biKurz, [67, 132, 76, 138, 79, 164, 73, 188, 68, 188, 69, 160]),
        poly(.uSpeiche, [46, 196, 57, 195, 60, 212, 55, 240, 49, 262, 45, 240, 44, 214]),
        poly(.uBeuger, [60, 198, 73, 198, 75, 222, 68, 252, 60, 282, 52, 282, 56, 262, 62, 236, 62, 212]),
        poly(.beQuads, [83, 272, 90, 280, 94, 320, 95, 358, 89, 372, 81, 350, 79, 310]),
        poly(.beQuads, [96, 282, 108, 290, 106, 330, 102, 364, 96, 362, 94, 330, 93, 298]),
        poly(.beQuads, [107, 336, 113, 344, 112, 372, 104, 380, 99, 372, 103, 352]),
        poly(.beAdd, [110, 290, 118, 300, 118, 322, 113, 334, 108, 318]),
        poly(.beWaden, [85, 404, 91, 400, 93, 430, 91, 458, 87, 440, 84, 420]),
        poly(.beWaden, [95, 402, 103, 402, 104, 440, 100, 476, 96, 468, 95, 430]),
        poly(.beWaden, [108, 404, 113, 406, 112, 440, 108, 452, 106, 430]),
    ]

    /// R, Rückseite.
    private static let roheHinten: [Roh] = [
        poly(.nHinten, [110, 58, 119, 58, 119, 76, 112, 78, 108, 66]),
        poly(.rTrapezOben, [119, 78, 112, 78, 104, 84, 90, 90, 76, 96, 92, 100, 110, 98, 119, 98]),
        poly(.rTrapezUnten, [119, 101, 108, 101, 98, 106, 104, 128, 112, 160, 119, 178]),
        poly(.sHinten, [76, 99, 64, 104, 58, 118, 66, 128, 78, 120, 88, 106]),
        poly(.sSeitlich, [62, 100, 54, 108, 50, 124, 53, 136, 59, 126, 62, 112]),
        poly(.rOben, [96, 108, 86, 113, 82, 126, 88, 138, 102, 140, 103, 126, 100, 113]),
        poly(.rLat, [80, 136, 88, 143, 104, 146, 110, 168, 114, 200, 108, 226, 98, 232, 92, 214, 88, 184, 82, 158]),
        poly(.rUnten, [112, 182, 118, 182, 118, 254, 110, 256, 104, 236, 108, 210]),
        poly(.triLang, [67, 130, 78, 130, 80, 152, 76, 176, 70, 184, 66, 160]),
        poly(.triSeitlich, [53, 128, 64, 128, 66, 156, 62, 180, 56, 170, 52, 148]),
        poly(.triMittel, [60, 182, 72, 184, 70, 194, 62, 194]),
        poly(.uStrecker, [46, 198, 72, 198, 73, 222, 65, 258, 57, 282, 50, 280, 46, 240, 44, 214]),
        poly(.bePo, [84, 260, 100, 258, 118, 264, 118, 316, 104, 322, 88, 316, 80, 292]),
        poly(.beBeuger, [82, 322, 96, 326, 98, 380, 90, 378, 84, 360, 80, 340]),
        poly(.beBeuger, [100, 326, 114, 324, 114, 350, 108, 378, 102, 382]),
        poly(.beWaden, [86, 398, 96, 396, 98, 436, 94, 452, 88, 440, 84, 420]),
        poly(.beWaden, [100, 396, 114, 398, 114, 428, 108, 452, 102, 448, 100, 420]),
        poly(.beWaden, [92, 456, 108, 456, 106, 480, 98, 482]),
    ]
}

/// One side of the figure as a Canvas drawing (`figurSvg` of the draft, without the front head).
/// Back hair is scaled 1.28 around (120, 0) like in the draft.
/// Pure values only, so the Canvas closure captures nothing that is actor-isolated.
struct MuskelAnsicht: Sendable {
    let person: Person
    let hinten: Bool
    let farben: [MuskelTeil: Color]
    let markiert: MuskelTeil?
    let fokus: MuskelGruppe?
    let gedrueckt: MuskelTeil?

    private static let tinte = FigurFarbe(0x4A3128).farbe
    private static let fremd = FigurFarbe(0xD8B195).farbe
    private static let hose = FigurFarbe(0x2E2E36).farbe
    private static let sneaker = FigurFarbe(0xF5F5F7).farbe
    private static let hautAhmed = FigurFarbe(0xF1C3A0).farbe
    private static let hautAnnika = FigurFarbe(0xF7D0B6).farbe
    private static let haarAhmed = FigurFarbe(0x2A201D).farbe
    private static let haarAnnika = FigurFarbe(0x4B2E22).farbe
    private static let scheitel = FigurFarbe(0x6B4434).farbe

    func zeichne(_ ctx: GraphicsContext, _ size: CGSize) {
        var g = ctx
        let r = MuskelPfade.rahmen
        let s = size.width / r.width
        g.scaleBy(x: s, y: s)
        g.translateBy(x: -r.minX, y: -r.minY)
        let figur = MuskelPfade.figur(person)
        let haut = person == .annika ? Self.hautAnnika : Self.hautAhmed

        g.fill(oval(P(120, MuskelPfade.kurz(P(0, 518)).y + 6), 58, 7), with: .color(Color.black.opacity(0.35)))
        let umriss = StrokeStyle(lineWidth: 5, lineJoin: .round)
        for p in figur.koerper {
            g.fill(p, with: .color(haut))
            g.stroke(p, with: .color(Self.tinte), style: umriss)
        }
        for p in figur.koerper { g.fill(p, with: .color(haut)) }
        g.fill(figur.hose, with: .color(Self.hose))
        g.stroke(figur.hose, with: .color(Self.tinte), style: StrokeStyle(lineWidth: 2))
        let sohle = StrokeStyle(lineWidth: 2.4, lineJoin: .round)
        for p in figur.schuhe {
            g.fill(p, with: .color(Self.sneaker))
            g.stroke(p, with: .color(Self.tinte), style: sohle)
        }
        muskeln(g, figur)
        if hinten { haare(g) }
    }

    private func muskeln(_ g: GraphicsContext, _ figur: MuskelPfade.Figur) {
        let seite = hinten ? MuskelPfade.Seite.hinten : MuskelPfade.Seite.vorne
        let rand = StrokeStyle(lineWidth: 1.5, lineJoin: .round)
        for f in figur.flaechen where f.seite == seite {
            let weiss = fokus == nil && f.teil == markiert
            g.fill(f.pfad, with: .color(fuellung(f.teil)))
            g.stroke(f.pfad, with: .color(weiss ? Color.white : Self.tinte), style: rand)
        }
    }

    /// Own color per part. With `fokus`, other groups turn skin-gray and the marked part white.
    private func fuellung(_ t: MuskelTeil) -> Color {
        var c = farben[t, default: Color.clear]
        if let fokus {
            c = t.gruppe != fokus ? Self.fremd : (t == markiert ? Color.white : c)
        }
        return t == gedrueckt ? c.opacity(0.72) : c
    }

    private func haare(_ ctx: GraphicsContext) {
        var g = ctx
        g.translateBy(x: 120, y: 0)
        g.scaleBy(x: 1.28, y: 1.28)
        g.translateBy(x: -120, y: 0)
        let kontur = StrokeStyle(lineWidth: 2.4)
        if person == .annika {
            let lang = Path { p in
                p.move(to: P(76, 40))
                p.addCurve(to: P(120, 2), control1: P(76, 14), control2: P(96, 2))
                p.addCurve(to: P(164, 40), control1: P(144, 2), control2: P(164, 14))
                p.addLine(to: P(164, 116))
                p.addCurve(to: P(149, 126), control1: P(164, 124), control2: P(157, 128))
                p.addLine(to: P(138, 121))
                p.addLine(to: P(120, 126))
                p.addLine(to: P(102, 121))
                p.addLine(to: P(91, 126))
                p.addCurve(to: P(76, 116), control1: P(83, 128), control2: P(76, 124))
                p.closeSubpath()
            }
            g.fill(lang, with: .color(Self.haarAnnika))
            g.stroke(lang, with: .color(Self.tinte), style: kontur)
            g.stroke(strich(P(120, 6), P(120, 46)), with: .color(Self.scheitel), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        } else {
            let form = oval(P(120, 44), 44, 42)
            g.fill(form, with: .color(Self.haarAhmed))
            g.stroke(form, with: .color(Self.tinte), style: kontur)
            for mitte in [P(86, 24), P(100, 10), P(120, 5), P(140, 10), P(154, 24), P(82, 46), P(158, 46)] {
                let locke = kreis(mitte, 12)
                g.fill(locke, with: .color(Self.haarAhmed))
                g.stroke(locke, with: .color(Self.tinte), style: kontur)
            }
            g.fill(oval(P(120, 46), 40, 37), with: .color(Self.haarAhmed))
        }
    }
}

/// One side of the muscle figure, standing still. Front: head from `KopfFigur`. Back: hair.
/// The Körper sheet can put a front and a back next to each other with this (as in the draft).
struct MuskelSeite: View {
    let person: Person
    let hinten: Bool
    let farbe: (MuskelTeil) -> Color
    var markiert: MuskelTeil?
    var fokus: MuskelGruppe?
    var gedrueckt: MuskelTeil?
    var animiert = true

    var body: some View {
        let ansicht = MuskelAnsicht(
            person: person, hinten: hinten,
            farben: Dictionary(uniqueKeysWithValues: MuskelTeil.allCases.map { ($0, farbe($0)) }),
            markiert: markiert, fokus: fokus, gedrueckt: gedrueckt
        )
        GeometryReader { geo in
            let s = geo.size.width / MuskelPfade.rahmen.width
            ZStack {
                Canvas { g, size in ansicht.zeichne(g, size) }
                if !hinten {
                    kopf(MuskelPfade.kopfBreite(person) * s)
                        .position(x: (120 - MuskelPfade.rahmen.minX) * s, y: (MuskelPfade.kopfBreite(person) / 2 - MuskelPfade.rahmen.minY) * s)
                }
            }
        }
        .aspectRatio(MuskelPfade.rahmen.width / MuskelPfade.rahmen.height, contentMode: .fit)
    }

    /// `KopfFigur` without the blue circle and the black collar: the head only, cut by an ellipse at the top.
    private func kopf(_ groesse: CGFloat) -> some View {
        let anzeige = FigurenModell.shared.anzeige(person)
        return FigurView(FigurenModell.shared.aussehen(person), zustand: anzeige.haupt, abzeichen: anzeige.abzeichen, groesse: groesse * 1.35, animiert: animiert, bildrate: 20)
            .frame(width: groesse, height: groesse, alignment: .top)
            .clipShape(.ellipse)
    }
}

/// The turnable cartoon muscle figure (Erholung, Körper tab). Drag turns 1:1 (1.1 deg per pt) and
/// swings on with a spring, a tap turns by 180 deg, a tap on a muscle reports its `MuskelTeil`.
/// With `fokus` (the sheet of one muscle group) the figure does not turn: it shows the side that
/// holds `markiert` or the group, other groups are skin-gray and `markiert` is white.
struct MuskelFigur: View {
    let person: Person
    let farbe: (MuskelTeil) -> Color
    let markiert: MuskelTeil?
    let fokus: MuskelGruppe?
    let onTipp: ((MuskelTeil) -> Void)?
    let animiert: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lauf: Lauf
    @State private var laeuft = false
    @State private var zug: Zug? = nil
    @State private var gedrueckt: MuskelTeil? = nil

    /// The turn as a damped spring in closed form (period 0.42 s, damping 0.8, as in the draft).
    /// The angle is a pure function of time: a touch in mid-flight picks the figure up where it is,
    /// and the side that shows always matches the drawn angle.
    private struct Lauf {
        static let dauer = 1.2
        var von: Double
        var tempo = 0.0
        var ziel: Double
        var seit = Date.distantPast

        static func ruhig(_ w: Double) -> Lauf { Lauf(von: w, ziel: w) }

        func winkel(_ jetzt: Date) -> Double {
            let t = jetzt.timeIntervalSince(seit)
            if t <= 0 { return von }
            if t >= Self.dauer { return ziel }
            let w0 = 2 * Double.pi / 0.42, z = 0.8
            let wd = w0 * (1 - z * z).squareRoot()
            let a = von - ziel
            return ziel + exp(-z * w0 * t) * (a * cos(wd * t) + (tempo + z * w0 * a) / wd * sin(wd * t))
        }
    }

    /// One touch from finger down to finger up.
    private struct Zug {
        enum Art { case tippen, drehen, scrollen }
        var art = Art.tippen
        let ort: CGPoint
        let von: Double
        var zeit: Date
        var x: CGFloat = 0
        var tempo = 0.0
    }

    /// `animiert` turns the figure in once from -34 deg to the front, as in the draft.
    init(
        person: Person, farbe: @escaping (MuskelTeil) -> Color, markiert: MuskelTeil? = nil,
        fokus: MuskelGruppe? = nil, onTipp: ((MuskelTeil) -> Void)? = nil, animiert: Bool = true
    ) {
        self.person = person
        self.farbe = farbe
        self.markiert = markiert
        self.fokus = fokus
        self.onTipp = onTipp
        self.animiert = animiert
        _lauf = State(initialValue: .ruhig(animiert && fokus == nil ? -34 : 0))
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: !laeuft)) { kontext in
                let w = winkel(kontext.date)
                figur(geo.size, w)
                    .overlay(alignment: .bottomTrailing) { knopf(w) }
            }
        }
        .aspectRatio(MuskelPfade.rahmen.width / MuskelPfade.rahmen.height, contentMode: .fit)
        .onAppear { einblenden() }
        // Pauses the timeline once the spring has settled; a new spring restarts this task.
        .task(id: lauf.seit) {
            let warte = lauf.seit.timeIntervalSinceNow + Lauf.dauer
            if warte > 0 {
                do { try await Task.sleep(for: .seconds(warte)) } catch { return }
            }
            laeuft = false
        }
    }

    private static func zeigtVorne(_ w: Double) -> Bool { cos(w * .pi / 180) >= 0 }

    /// The angle at `jetzt`. With `fokus` the figure stands still on the side that shows the muscle.
    private func winkel(_ jetzt: Date) -> Double {
        guard let fokus else { return lauf.winkel(jetzt) }
        return MuskelPfade.figur(person).hinten(fuer: fokus, teil: markiert) ? 180 : 0
    }

    private func figur(_ groesse: CGSize, _ w: Double) -> some View {
        let vorne = Self.zeigtVorne(w)
        return ZStack {
            seite(hinten: false).opacity(vorne ? 1 : 0)
            seite(hinten: true)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(vorne ? 0 : 1)
        }
        .rotation3DEffect(.degrees(w), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        // The gesture sits outside the turning view, so its coordinates do not turn with it.
        .contentShape(Rectangle())
        // ponytail: simultaneous, so a vertical drag on the figure still scrolls the page.
        .simultaneousGesture(geste(groesse))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.name), Muskeln von \(vorne ? "vorne" : "hinten")")
    }

    private func seite(hinten: Bool) -> MuskelSeite {
        MuskelSeite(person: person, hinten: hinten, farbe: farbe, markiert: markiert, fokus: fokus, gedrueckt: gedrueckt, animiert: animiert)
    }

    @ViewBuilder private func knopf(_ w: Double) -> some View {
        if fokus == nil {
            VStack(spacing: 2) {
                Button {
                    Haptik.leicht()
                    drehen()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(Color(uiColor: .tertiarySystemFill), in: .circle)
                }
                .buttonStyle(.federnd)
                .accessibilityLabel("Figur drehen")
                Text(Self.zeigtVorne(w) ? "Vorne" : "Hinten")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: Turning

    private func geste(_ groesse: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { wert in beruehren(wert, groesse) }
            .onEnded { wert in loslassen(wert, groesse) }
    }

    private func beruehren(_ wert: DragGesture.Value, _ groesse: CGSize) {
        // A touch the scroll view took never ends here: a new start point means a new touch.
        if zug?.ort != wert.startLocation { zug = nil }
        var z = zug ?? anfassen(wert, groesse)
        let dx = wert.translation.width, dy = wert.translation.height
        if z.art == .tippen, max(abs(dx), abs(dy)) > 8 {
            z.art = abs(dx) > abs(dy) && fokus == nil ? .drehen : .scrollen
            gedrueckt = nil
        }
        if z.art == .drehen {
            let dt = wert.time.timeIntervalSince(z.zeit)
            // ponytail: smoothed speed instead of the draft's window of six samples.
            if dt > 0 { z.tempo = z.tempo * 0.6 + Double(dx - z.x) / dt * 1.1 * 0.4 }
            z.zeit = wert.time
            z.x = dx
            lauf = .ruhig(z.von + Double(dx) * 1.1)
        }
        zug = z
    }

    /// Finger down: stops a turn in flight and notes the muscle under the finger.
    private func anfassen(_ wert: DragGesture.Value, _ groesse: CGSize) -> Zug {
        let w = winkel(wert.time)
        if fokus == nil { lauf = .ruhig(w) }
        gedrueckt = onTipp == nil ? nil : muskel(bei: wert.startLocation, groesse, w)
        return Zug(ort: wert.startLocation, von: w, zeit: wert.time)
    }

    private func loslassen(_ wert: DragGesture.Value, _ groesse: CGSize) {
        guard let z = zug else { return }
        zug = nil
        gedrueckt = nil
        let w = winkel(wert.time)
        switch z.art {
        case .drehen:
            let tempo = wert.time.timeIntervalSince(z.zeit) < 0.08 ? z.tempo : 0
            springe(zu: ((w + tempo * 0.099) / 180).rounded() * 180, tempo: tempo)
        case .tippen:
            if let onTipp, let teil = muskel(bei: wert.location, groesse, w) {
                Haptik.auswahl()
                onTipp(teil)
            } else if fokus == nil {
                Haptik.leicht()
                drehen()
            }
        case .scrollen:
            break
        }
    }

    /// Exact while the figure stands still, a good guess in flight.
    private func muskel(bei ort: CGPoint, _ groesse: CGSize, _ w: Double) -> MuskelTeil? {
        let r = MuskelPfade.rahmen
        let s = r.width / groesse.width
        return MuskelPfade.figur(person).teil(bei: P(r.minX + ort.x * s, r.minY + ort.y * s), hinten: !Self.zeigtVorne(w))
    }

    /// Starts the spring from wherever the figure is now. Reduce Motion: it just jumps.
    private func springe(zu ziel: Double, tempo: Double = 0, verzoegert: TimeInterval = 0) {
        if reduceMotion {
            lauf = .ruhig(ziel)
        } else {
            lauf = Lauf(von: lauf.winkel(Date()), tempo: tempo, ziel: ziel, seit: Date().addingTimeInterval(verzoegert))
            laeuft = true
        }
    }

    private func drehen() { springe(zu: (lauf.winkel(Date()) / 180).rounded() * 180 + 180) }

    private func einblenden() {
        if animiert, fokus == nil { springe(zu: 0, verzoegert: 0.16) }
    }
}
