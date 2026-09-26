import SwiftUI
import UIKit

/// Path data of the cartoon muscle figure, ported from `design/erholung/erholung.html` (`R`, `BASIS_MITTE`,
/// `BASIS_SEITE`, `HOSE`, `glatt`, `spiegel`, `faktor`, `kurz`). The numbers are the left half as x, y
/// pairs; the right half is mirrored. A `MuskelGruppe` is one connected surface per side, merged from its
/// parts with a convex hull instead of many separately outlined muscles (only `beine` keeps thigh/butt
/// and calf apart, a knee sits between them). Built once per person type (`ahmed`, `annika`).
enum MuskelPfade {
    enum Seite: Sendable { case vorne, hinten }

    /// One group's surface, both halves in one path, already in figure space. `beine` holds two or
    /// three unconnected pieces (thigh, butt, calf) in the same path, all in the group's one color.
    struct Flaeche: Sendable {
        let gruppe: MuskelGruppe
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
            func flaeche(_ g: MuskelGruppe, _ seite: Seite, _ stuecke: [[CGPoint]]) -> Flaeche {
                var p = Path()
                for stueck in stuecke {
                    p.addPath(pfad(stueck))
                    p.addPath(pfad(stueck.map(MuskelPfade.spiegel)))
                }
                return Flaeche(gruppe: g, seite: seite, pfad: p)
            }
            /// One merged surface per group that has parts on this side: all its parts' points
            /// together, then just the outer hull, so no line remains between sibling parts.
            func gruppen(_ stuecke: [(gruppe: MuskelGruppe, punkte: [CGPoint])], _ seite: Seite) -> [Flaeche] {
                MuskelGruppe.allCases.compactMap { g in
                    let punkte = stuecke.filter { $0.gruppe == g }.flatMap(\.punkte)
                    guard !punkte.isEmpty else { return nil }
                    return flaeche(g, seite, [MuskelPfade.hulle(punkte)])
                }
            }
            koerper = MuskelPfade.basisMitte.map(pfad) + MuskelPfade.basisSeite.dropLast().flatMap(paar)
            schuhe = paar(MuskelPfade.basisSeite[4])
            hose = pfad(MuskelPfade.hose)
            flaechen = gruppen(MuskelPfade.stueckeVorne, .vorne)
                + [flaeche(.beine, .vorne, [MuskelPfade.hulle(MuskelPfade.oberschenkelVorne), MuskelPfade.hulle(MuskelPfade.wadenVorne)])]
                + gruppen(MuskelPfade.stueckeHinten, .hinten)
                + [flaeche(.beine, .hinten, [
                    MuskelPfade.hulle(MuskelPfade.poHinten), MuskelPfade.hulle(MuskelPfade.beinbeugerHinten), MuskelPfade.hulle(MuskelPfade.wadenHinten),
                ])]
        }

        /// The group at a point in figure space, either half.
        func gruppe(bei p: CGPoint, hinten: Bool) -> MuskelGruppe? {
            let seite = hinten ? Seite.hinten : Seite.vorne
            return flaechen.last(where: { $0.seite == seite && $0.pfad.contains(p) })?.gruppe
        }

