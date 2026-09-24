import SwiftUI

/// Z-39.4: small extras on the figure, drawn in half and full body. The map derives them from the
/// weather (rain, sun, cold, snow) and from charging. `hanteln` (Brief G): a dumbbell in each hand,
/// curled in turn - the profile's gym scene.
/// `schlaefrig` (Brief G fix): late at night, tired eyes and now and then a yawn.
enum FigurExtra: String, CaseIterable, Sendable { case schirm, sonnenbrille, muetzeSchal, handyKabel, schneeflocken, hanteln, schlaefrig }

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
    private let poseImmer: Bool
    private let extras: Set<FigurExtra>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var sichtbar = false

    /// `bildrate`: frames per second of the loop; lower it where many figures or a map redraw.
    /// `poseImmer` (Brief I.5): a bought pose/dance normally only shows while `zustand` is otherwise
    /// idle — set `true` on a still snapshot (profile header, map pin) so it shows regardless of
    /// state except sleeping/offline/low-battery/bad-mood/a live Geste, which always win. Substitutes
    /// `.ruhig` for `zustand` in `leinwand` rather than only swapping the arms, so props/scenery/
    /// pajamas tied to the real `zustand` (barbell, sofa, phone, …) don't linger under the pose.
    /// `extras` (Z-39.4): umbrella, sunglasses, hat and scarf, phone with a white cable, snowflakes.
    init(_ aussehen: FigurAussehen, zustand: FigurZustand, abzeichen: [String] = [], groesse: CGFloat, animiert: Bool = true, bildrate: Double = 30, ganzkoerper: Bool = false, poseImmer: Bool = false, extras: Set<FigurExtra> = []) {
        self.aussehen = aussehen
        self.zustand = zustand
        self.abzeichen = abzeichen
        self.groesse = groesse
        self.animiert = animiert
        self.bildrate = bildrate
        self.ganzkoerper = ganzkoerper
        self.poseImmer = poseImmer
        self.extras = extras
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
        // `.ruhig` already falls to the `default:` branch in both `pose()` and `poseGanz()`, so
        // this reuses that existing "idle" path — with none of `zustand`'s props/scene/pajamas —
        // instead of teaching `Zeichner` a second pose-priority system.
        let posiert = poseImmer && aussehen.pose != nil && !Zeichner.keinePoseUeberschreibung.contains(zustand)
        let zeichner = Zeichner(aussehen, posiert ? .ruhig : zustand, abzeichen, t: t, statisch: statisch, ganz: ganzkoerper, extras: extras)
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

fileprivate enum Mund { case laecheln, grinsen, offen(CGFloat), neutral, traurig, kuss, schmoll, wellig, heulen, zaehne, schief }
fileprivate enum Auge { case offen(gross: Bool), zu, froh, muede, schock, boese }
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
    // v4 (Z-39.3): free everyday jewelry, 0 = none.
    let kette, ring, armband, uhrAlltag: Int
    /// v5 (fix round 3): chin hair, independent of the mustache.
    let kinnbart: Int
    /// v6 (fix round 4): moles on the cheeks, AirPods in both ears.
    let muttermale, airpods: Bool
    let extras: Set<FigurExtra>
    /// Gym look (Brief D addendum): Ahmed trains shirtless, Annika in a sleeveless sports top.
    let oberkoerperFrei, sportTop: Bool

    init(_ a: FigurAussehen, _ z: FigurZustand, _ abz: [String], t: Double, statisch: Bool, ganz: Bool, extras: Set<FigurExtra>) {
        typealias A = FigurAussehen
        self.z = z
        self.abz = Set(abz)
        self.t = t
        self.statisch = statisch
        self.ganz = ganz
        self.extras = extras
        kette = grenze(a.kette, A.ketten.count)
        ring = grenze(a.ring, A.ringe.count)
        armband = grenze(a.armband, A.armbaender.count)
        uhrAlltag = grenze(a.uhrAlltag, A.uhrenAlltag.count)
        kinnbart = grenze(a.kinnbart, A.kinnbaerte.count)
        muttermale = a.muttermale
        airpods = a.airpods
        let gym = z == .gym && a.person != nil
        let mannImGym = gym && a.person?.figurGeschlecht == .m
        // Fix round 3: "Oben ohne" (oberteil 33) is the bare torso outside the gym too.
        oberkoerperFrei = mannImGym || (z != .abend && grenze(a.oberteil, A.oberteile.count) == 33)
        sportTop = gym && !mannImGym
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
        let eigeneBrille = grenze(a.brille, A.brillen.count)
        // Sun extra: own sunglasses stay, anything else becomes plain sunglasses.
        brille = extras.contains(.sonnenbrille) && !Self.sonnenbrillen.contains(eigeneBrille) ? 3 : eigeneBrille
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
        let form = grenze(a.koerperform, A.koerperformen.count)
        // A trained body in the gym: below "Athletisch" the shirtless look switches to it.
        koerperform = mannImGym && A.koerper[form].muskel < 0.6 ? 3 : form
        groesseStufe = grenze(a.groesse, A.groessen.count)
        let freieSchuhe = grenze(a.schuhe, A.schuhArten.count)
        let fotoSchuh = A.fotoSchuhe[freieSchuhe]
        schuhe = fotoSchuh?.basis ?? freieSchuhe
        schuhF = fotoSchuh?.farbe ?? a.schuhfarbeHex.flatMap { FigurFarbe(hex: $0) } ?? A.farben.wahl(a.schuhfarbe).farbe
        jackeF = a.jackenfarbeHex.flatMap { FigurFarbe(hex: $0) } ?? A.farben.wahl(a.jackenfarbe).farbe
        let schlafanzug = z == .abend
        let freiesOberteil = grenze(a.oberteil, A.oberteile.count)
        let fotoOberteil = A.fotoOberteile[freiesOberteil]
        let oberteilFarbe = schlafanzug ? FigurFarbe(0xAFC8EE) : (fotoOberteil?.farbe ?? a.oberteilfarbeHex.flatMap { FigurFarbe(hex: $0) } ?? A.farben.wahl(a.oberteilfarbe).farbe)
        top = oberteilFarbe
        oberteil = schlafanzug ? 2 : (gym && !mannImGym ? 11 : (fotoOberteil?.basis ?? freiesOberteil))
        jacke = schlafanzug || gym ? 0 : grenze(a.jacke, A.jacken.count)
        let freieHose = grenze(a.hose, A.hosen.count)
        let fotoHose = A.fotoHosen[freieHose]
        hose = schlafanzug ? 3 : (gym ? (mannImGym ? 6 : 9) : (fotoHose?.basis ?? freieHose))
        let freieHosenFarbe = fotoHose?.farbe ?? a.hosenfarbeHex.flatMap { FigurFarbe(hex: $0) } ?? A.farben.wahl(a.hosenfarbe).farbe
        hoseF = schlafanzug ? oberteilFarbe : (gym ? FigurFarbe(0x2B2830) : freieHosenFarbe)
        hosenHexAktiv = !schlafanzug && !gym && (fotoHose != nil || a.hosenfarbeHex.flatMap { FigurFarbe(hex: $0) } != nil)
        let winter = extras.contains(.muetzeSchal)
        muetzeF = winter ? FigurFarbe(0xB33A4A) : A.farben.wahl(a.muetzenfarbe).farbe
        let ohneHut = schlafanzug || z == .rad || z == .schlaeft
        muetze = ohneHut ? 0 : (winter ? 3 : grenze(a.kopfbedeckung, A.kopfbedeckungen.count))
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
        if extras.contains(.schneeflocken) { schneeflocken(g, CGRect(x: 0, y: 0, width: 200, height: 240)) }
        let arme = mitExtras(pose())
        if let dach = schirmDachMitte(halb: true) { schirmDach(g, dach, radius: 42) }
        haareHinten(haarKontext(g))
        koerper(g)
        if extras.contains(.muetzeSchal) { schal(g, P(100, 160), s: 1) }
        kopfGruppe(g)
        mitte(g)
        let schulter: CGFloat = 40 * breite
        let d = km.armHalb
        if let l = arme.l { arm(g, P(100 - schulter, 184), l, d) }
        if let r = arme.r { arm(g, P(100 + schulter, 184), r, d) }
        if !rechteHandBelegt { requisite(g, arme.r?.hand ?? P(142, 252)) }
        extrasInHand(g, l: arme.l?.hand, r: arme.r?.hand, dach: schirmDachMitte(halb: true), groesse: 1)
        let hand: CGFloat = 9.5 * min(d, 1.12)
        if let l = arme.l { teil(g, kreis(l.hand, hand), haut) }
        if let r = arme.r { teil(g, kreis(r.hand, hand), haut) }
        zubehoer(g, arme)
        effekte(g)
        abzeichenVorn(g)
    }

    /// Z-24.2/Z-39.3: worn shop parts and free jewelry (bag on the free hand, watch on the other
    /// wrist, necklace at the collar, rings and bracelets on the hands).
    func zubehoer(_ g: GraphicsContext, _ arme: (l: Arm?, r: Arm?)) {
        if let id = tascheId {
            // Fix round 1: bags were drawn at hand-circle size on the hand, i.e. tiny, and in the
            // half figure the resting hand sits below the frame. Now: carried in a raised hand,
            // otherwise on a shoulder strap at the hip.
            if let hand = arme.r?.hand, hand.y < 226 {
                zeichneTasche(g, id: id, an: P(hand.x + 2, hand.y + 26), groesse: 1.3)
            } else {
                let strap = bogen(P(128, 168), P(162, 190), P(158, 170))
                linie(g, strap, Pal.dunkel.kontur, 5)
                linie(g, strap, Pal.dunkel.farbe, 3)
                zeichneTasche(g, id: id, an: P(162, 218), groesse: 1.3)
            }
        }
        uhrZeichnen(g, arme.l, groesse: km.armHalb)
        schmuckZeichnen(g, hals: P(100, 162), linkerArm: arme.l, rechterArm: arme.r, groesse: 1)
    }

    /// Wrist, not the hand itself — a hand-centered watch would just replace the hand circle.
    /// A shop watch wins over the free everyday one.
    /// The band wraps across the forearm (fix round 1); `groesse` follows the arm thickness.
    func uhrZeichnen(_ g: GraphicsContext, _ unterarm: Arm?, groesse: CGFloat) {
        guard let a = unterarm, uhrId != nil || uhrAlltag > 0 else { return }
        let handgelenk = zwischen(a.ellbogen, a.hand, 0.74)
        let winkel = atan2(Double(a.hand.y - a.ellbogen.y), Double(a.hand.x - a.ellbogen.x)) - Double.pi / 2
        if let id = uhrId {
            zeichneUhr(g, id: id, an: handgelenk, winkel: winkel, groesse: groesse)
        } else {
            let u = alltagsUhren[uhrAlltag - 1]
            zeichneUhr(g, u.stil, band: u.band, gehaeuse: u.gehaeuse, an: handgelenk, winkel: winkel, groesse: groesse)
        }
    }

    /// Necklaces at the collar; the free ring sits on the left hand, the free bracelet on the right
    /// wrist; a shop ring goes on the right hand, a shop bracelet on the left wrist above the watch.
    func schmuckZeichnen(_ g: GraphicsContext, hals: CGPoint, linkerArm: Arm?, rechterArm: Arm?, groesse: CGFloat) {
        let links = linkerArm.map { (ellbogen: $0.ellbogen, hand: $0.hand) }
        let rechts = rechterArm.map { (ellbogen: $0.ellbogen, hand: $0.hand) }
        if kette > 0 {
            let e = alltagsKetten[kette - 1]
            zeichneSchmuck(g, e.stil, e.farbe, hals: hals, arm: nil, groesse: groesse)
        }
        if ring > 0 {
            let e = alltagsRinge[ring - 1]
            zeichneSchmuck(g, e.stil, e.farbe, hals: hals, arm: links, groesse: groesse)
        }
        if armband > 0 {
            let e = alltagsArmbaender[armband - 1]
            zeichneSchmuck(g, e.stil, e.farbe, hals: hals, arm: rechts, groesse: groesse)
        }
        if let id = schmuckId, let e = schmuckKatalog[id] {
            let unterarm = e.stil.ort == .hand ? rechts : links
            zeichneSchmuck(g, id: id, hals: hals, arm: unterarm, groesse: groesse)
        }
    }

    /// Head, face, hair and everything worn on the head, in the half-figure space.
    func kopfGruppe(_ g: GraphicsContext) {
        kopf(g)
        gesicht(g)
        haareVorn(haarKontext(g))
        ohrringeZeichnen(g)
        if airpods { airpodsZeichnen(g) }
        muetzeZeichnen(g)
        kopfschmuck(g)
        brillen(g)
    }

    /// Under a covering hat the hair stops at the hat line, so tall styles never poke through.
    func haarKontext(_ g: GraphicsContext) -> GraphicsContext {
        guard (1...4).contains(muetze) || muetze == 7 || muetze == 8 else { return g }
        var h = g
        h.clip(to: Path(CGRect(x: -100, y: 34, width: 400, height: 400)))
        return h
    }

    /// Z-38.2: the body type's measures (`FigurAussehen.koerper`).
    var km: FigurAussehen.Koerper { FigurAussehen.koerper[koerperform] }

    var breite: CGFloat { km.breite }

    static let sonnenbrillen: Set<Int> = [3, 8, 9, 10, 11]

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
        // Mimik (Runde 3)
        case .zwinkert: return (4, 0)
        case .verliebt: return (Double(w(1.6)) * 4, 0)
        case .sauer: return (Double(w(18)) * 0.8, 0)
        case .schmollt: return (-4, 0)
        case .verlegen: return (Double(w(1.5)) * 3, 0)
        case .muede: return (Double(w(0.8)) * 2, 0)
        case .ueberrascht: return (0, -abs(w(3)) * 3)
        case .lachtTraenen: return (Double(w(1.2)) * 4, w(20) * 1.5)
        case .weint: return (0, w(14) * 0.8)
        case .denkt: return (-4, 0)
        case .feiert: return (0, -abs(w(6)) * 5)
        case .schockiert: return (-2, 0)
        case .daumen: return (0, -abs(w(2.5)) * 2)
        case .tanzt: return (Double(w(5)) * 6, -abs(w(10)) * 3)
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
        if oberkoerperFrei || sportTop { return .keine }
        if jacke > 0 { return .lang }
        switch oberteil {
        case 1, 2, 3, 5, 10, 13, 14, 16, 18, 19, 24, 25, 26, 31, 35: return .lang
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
        (38, 54, 140, 18, 162),  // Kantig lang (fix round 4: long, angular jaw, slightly pointed chin)
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
        case 2, 12, 13, 20, 25: 1
        case 4, 8, 11, 18: 2
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

        if oberkoerperFrei {
            let form = rumpf(0)
            teil(k, form, haut)
            k.fill(box(80, 150, 40, 28), with: .color(haut.farbe))
            var h = k
            h.clip(to: form)
            koerperDetails(h, nackt: true)
        } else if oberteil == 6 {
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
            koerperDetails(h, nackt: false)
            if Self.konturNachMuster.contains(oberteil) { linie(k, form, top.kontur, 3.5) }
        }
        if jacke > 0 { jackeZeichnen(k, form: rumpf(0), oben: 161, unten: 240, s: 1) }
    }

    /// Z-38.2 body cues in the half-figure torso space (`h` is clipped to the torso; the full body
    /// maps this space onto its torso): chest lines on muscular bodies, a bust line on curvy ones,
    /// and on the bare gym torso collarbones, chest and a light six-pack.
    func koerperDetails(_ h: GraphicsContext, nackt: Bool) {
        let k = km
        let farbe: Color = nackt ? haut.kontur.opacity(0.45) : top.kontur.opacity(0.18 + 0.2 * k.muskel)
        if nackt || k.muskel >= 0.5 {
            for seite in [CGFloat(-1), 1] {
                linie(h, bogen(P(100 + seite * 36, 198), P(100 + seite * 3, 206), P(100 + seite * 20, 218)), farbe, 2.4)
            }
        } else if k.kurve > 0 {
            for seite in [CGFloat(-1), 1] {
                linie(h, bogen(P(100 + seite * 32, 202), P(100 + seite * 5, 206), P(100 + seite * 19, 216)), top.kontur.opacity(0.28), 2)
                h.fill(oval(P(100 + seite * 19, 196), 7, 3.5), with: .color(.white.opacity(0.14)))
            }
        }
        if koerperform == 2 {
            // Kräftig: the round belly shows as a soft fold.
            linie(h, bogen(P(62, 254), P(138, 254), P(100, 274)), (nackt ? haut.kontur : top.kontur).opacity(0.32), 2.2)
        }
        guard nackt else { return }
        for seite in [CGFloat(-1), 1] {
            linie(h, bogen(P(100 + seite * 8, 172), P(100 + seite * 30, 170), P(100 + seite * 18, 176)), farbe, 2)
            // Outer edges of the abs.
            linie(h, bogen(P(100 + seite * 22, 222), P(100 + seite * 16, 286), P(100 + seite * 25, 256)), farbe, 2)
        }
        linie(h, strich(P(100, 214), P(100, 280)), farbe, 2)
        for y in [CGFloat(234), 252, 268] {
            linie(h, bogen(P(84, y), P(116, y), P(100, y + 4)), farbe, 1.8)
        }
        h.fill(oval(P(100, 284), 2, 3), with: .color(haut.kontur.opacity(0.6)))
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
        case 17...26, 31, 34, 35:
            markenOberteil(g, h)
        default:
            break
        }
    }

    /// Tops whose pattern runs over the torso edge, so the outline is drawn again on top.
    static let konturNachMuster: Set<Int> = [7, 12, 13, 18, 24, 25]

    /// Z-39.1/Z-39.2 brand tops, same spaces as `oberteilDetails` (`h` clipped to the torso).
    func markenOberteil(_ g: GraphicsContext, _ h: GraphicsContext) {
        let hell = top.mix(Pal.weiss, 0.75)
        switch oberteil {
        case 17:
            // H&M: plain tee, red logo on the chest.
            text(g, "H&M", P(126, 204), 11, FigurFarbe(0xE50010).farbe)
        case 18:
            // Zara: fitted rib knit with a square neck.
            for x in stride(from: CGFloat(34), to: 170, by: 7) { linie(h, strich(P(x, 150), P(x, 320)), top.kontur.opacity(0.22), 1.4) }
        case 19, 26:
            let kapuze = bogen(P(70, 164), P(130, 164), P(100, 196))
            linie(g, kapuze, top.kontur, 13)
            linie(g, kapuze, top.mal(0.88).farbe, 8.5)
            if oberteil == 19 {
                // Nike Tech Fleece: center zip, chest zip pocket, curved panel seams, swoosh.
                linie(h, strich(P(100, 190), P(100, 320)), Pal.silber.farbe, 2.5)
                linie(h, strich(P(62, 212), P(84, 200)), top.kontur, 2)
                teil(g, box(84, 197, 3, 6, 1), Pal.silber, 0.8)
                for seite in [CGFloat(-1), 1] { linie(h, bogen(P(100 + seite * 66, 190), P(100 + seite * 40, 300), P(100 + seite * 34, 240)), top.kontur.opacity(0.5), 1.6) }
                swoosh(g, P(128, 206), 0.9, hell.farbe)
            } else {
                // Balenciaga: oversized hoodie with the wordmark across the chest.
                text(g, "BALENCIAGA", P(100, 222), 9, hell.farbe)
            }
        case 20:
            // Nike jersey: trim-colored V collar, swoosh right, crest left (Brazil green on yellow).
            let v = Path { p in
                p.move(to: P(86, 161))
                p.addLine(to: P(100, 186))
                p.addLine(to: P(114, 161))
            }
            linie(g, v, trikotBesatz.kontur, 6)
            linie(g, v, trikotBesatz.farbe, 4)
            swoosh(g, P(74, 204), 0.8, trikotBesatz.farbe)
            let wappen = Path { p in
                p.move(to: P(118, 196))
                p.addLine(to: P(134, 196))
                p.addLine(to: P(134, 206))
                p.addQuadCurve(to: P(126, 214), control: P(134, 212))
                p.addQuadCurve(to: P(118, 206), control: P(118, 212))
                p.closeSubpath()
            }
            teil(g, wappen, FigurFarbe(0x2C5DB0), 1.5)
            g.fill(kreis(P(126, 204), 2.6), with: .color(Pal.gelb.farbe))
        case 21:
            // Puma: leaping cat over the wordmark.
            let katze = Path { p in
                p.move(to: P(84, 212))
                p.addQuadCurve(to: P(108, 200), control: P(94, 198))
                p.addLine(to: P(114, 194))
                p.addLine(to: P(116, 200))
                p.addQuadCurve(to: P(104, 210), control: P(112, 206))
                p.addQuadCurve(to: P(88, 216), control: P(96, 214))
                p.closeSubpath()
            }
            g.fill(katze, with: .color(hell.farbe))
            linie(g, bogen(P(84, 212), P(76, 222), P(78, 214)), hell.farbe, 2)
            text(g, "PUMA", P(100, 228), 10, hell.farbe)
        case 22:
            // Stüssy: the hand-written script logo.
            g.draw(Text("Stüssy").font(.custom("SnellRoundhand-Black", size: 17)).foregroundStyle(hell.farbe), at: P(100, 210))
        case 23:
            // Gucci: green-red-green web band across the chest.
            h.fill(box(20, 200, 160, 10), with: .color(FigurFarbe(0x1F7A45).farbe))
            h.fill(box(20, 203, 160, 4), with: .color(FigurFarbe(0xC8283F).farbe))
            text(g, "GUCCI", P(100, 190), 8, top.kontur)
        case 24:
            // Dior Oblique: diagonal jacquard lines and the wordmark.
            for x in stride(from: CGFloat(-40), to: 200, by: 12) {
                linie(h, strich(P(x, 330), P(x + 170, 150)), hell.farbe.opacity(0.35), 2)
            }
            text(g, "DIOR", P(100, 212), 11, hell.farbe)
        case 25:
            // Louis Vuitton: monogram flowers in gold on brown, shirt collar and buttons.
            let gold = FigurFarbe(0xD8B46A).farbe
            for y in stride(from: CGFloat(178), to: 320, by: 16) {
                let versatz: CGFloat = Int((y - 178) / 16) % 2 == 0 ? 0 : 9
                for x in stride(from: CGFloat(30) + versatz, to: 172, by: 18) { h.fill(funkel(P(x, y), 4), with: .color(gold)) }
            }
            hemdKragen(g)
        case 31:
            // Ahmed's pink knit: rib collar, a big white abstract graphic across the chest, rib hem.
            let bund = bogen(P(86, 161), P(114, 161), P(100, 176))
            linie(g, bund, top.kontur, 8)
            linie(g, bund, top.mal(0.9).farbe, 5)
            let weiss = Pal.weiss.farbe
            var grafik = Path()
            grafik.move(to: P(30, 206))
            grafik.addLine(to: P(62, 196))
            grafik.addLine(to: P(88, 182))
            grafik.addLine(to: P(104, 198))
            grafik.addLine(to: P(124, 184))
            grafik.addLine(to: P(170, 200))
            grafik.move(to: P(36, 226))
            grafik.addQuadCurve(to: P(110, 224), control: P(70, 244))
            grafik.addQuadCurve(to: P(168, 218), control: P(144, 206))
            grafik.move(to: P(40, 214))
            grafik.addQuadCurve(to: P(72, 206), control: P(50, 200))
            grafik.move(to: P(132, 230))
            grafik.addQuadCurve(to: P(160, 210), control: P(160, 232))
            linie(h, grafik, weiss, 3)
            h.fill(funkel(P(96, 212), 9), with: .color(weiss))
            for y in [CGFloat(292), 298] { linie(h, strich(P(20, y), P(180, y)), top.kontur.opacity(0.35), 1.4) }
        case 34, 35:
            // Gymshark (fix round 4): fitted, raglan seams, small shark logo on the chest.
            for seite in [CGFloat(-1), 1] {
                linie(h, bogen(P(100 + seite * 16, 164), P(100 + seite * 62, 198), P(100 + seite * 44, 170)), top.kontur.opacity(0.35), 1.6)
            }
            let hellesShirt = top.r + top.g + top.b > 1.5
            let hai = Path { p in
                p.move(to: P(118, 200))
                p.addQuadCurve(to: P(138, 195), control: P(130, 189))
                p.addQuadCurve(to: P(130, 203), control: P(136, 201))
                p.addQuadCurve(to: P(118, 200), control: P(124, 206))
                p.closeSubpath()
            }
            g.fill(hai, with: .color(hellesShirt ? Pal.dunkel.mal(0.8).farbe : Color.white))
        default:
            break
        }
    }

    /// Nike swoosh centered at `c`, `s` scales it.
    func swoosh(_ g: GraphicsContext, _ c: CGPoint, _ s: CGFloat, _ farbe: Color) {
        let p = Path { p in
            p.move(to: P(c.x - 9 * s, c.y - 1 * s))
            p.addQuadCurve(to: P(c.x + 11 * s, c.y - 6 * s), control: P(c.x - 6 * s, c.y + 8 * s))
            p.addQuadCurve(to: P(c.x - 9 * s, c.y - 1 * s), control: P(c.x - 5 * s, c.y + 4 * s))
            p.closeSubpath()
        }
        g.fill(p, with: .color(farbe))
    }

    /// Adidas trefoil: three leaves over three bars.
    func kleeblatt(_ g: GraphicsContext, _ c: CGPoint, _ s: CGFloat, _ farbe: Color) {
        let blaetter: [(CGFloat, Double)] = [(-4.5, -38), (0, 0), (4.5, 38)]
        for (dx, grad) in blaetter {
            var h = g
            h.translateBy(x: c.x + dx * s, y: c.y + abs(dx) * 0.3 * s)
            h.rotate(by: .degrees(grad))
            h.fill(oval(P(0, -4 * s), 2.6 * s, 4.6 * s), with: .color(farbe))
        }
        for i in 0..<3 {
            let y: CGFloat = c.y + (2 + CGFloat(i) * 2) * s
            linie(g, strich(P(c.x - 7 * s, y), P(c.x + 7 * s, y)), farbe, 0.9 * s)
        }
    }

    /// Open jacket: two front panels cut from the torso `form`, the top shows in the middle.
    /// `s` scales details (1 in the half figure, smaller on the full-body torso).
    func jackeZeichnen(_ g: GraphicsContext, form: Path, oben: CGFloat, unten: CGFloat, s: CGFloat) {
        let f = jackeF
        // Zipped jackets (Adidas, The North Face, Moncler) close in the middle.
        let zu = [8, 9, 11].contains(jacke)
        let innenO: CGFloat = zu ? 100 : 100 - 12 * s
        let innenU: CGFloat = zu ? 100 : 100 - 20 * s
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
        case 8...13:
            markenJacke(g, innen, oben: oben, unten: unten, s: s)
        default:
            break
        }
    }

    /// Z-39.1/Z-39.2 brand jackets. `innen` is clipped to the torso, `s` scales the details.
    func markenJacke(_ g: GraphicsContext, _ innen: GraphicsContext, oben: CGFloat, unten: CGFloat, s: CGFloat) {
        let f = jackeF
        let brustR = P(100 + 26 * s, oben + 38 * s)
        switch jacke {
        case 8:
            // Adidas track jacket (stripes on the sleeves come with the arms): stand collar, zip, trefoil.
            let kragen = bogen(P(100 - 24 * s, oben + 1), P(100 + 24 * s, oben + 1), P(100, oben + 12 * s))
            linie(g, kragen, f.kontur, 9 * s)
            linie(g, kragen, Pal.weiss.farbe, 6 * s)
            linie(innen, strich(P(100, oben), P(100, unten)), Pal.silber.farbe, 2.2 * s)
            kleeblatt(g, brustR, 1.1 * s, Pal.weiss.farbe)
        case 9, 11:
            // The North Face Nuptse (black shoulders, half-dome patch) and Moncler Maya (glossy, tricolore patch).
            if jacke == 9 { innen.fill(box(0, oben - 20, 200, 30 * s + 20), with: .color(Pal.dunkel.farbe)) }
            for i in 0..<8 {
                let y: CGFloat = oben + (26 + CGFloat(i) * 19) * s
                linie(innen, bogen(P(0, y), P(200, y), P(100, y + 7 * s)), f.kontur, 2.2)
                if jacke == 11 { linie(innen, bogen(P(20, y - 8 * s), P(180, y - 8 * s), P(100, y - 2 * s)), .white.opacity(0.28), 3 * s) }
            }
            linie(innen, strich(P(100, oben), P(100, unten)), Pal.silber.farbe, 2 * s)
            let kragen = bogen(P(100 - 22 * s, oben + 2), P(100 + 22 * s, oben + 2), P(100, oben + 10 * s))
            linie(g, kragen, f.kontur, 11 * s)
            linie(g, kragen, (jacke == 9 ? Pal.dunkel : f).farbe, 8 * s)
            if jacke == 9 {
                teil(g, box(brustR.x - 8 * s, brustR.y - 5 * s, 16 * s, 10 * s, 2 * s), Pal.dunkel, 1.2)
                for r in [CGFloat(2), 3.6, 5.2] {
                    linie(g, Path { p in p.addArc(center: P(brustR.x, brustR.y + 3 * s), radius: r * s, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false) }, .white, 0.9 * s)
                }
            } else {
                let patch = kreis(brustR, 6 * s)
                teil(g, patch, Pal.weiss, 1.2)
                var p = g
                p.clip(to: patch)
                p.fill(box(brustR.x - 6 * s, brustR.y - 6 * s, 4 * s, 12 * s), with: .color(FigurFarbe(0x2C4FA8).farbe))
                p.fill(box(brustR.x + 2 * s, brustR.y - 6 * s, 4 * s, 12 * s), with: .color(FigurFarbe(0xC8283F).farbe))
            }
        case 10:
            // Carhartt Detroit jacket: corduroy collar, chest pocket with the square label.
            let kragen = Path { p in
                p.move(to: P(100 - 12 * s, oben))
                p.addLine(to: P(100 - 34 * s, oben - 4 * s))
                p.addLine(to: P(100 - 26 * s, oben + 22 * s))
                p.closeSubpath()
            }
            let kord = FigurFarbe(0x4A3222)
            teil(g, kragen, kord, 2)
            teil(g, gespiegelt(kragen), kord, 2)
            let tasche = box(brustR.x - 10 * s, brustR.y - 8 * s, 20 * s, 18 * s, 2 * s)
            teil(innen, tasche, f.mal(0.93), 1.6)
            teil(g, box(brustR.x - 4 * s, brustR.y - 6 * s, 8 * s, 8 * s, 1.2 * s), FigurFarbe(0xE3A33A), 1)
            linie(g, strich(P(brustR.x - 1.5 * s, brustR.y - 2 * s), P(brustR.x + 1.5 * s, brustR.y - 2 * s)), Pal.tinte.farbe, 1.2 * s)
        case 12:
            // Chanel tweed: bouclé dots, braided trim along the front edges, gold buttons, CC.
            // ponytail: one path for all bouclé dots (a single fill per frame), fixed 9-unit grid.
            var boucle = Path()
            for y in stride(from: oben, to: unten + 20, by: 9) {
                let dx: CGFloat = Int((y - oben) / 9) % 2 == 0 ? 0 : 4.5
                for x in stride(from: CGFloat(24), to: 180, by: 9) {
                    boucle.addEllipse(in: CGRect(x: x + dx - 1.3, y: y - 1.3, width: 2.6, height: 2.6))
                }
            }
            innen.fill(boucle, with: .color(f.kontur.opacity(0.35)))
            let kante = strich(P(100 - 12 * s, oben), P(100 - 20 * s, unten))
            linie(g, kante, Pal.tinte.farbe, 4 * s)
            linie(g, kante, Pal.weiss.farbe, 2 * s)
            linie(g, gespiegelt(kante), Pal.tinte.farbe, 4 * s)
            linie(g, gespiegelt(kante), Pal.weiss.farbe, 2 * s)
            for i in 0..<3 { teil(g, kreis(P(100 - 26 * s, oben + (34 + CGFloat(i) * 22) * s), 3 * s), Pal.gold, 1) }
            chanelCC(g, brustR, 3.4 * s)
        case 13:
            // Prada Re-Nylon: glossy black nylon with the silver triangle plaque.
            for seite in [CGFloat(-1), 1] {
                linie(innen, strich(P(100 + seite * 44 * s, oben + 30 * s), P(100 + seite * 44 * s, unten - 10)), .white.opacity(0.18), 4 * s)
            }
            let dreieck = Path { p in
                p.move(to: P(brustR.x - 8 * s, brustR.y - 5 * s))
                p.addLine(to: P(brustR.x + 8 * s, brustR.y - 5 * s))
                p.addLine(to: P(brustR.x, brustR.y + 6 * s))
                p.closeSubpath()
            }
            teil(g, dreieck, Pal.silber, 1.2)
            linie(g, strich(P(100 - 12 * s, oben + 4), P(100 - 20 * s, unten - 4)), Pal.silber.farbe, 2 * s)
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

    /// `d` scales the thickness (the body type's `armHalb` in the half figure, `arm` on the full body).
    func arm(_ g: GraphicsContext, _ schulter: CGPoint, _ a: Arm, _ d: CGFloat = 1) {
        let oben = strich(schulter, a.ellbogen)
        let unten = strich(a.ellbogen, a.hand)
        let obenFarbe = aermel == .keine ? haut : aermelFarbe
        let untenFarbe = aermel == .lang ? aermelFarbe : haut
        let muskeln = muskelBeulen(schulter, a.ellbogen, d)
        // A raised or folded forearm lies in front of the upper arm, so it is drawn last;
        // otherwise the thick upper arm would swallow it (fix round 1: floating fists).
        let vorn = a.hand.y < a.ellbogen.y - 4
        linie(g, oben, obenFarbe.kontur, 25 * d)
        for m in muskeln { g.fill(kreis(m.c, m.r + 3 * d), with: .color(obenFarbe.kontur)) }
        if vorn {
            linie(g, oben, obenFarbe.farbe, 19 * d)
            for m in muskeln { g.fill(kreis(m.c, m.r), with: .color(obenFarbe.farbe)) }
            linie(g, unten, untenFarbe.kontur, 21 * d)
            linie(g, unten, untenFarbe.farbe, 15.5 * d)
        } else {
            linie(g, unten, untenFarbe.kontur, 21 * d)
            linie(g, unten, untenFarbe.farbe, 15.5 * d)
            linie(g, oben, obenFarbe.farbe, 19 * d)
            for m in muskeln { g.fill(kreis(m.c, m.r), with: .color(obenFarbe.farbe)) }
        }
        aermelDetails(g, schulter, a, d)
    }

    /// Z-38.2: shoulder cap and biceps of the muscular body types, as round bulges on the upper arm.
    func muskelBeulen(_ s: CGPoint, _ e: CGPoint, _ d: CGFloat) -> [(c: CGPoint, r: CGFloat)] {
        let m = km.muskel
        guard m > 0 else { return [] }
        let dx = e.x - s.x
        let dy = e.y - s.y
        let laenge = max(1, (dx * dx + dy * dy).squareRoot())
        // Unit normal pointing away from the body's middle (x = 100).
        var nx = -dy / laenge
        var ny = dx / laenge
        if (s.x - 100) * nx < 0 {
            nx = -nx
            ny = -ny
        }
        let kappe = P(s.x + dx * 0.14 + nx * 1.5 * d, s.y + dy * 0.14 + ny * 1.5 * d)
        let innen: CGFloat = 2 * m * d
        let bizeps = P(s.x + dx * 0.55 - nx * innen, s.y + dy * 0.55 - ny * innen)
        let kappeR: CGFloat = (10.5 + 2.5 * m) * d
        let bizepsR: CGFloat = (9.5 + 2.2 * m) * d
        return [(c: kappe, r: kappeR), (c: bizeps, r: bizepsR)]
    }

    /// Z-39.1 sleeve cues: Adidas three stripes down the whole arm, colored cuffs on the Nike jersey.
    func aermelDetails(_ g: GraphicsContext, _ s: CGPoint, _ a: Arm, _ d: CGFloat) {
        if jacke == 8 {
            dreiStreifen(g, s, a.ellbogen, d)
            dreiStreifen(g, a.ellbogen, a.hand, d)
        } else if jacke == 0 && oberteil == 20 && aermel == .kurz {
            let band = strich(zwischen(s, a.ellbogen, 0.8), zwischen(s, a.ellbogen, 0.97))
            linie(g, band, trikotBesatz.farbe, 19 * d)
        }
    }

    /// Three parallel stripes along a limb segment (Adidas); `d` scales their spacing.
    func dreiStreifen(_ g: GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ d: CGFloat, farbe: Color = .white) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let laenge = max(1, (dx * dx + dy * dy).squareRoot())
        let nx: CGFloat = -dy / laenge * 3.4 * d
        let ny: CGFloat = dx / laenge * 3.4 * d
        for k in [CGFloat(-1), 0, 1] {
            linie(g, strich(P(a.x + nx * k, a.y + ny * k), P(b.x + nx * k, b.y + ny * k)), farbe, 1.6 * d)
        }
    }

    /// Nike jersey trim: Brazil green on a yellow jersey, white otherwise.
    var trikotBesatz: FigurFarbe {
        top.r > 0.8 && top.g > 0.65 && top.b < 0.5 ? FigurFarbe(0x1E8A4C) : Pal.weiss
    }

    // MARK: Face

    /// Tired only while nothing more telling is going on (not asleep, no gesture or expression).
    /// Sitting up in bed after "Gute Nacht" (Brief G fix 2) is always tired.
    var schlaefrig: Bool { (extras.contains(.schlaefrig) || z == .sitztImBett) && !Self.keinePoseUeberschreibung.contains(z) }

    /// A short yawn about every half minute; never on a still frame (Reduce Motion, stickers).
    var gaehnt: Bool { schlaefrig && !statisch && zyklus(29) < 0.08 }

    var augenAusdruck: Auge {
        if schlaefrig { return gaehnt ? .zu : .muede }
        return switch z {
        case .schlaeft, .morgen: .zu
        case .lacht, .kuss, .gut, .naehe: .froh
        case .akkuLeer, .abend, .ruhe: .muede
        case .schautBild, .schautVideo, .anstupsen, .ueberrascht: .offen(gross: true)
        case .lachtTraenen, .feiert, .daumen, .tanzt: .froh
        case .weint: .zu
        case .muede: .muede
        case .schockiert: .schock
        case .sauer: .boese
        default: .offen(gross: false)
        }
    }

    var mundForm: Mund {
        if gaehnt { return .offen(7 + 7 * CGFloat(sin(Double(zyklus(29)) / 0.08 * Double.pi))) }
        return switch z {
        case .gut, .lacht, .pokal, .anstossen, .imChat: .grinsen
        case .schautBild, .schautVideo, .rennt: .offen(6)
        case .morgen: .offen(9)
        case .sprache: .offen(4 + 3 * abs(w(11)))
        case .schlaeft: .offen(3)
        case .mittel, .offline, .nichtStoeren: .neutral
        case .schlecht, .akkuLeer: .traurig
        case .kuss: .kuss
        case .zwinkert, .lachtTraenen, .feiert, .daumen, .tanzt: .grinsen
        case .sauer: .zaehne
        case .schmollt: .schmoll
        case .verlegen: .wellig
        case .muede, .ueberrascht: .offen(7)
        case .weint: .heulen
        case .denkt: .schief
        case .schockiert: .offen(13)
        default: .laecheln
        }
    }

    var blick: CGPoint {
        switch z {
        case .liest: P(w(1.6), 0.7)
        case .tippt, .arbeit, .schule, .zeichnet, .laedt: P(0, 0.7)
        case .kamera, .spielt: P(0.6, -0.7)
        case .anstupsen: P(0.8, 0)
        case .schmollt: P(-0.9, 0.1)
        case .verlegen: P(0.7, 0.8)
        case .denkt: P(-0.6, -0.9)
        default: P(0, 0)
        }
    }

    func gesicht(_ g: GraphicsContext) {
        let staerke = [.verliebt, .verlegen, .schmollt].contains(z) ? 0.7 : ((z == .kuss || z == .herz || z == .naehe || rouge) ? 0.5 : 0.28)
        let wange = Pal.rose.farbe.opacity(staerke)
        // Pouting puffs the cheeks.
        let backe: CGFloat = z == .schmollt ? 1.5 : 1
        g.fill(oval(P(68, 120), 10 * backe, 6 * backe), with: .color(wange))
        g.fill(oval(P(132, 120), 10 * backe, 6 * backe), with: .color(wange))
        if z == .verlegen {
            for x in [CGFloat(62), 68, 74, 126, 132, 138] { linie(g, strich(P(x, 123), P(x + 3, 117)), Pal.rose.kontur.opacity(0.6), 1.4) }
        }
        if z == .sauer {
            // Red forehead.
            var h = g
            h.clip(to: kopfPfad)
            h.fill(box(30, 30, 140, 40), with: .color(Pal.rose.farbe.opacity(0.22)))
        }
        if sommersprossen {
            let punkte: [CGPoint] = [P(62, 114), P(69, 110), P(74, 117), P(66, 121), P(92, 110), P(97, 106)]
            for c in punkte {
                g.fill(kreis(c, 1.4), with: .color(haut.mal(0.72).farbe))
                g.fill(kreis(P(200 - c.x, c.y), 1.4), with: .color(haut.mal(0.72).farbe))
            }
        }
        if muttermal { g.fill(kreis(P(122, 127), 1.9), with: .color(Pal.tinte.farbe.opacity(0.8))) }
        if muttermale {
            for c in [P(66, 118), P(130, 124)] { g.fill(kreis(c, 1.1), with: .color(haut.mal(0.5).farbe.opacity(0.75))) }
        }
        bartZeichnen(g)
        kinnbartZeichnen(g)
        brauen(g)
        augen(g)
        nase(g)
        mund(g)
        schnurrbartVorn(g)
    }

    func brauen(_ g: GraphicsContext) {
        let farbe = haar.mal(0.8)
        let hoch: CGFloat = (z == .schautBild || z == .schautVideo || z == .anstupsen) ? -5 : 0
        let traurig: CGFloat = [.schlecht, .akkuLeer, .weint, .verlegen].contains(z) ? -6 : 0
        let staunen: CGFloat = [.ueberrascht, .schockiert].contains(z) ? -8 : 0
        // Angry: inner ends down (V); pouting a little; thinking lifts one brow.
        let boese: CGFloat = z == .sauer ? 8 : (z == .schmollt ? 4 : 0)
        let dicken: [CGFloat] = [4.5, 2.6, 7, 5, 4.5, 4.5, 4.5, 4, 7.5]
        for seite in [CGFloat(-1), 1] {
            let heben: CGFloat = z == .denkt && seite > 0 ? -6 : staunen
            var aussen = P(100 + seite * 30, 81 + hoch + heben - boese * 0.4)
            var innen = P(100 + seite * 10, 80 + hoch + traurig + heben + boese)
            var ctrl = P(100 + seite * 20, 75 + hoch + heben)
            switch brauenStil {
            case 3:
                ctrl.y = 79 + hoch
                aussen.y = 80 + hoch
            case 8:
                // Dick gerade (Ahmed): thick, dark and nearly straight; expressions still move it.
                ctrl.y = 78 + hoch + heben
                aussen.y = 80 + hoch + heben - boese * 0.4
                innen.x = 100 + seite * 6 // almost joined
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
        if (offen && abz.contains("herzaugen")) || z == .verliebt {
            let s: CGFloat = 10 + 1.5 * w(8)
            for x in [CGFloat(80), 120] { teil(g, herzPfad(P(x, 98), s), Pal.rose, 2.5) }
            return
        }
        let blinzelt = !statisch && zyklus(4.2, 1.3) < 0.035
        let seiten: [(x: CGFloat, aussen: CGFloat)] = [(80, -1), (120, 1)]
        for s in seiten {
            let c = P(s.x, 98)
            if z == .zwinkert && s.aussen > 0 {
                geschlossen(g, c, s.aussen, froh: true)
                continue
            }
            if blinzelt && offen {
                geschlossen(g, c, s.aussen, froh: false)
                continue
            }
            switch form {
            case .zu: geschlossen(g, c, s.aussen, froh: false)
            case .froh: geschlossen(g, c, s.aussen, froh: true)
            case .offen(let gross): offenesAuge(g, c, s.aussen, gross: gross, lid: false)
            case .muede: offenesAuge(g, c, s.aussen, gross: false, lid: true)
            case .schock: schockAuge(g, c)
            case .boese:
                offenesAuge(g, c, s.aussen, gross: false, lid: false)
                // Slanted lid: the inner corner closes a little.
                let lid = Path { p in
                    p.move(to: P(c.x - s.aussen * 12, c.y - 14))
                    p.addLine(to: P(c.x + s.aussen * 12, c.y - 14))
                    p.addLine(to: P(c.x + s.aussen * 12, c.y - 10))
                    p.addLine(to: P(c.x - s.aussen * 12, c.y - 1))
                    p.closeSubpath()
                }
                g.fill(lid, with: .color(haut.farbe))
                linie(g, strich(P(c.x - s.aussen * 11, c.y - 1.5), P(c.x + s.aussen * 11, c.y - 10)), Pal.tinte.farbe, 3)
            }
        }
    }

    /// Shocked: big white eye, tiny pupil.
    func schockAuge(_ g: GraphicsContext, _ c: CGPoint) {
        let weiss = oval(c, 12, 15)
        g.fill(weiss, with: .color(.white))
        linie(g, weiss, Pal.tinte.farbe, 2.6)
        g.fill(kreis(P(c.x, c.y + 1), 2.6), with: .color(Pal.tinte.farbe))
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
        (1.1, 0.86, 4, 0.16, false),  // Scharf (fix round 3: crisp, relaxed, not sleepy)
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
        // "Scharf" gets a stronger upper lid line.
        linie(e, bogen(P(-rx, kante), P(rx, kante), P(0, bogenY)), tinte, augenform == 8 ? 4.2 : 3.2)
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
        case 8: FigurFarbe(0xF0B8BA) // Lippen hellrosa (Ahmed), pale
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
                if mundStil == 8 {
                    // Fix round 5: Ahmed's lips smaller and less prominent.
                    var k = g
                    k.translateBy(x: 100, y: 131)
                    k.scaleBy(x: 0.78, y: 0.78)
                    k.translateBy(x: -100, y: -131)
                    volleLippen(k, l)
                } else {
                    volleLippen(g, l)
                }
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
        case .schmoll:
            let f = lippe ?? haut.mix(Pal.rose, 0.45)
            teil(g, oval(P(100, 133), 7, 4.5), f, 2.2)
            linie(g, bogen(P(94, 133), P(106, 133), P(100, 130)), rand, 1.6)
        case .wellig:
            let welle = Path { p in
                p.move(to: P(90, 130))
                p.addQuadCurve(to: P(96, 130), control: P(93, 127))
                p.addQuadCurve(to: P(102, 130), control: P(99, 133))
                p.addQuadCurve(to: P(108, 130), control: P(105, 127))
                p.addQuadCurve(to: P(112, 129), control: P(110, 132))
            }
            linie(g, welle, rand, 2.6)
        case .heulen:
            let m = Path { p in
                p.move(to: P(86, 140))
                p.addQuadCurve(to: P(114, 140), control: P(100, 118))
                p.addQuadCurve(to: P(86, 140), control: P(100, 148))
                p.closeSubpath()
            }
            g.fill(m, with: .color(Pal.mundInnen.farbe))
            var h = g
            h.clip(to: m)
            h.fill(oval(P(100, 145), 8, 5), with: .color(Pal.zunge.farbe))
            linie(g, m, rand, lippe == nil ? 2.5 : 3.5)
        case .zaehne:
            let m = box(87, 125, 26, 12, 5)
            g.fill(m, with: .color(.white))
            for x in [CGFloat(93.5), 100, 106.5] { linie(g, strich(P(x, 125), P(x, 137)), Pal.tinte.farbe.opacity(0.5), 1.2) }
            linie(g, strich(P(87, 131), P(113, 131)), Pal.tinte.farbe.opacity(0.5), 1.2)
            linie(g, m, rand, 2.5)
        case .schief:
            linie(g, bogen(P(93, 132), P(108, 128), P(101, 133)), rand, 2.8)
        }
    }

    /// Fix round 3: chin hair on its own (combines with every mustache), medium brown like
    /// Ahmed's mustache. 1 = light, sparse goatee; 2 = fuller chin patch.
    func kinnbartZeichnen(_ g: GraphicsContext) {
        guard kinnbart > 0 else { return }
        // Fix round 5: only faint stubble, a few tiny soft dots, no shape, no outline.
        let deckung: Double = kinnbart == 2 ? 0.4 : 0.22
        let punkte: [CGPoint] = [P(95, 145), P(100, 148), P(105, 145), P(98, 152), P(103, 151), P(92, 149), P(108, 149)]
        for c in punkte.prefix(kinnbart == 2 ? 7 : 5) {
            g.fill(kreis(c, 0.75), with: .color(FigurFarbe(0x6B4A36).farbe.opacity(deckung)))
        }
    }

    /// Fix round 5: the mustaches 14/15 sit on top of the lips, so they are drawn after the mouth.
    /// 14: two soft lobes meeting under the nose, reaching the mouth corners; 15: trimmed, curled ends.
    func schnurrbartVorn(_ g: GraphicsContext) {
        guard bart == 14 || bart == 15 else { return }
        let braun = FigurFarbe(0x5C3E2C)
        var h = g
        h.clip(to: kopfPfad)
        if bart == 14 {
            for seite in [CGFloat(-1), 1] {
                let lappen = Path { p in
                    p.move(to: P(100, 119))
                    p.addQuadCurve(to: P(100 + seite * 15, 126), control: P(100 + seite * 9, 117))
                    p.addQuadCurve(to: P(100, 123), control: P(100 + seite * 8, 126))
                    p.closeSubpath()
                }
                h.fill(lappen, with: .color(braun.farbe))
            }
            return
        }
        let form = Path { p in
            p.move(to: P(100, 120.5))
            p.addQuadCurve(to: P(84, 126.5), control: P(90, 119))
            p.addQuadCurve(to: P(81, 123.5), control: P(81.5, 126.5))
            p.addQuadCurve(to: P(100, 124.5), control: P(88, 127))
            p.addQuadCurve(to: P(119, 123.5), control: P(112, 127))
            p.addQuadCurve(to: P(116, 126.5), control: P(118.5, 126.5))
            p.addQuadCurve(to: P(100, 120.5), control: P(110, 119))
            p.closeSubpath()
        }
        teil(h, form, braun, 1.2)
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
        case 13:
            // Feiner Schnurrbart (Ahmed's Bitmoji): thin, with little curled tips.
            for seite in [CGFloat(-1), 1] {
                let oberlippe = bogen(P(100, 123.5), P(100 + seite * 16, 127), P(100 + seite * 8, 120.5))
                let spitze = bogen(P(100 + seite * 16, 127), P(100 + seite * 20, 121.5), P(100 + seite * 21, 127.5))
                // Fix round 2: really thin and subtle, like the Bitmoji.
                linie(h, oberlippe, haar.farbe.opacity(0.85), 2)
                linie(h, spitze, haar.farbe.opacity(0.85), 1.4)
            }
        case 14, 15:
            break // drawn after the mouth, see `schnurrbartVorn`
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
        streifen(g, p, s)
    }

    /// The hair color's highlight streaks inside `p`.
    func streifen(_ g: GraphicsContext, _ p: Path, _ s: FigurFarbe) {
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
        case 34...: // Z-38.3 Runde-3 styles
            neueFrisurHinten(g)
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
        case 25:
            haarTeil(g, kappe(top: 18, scheitel: 76, ansatz: 52, unten: 100))
            haarTeil(g, gespiegelt(straehneGlatt(120)))
            var glieder: [CGPoint] = []
            // Fix round 1: five links end above the elbow, no stray tie dot.
            for i in 0..<5 { glieder.append(P(152 - CGFloat(i) * 2.5, 112 + CGFloat(i) * 16)) }
            for c in glieder { g.fill(oval(c, 13, 12), with: .color(haar.kontur)) }
            for c in glieder { g.fill(oval(c, 11, 10), with: .color(haar.farbe)) }
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
            // Z-38.3: the Runde-3 styles draw their own strands and highlight.
            neueFrisurVorn(g)
            return
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
        let sonne = Self.sonnenbrillen.contains(brille)
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

    /// Fix round 4: white AirPods in both ears (bud in the ear, stem pointing down).
    func airpodsZeichnen(_ g: GraphicsContext) {
        for (x, seite) in [(CGFloat(44), CGFloat(1)), (156, -1)] {
            let stiel = strich(P(x + seite, 104), P(x + seite * 2, 118))
            linie(g, stiel, Pal.silber.kontur, 5)
            linie(g, stiel, .white, 3.2)
            teil(g, oval(P(x + seite * 2, 101), 4.2, 4.6), Pal.weiss, 1.4)
        }
    }

    func ohrringeZeichnen(_ g: GraphicsContext) {
        // A shop earring (Z-39.2) replaces the free pair.
        if let id = schmuckId, schmuckKatalog[id]?.stil.ort == .ohr {
            zeichneOhrschmuck(g, id: id)
            return
        }
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
            case 5:
                // Diamant-Stecker
                teil(g, kreis(P(x, 111), 3.4), FigurFarbe(0xE6F3FF), 1.2)
                g.fill(funkel(P(x, 111), 2.6), with: .color(.white))
            case 6:
                // Große Kreolen
                linie(g, kreis(P(x, 124), 13), Pal.gold.kontur, 4.5)
                linie(g, kreis(P(x, 124), 13), Pal.gold.farbe, 2.6)
            case 7:
                // Herz-Hänger
                linie(g, strich(P(x, 110), P(x, 118)), Pal.gold.farbe, 1.6)
                teil(g, herzPfad(P(x, 122), 4.2), Pal.rose, 1.2)
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
            if extras.contains(.muetzeSchal) {
                // Winter extra: pompom on top.
                teil(g, kreis(P(100, 8), 9), Pal.weiss, 2.5)
                for dx in [CGFloat(-4), 0, 4] { linie(g, strich(P(100 + dx, 3), P(100 + dx * 1.3, 13)), Pal.weiss.kontur.opacity(0.5), 1.2) }
            }
        case 7:
            // Carhartt Beanie: short watch cap high on the head, deep cuff with the square label.
            let form = Path { p in
                p.move(to: P(42, 62))
                p.addCurve(to: P(100, 8), control1: P(40, 26), control2: P(66, 8))
                p.addCurve(to: P(158, 62), control1: P(134, 8), control2: P(160, 26))
                p.closeSubpath()
            }
            teil(g, form, f)
            var r = g
            r.clip(to: form)
            for x in stride(from: CGFloat(50), to: 156, by: 8) { linie(r, strich(P(x, 8), P(x, 44)), f.kontur.opacity(0.35), 1.4) }
            let bund = box(38, 40, 124, 26, 11)
            teil(g, bund, f.mal(0.9))
            var h = g
            h.clip(to: bund)
            for x in stride(from: CGFloat(44), to: 160, by: 7) { linie(h, strich(P(x, 40), P(x, 66)), f.kontur.opacity(0.7), 1.3) }
            teil(g, box(90, 45, 20, 16, 2.5), FigurFarbe(0xE3A33A), 1.6)
            linie(g, Path { p in p.addArc(center: P(100, 53), radius: 4, startAngle: .degrees(40), endAngle: .degrees(320), clockwise: false) }, Pal.tinte.farbe, 2)
        case 8:
            // Trucker Cap (fix round 4): tall front panel, mesh sides, curved brim, blackletter logo in tone.
            let krone = Path { p in
                p.move(to: P(40, 68))
                p.addCurve(to: P(100, 2), control1: P(34, 20), control2: P(62, 2))
                p.addCurve(to: P(160, 68), control1: P(138, 2), control2: P(166, 20))
                p.addQuadCurve(to: P(40, 68), control: P(100, 56))
                p.closeSubpath()
            }
            teil(g, krone, f)
            var netz = g
            netz.clip(to: krone)
            for x in stride(from: CGFloat(34), to: 62, by: 5) { linie(netz, strich(P(x, 20), P(x, 70)), f.kontur.opacity(0.45), 1) }
            for x in stride(from: CGFloat(140), to: 168, by: 5) { linie(netz, strich(P(x, 20), P(x, 70)), f.kontur.opacity(0.45), 1) }
            teil(g, kreis(P(100, 4), 4), f.mal(0.85), 2)
            // Fix round 5: a real curved front brim, lit on top, shaded along its front edge;
            // the fringe peeks out underneath.
            let schirm = Path { p in
                p.move(to: P(42, 64))
                p.addQuadCurve(to: P(158, 64), control: P(100, 50))
                p.addQuadCurve(to: P(42, 64), control: P(100, 96))
                p.closeSubpath()
            }
            teil(g, schirm, f.mal(0.82))
            linie(g, bogen(P(54, 69), P(146, 69), P(100, 88)), f.mal(0.55).farbe, 3)
            linie(g, bogen(P(62, 61), P(138, 61), P(100, 53)), Color.white.opacity(0.14), 3)
            g.draw(Text("\u{1D504}").font(.system(size: 26, weight: .bold)).foregroundStyle(f.mix(Pal.weiss, 0.16).farbe), at: P(100, 34))
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

    /// Every `z` with its own scripted arm animation that a static bought pose must never cut off —
    /// device/mood states, plus live Gesten (kiss lean in `ProfileView`, high-five/laugh/toast/
    /// trophy), which are meaningful and brief, unlike the all-day Ort/Tageszeit states `FigurView`'s
    /// `poseImmer` (Brief I.5) substitutes `.ruhig` for.
    static let keinePoseUeberschreibung: Set<FigurZustand> = Set<FigurZustand>([.schlaeft, .offline, .akkuLeer, .schlecht, .kuss, .herz, .lacht, .anstossen, .pokal]).union(FigurZustand.mimik)

    /// Z-23.3/Z-24.2: a bought pose/dance shows while the figure is just idling (Profil, Karte) —
    /// it never fights a meaningful activity pose (typing, sleeping, …).
    func poseUeberschreibung() -> (l: Arm?, r: Arm?)? {
        guard let id = poseId, !Self.keinePoseUeberschreibung.contains(z) else { return nil }
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
            // Arms swing opposite to the legs; a still frame shows mid-stride.
            let s: CGFloat = statisch ? 0.9 : w(7)
            let vl: CGFloat = max(0, -s)
            let vr: CGFloat = max(0, s)
            return (Arm(P(44 + vl * 8, 214 - vl * 10), P(54 + vl * 18, 246 - vl * 34)), Arm(P(156 - vr * 8, 214 - vr * 10), P(146 - vr * 18, 246 - vr * 34)))
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
        // Mimik (Runde 3)
        case .zwinkert:
            return (Arm(P(28, 222), P(50, 250)), Arm(P(182, 200), P(170, 158)))
        case .verliebt:
            return (Arm(P(56, 214), P(92, 160)), Arm(P(144, 214), P(108, 160)))
        case .sauer:
            // Crossed: two diagonal forearms at different heights, hands tucked at the far elbow.
            return (Arm(P(40, 228), P(136, 204)), Arm(P(160, 216), P(64, 236)))
        case .schmollt:
            return (Arm(P(28, 220), P(48, 248)), Arm(P(172, 220), P(152, 248)))
        case .verlegen:
            return (restL, Arm(P(174, 168), P(158, 86)))
        case .muede:
            return (Arm(P(52, 190), P(76, 106)), Arm(P(152, 222), P(128, 196)))
        case .ueberrascht:
            let s = w(3) * 3
            return (Arm(P(34, 196), P(40, 148 + s)), Arm(P(166, 196), P(160, 148 + s)))
        case .lachtTraenen:
            return (Arm(P(40, 214), P(80, 232)), Arm(P(162, 196), P(132, 110)))
        case .weint:
            let s = w(10) * 2
            return (Arm(P(46, 196), P(76, 108 + s)), Arm(P(154, 196), P(124, 108 - s)))
        case .denkt:
            return (Arm(P(44, 230), P(142, 214)), Arm(P(160, 218), P(114, 150)))
        case .feiert:
            let s = w(6) * 6
            return (Arm(P(30, 160), P(38, 104 + s)), Arm(P(170, 160), P(162, 104 - s)))
        case .schockiert:
            return (Arm(P(34, 196), P(62, 124)), Arm(P(166, 196), P(138, 124)))
        case .daumen:
            return (restL, Arm(P(166, 212), P(146, 174)))
        case .tanzt:
            let s = w(5)
            return (Arm(P(36, 190 - s * 10), P(28 + s * 6, 140 - s * 16)), Arm(P(164, 190 + s * 10), P(172 - s * 6, 140 + s * 16)))
        default:
            // Z-23.3/Z-24.2: a bought pose/dance shows whenever nothing more specific is going on
            // (Profil, Karte, "zuhause", …) — it never overrides a real activity pose above.
            if let o = poseUeberschreibung() { return o }
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
        case .zwinkert:
            fingerZeigt(g, hand, richtung: P(-6, -15), s: 1)
        case .daumen:
            daumenHoch(g, hand, s: 1)
        case .muede:
            kaffee(g, P(hand.x, hand.y - 14), s: 1)
        default:
            break
        }
    }

    /// Index finger pointing out of the hand; drawn before the hand circle so the hand covers its base.
    func fingerZeigt(_ g: GraphicsContext, _ hand: CGPoint, richtung d: CGPoint, s: CGFloat) {
        let finger = strich(hand, P(hand.x + d.x * s, hand.y + d.y * s))
        linie(g, finger, haut.kontur, 9 * s)
        linie(g, finger, haut.farbe, 6 * s)
    }

    /// Thumb sticking up out of the fist.
    func daumenHoch(_ g: GraphicsContext, _ hand: CGPoint, s: CGFloat) {
        let daumen = strich(hand, P(hand.x - s, hand.y - 16 * s))
        linie(g, daumen, haut.kontur, 10 * s)
        linie(g, daumen, haut.farbe, 7 * s)
    }

    /// Coffee to go with a little steam.
    func kaffee(_ g: GraphicsContext, _ c: CGPoint, s: CGFloat) {
        var h = g
        h.translateBy(x: c.x, y: c.y)
        h.scaleBy(x: s, y: s)
        let becher = Path { p in
            p.move(to: P(-8, -10))
            p.addLine(to: P(8, -10))
            p.addLine(to: P(6, 10))
            p.addLine(to: P(-6, 10))
            p.closeSubpath()
        }
        teil(h, becher, Pal.weiss, 2)
        h.fill(box(-7, -3, 14, 6), with: .color(Pal.holz.farbe))
        teil(h, box(-9.5, -14, 19, 5, 2), Pal.holz.mal(0.75), 1.5)
        for i in 0..<2 {
            let p = zyklus(1.6, Double(i) * 0.8)
            var d = h
            d.opacity = Double(1 - p)
            let x: CGFloat = CGFloat(i) * 6 - 3
            linie(d, bogen(P(x, -18 - p * 12), P(x + 2, -30 - p * 12), P(x + 5, -24 - p * 12)), Pal.silber.kontur, 1.6)
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
        case .zwinkert, .verliebt, .sauer, .schmollt, .verlegen, .muede, .ueberrascht, .lachtTraenen, .weint, .denkt, .feiert, .schockiert, .daumen, .tanzt:
            mimikEffekte(g)
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

    /// Effects of the Runde-3 expressions, in the half-figure (head) space.
    func mimikEffekte(_ g: GraphicsContext) {
        let tinte = Pal.tinte.farbe
        switch z {
        case .zwinkert:
            g.fill(funkel(P(146, 84), 5 + 2 * abs(w(4))), with: .color(Pal.gelb.farbe))
        case .verliebt:
            herzen(g, CGRect(x: 24, y: 16, width: 152, height: 100), 5)
        case .sauer:
            // Anger mark and steam.
            var h = g
            h.translateBy(x: 152, y: 50)
            h.scaleBy(x: 1 + 0.08 * abs(w(8)), y: 1 + 0.08 * abs(w(8)))
            for k in 0..<4 {
                var r = h
                r.rotate(by: .degrees(Double(k) * 90))
                linie(r, bogen(P(3, -9), P(9, -3), P(4, -4)), Pal.rose.farbe, 3)
            }
            for (i, x) in [CGFloat(54), 146].enumerated() {
                let p = zyklus(1.4, Double(i) * 0.7)
                var d = g
                d.opacity = Double(1 - p)
                teil(d, kreis(P(x, 40 - p * 22), 6 + p * 5), Pal.weiss, 2)
            }
        case .schmollt:
            let wolke = [kreis(P(150, 132), 6), kreis(P(160, 128), 8), kreis(P(170, 133), 6)]
            for p in wolke { linie(g, p, Pal.wolke.kontur, 4) }
            for p in wolke { g.fill(p, with: .color(.white)) }
        case .verlegen:
            teil(g, tropfenPfad(P(150, 68 + zyklus(2.2) * 8)), Pal.himmel, 2)
        case .muede:
            teil(g, tropfenPfad(P(66, 110)), Pal.himmel, 1.5)
        case .ueberrascht:
            let s: CGFloat = 1 + 0.15 * abs(w(6))
            g.fill(box(160, 22, 7 * s, 22 * s, 3.5), with: .color(Pal.rose.farbe))
            g.fill(kreis(P(163.5, 50 * s), 4), with: .color(Pal.rose.farbe))
        case .lachtTraenen:
            for seite in [CGFloat(-1), 1] {
                linie(g, strich(P(100 + seite * 64, 78), P(100 + seite * 76, 70)), tinte, 3)
                for i in 0..<2 {
                    let p = zyklus(0.8, Double(i) * 0.4)
                    let tropfen = P(100 + seite * (34 + p * 30), 104 - p * 8 + p * p * 30)
                    teil(g, tropfenPfad(tropfen), Pal.himmel, 1.5)
                }
            }
        case .weint:
            for seite in [CGFloat(-1), 1] {
                let strom = bogen(P(100 + seite * 30, 104), P(100 + seite * 34, 156), P(100 + seite * 38, 128))
                linie(g, strom, Pal.himmel.kontur.opacity(0.6), 7)
                linie(g, strom, Pal.himmel.farbe, 4.5)
                let p = zyklus(0.9, seite > 0 ? 0.45 : 0)
                var d = g
                d.opacity = Double(1 - p)
                teil(d, tropfenPfad(P(100 + seite * 34, 160 + p * 40)), Pal.himmel, 1.5)
            }
        case .denkt:
            teil(g, kreis(P(142, 70), 3), Pal.weiss, 2)
            teil(g, kreis(P(152, 60), 5), Pal.weiss, 2)
            teil(g, box(146, 20, 44, 30, 15), Pal.weiss, 2.5)
            text(g, "?", P(168, 35), 17, Pal.nacht.farbe)
        case .feiert:
            let farben = [Pal.rose, Pal.gelb, Pal.blau, Pal.mint]
            for i in 0..<12 {
                let p = zyklus(2.4, Double(i) * 0.2)
                let x: CGFloat = 14 + CGFloat(i) * 15 + w(3, Double(i)) * 6
                var h = g
                h.translateBy(x: x, y: 10 + p * 200)
                h.rotate(by: .degrees(Double(i) * 37 + t * 120))
                h.fill(box(-3, -1.5, 6, 3, 1), with: .color(farben[i % farben.count].farbe))
            }
        case .schockiert:
            for x in [CGFloat(78), 90, 102, 114, 126] {
                linie(g, strich(P(x, 40), P(x, 58)), Pal.nacht.farbe.opacity(0.35), 2.5)
            }
            teil(g, tropfenPfad(P(154, 72)), Pal.himmel, 1.5)
            teil(g, tropfenPfad(P(46, 76)), Pal.himmel, 1.5)
        case .daumen:
            g.fill(funkel(P(164, 150), 6 + 2 * abs(w(4))), with: .color(Pal.gelb.farbe))
        case .tanzt:
            for i in 0..<2 {
                let p = zyklus(1.8, Double(i) * 0.9)
                var d = g
                d.opacity = Double(1 - p)
                let x: CGFloat = i == 0 ? 30 : 166
                text(d, i == 0 ? "♪" : "♫", P(x + w(3, Double(i)) * 6, 90 - p * 60), 20, Pal.nacht.farbe)
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
        // Scenes with furniture only bob; standing figures may also sway. Driving (Brief G bugfix):
        // the car drifts and tilts gently, in step with the steering wheel (`lenkWinkel`).
        let winkel: Double = [.stehen, .gehen, .rennen, .fahren].contains(hal) ? bew.winkel : 0
        let drift: CGFloat = hal == .fahren ? w(1.8) * 3 : 0
        let atem: CGFloat = z == .offline ? 1 : 1.005 + 0.005 * w(2 * Double.pi / 3.6)
        g.translateBy(x: 100 + drift, y: 392)
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
        if extras.contains(.schneeflocken) { schneeflocken(g, CGRect(x: 0, y: 0, width: 200, height: 400)) }
        szeneHinten(g, m, oben)
        let arme = mitExtrasGanz(poseGanz(m), m)
        let dach = schirmDachMitte(halb: false, m)
        if let dach { schirmDach(u, dach, radius: 40) }
        haareHinten(haarKontext(k))
        if hal != .fahren { beine(g, m, hal, oben) }
        rumpfGanz(u, m)
        if extras.contains(.muetzeSchal) { schal(u, P(100, m.schulterY - 4), s: 0.66) }
        kopfGruppe(k)
        vorArmen(g, u, m, oben)
        arm(u, P(100 - m.s + 6, m.schulterY + 10), arme.l, m.arm)
        arm(u, P(100 + m.s - 6, m.schulterY + 10), arme.r, m.arm)
        if !rechteHandBelegt { handRequisite(u, arme, m) }
        extrasInHand(u, l: arme.l.hand, r: arme.r.hand, dach: dach, groesse: 0.66)
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

    /// Z-24.2/Z-39.3: worn shop parts and free jewelry, scaled like `jackeZeichnen`'s `s: 0.66` onto the full-body torso.
    func zubehoerGanz(_ g: GraphicsContext, _ arme: (l: Arm, r: Arm), _ m: Masse) {
        let s: CGFloat = 0.66
        if let id = tascheId {
            // Hangs from the right hand, the handle in the fist, big enough to read (fix round 1).
            zeichneTasche(g, id: id, an: P(arme.r.hand.x + 2, arme.r.hand.y + 22), groesse: 1.15)
        }
        uhrZeichnen(g, arme.l, groesse: m.arm)
        schmuckZeichnen(g, hals: P(100, m.schulterY - 6), linkerArm: arme.l, rechterArm: arme.r, groesse: s)
    }

    func masse() -> Masse {
        let beinLaengen: [CGFloat] = [112, 124, 136]
        let k = km
        let beinL = beinLaengen[groesseStufe]
        let hueftY = Masse.fussY - beinL
        return Masse(s: k.s, t: k.t, h: k.h, arm: k.arm, bein: k.bein,
                     hueftY: hueftY, schulterY: hueftY - 96, knieY: hueftY + beinL * 0.5)
    }

    var haltung: Haltung {
        switch z {
        case .laeuft, .tanzt: .gehen
        case .rennt: .rennen
        case .rad: .rad
        case .faehrt, .fahrschule: .fahren
        case .zuhause, .schule, .arbeit, .schautVideo, .ruhe, .zug: .sitzen
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
                // Stride: the lifted leg bends, its foot kicks back and up; the other one is planted.
                return Bein(h: P(x, hy), k: P(x + seite * 2 + phase * 4, m.knieY - hebt * 12), f: P(x + seite * 3 - phase * 6, fy - hebt * 24))
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
        case .gehen: s = statisch ? 0.9 : w(7)
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
        case 0, 2: return FigurFarbe(0x9DB8D9)
        case 1: return FigurFarbe(0x34507A)
        case 13: return FigurFarbe(0x4B6C98) // Levi's 501, mid blue wash
        default: return hoseF
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
        case 4, 14: breiten = (0.66, 0.56, 0.42)
        case 9, 15: breiten = (0.54, 0.42, 0.34)
        case 12: breiten = (0.64, 0.56, 0.5)
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
        case 12...15:
            markenHose(g, seiten, m, hy)
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

    /// Z-39.1 brand pants: Adidas three stripes, Levi's 501 button fly and red tab, Nike Tech Fleece
    /// cuffs and swoosh, Puma leggings side stripe.
    func markenHose(_ g: GraphicsContext, _ seiten: [(bein: Bein, seite: CGFloat)], _ m: Masse, _ hy: CGFloat) {
        let b = m.bein
        let farbe = hosenFarbe
        let linksOben = seiten[0].bein.h
        let rechtsOben = seiten[1].bein.h
        switch hose {
        case 12:
            for s in seiten {
                let oben = P(s.bein.h.x + s.seite * b * 0.46, s.bein.h.y + 6)
                let unten = P(s.bein.f.x + s.seite * b * 0.36, s.bein.f.y - 4)
                dreiStreifen(g, oben, unten, 0.55)
            }
        case 13:
            for i in 0..<3 { g.fill(kreis(P(100, hy - 2 + CGFloat(i) * 6), 1.1), with: .color(Pal.gold.farbe)) }
            g.fill(box(linksOben.x - b * 0.62, hy + 2, 3, 5, 1), with: .color(FigurFarbe(0xC8283F).farbe))
            for s in seiten {
                let naht = bogen(P(s.bein.h.x - s.seite * 2, hy - 4), P(s.bein.h.x + s.seite * b * 0.6, hy + 8), P(s.bein.h.x + s.seite * 2, hy + 8))
                linie(g, naht, FigurFarbe(0xE3A33A).farbe.opacity(0.8), 1)
            }
        case 14:
            for s in seiten {
                let f = s.bein.f
                teil(g, box(f.x - b * 0.44, f.y - 9, b * 0.88, 9, 3.5), farbe.mal(0.85), 2)
            }
            swoosh(g, P(linksOben.x, linksOben.y + 16), 0.5, farbe.mix(Pal.weiss, 0.8).farbe)
            linie(g, strich(P(rechtsOben.x + 2, rechtsOben.y + 10), P(rechtsOben.x + 6, rechtsOben.y + 22)), farbe.kontur, 1.2)
        case 15:
            for s in seiten {
                let oben = P(s.bein.h.x + s.seite * b * 0.5, s.bein.h.y + 4)
                let unten = P(s.bein.f.x + s.seite * b * 0.3, s.bein.f.y - 6)
                linie(g, strich(oben, unten), .white.opacity(0.85), 1.6)
            }
            g.fill(kreis(P(rechtsOben.x + 2, hy + 8), 1.8), with: .color(.white))
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
        case 10:
            // Nike Air Force 1: chunky upper, thick white cupsole, swoosh, perforated toe.
            teil(g, box(x - 13, y - 6, 26, 14, 7), c, 3)
            teil(g, box(x - 14, y + 4, 28, 7, 3), Pal.weiss, 2)
            linie(g, strich(P(x - 13, y + 7.5), P(x + 13, y + 7.5)), Pal.silber.farbe, 1)
            swoosh(g, P(x + 1, y + 1), 0.55, hell ? Pal.silber.mal(0.9).farbe : Pal.weiss.farbe)
            for dx in [CGFloat(-9), -6.5, -4] { g.fill(kreis(P(x + dx, y - 1), 0.7), with: .color(c.kontur)) }
        case 11:
            // Adidas Samba: slim upper, suede T-toe, three stripes, gum sole.
            teil(g, box(x - 13, y - 4, 26, 12, 6), c, 3)
            g.fill(box(x - 13, y - 3, 7, 10, 3), with: .color(c.mal(0.85).farbe))
            let streifenFarbe: Color = hell ? Pal.tinte.farbe : .white
            for dx in [CGFloat(-1), 2.5, 6] { linie(g, strich(P(x + dx, y + 6), P(x + dx + 3.5, y - 3)), streifenFarbe, 1.6) }
            teil(g, box(x - 13.5, y + 7, 27, 4, 2), FigurFarbe(0xC98A4B), 1.5)
        case 12:
            // New Balance 550: chunky leather, green "N", colored heel.
            teil(g, box(x - 13, y - 7, 26, 15, 7), c, 3)
            teil(g, box(x - 13.5, y + 6, 27, 5, 2.5), Pal.weiss, 1.8)
            text(g, "N", P(x + 1, y + 1), 9, FigurFarbe(0x2E7D4F).farbe)
            g.fill(box(x + 8, y - 5, 4, 10, 2), with: .color(FigurFarbe(0x2E7D4F).farbe))
        case 13:
            // Gucci Ace: white leather with the green-red-green web and a gold bee.
            teil(g, box(x - 12, y - 5, 24, 15, 7), c, 3)
            g.fill(box(x - 12, y + 6, 24, 4, 2), with: .color(sohle.farbe))
            g.fill(box(x - 4, y - 4, 4, 10), with: .color(FigurFarbe(0x1F7A45).farbe))
            g.fill(box(x - 2.8, y - 4, 1.6, 10), with: .color(FigurFarbe(0xC8283F).farbe))
            g.fill(kreis(P(x + 6, y), 1.6), with: .color(Pal.gold.farbe))
        case 14:
            // Balenciaga Triple S: stacked chunky sole, layered upper.
            teil(g, box(x - 13, y - 7, 26, 13, 6), c, 3)
            teil(g, box(x - 11, y - 5, 12, 8, 3), c.mix(Pal.weiss, 0.4), 1.5)
            teil(g, box(x - 15, y + 4, 30, 4, 2), Pal.silber, 1.5)
            teil(g, box(x - 15, y + 8, 30, 4, 2), FigurFarbe(0xD8C3A0), 1.5)
            teil(g, box(x - 14, y + 12, 28, 3, 1.5), Pal.dunkel.mix(Pal.weiss, 0.3), 1)
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
        // Z-38.2: chest (muscular) or bust (curvy) bows the flank outward; 0 keeps the old straight flank.
        let bauch: CGFloat = 8 * km.muskel + 5 * km.kurve
        let flankeX: CGFloat = (m.s + m.t) / 2 + bauch
        let flankeY: CGFloat = (sY + 14 + taille) / 2
        // Kräftig: a round belly between waist and hem.
        let bauchRund: CGFloat = koerperform == 2 ? 9 : 0
        let bauchX: CGFloat = (m.t + saum) / 2 + bauchRund
        let bauchY: CGFloat = (taille + unten) / 2
        return Path { p in
            p.move(to: P(89, sY - 2))
            p.addQuadCurve(to: P(100 - m.s, sY + 14), control: P(104 - m.s, sY - 2))
            p.addQuadCurve(to: P(100 - m.t, taille), control: P(100 - flankeX, flankeY))
            p.addQuadCurve(to: P(100 - saum, unten), control: P(100 - bauchX, bauchY))
            p.addQuadCurve(to: P(100 + saum, unten), control: P(100, unten + 4))
            p.addQuadCurve(to: P(100 + m.t, taille), control: P(100 + bauchX, bauchY))
            p.addQuadCurve(to: P(100 + m.s, sY + 14), control: P(100 + flankeX, flankeY))
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
        if oberkoerperFrei {
            teil(g, voll, haut)
            g.fill(box(90, sY - 8, 20, 14), with: .color(haut.farbe))
            var d = g
            d.clip(to: voll)
            d.translateBy(x: 100, y: sY - 2)
            d.scaleBy(x: 0.66 * m.s / 41, y: 0.8)
            d.translateBy(x: -100, y: -161)
            koerperDetails(d, nackt: true)
            return
        }
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
            // Details follow the body's width (Normal = the old 0.66).
            let quer: CGFloat = 0.66 * m.s / 41
            dg.translateBy(x: 100, y: sY - 2)
            dg.scaleBy(x: quer, y: 0.8)
            dg.translateBy(x: -100, y: -161)
            var d = g
            d.clip(to: form)
            d.translateBy(x: 100, y: sY - 2)
            d.scaleBy(x: quer, y: 0.8)
            d.translateBy(x: -100, y: -161)
            oberteilDetails(dg, d)
            koerperDetails(d, nackt: false)
            if Self.konturNachMuster.contains(oberteil) { linie(g, form, top.kontur, 3.5) }
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
        guard let id = poseId, !Self.keinePoseUeberschreibung.contains(z) else { return nil }
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
            // Opposite to the legs: when the left leg lifts, the right arm swings forward (up and in).
            let s: CGFloat = statisch ? 0.9 : w(7)
            let vl: CGFloat = max(0, -s)
            let vr: CGFloat = max(0, s)
            return (Arm(P(lx - 6 + vl * 6, y + 48 - vl * 6), P(lx - 2 + vl * 16, y + 88 - vl * 30)), Arm(P(rx + 6 - vr * 6, y + 48 - vr * 6), P(rx + 2 - vr * 16, y + 88 - vr * 30)))
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
        case .zuhause, .schule, .schautVideo, .ruhe, .zug:
            return (Arm(P(lx - 6, y + 48), P(86, y + 84)), Arm(P(rx + 6, y + 48), P(114, y + 84)))
        // Mimik (Runde 3); the head space maps to y + (hy - 133.6) * 0.8 here.
        case .zwinkert:
            return (Arm(P(lx - 16, y + 50), P(lx + 4, y + 88)), Arm(P(rx + 24, y + 26), P(rx + 20, y - 8)))
        case .verliebt:
            return (Arm(P(lx - 2, y + 44), P(94, y - 6)), Arm(P(rx + 2, y + 44), P(106, y - 6)))
        case .sauer:
            return (Arm(P(lx - 4, y + 50), P(rx + 2, y + 32)), Arm(P(rx + 4, y + 42), P(lx - 2, y + 58)))
        case .schmollt:
            return (Arm(P(lx - 20, y + 46), P(lx + 2, y + 88)), Arm(P(rx + 20, y + 46), P(rx - 2, y + 88)))
        case .verlegen:
            return (restL, Arm(P(rx + 22, y - 8), P(rx + 6, y - 62)))
        case .muede:
            return (Arm(P(lx - 8, y + 20), P(86, y - 52)), Arm(P(rx + 8, y + 50), P(rx - 10, y + 30)))
        case .ueberrascht:
            let s: CGFloat = w(3) * 2
            return (Arm(P(lx - 14, y + 20), P(lx - 8, y - 30 + s)), Arm(P(rx + 14, y + 20), P(rx + 8, y - 30 + s)))
        case .lachtTraenen:
            return (Arm(P(lx - 6, y + 48), P(92, y + 70)), Arm(P(rx + 10, y + 10), P(120, y - 50)))
        case .weint:
            let s: CGFloat = w(10) * 1.5
            return (Arm(P(lx - 6, y + 20), P(88, y - 50 + s)), Arm(P(rx + 6, y + 20), P(112, y - 50 - s)))
        case .denkt:
            return (Arm(P(lx - 4, y + 54), P(rx, y + 40)), Arm(P(rx + 10, y + 40), P(110, y - 8)))
        case .feiert:
            let s: CGFloat = w(6) * 5
            return (Arm(P(lx - 18, y - 2), P(lx - 26, y - 44 + s)), Arm(P(rx + 18, y - 2), P(rx + 26, y - 44 - s)))
        case .schockiert:
            return (Arm(P(lx - 12, y + 24), P(78, y - 36)), Arm(P(rx + 12, y + 24), P(122, y - 36)))
        case .daumen:
            return (restL, Arm(P(rx + 22, y + 32), P(rx + 16, y + 2)))
        case .tanzt:
            let s = w(5)
            return (Arm(P(lx - 16, y + 10 - s * 8), P(lx - 30, y - 24 + s * 14)), Arm(P(rx + 16, y + 10 + s * 8), P(rx + 30, y - 24 - s * 14)))
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
        case .zwinkert:
            fingerZeigt(g, arme.r.hand, richtung: P(-6, -15), s: 0.66)
        case .daumen:
            daumenHoch(g, arme.r.hand, s: 0.66)
        case .muede:
            kaffee(g, P(arme.r.hand.x, arme.r.hand.y - 9), s: 0.66)
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
        case .zug:
            // Brief G bugfix: a train seat by the window, the landscape rushing past behind the glass.
            let fenster = box(10, sitz - 214, 180, 118, 16)
            teil(g, fenster, Pal.silber, 3)
            var glas = g
            glas.clip(to: box(18, sitz - 206, 164, 102, 10))
            glas.fill(box(18, sitz - 206, 164, 102), with: .linearGradient(Gradient(colors: [Pal.himmel.farbe, Pal.weiss.farbe]), startPoint: P(0, sitz - 206), endPoint: P(0, sitz - 104)))
            glas.fill(box(18, sitz - 140, 164, 36), with: .color(Pal.gruen.farbe.opacity(0.8)))
            for i in 0..<5 {
                let x: CGFloat = 200 - zyklus(0.9, Double(i) * 0.19) * 220
                linie(glas, strich(P(x, sitz - 190 + CGFloat(i) * 17), P(x + 34, sitz - 190 + CGFloat(i) * 17)), .white.opacity(0.7), 3)
            }
            teil(g, box(24, sitz - 104, 152, 110, 22), Pal.band)
            teil(g, box(14, sitz - 6, 172, 36, 12), Pal.band.mal(0.85))
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

// MARK: - Hairstyles Runde 3 (Z-38.3)

/// Quad strokes (from, to, control) for strand lines and highlights.
fileprivate typealias Striche = [(CGPoint, CGPoint, CGPoint)]

extension Zeichner {
    /// Strand lines: lighter than very dark hair (dark lines would vanish in black), darker otherwise.
    var straehnenFarbe: Color {
        let hell: Double = haar.r * 0.3 + haar.g * 0.59 + haar.b * 0.11
        return hell < 0.22 ? haar.mix(Pal.weiss, 0.3).farbe : haar.kontur.opacity(0.6)
    }

    /// One piece of a Runde-3 style: all parts as one shape (outlines first), the color's streaks,
    /// strand lines and a highlight.
    func haarStueck(_ g: GraphicsContext, _ teile: [Path], linien: Striche = [], glanz: Striche = []) {
        verbunden(g, teile, haar)
        if let s = straehne { for p in teile { streifen(g, p, s) } }
        if !linien.isEmpty { linie(g, buendel(linien), straehnenFarbe, 1.8) }
        if !glanz.isEmpty { linie(g, buendel(glanz), .white.opacity(0.42), 4.5) }
    }

    func verbinde(_ teile: Striche...) -> Striche { teile.flatMap { $0 } }

    func buendel(_ l: Striche) -> Path {
        Path { p in
            for (a, b, c) in l {
                p.move(to: a)
                p.addQuadCurve(to: b, control: c)
            }
        }
    }

    /// Mirrors strokes around x = 100.
    func gespiegelteStriche(_ l: Striche) -> Striche {
        l.map { (P(200 - $0.0.x, $0.0.y), P(200 - $0.1.x, $0.1.y), P(200 - $0.2.x, $0.2.y)) }
    }

    /// Faded or shaved sides: a short cap mixed with the skin.
    func seitenFade(_ g: GraphicsContext, _ anteil: Double, ansatz: CGFloat = 60, unten: CGFloat = 94) {
        teil(g, kappe(top: 24, scheitel: 100, ansatz: ansatz, unten: unten), haar.mix(haut, anteil), 2.5)
    }

    /// Hair volume on top only (for styles with faded sides).
    func schopf(top: CGFloat, halb: CGFloat, unten: CGFloat) -> Path {
        let seite: CGFloat = top + (unten - top) * 0.35
        return Path { p in
            p.move(to: P(100 - halb, unten))
            p.addCurve(to: P(100, top), control1: P(100 - halb - 4, seite), control2: P(100 - halb * 0.6, top))
            p.addCurve(to: P(100 + halb, unten), control1: P(100 + halb * 0.6, top), control2: P(100 + halb + 4, seite))
            p.addQuadCurve(to: P(100 - halb, unten), control: P(100, unten - 14))
            p.closeSubpath()
        }
    }

    /// Pointed locks hanging from `oben` between `x0` and `x1`; the tips run from `links` to
    /// `rechts` (y) and lean by `neigung` (negative = swept to the viewer's left).
    func pony(_ x0: CGFloat, _ x1: CGFloat, oben: CGFloat, links: CGFloat, rechts: CGFloat, n: Int, neigung: CGFloat) -> Path {
        let b: CGFloat = (x1 - x0) / CGFloat(n)
        return Path { p in
            p.move(to: P(x0, oben))
            for i in 0..<n {
                let a: CGFloat = x0 + CGFloat(i) * b
                let t: CGFloat = n > 1 ? CGFloat(i) / CGFloat(n - 1) : 0.5
                let spitzeY: CGFloat = links + (rechts - links) * t
                let kerbeY: CGFloat = i == n - 1 ? oben : oben + (spitzeY - oben) * 0.42
                let mitteY: CGFloat = (oben + spitzeY) / 2
                p.addQuadCurve(to: P(a + b * 0.5 + neigung, spitzeY), control: P(a + neigung * 0.3, mitteY + 6))
                let zurueck: CGFloat = spitzeY - (spitzeY - kerbeY) * 0.35
                p.addQuadCurve(to: P(a + b, kerbeY), control: P(a + b * 0.85 + neigung * 0.4, zurueck))
            }
            p.closeSubpath()
        }
    }

    /// A strand line down the middle of each `pony` lock.
    func ponyLinien(_ x0: CGFloat, _ x1: CGFloat, oben: CGFloat, links: CGFloat, rechts: CGFloat, n: Int, neigung: CGFloat) -> Striche {
        let b: CGFloat = (x1 - x0) / CGFloat(n)
        return (0..<n).map { (i: Int) -> (CGPoint, CGPoint, CGPoint) in
            let a: CGFloat = x0 + CGFloat(i) * b
            let t: CGFloat = n > 1 ? CGFloat(i) / CGFloat(n - 1) : 0.5
            let spitzeY: CGFloat = links + (rechts - links) * t
            let ende = P(a + b * 0.5 + neigung * 0.8, spitzeY - (spitzeY - oben) * 0.22)
            return (P(a + b * 0.5, oben + 4), ende, P(a + b * 0.45 + neigung * 0.2, (oben + spitzeY) / 2))
        }
    }

    /// One pointed lock from `basis` (`b` wide) to `spitze`, bowed to one side by `biegung`.
    func locke(_ basis: CGPoint, _ spitze: CGPoint, _ b: CGFloat, _ biegung: CGFloat = 0.25) -> Path {
        let dx = spitze.x - basis.x
        let dy = spitze.y - basis.y
        let l = max(1, (dx * dx + dy * dy).squareRoot())
        let nx: CGFloat = -dy / l * b / 2
        let ny: CGFloat = dx / l * b / 2
        let mx: CGFloat = basis.x + dx * 0.5 + nx * biegung * 4
        let my: CGFloat = basis.y + dy * 0.5 + ny * biegung * 4
        return Path { p in
            p.move(to: P(basis.x + nx, basis.y + ny))
            p.addQuadCurve(to: spitze, control: P(mx + nx, my + ny))
            p.addQuadCurve(to: P(basis.x - nx, basis.y - ny), control: P(mx - nx * 0.6, my - ny * 0.6))
            p.closeSubpath()
        }
    }

    /// Front strand from the temple past the shoulder down to `u` (viewer's left; mirror with `gespiegelt`).
    func strang(u: CGFloat, breit: CGFloat = 30, aussen: CGFloat = 28) -> Path {
        let innen: CGFloat = aussen + breit
        return Path { p in
            p.move(to: P(46, 80))
            p.addCurve(to: P(aussen, u - 10), control1: P(34, 118), control2: P(aussen, u - 50))
            p.addQuadCurve(to: P(innen, u), control: P((aussen + innen) / 2 - 4, u + 8))
            p.addCurve(to: P(60, 104), control1: P(innen, u - 60), control2: P(58, 140))
            p.closeSubpath()
        }
    }

    func strangLinien(u: CGFloat, breit: CGFloat = 30, aussen: CGFloat = 28) -> Striche {
        [(P(48, 100), P(aussen + breit * 0.35, u - 14), P(38, u * 0.55 + 40)),
         (P(55, 112), P(aussen + breit * 0.72, u - 8), P(50, u * 0.6 + 40))]
    }

    /// Wavy front strand (viewer's left).
    func wellenStrang(u: CGFloat) -> Path {
        Path { p in
            p.move(to: P(46, 80))
            p.addQuadCurve(to: P(34, 120), control: P(30, 96))
            p.addQuadCurve(to: P(36, 160), control: P(46, 140))
            p.addQuadCurve(to: P(28, 198), control: P(22, 180))
            p.addQuadCurve(to: P(38, u), control: P(40, u - 16))
            p.addQuadCurve(to: P(64, u - 4), control: P(52, u + 6))
            p.addQuadCurve(to: P(58, 196), control: P(68, u - 22))
            p.addQuadCurve(to: P(62, 156), control: P(48, 176))
            p.addQuadCurve(to: P(56, 116), control: P(70, 136))
            p.addQuadCurve(to: P(60, 100), control: P(54, 104))
            p.closeSubpath()
        }
    }

    /// Braid: overlapping ovals from `a` to `b` with a woven line in each.
    func zopfKette(_ g: GraphicsContext, von a: CGPoint, bis b: CGPoint, n: Int, r: CGFloat) {
        let glieder = (0..<n).map { zwischen(a, b, CGFloat($0) / CGFloat(max(n - 1, 1))) }
        for c in glieder { g.fill(oval(c, r + 2, r * 0.9 + 2), with: .color(haar.kontur)) }
        for c in glieder {
            g.fill(oval(c, r, r * 0.9), with: .color(haar.farbe))
            linie(g, bogen(P(c.x - r * 0.7, c.y - r * 0.2), P(c.x + r * 0.7, c.y - r * 0.2), P(c.x, c.y + r * 0.5)), straehnenFarbe, 1.4)
        }
    }

    /// A thin box braid from `a` to `b`.
    func flechte(_ g: GraphicsContext, von a: CGPoint, bis b: CGPoint) {
        let s = strich(a, b)
        linie(g, s, haar.kontur, 9)
        linie(g, s, haar.farbe, 6)
        let n = Int(max(1, abs(b.y - a.y) / 8))
        for i in 0..<n {
            let c = zwischen(a, b, (CGFloat(i) + 0.5) / CGFloat(n))
            linie(g, strich(P(c.x - 3, c.y - 2), P(c.x + 3, c.y + 2)), straehnenFarbe, 1.2)
        }
    }

    /// Curly puff: bumps around a circle.
    func puff(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat) {
        var bumps: [CGPoint] = []
        for i in 0..<10 {
            let a = Double(i) / 10 * 2 * Double.pi
            bumps.append(P(c.x + r * CGFloat(cos(a)), c.y + r * CGFloat(sin(a))))
        }
        let klein: CGFloat = r * 0.42
        for b in bumps { g.fill(kreis(b, klein + 2.5), with: .color(haar.kontur)) }
        g.fill(kreis(c, r + 2), with: .color(haar.kontur))
        for b in bumps { g.fill(kreis(b, klein), with: .color(haar.farbe)) }
        g.fill(kreis(c, r), with: .color(haar.farbe))
        for b in bumps.prefix(5) { linie(g, bogen(P(b.x - 3, b.y), P(b.x + 3, b.y + 1), P(b.x, b.y - 4)), straehnenFarbe, 1.3) }
    }

    /// Fix round 4: Ahmed's own hairstyles (from his photos), all drawn with the sticker curl engine.
    /// 78 curly fringe over one eye, 79 mushroom cloud (his standard), 80 wavy side swoop,
    /// 81 extra fluffy curls, 82 gym wet look.
    func ahmedFrisur(_ g: GraphicsContext) {
        switch frisur {
        case 78: lockenWolke(g, fransen: 88, neigung: -4, auge: true)
        case 79: lockenWolke(g, fransen: 92)
        case 80: lockenWolke(g, fransen: 86, neigung: 10)
        case 81: lockenWolke(g, fransen: 84, wolke: 1.12)
        default: lockenWolke(g, fransen: 100, nass: true)
        }
    }

    /// Fix round 5: curls like the ChatGPT stickers (`design/ki/sticker/wir-ich.png`): one solid
    /// near-black mass with a soft cloud silhouette only slightly wider than the head, built from big
    /// soft wave clumps with pointed tips, a messy fringe of thick pointed strands curving across the
    /// forehead, a few broad subtle highlight arcs, over a low taper with free ears. No thin squiggles.
    /// `fransen`: where the fringe ends (y), `neigung` leans it, `wolke` > 1 adds volume and clumps,
    /// `auge` dips one strand toward the right eye, `nass` = flatter mass with longer, thinner strands.
    func lockenWolke(_ g: GraphicsContext, fransen: CGFloat, neigung: CGFloat = 0, wolke: CGFloat = 1, auge: Bool = false, nass: Bool = false) {
        seitenFade(g, 0.6, ansatz: 64, unten: 98)
        var h = g
        h.translateBy(x: 0, y: 6)
        let senken: CGFloat = nass ? 8 : 0
        let r0: CGFloat = 18 * wolke * (nass ? 0.85 : 1)
        let mittelpunkte: [CGPoint] = [
            P(46, 60), P(54, 38), P(72, 22), P(96, 14 + senken), P(120, 16 + senken), P(142, 26), P(154, 46), P(156, 64),
        ]
        let dom = Path { p in
            p.move(to: P(38, 80))
            p.addCurve(to: P(100, 14 + senken), control1: P(34, 32), control2: P(62, 14 + senken))
            p.addCurve(to: P(162, 80), control1: P(138, 14 + senken), control2: P(166, 32))
            p.addQuadCurve(to: P(38, 80), control: P(100, 62))
            p.closeSubpath()
        }
        var teile: [Path] = [dom]
        for c in mittelpunkte { teile.append(kreis(c, r0)) }
        // Big soft wave clumps with pointed tips around the outline.
        var klumpen: [(CGPoint, CGPoint, CGFloat, CGFloat)] = [
            (P(50, 56), P(30, 84), 26, -0.5), (P(58, 34), P(32, 42), 24, 0.45), (P(80, 20), P(64, 6 + senken), 22, -0.4),
            (P(110, 16), P(124, 4 + senken), 22, 0.4), (P(140, 30), P(166, 36), 24, -0.45), (P(152, 56), P(172, 84), 26, 0.5),
        ]
        if wolke > 1.05 {
            klumpen += [(P(96, 14), P(90, 0), 20, 0.3), (P(126, 18), P(146, 12), 20, -0.3)]
        }
        // Thick pointed fringe strands curving across the forehead.
        klumpen += [
            (P(62, 54), P(54, fransen - 8), 24, -0.55), (P(82, 52), P(84 + neigung, fransen), 24, 0.5),
            (P(102, 52), P(110 + neigung, fransen + 2), 24, -0.5), (P(122, 54), P(132 + neigung, fransen - 4), 22, 0.5),
            (P(140, 58), P(150 + neigung, fransen - 14), 18, -0.4),
        ]
        if auge { klumpen.append((P(114, 52), P(126, fransen + 16), 26, 0.45)) }
        if nass { klumpen.append((P(92, 54), P(94, fransen + 6), 16, 0.2)) }
        for k in klumpen { teile.append(locke(k.0, k.1, k.2, k.3)) }
        verbunden(h, teile, haar)
        if let s = straehne { for p in teile { streifen(h, p, s) } }
        // Subtle clump separations: a few broad soft curves.
        let trennungen: Striche = [
            (P(60, 40), P(46, 70), P(46, 52)), (P(84, 26), P(70, 48), P(72, 34)),
            (P(118, 24), P(132, 46), P(130, 32)), (P(144, 40), P(156, 70), P(156, 52)),
        ]
        linie(h, buendel(trennungen), haar.mix(Pal.weiss, 0.12).farbe, 2.4)
        // Broad, subtle highlight arcs.
        let glanz = Path { p in
            p.addArc(center: P(78, 40), radius: 22, startAngle: .degrees(215), endAngle: .degrees(285), clockwise: false)
            p.move(to: P(112 + 20 * CGFloat(cos(235 * Double.pi / 180)), 34 + 20 * CGFloat(sin(235 * Double.pi / 180))))
            p.addArc(center: P(112, 34), radius: 20, startAngle: .degrees(235), endAngle: .degrees(305), clockwise: false)
        }
        linie(h, glanz, haar.mix(Pal.weiss, nass ? 0.3 : 0.2).farbe, 5)
    }

    /// Standard highlight on the left of the crown.
    var glanzLinks: Striche { [(P(62, 56), P(88, 28), P(66, 34)), (P(94, 24), P(104, 23), P(99, 21))] }

    func neueFrisurHinten(_ g: GraphicsContext) {
        switch frisur {
        case 44:
            haarStueck(g, [langHinten(128)])
        case 45:
            haarStueck(g, [langHinten(150), locke(P(40, 138), P(24, 160), 16, -0.3), locke(P(160, 138), P(176, 160), 16, 0.3)])
        case 46:
            haarStueck(g, [langHinten(176)])
        case 47:
            haarStueck(g, [box(46, 60, 108, 124, 34), locke(P(56, 176), P(50, 196), 14), locke(P(144, 176), P(150, 196), 14)],
                   linien: [(P(56, 120), P(58, 178), P(52, 150)), (P(144, 120), P(142, 178), P(148, 150))])
        case 54:
            haarTeil(g, kreis(P(100, 16), 15))
            linie(g, bogen(P(90, 12), P(110, 20), P(102, 6)), straehnenFarbe, 1.6)
        case 56, 58, 63, 66, 70, 73:
            let seiten: Striche = [(P(36, 110), P(34, 226), P(28, 170)), (P(164, 110), P(166, 226), P(172, 170))]
            haarStueck(g, [langHinten(frisur == 56 ? 236 : 230)], linien: seiten)
        case 57:
            haarStueck(g, [langHinten(222), locke(P(44, 214), P(40, 236), 18), locke(P(156, 214), P(160, 236), 18)])
        case 59:
            haarStueck(g, [langHinten(226), wellenStrang(u: 228), gespiegelt(wellenStrang(u: 228))])
        case 60:
            let schwanz = Path { p in
                p.move(to: P(118, 30))
                p.addCurve(to: P(176, 196), control1: P(186, 30), control2: P(196, 140))
                p.addCurve(to: P(150, 110), control1: P(160, 196), control2: P(150, 150))
                p.addCurve(to: P(128, 40), control1: P(150, 70), control2: P(140, 44))
                p.closeSubpath()
            }
            haarStueck(g, [schwanz], linien: [(P(132, 44), P(170, 186), P(176, 90)), (P(140, 70), P(160, 180), P(158, 120))], glanz: [(P(146, 50), P(168, 110), P(168, 70))])
            teil(g, oval(P(126, 32), 7, 9), Pal.dunkel, 2)
        case 61:
            haarStueck(g, [kreis(P(100, 14), 20), locke(P(112, 6), P(130, -2), 8, 0.4)],
                   linien: [(P(84, 10), P(114, 20), P(100, 0)), (P(90, 22), P(116, 8), P(108, 26))])
        case 62:
            haarStueck(g, [kreis(P(154, 136), 19)], linien: [(P(140, 132), P(166, 140), P(154, 124)), (P(144, 144), P(164, 130), P(160, 148))])
        case 64:
            haarStueck(g, [langHinten(178)])
        case 65:
            haarStueck(g, [box(32, 30, 136, 124, 50)])
        case 69:
            haarStueck(g, [langHinten(212)])
            var locken = seitenLocken(212)
            for y in stride(from: CGFloat(110), through: 200, by: 22) { locken += [P(28, y), P(172, y)] }
            lockenKette(g, locken, 15)
        case 71:
            haarStueck(g, [langHinten(188), locke(P(34, 178), P(20, 198), 16, -0.3), locke(P(58, 184), P(54, 204), 14),
                       locke(P(166, 178), P(180, 198), 16, 0.3), locke(P(142, 184), P(146, 204), 14)])
        case 72:
            haarStueck(g, [langHinten(224)])
        case 74:
            haarStueck(g, [oval(P(100, 22), 34, 18)], linien: [(P(72, 22), P(128, 22), P(100, 10)), (P(76, 28), P(124, 30), P(100, 40))])
            teil(g, box(80, 6, 40, 16, 5), FigurFarbe(0xB07A4F), 2)
            for x in stride(from: CGFloat(86), through: 114, by: 7) { linie(g, strich(P(x, 18), P(x, 26)), FigurFarbe(0x7A5234).farbe, 2) }
        case 75:
            let schwanz = Path { p in
                p.move(to: P(94, 14))
                p.addCurve(to: P(168, 170), control1: P(150, -4), control2: P(190, 100))
                p.addCurve(to: P(140, 90), control1: P(152, 170), control2: P(142, 130))
                p.addCurve(to: P(108, 20), control1: P(138, 50), control2: P(124, 22))
                p.closeSubpath()
            }
            haarStueck(g, [schwanz], linien: [(P(112, 16), P(164, 158), P(170, 60))])
            for i in 0..<6 {
                let a = Double(i) / 6 * 2 * Double.pi
                teil(g, kreis(P(102 + 8 * CGFloat(cos(a)), 16 + 5 * CGFloat(sin(a))), 5), Pal.rose, 1.5)
            }
        case 76:
            puff(g, P(56, 30), 24)
            puff(g, P(144, 30), 24)
        case 77:
            for x in stride(from: CGFloat(34), through: 166, by: 11) where abs(x - 100) > 36 {
                flechte(g, von: P(x, 70), bis: P(x + (x < 100 ? -4 : 4), 232))
            }
        default:
            break
        }
    }

    func neueFrisurVorn(_ g: GraphicsContext) {
        switch frisur {
        case 34:
            // Ahmed's Bitmoji (fix round 2, after the `wir-*` stickers): full, messy, textured hair with
            // fluffy volume on top, locks falling over the ear tops and a wavy fringe into the forehead.
            let k = kappe(top: 14, scheitel: 118, ansatz: 44, unten: 100)
            let fr = pony(46, 152, oben: 34, links: 88, rechts: 72, n: 6, neigung: -7)
            let volumen = [oval(P(64, 40), 22, 20), oval(P(88, 24), 23, 19), oval(P(114, 22), 23, 19), oval(P(138, 36), 22, 20)]
            let locken = [locke(P(50, 66), P(38, 108), 18, -0.3), locke(P(150, 66), P(162, 106), 18, 0.3),
                          locke(P(58, 30), P(42, 44), 14, -0.6), locke(P(142, 28), P(158, 42), 14, 0.6),
                          locke(P(72, 20), P(60, 8), 10, -0.5), locke(P(130, 18), P(144, 8), 10, 0.5)]
            let linien = verbinde(ponyLinien(46, 152, oben: 34, links: 88, rechts: 72, n: 6, neigung: -7),
                                  [(P(118, 16), P(72, 44), P(90, 20)), (P(126, 22), P(100, 52), P(116, 28)), (P(140, 30), P(148, 62), P(148, 44)),
                                   (P(70, 30), P(56, 60), P(58, 40)), (P(96, 12), P(84, 30), P(90, 18)),
                                   (P(150, 60), P(160, 96), P(158, 76)), (P(50, 62), P(42, 98), P(42, 78))])
            haarStueck(g, [k, fr] + volumen + locken, linien: linien, glanz: [(P(66, 34), P(92, 18), P(72, 20)), (P(104, 16), P(120, 18), P(112, 13))])
        case 35:
            seitenFade(g, 0.5)
            let fr = pony(54, 146, oben: 40, links: 70, rechts: 62, n: 6, neigung: -6)
            haarStueck(g, [schopf(top: 14, halb: 50, unten: 64), fr, locke(P(96, 20), P(86, 4), 9, -0.3)],
                   linien: ponyLinien(54, 146, oben: 40, links: 70, rechts: 62, n: 6, neigung: -6), glanz: glanzLinks)
        case 36:
            let fr = pony(46, 100, oben: 40, links: 92, rechts: 58, n: 3, neigung: -7)
            let fl = ponyLinien(46, 100, oben: 40, links: 92, rechts: 58, n: 3, neigung: -7)
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 44, unten: 98), fr, gespiegelt(fr)],
                   linien: verbinde(fl, gespiegelteStriche(fl), [(P(100, 18), P(100, 44), P(99, 30))]), glanz: glanzLinks)
        case 37:
            seitenFade(g, 0.55, ansatz: 58)
            let quiff = Path { p in
                p.move(to: P(56, 60))
                p.addCurve(to: P(92, 4), control1: P(50, 30), control2: P(64, 6))
                p.addCurve(to: P(146, 34), control1: P(124, 2), control2: P(150, 14))
                p.addCurve(to: P(146, 58), control1: P(144, 44), control2: P(148, 52))
                p.addQuadCurve(to: P(56, 60), control: P(100, 42))
                p.closeSubpath()
            }
            haarStueck(g, [quiff], linien: [(P(64, 52), P(96, 10), P(66, 22)), (P(84, 50), P(118, 8), P(88, 18)), (P(108, 48), P(138, 22), P(120, 24))],
                   glanz: [(P(72, 38), P(96, 14), P(78, 20))])
        case 38:
            seitenFade(g, 0.5, ansatz: 62)
            let fr = pony(52, 148, oben: 44, links: 60, rechts: 58, n: 9, neigung: 1)
            var textur: Striche = []
            for x in stride(from: CGFloat(62), through: 138, by: 12) { textur.append((P(x, 24), P(x + 2, 40), P(x - 1, 32))) }
            haarStueck(g, [schopf(top: 18, halb: 50, unten: 58), fr], linien: textur, glanz: glanzLinks)
        case 39:
            teil(g, kappe(top: 26, scheitel: 100, ansatz: 54, unten: 90), haar.mix(haut, 0.4), 2.5)
            linie(g, bogen(P(62, 60), P(86, 36), P(66, 44)), haut.farbe, 2.5)
            linie(g, buendel([(P(70, 40), P(96, 30), P(80, 32))]), .white.opacity(0.3), 3.5)
        case 40:
            seitenFade(g, 0.55)
            let top = Path { p in
                p.move(to: P(54, 62))
                p.addCurve(to: P(100, 12), control1: P(50, 30), control2: P(70, 12))
                p.addCurve(to: P(150, 60), control1: P(132, 12), control2: P(154, 34))
                p.addCurve(to: P(74, 50), control1: P(128, 48), control2: P(96, 44))
                p.addQuadCurve(to: P(54, 62), control: P(62, 52))
                p.closeSubpath()
            }
            haarStueck(g, [top], linien: [(P(80, 20), P(148, 52), P(126, 22)), (P(80, 34), P(140, 58), P(118, 36))], glanz: [(P(84, 22), P(120, 18), P(100, 14))])
            linie(g, bogen(P(72, 50), P(80, 18), P(72, 30)), haut.mal(0.9).farbe, 2)
        case 41:
            seitenFade(g, 0.55, ansatz: 58)
            let pomp = Path { p in
                p.move(to: P(54, 60))
                p.addCurve(to: P(100, 2), control1: P(46, 22), control2: P(66, 2))
                p.addCurve(to: P(146, 60), control1: P(134, 2), control2: P(154, 22))
                p.addQuadCurve(to: P(54, 60), control: P(100, 50))
                p.closeSubpath()
            }
            haarStueck(g, [pomp], linien: [(P(62, 56), P(96, 8), P(62, 24)), (P(80, 54), P(110, 6), P(82, 18)), (P(102, 52), P(128, 10), P(106, 16)), (P(122, 54), P(142, 24), P(130, 26))],
                   glanz: [(P(70, 30), P(96, 10), P(76, 14))])
        case 42:
            let k = kappe(top: 20, scheitel: 100, ansatz: 56, unten: 94)
            let spitzen: [(CGFloat, CGFloat)] = [(58, 20), (76, 8), (94, 3), (112, 5), (130, 10), (146, 22)]
            let teile = [k] + spitzen.map { locke(P($0.0, 38), P($0.0 + ($0.0 - 100) * 0.12, $0.1), 18) }
            haarStueck(g, teile, linien: spitzen.map { (P($0.0, 40), P($0.0 + ($0.0 - 100) * 0.1, $0.1 + 10), P($0.0, 28)) }, glanz: glanzLinks)
        case 43:
            seitenFade(g, 0.65, ansatz: 62, unten: 92)
            let top = Path { p in
                p.move(to: P(52, 60))
                p.addCurve(to: P(96, 10), control1: P(48, 28), control2: P(66, 10))
                p.addCurve(to: P(160, 70), control1: P(136, 10), control2: P(162, 36))
                p.addCurve(to: P(150, 96), control1: P(162, 84), control2: P(156, 94))
                p.addCurve(to: P(110, 52), control1: P(146, 72), control2: P(130, 54))
                p.addQuadCurve(to: P(52, 60), control: P(78, 50))
                p.closeSubpath()
            }
            haarStueck(g, [top], linien: [(P(62, 52), P(150, 84), P(116, 16)), (P(76, 50), P(146, 94), P(128, 30))], glanz: [(P(70, 30), P(110, 16), P(84, 18))])
        case 44:
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 50, unten: 104)],
                   linien: [(P(66, 58), P(86, 18), P(70, 30)), (P(86, 50), P(100, 16), P(88, 26)), (P(114, 50), P(104, 16), P(112, 26)), (P(134, 58), P(114, 18), P(130, 30))],
                   glanz: [(P(60, 50), P(92, 22), P(66, 28)), (P(110, 22), P(136, 36), P(128, 24))])
        case 45:
            haarStueck(g, [kappe(top: 12, scheitel: 100, ansatz: 48, unten: 110), locke(P(44, 100), P(30, 128), 14, -0.3), locke(P(156, 100), P(170, 128), 14, 0.3)],
                   linien: [(P(64, 56), P(58, 110), P(50, 70)), (P(82, 48), P(100, 14), P(84, 24)), (P(118, 48), P(100, 14), P(116, 24)), (P(136, 56), P(142, 110), P(150, 70))],
                   glanz: glanzLinks)
        case 46:
            let s = strang(u: 170, breit: 24, aussen: 30)
            let sl = strangLinien(u: 170, breit: 24, aussen: 30)
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 46, unten: 108), s, gespiegelt(s)],
                   linien: verbinde(sl, gespiegelteStriche(sl), [(P(100, 16), P(100, 46), P(99, 30)), (P(98, 46), P(56, 86), P(66, 50)), (P(102, 46), P(144, 86), P(134, 50))]),
                   glanz: glanzLinks)
        case 47:
            let fr = pony(54, 146, oben: 40, links: 64, rechts: 64, n: 7, neigung: 0)
            haarStueck(g, [kappe(top: 18, scheitel: 100, ansatz: 54, unten: 104), fr],
                   linien: ponyLinien(54, 146, oben: 40, links: 64, rechts: 64, n: 7, neigung: 0), glanz: glanzLinks)
        case 48:
            seitenFade(g, 0.6)
            let top = Path { p in
                p.move(to: P(50, 60))
                p.addCurve(to: P(100, 14), control1: P(48, 28), control2: P(70, 14))
                p.addCurve(to: P(150, 60), control1: P(130, 14), control2: P(152, 28))
                p.addQuadCurve(to: P(50, 60), control: P(100, 62))
                p.closeSubpath()
            }
            var textur: Striche = []
            for x in stride(from: CGFloat(58), through: 142, by: 10) { textur.append((P(x, 40), P(x, 58), P(x + 1, 50))) }
            haarStueck(g, [top], linien: textur, glanz: [(P(64, 34), P(92, 20), P(72, 22))])
        case 49:
            seitenFade(g, 0.5)
            let fr = pony(52, 148, oben: 44, links: 62, rechts: 60, n: 10, neigung: -3)
            haarStueck(g, [schopf(top: 16, halb: 50, unten: 56), fr, locke(P(84, 22), P(76, 6), 9, -0.3), locke(P(108, 20), P(116, 4), 9, 0.3)],
                   linien: ponyLinien(52, 148, oben: 44, links: 62, rechts: 60, n: 10, neigung: -3), glanz: glanzLinks)
        case 50:
            seitenFade(g, 0.6)
            haarStueck(g, [schopf(top: 22, halb: 26, unten: 60), locke(P(88, 48), P(92, 14), 22), locke(P(100, 38), P(104, 2), 22), locke(P(112, 48), P(116, 12), 20)],
                   linien: [(P(92, 50), P(98, 12), P(92, 30)), (P(108, 50), P(112, 16), P(108, 30))], glanz: [(P(86, 36), P(96, 12), P(88, 20))])
        case 51:
            let k = kappe(top: 22, scheitel: 100, ansatz: 54, unten: 92)
            teil(g, k, haar, 2.5)
            var wellen = Path()
            for y in stride(from: CGFloat(30), through: 54, by: 8) {
                wellen.addPath(Path { p in
                    p.move(to: P(56, y + 6))
                    for i in 0..<6 {
                        let xa: CGFloat = 56 + CGFloat(i) * 15
                        let dy: CGFloat = i % 2 == 0 ? -4 : 4
                        p.addQuadCurve(to: P(xa + 15, y + 6), control: P(xa + 7.5, y + 6 + dy))
                    }
                })
            }
            var h = g
            h.clip(to: k)
            linie(h, wellen, straehnenFarbe, 1.6)
            linie(g, buendel(glanzLinks), .white.opacity(0.35), 4)
        case 52:
            seitenFade(g, 0.55)
            haarStueck(g, [schopf(top: 24, halb: 48, unten: 58)])
            for x in stride(from: CGFloat(58), through: 142, by: 12) {
                let strang = box(x - 5, 14 + abs(x - 100) * 0.22, 10, 24, 5)
                linie(g, strang, haar.kontur, 3)
                g.fill(strang, with: .color(haar.farbe))
                linie(g, strich(P(x - 3, 20 + abs(x - 100) * 0.22), P(x + 3, 26 + abs(x - 100) * 0.22)), straehnenFarbe, 1.3)
            }
        case 53:
            teil(g, kappe(top: 24, scheitel: 100, ansatz: 50, unten: 92), haar.mix(haut, 0.3), 2.5)
            for x in [CGFloat(64), 82, 100, 118, 136] {
                zopfKette(g, von: P(x, 54), bis: P(100 + (x - 100) * 0.45, 24), n: 5, r: 5)
            }
        case 54:
            seitenFade(g, 0.55)
            haarStueck(g, [schopf(top: 22, halb: 44, unten: 56)],
                   linien: [(P(66, 52), P(94, 24), P(74, 30)), (P(100, 52), P(100, 24), P(102, 38)), (P(134, 52), P(106, 24), P(126, 30))], glanz: glanzLinks)
        case 55:
            let fr = pony(46, 154, oben: 38, links: 72, rechts: 70, n: 8, neigung: 3)
            let flicks = [locke(P(44, 60), P(24, 74), 14, -0.3), locke(P(156, 60), P(176, 72), 14, 0.3),
                          locke(P(62, 22), P(46, 8), 12, -0.3), locke(P(138, 22), P(154, 8), 12, 0.3), locke(P(100, 12), P(104, 0), 12, 0.2)]
            haarStueck(g, [kappe(top: 8, scheitel: 100, ansatz: 50, unten: 104), fr] + flicks,
                   linien: ponyLinien(46, 154, oben: 38, links: 72, rechts: 70, n: 8, neigung: 3), glanz: glanzLinks)
        case 56:
            // Annika's Bitmoji: long, straight, middle part, front strands over the shoulders.
            let s = strang(u: 232, breit: 32, aussen: 26)
            let sl = strangLinien(u: 232, breit: 32, aussen: 26)
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 42, unten: 108), s, gespiegelt(s)],
                   linien: verbinde(sl, gespiegelteStriche(sl), [(P(100, 16), P(100, 44), P(99, 30)), (P(98, 42), P(52, 88), P(64, 48)), (P(102, 42), P(148, 88), P(136, 48))]),
                   glanz: [(P(60, 64), P(84, 30), P(64, 40)), (P(116, 26), P(130, 30), P(124, 25))])
        case 57:
            let s = strang(u: 196, breit: 30, aussen: 28)
            let lagen = [locke(P(52, 90), P(66, 144), 18, 0.3), locke(P(148, 90), P(134, 144), 18, -0.3)]
            let sl = strangLinien(u: 196)
            haarStueck(g, [kappe(top: 12, scheitel: 92, ansatz: 44, unten: 108), s, gespiegelt(s)] + lagen,
                   linien: verbinde(sl, gespiegelteStriche(sl), [(P(92, 44), P(56, 84), P(64, 50))]), glanz: glanzLinks)
        case 58:
            let vorhang = Path { p in
                p.move(to: P(100, 38))
                p.addCurve(to: P(54, 100), control1: P(76, 40), control2: P(56, 64))
                p.addLine(to: P(64, 102))
                p.addCurve(to: P(98, 50), control1: P(66, 72), control2: P(82, 52))
                p.closeSubpath()
            }
            let s = strang(u: 226)
            let sl = strangLinien(u: 226)
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 44, unten: 108), s, gespiegelt(s), vorhang, gespiegelt(vorhang)],
                   linien: verbinde(sl, gespiegelteStriche(sl), [(P(96, 48), P(62, 94), P(70, 58)), (P(104, 48), P(138, 94), P(130, 58))]), glanz: glanzLinks)
        case 59:
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 44, unten: 108)],
                   linien: [(P(100, 16), P(100, 44), P(99, 30)), (P(96, 44), P(54, 90), P(62, 52)), (P(104, 44), P(146, 90), P(138, 52))], glanz: glanzLinks)
        case 60:
            haarStueck(g, [kappe(top: 18, scheitel: 100, ansatz: 50, unten: 94)],
                   linien: [(P(62, 60), P(124, 28), P(80, 30)), (P(84, 52), P(126, 30), P(100, 36)), (P(138, 60), P(128, 30), P(140, 42))],
                   glanz: [(P(64, 50), P(96, 24), P(70, 28)), (P(104, 22), P(122, 26), P(114, 20))])
        case 61:
            haarStueck(g, [kappe(top: 18, scheitel: 100, ansatz: 50, unten: 100), locke(P(52, 84), P(58, 140), 10, 0.4), locke(P(148, 84), P(142, 140), 10, -0.4)],
                   linien: [(P(66, 58), P(94, 22), P(72, 30)), (P(134, 58), P(106, 22), P(128, 30))], glanz: glanzLinks)
        case 62:
            haarStueck(g, [kappe(top: 16, scheitel: 100, ansatz: 46, unten: 104)],
                   linien: [(P(100, 18), P(100, 46), P(99, 32)), (P(96, 46), P(56, 92), P(62, 54)), (P(104, 46), P(146, 92), P(138, 54))],
                   glanz: [(P(60, 60), P(86, 28), P(64, 36)), (P(114, 28), P(140, 60), P(136, 36))])
        case 63:
            let s = strang(u: 222)
            let sl = strangLinien(u: 222)
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 46, unten: 106), s, gespiegelt(s)],
                   linien: verbinde(sl, gespiegelteStriche(sl), [(P(100, 16), P(100, 46), P(99, 30))]), glanz: glanzLinks)
            let schleife = Path { p in
                p.move(to: P(100, 14))
                p.addLine(to: P(82, 4))
                p.addLine(to: P(82, 24))
                p.closeSubpath()
            }
            teil(g, schleife, Pal.rose, 2)
            teil(g, gespiegelt(schleife), Pal.rose, 2)
            teil(g, kreis(P(100, 14), 4.5), Pal.rose.mal(0.85), 2)
        case 64:
            let s = strang(u: 176, breit: 30, aussen: 28)
            let sl = strangLinien(u: 176)
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 44, unten: 108), s, gespiegelt(s)],
                   linien: verbinde(sl, gespiegelteStriche(sl), [(P(100, 16), P(100, 44), P(99, 30))]), glanz: glanzLinks)
        case 65:
            let seite = Path { p in
                p.move(to: P(44, 70))
                p.addQuadCurve(to: P(36, 110), control: P(32, 90))
                p.addQuadCurve(to: P(42, 150), control: P(48, 130))
                p.addQuadCurve(to: P(68, 150), control: P(56, 160))
                p.addQuadCurve(to: P(58, 110), control: P(70, 130))
                p.addQuadCurve(to: P(56, 76), control: P(52, 92))
                p.closeSubpath()
            }
            let welle = Path { p in
                p.move(to: P(70, 46))
                p.addCurve(to: P(152, 86), control1: P(112, 30), control2: P(150, 52))
                p.addCurve(to: P(104, 62), control1: P(140, 70), control2: P(122, 60))
                p.addCurve(to: P(70, 46), control1: P(88, 64), control2: P(74, 56))
                p.closeSubpath()
            }
            haarStueck(g, [kappe(top: 16, scheitel: 76, ansatz: 50, unten: 106), seite, gespiegelt(seite), welle],
                   linien: [(P(76, 48), P(146, 80), P(118, 42)), (P(46, 90), P(50, 144), P(38, 120)), (P(154, 90), P(150, 144), P(162, 120))], glanz: glanzLinks)
        case 66, 70:
            let ponyForm = Path { p in
                p.move(to: P(50, 44))
                p.addCurve(to: P(100, 20), control1: P(52, 26), control2: P(72, 20))
                p.addCurve(to: P(150, 44), control1: P(128, 20), control2: P(148, 26))
                p.addLine(to: P(152, 72))
                p.addQuadCurve(to: P(48, 72), control: P(100, 78))
                p.closeSubpath()
            }
            var textur: Striche = []
            for x in stride(from: CGFloat(62), through: 138, by: 12) { textur.append((P(x, 36), P(x, 68), P(x - 2, 52))) }
            var teile = [kappe(top: 14, scheitel: 100, ansatz: 50, unten: 108), ponyForm]
            if frisur == 66 {
                let s = strang(u: 228)
                teile += [s, gespiegelt(s)]
                textur += verbinde(strangLinien(u: 228), gespiegelteStriche(strangLinien(u: 228)))
            } else {
                let seite = Path { p in
                    p.move(to: P(44, 76))
                    p.addLine(to: P(38, 152))
                    p.addLine(to: P(64, 152))
                    p.addLine(to: P(60, 90))
                    p.closeSubpath()
                }
                teile += [seite, gespiegelt(seite)]
            }
            haarStueck(g, teile, linien: textur, glanz: [(P(64, 34), P(92, 24), P(72, 24))])
        case 67:
            let schwung = Path { p in
                p.move(to: P(64, 40))
                p.addCurve(to: P(160, 110), control1: P(120, 30), control2: P(162, 70))
                p.addLine(to: P(146, 114))
                p.addCurve(to: P(70, 54), control1: P(140, 76), control2: P(108, 50))
                p.closeSubpath()
            }
            haarStueck(g, [kappe(top: 16, scheitel: 78, ansatz: 50, unten: 104), schwung],
                   linien: [(P(72, 44), P(152, 104), P(136, 46)), (P(80, 52), P(148, 110), P(126, 58))], glanz: glanzLinks)
            zopfKette(g, von: P(152, 114), bis: P(142, 226), n: 8, r: 11)
            teil(g, kreis(P(141, 234), 5), Pal.rose, 2)
        case 68:
            haarStueck(g, [kappe(top: 18, scheitel: 100, ansatz: 50, unten: 98)], linien: [(P(100, 20), P(100, 50), P(99, 34))], glanz: glanzLinks)
            for seite in [CGFloat(-1), 1] {
                zopfKette(g, von: P(100 + seite * 26, 44), bis: P(100 + seite * 48, 96), n: 4, r: 8)
                zopfKette(g, von: P(100 + seite * 52, 104), bis: P(100 + seite * 56, 214), n: 7, r: 10)
                teil(g, kreis(P(100 + seite * 56, 224), 4.5), Pal.rose, 1.5)
            }
        case 69:
            haarStueck(g, [kappe(top: 14, scheitel: 100, ansatz: 46, unten: 106)], linien: [(P(100, 16), P(100, 44), P(99, 30))])
            lockenKette(g, [P(58, 42), P(74, 26), P(90, 20), P(110, 20), P(126, 26), P(142, 42)], 12)
            lockenKette(g, seitenLocken(200), 12)
        case 71:
            let fr = pony(52, 148, oben: 40, links: 72, rechts: 72, n: 7, neigung: 0)
            let lagen = [locke(P(48, 94), P(34, 140), 16, -0.3), locke(P(50, 124), P(40, 172), 14, -0.2),
                         locke(P(152, 94), P(166, 140), 16, 0.3), locke(P(150, 124), P(160, 172), 14, 0.2)]
            haarStueck(g, [kappe(top: 10, scheitel: 100, ansatz: 48, unten: 106), fr] + lagen,
                   linien: ponyLinien(52, 148, oben: 40, links: 72, rechts: 72, n: 7, neigung: 0), glanz: glanzLinks)
        case 72:
            let fluegel = Path { p in
                p.move(to: P(56, 60))
                p.addCurve(to: P(30, 132), control1: P(40, 80), control2: P(26, 110))
                p.addQuadCurve(to: P(48, 136), control: P(38, 144))
                p.addCurve(to: P(62, 70), control1: P(52, 110), control2: P(60, 84))
                p.closeSubpath()
            }
            let s = strang(u: 222, breit: 30, aussen: 24)
            haarStueck(g, [kappe(top: 10, scheitel: 100, ansatz: 44, unten: 106), s, gespiegelt(s), fluegel, gespiegelt(fluegel)],
                   linien: [(P(100, 14), P(100, 44), P(99, 28)), (P(58, 74), P(36, 128), P(40, 96)), (P(142, 74), P(164, 128), P(160, 96))], glanz: glanzLinks)
        case 73:
            let schwung = Path { p in
                p.move(to: P(70, 36))
                p.addCurve(to: P(156, 110), control1: P(120, 34), control2: P(160, 70))
                p.addLine(to: P(146, 112))
                p.addCurve(to: P(72, 50), control1: P(140, 76), control2: P(110, 50))
                p.closeSubpath()
            }
            let s = gespiegelt(strang(u: 228))
            haarStueck(g, [kappe(top: 14, scheitel: 70, ansatz: 48, unten: 100), schwung, s],
                   linien: verbinde([(P(76, 42), P(150, 100), P(130, 42))], gespiegelteStriche(strangLinien(u: 228))), glanz: glanzLinks)
        case 74:
            haarStueck(g, [kappe(top: 18, scheitel: 100, ansatz: 48, unten: 98), locke(P(56, 76), P(54, 132), 9, 0.5), locke(P(144, 76), P(146, 132), 9, -0.5)],
                   linien: [(P(66, 56), P(96, 20), P(72, 28)), (P(134, 56), P(104, 20), P(128, 28))], glanz: glanzLinks)
        case 75:
            let fr = pony(56, 144, oben: 42, links: 66, rechts: 66, n: 6, neigung: 0)
            haarStueck(g, [kappe(top: 18, scheitel: 100, ansatz: 52, unten: 96), fr],
                   linien: ponyLinien(56, 144, oben: 42, links: 66, rechts: 66, n: 6, neigung: 0), glanz: glanzLinks)
        case 76:
            haarStueck(g, [kappe(top: 22, scheitel: 100, ansatz: 50, unten: 96)], linien: [(P(100, 24), P(100, 50), P(99, 36))])
            teil(g, box(66, 40, 14, 7, 3.5), Pal.gelb, 1.5)
            teil(g, box(120, 40, 14, 7, 3.5), Pal.gelb, 1.5)
        case 77:
            haarStueck(g, [kappe(top: 16, scheitel: 100, ansatz: 48, unten: 104)],
                   linien: [(P(100, 18), P(100, 48), P(99, 32)), (P(70, 34), P(130, 34), P(100, 28)), (P(62, 48), P(138, 48), P(100, 42))])
            for x in [CGFloat(46), 56] {
                flechte(g, von: P(x, 90), bis: P(x - 6, 226))
                flechte(g, von: P(200 - x, 90), bis: P(206 - x, 226))
            }
        case 78...82:
            ahmedFrisur(g)
        default:
            break
        }
    }
}

