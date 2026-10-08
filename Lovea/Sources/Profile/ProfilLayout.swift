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
    /// The scene never gets wider than a Pro Max iPhone: on an iPad it would be taller than the screen.
    static let maxSzeneBreite: CGFloat = 430
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

    /// The tab bar of iOS 26 folds away while the lower part scrolls and gives its room to it. A device whose
    /// `unten` lies in this band would flip between fixed and whole-scroll mid-scroll, so none may.
    static let tabLeistenSpiel: CGFloat = 50
}
