import SwiftUI

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

func funkel(_ c: CGPoint, _ r: CGFloat) -> Path {
    Path { p in
        p.move(to: P(c.x, c.y - r))
        p.addQuadCurve(to: P(c.x + r, c.y), control: c)
        p.addQuadCurve(to: P(c.x, c.y + r), control: c)
        p.addQuadCurve(to: P(c.x - r, c.y), control: c)
        p.addQuadCurve(to: P(c.x, c.y - r), control: c)
        p.closeSubpath()
    }
}

func tropfenPfad(_ c: CGPoint) -> Path {
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

/// Brief F2: vertical and round gradients in the figure space, like the SVG `userSpaceOnUse` gradients.
func verlaufY(_ y0: CGFloat, _ y1: CGFloat, _ stops: [Gradient.Stop]) -> GraphicsContext.Shading {
    .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: 0, y: y0), endPoint: CGPoint(x: 0, y: y1))
}

func verlaufRund(_ c: CGPoint, _ r: CGFloat, _ stops: [Gradient.Stop]) -> GraphicsContext.Shading {
    .radialGradient(Gradient(stops: stops), center: c, startRadius: 0, endRadius: r)
}

/// Fill with a free outline colour (the new faces do not always use `kontur`).
func flaeche(_ g: GraphicsContext, _ p: Path, _ fuellung: GraphicsContext.Shading, rand: Color? = nil, breite: CGFloat = 0) {
    g.fill(p, with: fuellung)
    if let rand { g.stroke(p, with: .color(rand), style: StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round)) }
}

func text(_ g: GraphicsContext, _ s: String, _ c: CGPoint, _ groesse: CGFloat, _ farbe: Color) {
    g.draw(Text(s).font(.system(size: groesse, weight: .heavy, design: .rounded)).foregroundStyle(farbe), at: c)
}

extension Array {
    func wahl(_ i: Int) -> Element { self[Swift.min(Swift.max(i, 0), count - 1)] }
}

func grenze(_ i: Int, _ n: Int) -> Int { min(max(i, 0), n - 1) }

func zwischen(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
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

struct Arm {
    let ellbogen: CGPoint
    let hand: CGPoint
    init(_ ellbogen: CGPoint, _ hand: CGPoint) {
        self.ellbogen = ellbogen
        self.hand = hand
    }
}

struct Bein {
    let h: CGPoint
    let k: CGPoint
    let f: CGPoint
}

enum Mund { case laecheln, grinsen, offen(CGFloat), neutral, traurig, kuss, schmoll, wellig, heulen, zaehne, schief }
enum Auge { case offen(gross: Bool), zu, froh, muede, schock, boese }

/// Brief F2: the redesigned faces, `gesichtsform` 7 (Ahmed, option B) and 8 (Annika, option 3).
/// Deviation from the plan: `Equatable` added — the plan's own `mundMitte` (`self == .b`) and later
/// tasks compare `neu`/`self` with `==`, which needs an explicit conformance to compile.
enum NeuesGesicht: Equatable {
    case b, an3

    /// Eye centres, left then right (`notizen.md`, anchor table).
    var augen: [(c: CGPoint, sd: CGFloat)] {
        switch self {
        case .b: [(P(81, 101), -1), (P(119, 101), 1)]
        case .an3: [(P(81.5, 102), -1), (P(118.5, 102), 1)]
        }
    }

    /// Where the old mouth shapes (built around (100|131)) land on this face.
    var mundMitte: CGFloat { self == .b ? 142.5 : 132.5 }
}

/// Brief F3: Ahmed's V-taper upper body for face B (`design/figur-redesign/koerper.py`, V4 and V5).
/// `sch` = left shoulder joint x, `taille` = left waist x at the bottom edge (y 240), `armB` = half
/// sleeve width at the hem, `delt` = roundness of the shoulder cap, `dick` = arm thickness.
struct VForm {
    let sch, taille, armB, delt, dick: CGFloat

    static let alltag = VForm(sch: 50, taille: 68, armB: 13.5, delt: 1, dick: 1)
    static let gym = VForm(sch: 46, taille: 70, armB: 15, delt: 1.2, dick: 1.1)

    var schulterL: CGPoint { P(sch, 182) }
    var ellbogenL: CGPoint { P(sch - 18, 228) }
    var handL: CGPoint { P(sch - 16, 262) }

    /// Left armpit: the inner end of the sleeve hem, moved up and in (koerper.py `shirt_v`).
    var achselL: CGPoint {
        let s = schulterL, e = ellbogenL
        let dx = e.x - s.x, dy = e.y - s.y
        let l = (dx * dx + dy * dy).squareRoot()
        return P(s.x + dx * 0.5 + dy / l * armB + 8, s.y + dy * 0.5 - dx / l * armB - 9)
    }
}

enum Aermel { case lang, kurz, keine }
enum Haltung { case stehen, gehen, rennen, rad, fahren, sitzen, scooter }

/// Full-body proportions in the 200 x 400 space. Feet stand at `fussY`, taller figures have longer legs.
struct Masse {
    let s: CGFloat          // shoulder half width
    let t: CGFloat          // waist half width
    let h: CGFloat          // hip half width
    let arm: CGFloat        // arm thickness relative to the half figure
    let bein: CGFloat       // leg thickness
    let hueftY: CGFloat
    let schulterY: CGFloat
    let knieY: CGFloat
    static let fussY: CGFloat = FigurPoseLogik.fussY
}