// MARK: - Extras (Z-39.4)

extension Zeichner {
    /// No umbrella in a vehicle, in bed or on the sofa: the arms are busy there.
    var schirmAktiv: Bool {
        extras.contains(.schirm) && ![.faehrt, .fahrschule, .rad, .schlaeft, .zuhause, .ruhe, .zug].contains(z)
    }

    /// Dumbbells only while both hands are free of phone and umbrella.
    var hantelnAktiv: Bool { extras.contains(.hanteln) && !extras.contains(.handyKabel) && !schirmAktiv }

    /// The right hand holds the phone, the umbrella or a dumbbell, so the state's own hand prop steps aside.
    var rechteHandBelegt: Bool { extras.contains(.handyKabel) || schirmAktiv || hantelnAktiv }

    /// Curl phase 0 (arm down) … 1 (weight at the shoulder); the right arm runs half a beat behind.
    func hub(_ versatz: Double) -> CGFloat { (1 + w(3.2, versatz)) / 2 }

    /// Half figure: the right hand holds the phone (the left one the cable) or the umbrella; with
    /// both, the umbrella moves to the left hand.
    func mitExtras(_ arme: (l: Arm?, r: Arm?)) -> (l: Arm?, r: Arm?) {
        var a = arme
        if hantelnAktiv {
            let l = hub(0), r = hub(Double.pi)
            a.l = Arm(P(46, 212), P(54 + l * 8, 238 - l * 58))
            a.r = Arm(P(154, 212), P(146 - r * 8, 238 - r * 58))
        }
        let mitHandy = extras.contains(.handyKabel)
        if mitHandy {
            a.l = Arm(P(40, 222), P(62, 206))
            a.r = Arm(P(160, 222), P(140, 196))
        }
        if schirmAktiv {
            if mitHandy { a.l = Arm(P(30, 188), P(28, 142)) } else { a.r = Arm(P(170, 188), P(172, 142)) }
        }
        return a
    }