        /// Which side shows a group: the back only if the group has no surface on the front.
        func hinten(fuer g: MuskelGruppe) -> Bool {
            !flaechen.contains(where: { $0.seite == .vorne && $0.gruppe == g })
        }
    }

    static let ahmed = Figur(frau: false)
    static let annika = Figur(frau: true)

    static func figur(_ p: Person) -> Figur { p == .annika ? annika : ahmed }

    /// The drawn area (SVG viewBox `8 -4 224 428` of the draft).
    static let rahmen = CGRect(x: 8, y: -4, width: 224, height: 428)

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

    /// Convex hull (monotone chain), the shape of a group's outer edge once its parts' points are
    /// pooled. That is what turns "many small outlined muscles" into "one soft surface per group".
    /// Fewer than 3 points: nothing to hull, returned as-is.
    static func hulle(_ punkte: [CGPoint]) -> [CGPoint] {
        guard punkte.count > 2 else { return punkte }
        let p = punkte.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        func kreuz(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        var unten: [CGPoint] = []
        for pt in p {
            while unten.count >= 2, kreuz(unten[unten.count - 2], unten[unten.count - 1], pt) <= 0 { unten.removeLast() }
            unten.append(pt)
        }
        var oben: [CGPoint] = []
        for pt in p.reversed() {
            while oben.count >= 2, kreuz(oben[oben.count - 2], oben[oben.count - 1], pt) <= 0 { oben.removeLast() }
            oben.append(pt)
        }
        unten.removeLast()
        oben.removeLast()
        return unten + oben
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

    private static func teil(_ g: MuskelGruppe, _ f: [CGFloat]) -> (gruppe: MuskelGruppe, punkte: [CGPoint]) { (g, punkte(f)) }

    /// Rounded rectangle as eight points (`rrect` of the draft).
    private static func rechteck(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ r: CGFloat) -> [CGPoint] {
        [P(x1 + r, y1), P(x2 - r, y1), P(x2, y1 + r), P(x2, y2 - r), P(x2 - r, y2), P(x1 + r, y2), P(x1, y2 - r), P(x1, y1 + r)]
    }

    // MARK: Data

    /// BASIS_MITTE: Kopf, Hals, Rumpf. Der Kopf bleibt eine schlichte runde Form ohne Gesicht, kein Chibi.
    private static let basisMitte: [[CGPoint]] = [
        punkte([120, 14, 131, 17, 138, 28, 139, 42, 136, 52, 130, 60, 120, 63, 110, 60, 104, 52, 101, 42, 102, 28, 109, 17]),
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

    /// Muskelteile, Vorderseite, nach Gruppe. Nacken und Rücken zeigen sich nur von hinten, deshalb
    /// fehlen sie hier ganz. Reihenfolge egal, jede Gruppe wird zu einer Fläche zusammengefasst.
    private static let stueckeVorne: [(gruppe: MuskelGruppe, punkte: [CGPoint])] = [
        teil(.schulter, [86, 92, 76, 94, 68, 104, 68, 122, 74, 128, 82, 116, 88, 102]),
        teil(.schulter, [72, 94, 62, 98, 52, 110, 50, 128, 56, 136, 64, 124, 66, 106]),
        teil(.brust, [118, 90, 102, 88, 90, 96, 88, 108, 102, 112, 118, 110]),
        teil(.brust, [118, 113, 102, 115, 88, 111, 85, 124, 92, 138, 106, 143, 118, 141]),
        teil(.bauch, [86, 142, 96, 146, 102, 152, 102, 196, 100, 230, 92, 238, 88, 212, 86, 176]),
        (.bauch, rechteck(104, 146, 118, 164, 4)),
        (.bauch, rechteck(104, 167, 118, 186, 4)),
        (.bauch, rechteck(104, 189, 118, 208, 4)),
        (.bauch, rechteck(104, 211, 118, 248, 6)),
        teil(.bizeps, [58, 138, 64, 132, 67, 160, 65, 188, 59, 186, 55, 164]),
        teil(.bizeps, [67, 132, 76, 138, 79, 164, 73, 188, 68, 188, 69, 160]),
        teil(.unterarme, [46, 196, 57, 195, 60, 212, 55, 240, 49, 262, 45, 240, 44, 214]),
        teil(.unterarme, [60, 198, 73, 198, 75, 222, 68, 252, 60, 282, 52, 282, 56, 262, 62, 236, 62, 212]),
    ]

    /// Beine vorn: Oberschenkel (Quadrizeps, Adduktoren) und Waden bleiben eigene Stücke, dazwischen
    /// sitzt das Knie. Beide zusammen ergeben trotzdem eine Flaeche der Gruppe `beine`.
    private static let oberschenkelVorne: [CGPoint] = [
        punkte([83, 272, 90, 280, 94, 320, 95, 358, 89, 372, 81, 350, 79, 310]),
        punkte([96, 282, 108, 290, 106, 330, 102, 364, 96, 362, 94, 330, 93, 298]),
        punkte([107, 336, 113, 344, 112, 372, 104, 380, 99, 372, 103, 352]),
        punkte([110, 290, 118, 300, 118, 322, 113, 334, 108, 318]),
    ].flatMap { $0 }
    private static let wadenVorne: [CGPoint] = [
        punkte([85, 404, 91, 400, 93, 430, 91, 458, 87, 440, 84, 420]),
        punkte([95, 402, 103, 402, 104, 440, 100, 476, 96, 468, 95, 430]),
        punkte([108, 404, 113, 406, 112, 440, 108, 452, 106, 430]),
    ].flatMap { $0 }

    /// Muskelteile, Rückseite, nach Gruppe. Brust und Bizeps zeigen sich nur von vorne, deshalb fehlen
    /// sie hier ganz.
    private static let stueckeHinten: [(gruppe: MuskelGruppe, punkte: [CGPoint])] = [
        teil(.nacken, [110, 58, 119, 58, 119, 76, 112, 78, 108, 66]),
        teil(.schulter, [76, 99, 64, 104, 58, 118, 66, 128, 78, 120, 88, 106]),
        teil(.schulter, [62, 100, 54, 108, 50, 124, 53, 136, 59, 126, 62, 112]),
        teil(.ruecken, [119, 78, 112, 78, 104, 84, 90, 90, 76, 96, 92, 100, 110, 98, 119, 98]),
        teil(.ruecken, [119, 101, 108, 101, 98, 106, 104, 128, 112, 160, 119, 178]),
        teil(.ruecken, [96, 108, 86, 113, 82, 126, 88, 138, 102, 140, 103, 126, 100, 113]),
        teil(.ruecken, [80, 136, 88, 143, 104, 146, 110, 168, 114, 200, 108, 226, 98, 232, 92, 214, 88, 184, 82, 158]),
        teil(.ruecken, [112, 182, 118, 182, 118, 254, 110, 256, 104, 236, 108, 210]),
        teil(.trizeps, [67, 130, 78, 130, 80, 152, 76, 176, 70, 184, 66, 160]),
        teil(.trizeps, [53, 128, 64, 128, 66, 156, 62, 180, 56, 170, 52, 148]),
        teil(.trizeps, [60, 182, 72, 184, 70, 194, 62, 194]),
        teil(.unterarme, [46, 198, 72, 198, 73, 222, 65, 258, 57, 282, 50, 280, 46, 240, 44, 214]),
    ]

    /// Beine hinten: Po, Beinbeuger und Waden bleiben eigene Stücke, alle in der Farbe von `beine`.
    private static let poHinten: [CGPoint] = punkte([84, 260, 100, 258, 118, 264, 118, 316, 104, 322, 88, 316, 80, 292])
    private static let beinbeugerHinten: [CGPoint] = [
        punkte([82, 322, 96, 326, 98, 380, 90, 378, 84, 360, 80, 340]),
        punkte([100, 326, 114, 324, 114, 350, 108, 378, 102, 382]),
    ].flatMap { $0 }
    private static let wadenHinten: [CGPoint] = [
        punkte([86, 398, 96, 396, 98, 436, 94, 452, 88, 440, 84, 420]),
        punkte([100, 396, 114, 398, 114, 428, 108, 452, 102, 448, 100, 420]),
        punkte([92, 456, 108, 456, 106, 480, 98, 482]),
    ].flatMap { $0 }
}

/// One side of the figure as a Canvas drawing (`figurSvg` of the draft, without the head image and
/// hair: the head is a plain shape in `koerper`, drawn in skin color like the rest of the body).
/// Pure values only, so the Canvas closure captures nothing that is actor-isolated.
struct MuskelAnsicht: Sendable {
    let person: Person
    let hinten: Bool
    let farben: [MuskelGruppe: Color]
    let fokus: MuskelGruppe?
    let gedrueckt: MuskelGruppe?

    private static let tinte = FigurFarbe(0x4A3128).farbe
    private static let fremd = FigurFarbe(0xD8B195).farbe
    private static let hose = FigurFarbe(0x2E2E36).farbe
    private static let sneaker = FigurFarbe(0xF5F5F7).farbe
    private static let hautAhmed = FigurFarbe(0xF1C3A0).farbe
    private static let hautAnnika = FigurFarbe(0xF7D0B6).farbe

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
    }

    private func muskeln(_ g: GraphicsContext, _ figur: MuskelPfade.Figur) {
        let seite = hinten ? MuskelPfade.Seite.hinten : MuskelPfade.Seite.vorne
        let rand = StrokeStyle(lineWidth: 1.5, lineJoin: .round)
        for f in figur.flaechen where f.seite == seite {
            g.fill(f.pfad, with: .color(fuellung(f.gruppe)))
            g.stroke(f.pfad, with: .color(Self.tinte), style: rand)
        }
    }

    /// Own color per group. With `fokus`, every other group turns skin-gray.
    private func fuellung(_ g: MuskelGruppe) -> Color {
        let c = farben[g, default: Color.clear]
        let basis = fokus.map { $0 == g ? c : Self.fremd } ?? c
        return g == gedrueckt ? basis.opacity(0.72) : basis
    }
}

/// One side of the muscle figure, standing still. The Körper sheet can put a front and a back next to
/// each other with this (as in the draft).
struct MuskelSeite: View {
    let person: Person
    let hinten: Bool
    let farbe: (MuskelGruppe) -> Color
    var fokus: MuskelGruppe?
    var gedrueckt: MuskelGruppe?

    var body: some View {
        let ansicht = MuskelAnsicht(
            person: person, hinten: hinten,
            farben: Dictionary(uniqueKeysWithValues: MuskelGruppe.allCases.map { ($0, farbe($0)) }),
            fokus: fokus, gedrueckt: gedrueckt
        )
        Canvas { g, size in ansicht.zeichne(g, size) }
            .aspectRatio(MuskelPfade.rahmen.width / MuskelPfade.rahmen.height, contentMode: .fit)
    }
}

/// The turnable cartoon muscle figure (Erholung, Körper tab). Drag turns 1:1 (1.1 deg per pt) and
/// swings on with a spring, a tap turns by 180 deg. A tap on a muscle group reports that `MuskelGruppe`
/// and does not turn; a tap beside the body, on skin without a group there, turns it instead. With
/// `fokus` (the sheet of one muscle group) the figure does not turn: it shows the side that holds the
/// group, that group in its own color, everything else skin-gray.
struct MuskelFigur: View {
    let person: Person
    let farbe: (MuskelGruppe) -> Color
    let fokus: MuskelGruppe?
    let onTipp: ((MuskelGruppe) -> Void)?
    let animiert: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lauf: Lauf
    @State private var laeuft = false
    @State private var zug: Zug? = nil
    @State private var gedrueckt: MuskelGruppe? = nil

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
        person: Person, farbe: @escaping (MuskelGruppe) -> Color,
        fokus: MuskelGruppe? = nil, onTipp: ((MuskelGruppe) -> Void)? = nil, animiert: Bool = true
    ) {
        self.person = person
        self.farbe = farbe
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

    /// The angle at `jetzt`. With `fokus` the figure stands still on the side that shows the group.
    private func winkel(_ jetzt: Date) -> Double {
        guard let fokus else { return lauf.winkel(jetzt) }
        return MuskelPfade.figur(person).hinten(fuer: fokus) ? 180 : 0
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
        MuskelSeite(person: person, hinten: hinten, farbe: farbe, fokus: fokus, gedrueckt: gedrueckt)
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

    /// Finger down: stops a turn in flight and notes the group under the finger.
    private func anfassen(_ wert: DragGesture.Value, _ groesse: CGSize) -> Zug {
        let w = winkel(wert.time)
        if fokus == nil { lauf = .ruhig(w) }
        gedrueckt = onTipp == nil ? nil : gruppe(bei: wert.startLocation, groesse, w)
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
            if let onTipp, let gruppe = gruppe(bei: wert.location, groesse, w) {
                Haptik.auswahl()
                onTipp(gruppe)
            } else if fokus == nil {
                Haptik.leicht()
                drehen()
            }
        case .scrollen:
            break
        }
    }

    /// Exact while the figure stands still, a good guess in flight. `nil` beside the body or on skin
    /// that belongs to no group (head, hands, neck, gaps): that is what turns the figure instead.
    private func gruppe(bei ort: CGPoint, _ groesse: CGSize, _ w: Double) -> MuskelGruppe? {
        let r = MuskelPfade.rahmen
        let s = r.width / groesse.width
        return MuskelPfade.figur(person).gruppe(bei: P(r.minX + ort.x * s, r.minY + ort.y * s), hinten: !Self.zeigtVorne(w))
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
