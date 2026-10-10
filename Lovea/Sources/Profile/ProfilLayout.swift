import SwiftUI

/// p69: how the profile's top part (the scene and the zone strip under it) fits the room the screen gives it.
/// Pure, so the numbers are tested on real device sizes.
///
/// Why the profile felt "too long": scene (about 1.1 x width) + status bar + zone strip stand outside the
/// scroll view, so everything else, a long list of cards, scrolled in what was left: about 250 pt on an
/// iPhone 14, 149 pt on an iPhone SE, nothing on an iPad. The old test left the strip out of its sum.
enum ProfilLayout {
    /// Smallest hit area of any control (pt).
    static let tippMinimum: CGFloat = ProfilSlots.tippMinimum
    /// The zone strip under the scene (Schlafen, Wohnen, Regal). Every button in it is hit on the whole height.
    static let leistenHoehe: CGFloat = tippMinimum
    /// The tab strip in the part that scrolls (Zimmer, Wir, Erinnerungen, Quests).
    static let reiterHoehe: CGFloat = tippMinimum
    /// What the part under the scene keeps at least while scene and strip stand still: the tab strip and
    /// about three rows. With less, the whole profile scrolls as one (small iPhones, iPad landscape).
    static let unterMinimum: CGFloat = 200
    /// The scene never gets wider than the widest iPhone (16/17 Pro Max, 440 pt), so no phone shows bare strips at the sides; on an iPad it would be taller than the screen.
    static let maxSzeneBreite: CGFloat = 440
    /// Air under the last card, above the tab bar.
    static let schlussPolster: CGFloat = 32
    /// Navigation chrome (the two strips) stops growing with Dynamic Type here; the content below keeps scaling.
    static let leistenSchrift: ClosedRange<DynamicTypeSize> = DynamicTypeSize.xSmall...DynamicTypeSize.xxxLarge

    struct Szene: Equatable {
        /// Width the scene is drawn at; centred when the screen is wider.
        var breite: CGFloat
        /// Height of the scene including the status bar the wall bleeds into (without the zone strip).
        var hoehe: CGFloat
        /// What is left under scene and zone strip.
        var unten: CGFloat
        /// True: scene and strip stand still on top and only the rest scrolls. False: the screen is too
        /// small for that, the whole profile scrolls as one.
        var klebt: Bool
    }

    /// `breite`, `hoehe`: the room of the profile (`hoehe` reaches under the status bar and ends at the tab bar).
    /// `oben`: the status bar.
    static func szene(breite: CGFloat, hoehe: CGFloat, oben: CGFloat) -> Szene {
        let b = max(0, min(breite, maxSzeneBreite))
        let h = oben + ProfilPanoramaLayout.szeneHoehe(breite: b)
        let unten = hoehe - h - leistenHoehe
        return Szene(breite: b, hoehe: h, unten: unten, klebt: unten >= unterMinimum)
    }

    /// Fein-Profil: air above the world for the floating buttons (4 above, the 44 pt button, 4 below). The world
    /// never reaches up into it, so nothing tappable in the room lies under the gear, the chip or the Gym bar.
    static let chromeBand: CGFloat = tippMinimum + 8

    /// Fein-Profil: the profile is the scene alone (no tabs under it). The scene is only as tall as chrome band
    /// and world need (the world never rises above the band), so the lamp cable stays short and nothing is
    /// squeezed. What the screen gives beyond that is `unten`: the floor continues there (`ProfileView`).
    /// `oben`: `Oben.chrome`, below the status bar and the Gym bar.
    static func profil(breite: CGFloat, hoehe: CGFloat, chrome: CGFloat) -> Szene {
        let b = max(0, min(breite, maxSzeneBreite))
        let mindest = chrome + chromeBand + ProfilPanoramaLayout.szeneHoehe(breite: b)
        return Szene(breite: b, hoehe: mindest, unten: max(0, hoehe - mindest), klebt: true)
    }

    /// Fein-Profil: where the world's top edge lies in a scene of height `hoehe` (measured from the scene's top).
    static func weltOben(breite: CGFloat, hoehe: CGFloat) -> CGFloat {
        hoehe - ProfilPanoramaLayout.szeneHoehe(breite: max(0, min(breite, maxSzeneBreite)))
    }

    /// p72: where scene and floating chrome (online chip, gear) start, measured from the very top of the screen.
    struct Oben: Equatable {
        /// The status bar the wall bleeds into; the scene is drawn below it.
        var szene: CGFloat
        /// The chip and the gear: below the status bar and below whatever hangs under it (the Gym bar).
        var chrome: CGFloat
    }

    /// `innen`: the top inset read inside the profile. The profile reaches under the status bar (`ignoresSafeArea`),
    /// and a view that ignores an edge reads 0 there, so the gear sat at the very top, in the status bar's taps.
    /// `aussen`: the top inset read outside that (status bar, plus the Gym bar while it shows).
    /// `statusleiste`: the real status bar height of the scene.
    /// The own profile has no navigation bar: the scene starts under the real status bar (steady, whether or not the
    /// Gym bar shows) and the chrome clears the status bar and the Gym bar. The partner sheet keeps the inset it gets.
    static func oben(eigenes: Bool, innen: CGFloat, aussen: CGFloat, statusleiste: CGFloat) -> Oben {
        guard eigenes else { return Oben(szene: innen, chrome: innen) }
        return Oben(szene: statusleiste, chrome: max(aussen, statusleiste))
    }

    /// The tab bar of iOS 26 folds away while the lower part scrolls and gives its room to it. A device whose
    /// `unten` lies in this band would flip between fixed and whole-scroll mid-scroll, so none may.
    static let tabLeistenSpiel: CGFloat = 50
}