    /// Full-body counterpart of `mitExtras`, in body space.
    func mitExtrasGanz(_ arme: (l: Arm, r: Arm), _ m: Masse) -> (l: Arm, r: Arm) {
        var a = arme
        let lx: CGFloat = 100 - m.s + 6
        let rx: CGFloat = 100 + m.s - 6
        let y = m.schulterY
        if hantelnAktiv {
            let l = hub(0), r = hub(Double.pi)
            a.l = Arm(P(lx - 4, y + 50), P(lx - 8 + l * 10, y + 92 - l * 52))
            a.r = Arm(P(rx + 4, y + 50), P(rx + 8 - r * 10, y + 92 - r * 52))
        }
        let mitHandy = extras.contains(.handyKabel)
        if mitHandy {
            a.l = Arm(P(lx - 6, y + 46), P(lx + 8, y + 44))
            a.r = Arm(P(rx + 6, y + 46), P(rx - 8, y + 30))
        }
        if schirmAktiv {
            if mitHandy { a.l = Arm(P(lx - 16, y + 30), P(lx - 18, y - 22)) } else { a.r = Arm(P(rx + 16, y + 30), P(rx + 18, y - 22)) }
        }
        return a
    }

    /// Umbrella canopy center, beside the head on the holding hand's side (`nil` = no umbrella).
    func schirmDachMitte(halb: Bool, _ m: Masse? = nil) -> CGPoint? {
        guard schirmAktiv else { return nil }
        let links = extras.contains(.handyKabel)
        if halb { return P(links ? 46 : 154, 38) }
        let s: CGFloat = m?.s ?? 41
        let y: CGFloat = (m?.schulterY ?? 152) - 112
        return P(links ? 100 - s + 4 : 100 + s - 4, y)
    }

