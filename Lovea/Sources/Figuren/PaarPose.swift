import SwiftUI

/// Teil 2 (Nähe): the pair poses, values from design/figur-redesign/naehe.py. Distances are
/// between the two figures' centres in points of the profile's 340-pt full bodies (0.85 pt per unit).
struct NaehePose: Equatable, Sendable {
    var abstand: CGFloat
    var vorn: Person
    var annika: Umarmung
    var ahmed: Umarmung
    var zustandAnnika: FigurZustand
    var zustandAhmed: FigurZustand

    func umarmung(_ p: Person) -> Umarmung { p == .ahmed ? ahmed : annika }
    func zustand(_ p: Person) -> FigurZustand { p == .ahmed ? zustandAhmed : zustandAnnika }
    /// Sideways shift of each figure from its place in the profile's HStack (centres 106 pt apart).
    func versatz(_ p: Person) -> CGFloat { (106 - abstand) / 2 * (p == .ahmed ? -1 : 1) }

    private static func um(_ seite: CGFloat, _ abstand: CGFloat, neigung: CGFloat = 0, drehung: CGFloat = 0,
                           augenZu: Bool = false, kuss: CGFloat = 0, hand: PaarHand? = nil) -> Umarmung {
        Umarmung(seite: seite, abstand: abstand / 0.85, arme: 0, kuss: kuss, neigung: neigung, drehung: drehung,
                 augenZu: augenZu, hand: hand)
    }

    static func stufe(_ n: Int, vorn: Person) -> NaehePose {
        switch n {
        case 1:
            return NaehePose(abstand: 91, vorn: .ahmed,
                            annika: um(1, 91, neigung: 3, drehung: 11), ahmed: um(-1, 91, neigung: -3, drehung: -11),
                            zustandAnnika: .gut, zustandAhmed: .gut)
        case 2:
            return NaehePose(abstand: 70, vorn: .annika,
                            annika: um(1, 70, neigung: 6), ahmed: um(-1, 70, neigung: -4, hand: .schulter),
                            zustandAnnika: .gut, zustandAhmed: .ruhig)
        case 3:
            return NaehePose(abstand: 64, vorn: .ahmed,
                            annika: um(1, 64, neigung: 14, hand: .brust), ahmed: um(-1, 64, neigung: -5, hand: .schulter),
                            zustandAnnika: .gut, zustandAhmed: .ruhig)
        default:
            return NaehePose(abstand: 106, vorn: vorn, annika: um(1, 106), ahmed: um(-1, 106),
                            zustandAnnika: .ruhig, zustandAhmed: .ruhig)
        }
    }

    static let kuss = NaehePose(abstand: 34, vorn: .ahmed,
                               annika: um(1, 34, neigung: 14, drehung: 16, augenZu: true, kuss: 1, hand: .hals),
                               ahmed: um(-1, 34, neigung: -10, drehung: -22, augenZu: true, kuss: 1, hand: .taille),
                               zustandAnnika: .kuss, zustandAhmed: .kuss)

    /// Blend two poses: numbers glide, hands, eyes, front figure and moods switch at the middle.
    static func mix(_ a: NaehePose, _ b: NaehePose, _ t: CGFloat) -> NaehePose {
        let t = min(max(t, 0), 1)
        func l(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * t }
        func u(_ x: Umarmung, _ y: Umarmung) -> Umarmung {
            let spaet = t >= 0.5
            return Umarmung(seite: x.seite, abstand: l(x.abstand, y.abstand), arme: 0, kuss: l(x.kuss, y.kuss),
                            neigung: l(x.neigung ?? 0, y.neigung ?? 0), drehung: l(x.drehung ?? 0, y.drehung ?? 0),
                            augenZu: spaet ? y.augenZu : x.augenZu, hand: spaet ? y.hand : x.hand)
        }
        let spaet = t >= 0.5
        return NaehePose(abstand: l(a.abstand, b.abstand), vorn: spaet ? b.vorn : a.vorn,
                        annika: u(a.annika, b.annika), ahmed: u(a.ahmed, b.ahmed),
                        zustandAnnika: spaet ? b.zustandAnnika : a.zustandAnnika,
                        zustandAhmed: spaet ? b.zustandAhmed : a.zustandAhmed)
    }
}
