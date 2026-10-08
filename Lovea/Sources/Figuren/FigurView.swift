import SwiftUI

/// Z-39.4: small extras on the figure, drawn in half and full body. The map derives them from the
/// weather (rain, sun, cold, snow) and from charging. `hanteln` (Brief G): a dumbbell in each hand,
/// curled in turn - the profile's gym scene.
/// `schlaefrig` (Brief G fix): late at night, tired eyes and now and then a yawn.
/// `mitzeichnen` (Brief Z): drawing together, both tablets show one shared doodle (`ZeichenStriche`).
enum FigurExtra: String, CaseIterable, Sendable { case schirm, sonnenbrille, muetzeSchal, handyKabel, schneeflocken, hanteln, schlaefrig, mitzeichnen }

/// Brief K: the profile's hug and kiss, full body only. `seite` -1 = the partner stands left,
/// +1 = right; `abstand` is the distance between the two figure centres in canvas units. `arme`
/// and `kuss` run 0…1: the arms go around the partner, the head tilts and the face turns to them.
/// The right figure lays its arm over the partner's shoulders, the left one's goes round the waist
/// behind them, so the right figure must be drawn in front.
/// Teil 2 (Nähe): where this figure's partner-side hand rests on the partner.
enum PaarHand: String, Sendable, Equatable { case schulter, brust, hals, taille }

/// Teil 2: which part of a figure a view draws, so two figures can be layered
/// (both bodies first, then both pair arms on top).
enum PaarEbene: Sendable, Equatable { case alles, ohneArm, nurArm }

struct Umarmung: Equatable, Sendable {
    var seite: CGFloat
    var abstand: CGFloat
    var arme: CGFloat
    var kuss: CGFloat
    /// Teil 2: explicit pose values. `nil`/`false` keeps the Brief K hug behaviour.
    var neigung: CGFloat? = nil      // head lean in degrees, sign as drawn on screen (+ = clockwise)
    var drehung: CGFloat? = nil      // 3/4 turn: feature slide in head units, sign = screen direction
    var augenZu: Bool = false
    var hand: PaarHand? = nil
    var ebene: PaarEbene = .alles
    /// The partner's hand rests over this figure's far shoulder (their arm runs behind this back).
    /// Drawn by this figure, because it lies outside the partner's own drawing area; value = their skin.
    var haltHand: FigurFarbe? = nil
}

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
    private let extras: Set<FigurExtra>
    private let tisch: Int
    private let umarmung: Umarmung?
    /// Teil 4: the exercise the gym scene shows; nil picks one at random per person.
    private let gymGeste: GymGeste?
    /// p65: where the whole body is (sits on the sofa or the bed edge, lies); nil = as the state says.
    private let pose: FigurPose?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var sichtbar = false

    /// `bildrate`: frames per second of the loop; lower it where many figures or a map redraw.
    /// `extras` (Z-39.4): umbrella, sunglasses, hat and scarf, phone with a white cable, snowflakes.
    /// `pose` (p65): whole body only. Sitting drops the hips to the seat; lying turns the body by 90
    /// degrees and the frame becomes `FigurPoseLogik.rahmen` (wide).
    init(_ aussehen: FigurAussehen, zustand: FigurZustand, abzeichen: [String] = [], groesse: CGFloat, animiert: Bool = true, bildrate: Double = 30, ganzkoerper: Bool = false, extras: Set<FigurExtra> = [], tisch: Int = 0, umarmung: Umarmung? = nil, gymGeste: GymGeste? = nil, pose: FigurPose? = nil) {
        self.pose = ganzkoerper ? pose : nil
        self.umarmung = umarmung
        self.aussehen = aussehen
        self.zustand = zustand
        self.abzeichen = abzeichen
        self.groesse = groesse
        self.animiert = animiert
        self.bildrate = bildrate
        self.ganzkoerper = ganzkoerper
        self.extras = extras
        self.tisch = tisch
        self.gymGeste = gymGeste
    }

    var body: some View {
        // Built once per look/state here, outside the clock: each tick only sets `t` on a copy
        // (the colours, lookups and derived flags cost more than the copy).
        let laeuft = animiert && !reduceMotion
        let basis = zeichner(statisch: !laeuft)
        Group {
            if laeuft {
                TimelineView(.animation(minimumInterval: 1.0 / bildrate, paused: !sichtbar || scenePhase != .active)) { kontext in
                    leinwand(basis, kontext.date.timeIntervalSinceReferenceDate)
                }
            } else {
                leinwand(basis, 0.4)
            }
        }
        .frame(width: rahmen.width, height: rahmen.height)
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

    private var rahmen: CGSize {
        if ganzkoerper { return FigurPoseLogik.rahmen(pose ?? .stehen, hoehe: groesse) }
        return CGSize(width: groesse * 5 / 6, height: groesse)
    }

    private func zeichner(statisch: Bool) -> Zeichner {
        Zeichner(aussehen, zustand, abzeichen, t: 0.4, statisch: statisch, ganz: ganzkoerper, extras: extras, tisch: tisch, umarmung: umarmung, gymGeste: gymGeste, pose: pose)
    }

    private func leinwand(_ basis: Zeichner, _ t: Double) -> some View {
        let zeichner = basis.bei(t)
        let drehung = pose.map(FigurPoseLogik.drehung) ?? 0
        return Canvas { g, size in
            guard drehung != 0 else {
                zeichner.zeichne(g, size)
                return
            }
            // Lying: the standing body is drawn in a tall frame (size swapped) and turned around its centre.
            var d = g
            d.translateBy(x: size.width / 2, y: size.height / 2)
            d.rotate(by: .degrees(drehung))
            d.translateBy(x: -size.height / 2, y: -size.width / 2)
            zeichner.zeichne(d, CGSize(width: size.height, height: size.width))
        }
    }
}