    /// Canopy leaning toward the head, drawn behind it; the shaft comes with the hands.
    func schirmDach(_ g: GraphicsContext, _ c: CGPoint, radius r: CGFloat) {
        var h = g
        h.translateBy(x: c.x, y: c.y)
        h.rotate(by: .degrees(c.x > 100 ? -12 : 12))
        let n = 4
        let feld: CGFloat = 2 * r / CGFloat(n)
        let form = Path { p in
            p.move(to: P(-r, 0))
            p.addCurve(to: P(r, 0), control1: P(-r * 0.98, -r * 1.28), control2: P(r * 0.98, -r * 1.28))
            for i in 0..<n {
                let x0: CGFloat = r - CGFloat(i) * feld
                p.addQuadCurve(to: P(x0 - feld, 0), control: P(x0 - feld / 2, -r * 0.2))
            }
            p.closeSubpath()
        }
        let f = FigurFarbe(0xFF6F8A)
        teil(h, form, f)
        var innen = h
        innen.clip(to: form)
        for i in [1, 3] {
            let x0: CGFloat = -r + CGFloat(i) * feld
            let keil = Path { p in
                p.move(to: P(0, -r * 0.96))
                p.addLine(to: P(x0, 2))
                p.addLine(to: P(x0 + feld, 2))
                p.closeSubpath()
            }
            innen.fill(keil, with: .color(Pal.weiss.farbe.opacity(0.5)))
        }
        for i in 1..<n {
            let x: CGFloat = -r + CGFloat(i) * feld
            linie(h, bogen(P(0, -r * 0.96), P(x, 0), P(x * 0.55, -r * 0.62)), f.kontur, 1.6)
        }
        teil(h, kreis(P(0, -r * 0.97), 3), Pal.dunkel, 1.5)
    }

    /// What the hands hold: the umbrella shaft with its hook, the phone (right) and the white
    /// charging cable ending in a plug in the left hand. `s` scales it (0.66 on the full body).
    func extrasInHand(_ g: GraphicsContext, l: CGPoint?, r: CGPoint?, dach: CGPoint?, groesse s: CGFloat) {
        if hantelnAktiv {
            for h in [l, r].compactMap({ $0 }) {
                let stange = strich(P(h.x - 20 * s, h.y), P(h.x + 20 * s, h.y))
                linie(g, stange, Pal.silber.kontur, 7 * s)
                linie(g, stange, Pal.silber.farbe, 4 * s)
                teil(g, box(h.x - 28 * s, h.y - 12 * s, 9 * s, 24 * s, 3 * s), Pal.dunkel, 3 * s)
                teil(g, box(h.x + 19 * s, h.y - 12 * s, 9 * s, 24 * s, 3 * s), Pal.dunkel, 3 * s)
            }
        }
        let mitHandy = extras.contains(.handyKabel)
        if let dach, let griff = mitHandy ? l : r {
            let stock = strich(griff, dach)
            linie(g, stock, Pal.dunkel.kontur, 6 * s)
            linie(g, stock, Pal.silber.farbe, 3.6 * s)
            let seite: CGFloat = griff.x < 100 ? 1 : -1
            let haken = bogen(P(griff.x, griff.y + 2 * s), P(griff.x + seite * 9 * s, griff.y + 13 * s), P(griff.x + seite * s, griff.y + 19 * s))
            linie(g, haken, Pal.holz.kontur, 6.5 * s)
            linie(g, haken, Pal.holz.farbe, 4 * s)
        }
        guard mitHandy, let r else { return }
        let ziel = l ?? P(r.x - 60 * s, r.y + 20 * s)
        let start = P(r.x, r.y + 6 * s)
        let kabel = Path { p in
            p.move(to: start)
            p.addCurve(to: P(ziel.x, ziel.y - 6 * s), control1: P(start.x - 4 * s, start.y + 46 * s), control2: P(ziel.x + 4 * s, ziel.y + 44 * s))
        }
        linie(g, kabel, Pal.weiss.kontur, 5.5 * s)
        linie(g, kabel, .white, 3.2 * s)
        var t = g
        t.translateBy(x: r.x, y: r.y - 14 * s)
        t.scaleBy(x: s * 0.9, y: s * 0.9)
        handy(t, .zero, rueckseite: true)
        if let l {
            teil(g, box(l.x - 4 * s, l.y - 17 * s, 8 * s, 12 * s, 2.5 * s), Pal.weiss, 1.6 * s)
            g.fill(box(l.x - 2.4 * s, l.y - 22 * s, 4.8 * s, 6 * s, s), with: .color(Pal.silber.farbe))
        }
    }

    /// Scarf around the neck with a hanging end, in the winter hat's color. `c`: collar point.
    func schal(_ g: GraphicsContext, _ c: CGPoint, s: CGFloat) {
        var h = g
        h.translateBy(x: c.x, y: c.y)
        h.scaleBy(x: s, y: s)
        let f = muetzeF
        teil(h, box(5, 2, 15, 46, 5), f.mal(0.92), 3)
        for y in [CGFloat(14), 30] { linie(h, strich(P(6, y), P(19, y)), Pal.weiss.farbe, 3) }
        for x in stride(from: CGFloat(7), through: 18, by: 3.6) { linie(h, strich(P(x, 48), P(x, 55)), f.farbe, 2) }
        let band = bogen(P(-26, -6), P(26, -6), P(0, 16))
        linie(h, band, f.kontur, 18)
        linie(h, band, f.farbe, 13.5)
        linie(h, bogen(P(-20, -3), P(20, -3), P(0, 14)), Pal.weiss.farbe.opacity(0.85), 2.5)
    }

    /// Slowly falling snowflakes over `bereich`, behind the figure.
    func schneeflocken(_ g: GraphicsContext, _ bereich: CGRect) {
        let n = 9
        for i in 0..<n {
            let p = zyklus(7, Double(i) * 7 / Double(n))
            let x: CGFloat = bereich.minX + bereich.width * (CGFloat(i) + 0.5) / CGFloat(n) + w(1.3, Double(i)) * 6
            let y: CGFloat = bereich.minY + bereich.height * (CGFloat((i * 37) % 100) / 100 + p).truncatingRemainder(dividingBy: 1)
            let r: CGFloat = bereich.height / 60 + CGFloat(i % 3)
            for k in 0..<3 {
                let a = Double(k) * Double.pi / 3 + Double(i)
                let dx = CGFloat(cos(a)) * r
                let dy = CGFloat(sin(a)) * r
                let strahl = strich(P(x - dx, y - dy), P(x + dx, y + dy))
                linie(g, strahl, Pal.himmel.kontur.opacity(0.55), 3.2)
                linie(g, strahl, .white, 1.7)
            }
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
