import SwiftUI

/// p65 A1: the profile scene as a panorama. One slot per object in a world of 975 design units
/// (2.5 screens of 390), three zones, and the numbers behind the swipe. Pure rects, no drawing, so the
/// no-overlap rule and the 44 pt tap rule are unit tests. Heights are the old design space (430).

/// The three places of the panorama, left to right.
enum ProfilZone: Int, CaseIterable {
    case schlaf, wohn, regal

    var titel: String {
        switch self {
        case .schlaf: "Schlafen"
        case .wohn: "Wohnen"
        case .regal: "Regal"
        }
    }
}

/// Everything that has a fixed place in the scene.
enum ProfilDing: CaseIterable {
    case rahmen0, rahmen1, rahmen2, platte, countdown, bett, geschenkbox, nachttisch
    case lampe, schalter, pflanze, fenster, kommode, waerme, sofa, fernseher, kalender
    case spiegel, zettel, regalDeko, pinnwand, pokale, kleiderschrank, ziel, kuehl
    /// p68: Ahmeds Bord für seine Blumen (nur im Panorama gezeichnet, nur wenn er welche gewählt hat).
    case bord
}

/// Which world a layer draws: the old single sheet or the panorama. Every layer takes one, default `.einzel`.
enum ProfilWelt {
    case einzel, panorama

    var breite: CGFloat { self == .einzel ? SzenenZeichnung.breite : ProfilSlots.weltBreite }

    /// How far the object moves from its old place (design units).
    func versatz(_ d: ProfilDing) -> CGSize { self == .einzel ? .zero : ProfilSlots.versatz(d) }

    /// The object's rect in this world.
    func rect(_ d: ProfilDing) -> CGRect {
        switch self {
        case .einzel: d == .sofa ? ZuhauseZeichnung.sofa : ProfilSlots.nativ(d)
        case .panorama: ProfilSlots.welt(d)
        }
    }
}

extension ProfilDing {
    /// The photo frame of slot 0 to 2 of `Zimmer.rahmen`.
    static func rahmen(_ slot: Int) -> ProfilDing { [.rahmen0, .rahmen1, .rahmen2][slot] }
}

extension ProfilWelt {
    /// Draws one object at its place in this world: `f` draws it where it used to be, the context is shifted.
    func zeichne(_ g: GraphicsContext, _ d: ProfilDing, _ f: (GraphicsContext) -> Void) {
        let v = versatz(d)
        guard v != .zero else { return f(g) }
        var h = g
        h.translateBy(x: v.width, y: v.height)
        f(h)
    }

    /// A point of an object, moved to its place in this world.
    func ort(_ p: CGPoint, _ d: ProfilDing) -> CGPoint {
        let v = versatz(d)
        return CGPoint(x: p.x + v.width, y: p.y + v.height)
    }
}

enum ProfilSlots {
    static let weltBreite: CGFloat = 975
    static let hoehe: CGFloat = SzenenZeichnung.hoehe
    /// One screen of the world, in design units.
    static let ansichtBreite: CGFloat = SzenenZeichnung.breite
    /// No two objects come closer than this.
    static let mindestAbstand: CGFloat = 6
    static let tippMinimum: CGFloat = 44
    /// Two tap areas may overlap by this much (in design units) on their short side.
    static let maxTippUeberlapp: CGFloat = 8
    /// The widened sofa: two whole-body people sit side by side.
    static let sofaBreite: CGFloat = 140

    // Centres and widths of the small things that used to be private to their layers (height follows the raster).
    static let platteMitte = P(45, 113)
    static let platteBreite: CGFloat = 78
    static let spiegelMitte = P(338, 80)
    static let spiegelBreite: CGFloat = 46
    static let nachttischMitte = P(322, 402)
    static let nachttischBreite: CGFloat = 40
    static let kuehlMitte = P(366, 396)
    static let kuehlBreite: CGFloat = 36
    static let waermeMitte = P(284, 339)
    static let waermeBreite: CGFloat = 40
    static let zettelMitte = P(332, 150)
    static let zettelBreite: CGFloat = 30
    static let schalterMitte = P(150, 176)
    static let schalterBreite: CGFloat = 18
    static let geschenkMitte = P(118, 338)
    static let geschenkBreite: CGFloat = 36
    static let regalAlbum = P(306, 126)
    static let regalGlobus = P(355, 108)

    private static func mitte(_ m: CGPoint, breite: CGFloat, raster: CGSize) -> CGRect {
        let h = breite * raster.height / raster.width
        return CGRect(x: m.x - breite / 2, y: m.y - h / 2, width: breite, height: h)
    }

    private static func um(_ m: CGPoint, _ b: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: m.x - b / 2, y: m.y - h / 2, width: b, height: h)
    }

    /// The dresser with its bouquets and the round table in front of it.
    private static var kommode: CGRect {
        let s = ZuhauseZeichnung.schrank, t = ZuhauseZeichnung.tisch
        let links = min(s.minX - 4, t.x - 31), rechts = max(s.maxX + 4, t.x + 31)
        let oben = ZuhauseZeichnung.schrankOben + 2 - ZuhauseZeichnung.strauss.height
        return CGRect(x: links, y: oben, width: rechts - links, height: t.y + 30 - oben)
    }

    // MARK: Native rects (the old single sheet, from the real constants)

    static func nativ(_ d: ProfilDing) -> CGRect {
        switch d {
        case .rahmen0: ZimmerLebenLayout.rahmen[0]
        case .rahmen1: ZimmerLebenLayout.rahmen[1]
        case .rahmen2: ZimmerLebenLayout.rahmen[2]
        case .platte: mitte(platteMitte, breite: platteBreite, raster: AlltagZeichnung.platteRaster)
        case .countdown:
            CGRect(x: ZimmerCountdownZeichnung.ort.x - 38, y: ZimmerCountdownZeichnung.ort.y - 26, width: 76, height: 84)
        case .bett:
            CGRect(x: ZuhauseZeichnung.bettOrt.x, y: ZuhauseZeichnung.bettOrt.y,
                   width: 300 * ZuhauseZeichnung.bettMass, height: 220 * ZuhauseZeichnung.bettMass)
        case .geschenkbox: mitte(geschenkMitte, breite: geschenkBreite, raster: SignaleZeichnung.geschenkRaster)
        case .nachttisch: mitte(nachttischMitte, breite: nachttischBreite, raster: AlltagZeichnung.nachttischRaster)
        case .lampe:
            CGRect(x: ZuhauseZeichnung.lampe.x - 26, y: ZuhauseZeichnung.lampe.y - 52, width: 52, height: 60)
        case .schalter: mitte(schalterMitte, breite: schalterBreite, raster: SignaleZeichnung.schalterRaster)
        case .pflanze: ZimmerLebenLayout.pflanze
        case .fenster:
            // Window with both curtains and the string of lights above it.
            CGRect(x: ZuhauseZeichnung.fenster.minX - 16, y: ZuhauseZeichnung.fenster.minY - 17,
                   width: ZuhauseZeichnung.fenster.width + 32, height: ZuhauseZeichnung.fenster.height + 25)
        case .kommode: kommode
        case .bord: ZuhauseZeichnung.bord
        case .waerme: mitte(waermeMitte, breite: waermeBreite, raster: AlltagZeichnung.waermeRaster)
        case .sofa:
            CGRect(x: ZuhauseZeichnung.sofa.minX, y: ZuhauseZeichnung.sofa.minY, width: sofaBreite, height: ZuhauseZeichnung.sofa.height)
        case .fernseher: ZimmerLebenLayout.fernseher
        case .kalender: ZimmerLebenLayout.kalender
        case .spiegel: mitte(spiegelMitte, breite: spiegelBreite, raster: AlltagZeichnung.spiegelRaster)
        case .zettel: mitte(zettelMitte, breite: zettelBreite, raster: SignaleZeichnung.zettelRaster)
        case .regalDeko: um(regalGlobus, 40, 48).union(um(regalAlbum, 44, 44))
        case .pinnwand: ZimmerLebenLayout.pinnwand
        case .pokale: ZimmerLebenLayout.pokale
        case .kleiderschrank: ZimmerMoebel.stange.union(ZimmerMoebel.regal)
        case .ziel: ZimmerLebenLayout.ziel
        case .kuehl: mitte(kuehlMitte, breite: kuehlBreite, raster: AlltagZeichnung.kuehlRaster)
        }
    }

    // MARK: Slots

    /// Where each object moves in the panorama, plus its zone and whether it can be tapped.
    private struct Slot {
        let dx: CGFloat
        let dy: CGFloat
        let zone: ProfilZone
        let tippbar: Bool
    }

    private static func slot(_ d: ProfilDing) -> Slot {
        switch d {
        // Schlafen
        case .rahmen1: Slot(dx: -4, dy: 0, zone: .schlaf, tippbar: true)
        case .rahmen2: Slot(dx: -1, dy: 0, zone: .schlaf, tippbar: true)
        case .rahmen0: Slot(dx: -1, dy: 0, zone: .schlaf, tippbar: true)
        case .platte: Slot(dx: 85, dy: 0, zone: .schlaf, tippbar: true)
        case .countdown: Slot(dx: 163, dy: 0, zone: .schlaf, tippbar: true)
        case .bett: Slot(dx: 0, dy: 0, zone: .schlaf, tippbar: true)
        case .geschenkbox: Slot(dx: 100, dy: 0, zone: .schlaf, tippbar: true)
        case .nachttisch: Slot(dx: -122, dy: 0, zone: .schlaf, tippbar: true)
        case .bord: Slot(dx: 0, dy: 0, zone: .schlaf, tippbar: false)
        // Wohnen
        case .lampe: Slot(dx: 173, dy: 0, zone: .wohn, tippbar: true)
        case .schalter: Slot(dx: 133, dy: 0, zone: .wohn, tippbar: true)
        case .pflanze: Slot(dx: 181, dy: 0, zone: .wohn, tippbar: true)
        case .fenster: Slot(dx: 235, dy: 0, zone: .wohn, tippbar: false)
        case .kommode: Slot(dx: 228, dy: 0, zone: .wohn, tippbar: false)
        case .waerme: Slot(dx: 94, dy: 0, zone: .wohn, tippbar: true)
        case .sofa: Slot(dx: 216, dy: 0, zone: .wohn, tippbar: true)
        case .fernseher: Slot(dx: 451, dy: 0, zone: .wohn, tippbar: true)
        case .kalender: Slot(dx: 544, dy: -10, zone: .wohn, tippbar: true)
        // Regal
        case .spiegel: Slot(dx: 302, dy: 0, zone: .regal, tippbar: true)
        case .zettel: Slot(dx: 308, dy: 0, zone: .regal, tippbar: true)
        case .regalDeko: Slot(dx: 385, dy: 0, zone: .regal, tippbar: true)
        case .pinnwand: Slot(dx: 477, dy: 0, zone: .regal, tippbar: true)
        case .pokale: Slot(dx: 477, dy: 0, zone: .regal, tippbar: true)
        case .kleiderschrank: Slot(dx: 577, dy: 0, zone: .regal, tippbar: true)
        case .ziel: Slot(dx: 326, dy: 0, zone: .regal, tippbar: true)
        case .kuehl: Slot(dx: 364, dy: 0, zone: .regal, tippbar: true)
        }
    }

    static func versatz(_ d: ProfilDing) -> CGSize { CGSize(width: slot(d).dx, height: slot(d).dy) }
    static func zone(_ d: ProfilDing) -> ProfilZone { slot(d).zone }
    static func tippbar(_ d: ProfilDing) -> Bool { slot(d).tippbar }

    /// The object's rect in the panorama.
    static func welt(_ d: ProfilDing) -> CGRect {
        let v = versatz(d)
        return nativ(d).offsetBy(dx: v.width, dy: v.height)
    }

    /// The tap area: the rect, widened around its centre to at least 44 pt on screen (`massstab` = pt per unit).
    static func tippFlaeche(_ d: ProfilDing, massstab: CGFloat) -> CGRect {
        let r = welt(d)
        let mindest = tippMinimum / massstab
        let b = max(r.width, mindest), h = max(r.height, mindest)
        return CGRect(x: r.midX - b / 2, y: r.midY - h / 2, width: b, height: h)
    }

    // MARK: Zones

    /// A zone ends where the next begins: Schlafen to 254, Wohnen to 622.
    private static let zonenGrenzen: [CGFloat] = [254, 622]

    static func zone(beiX x: CGFloat) -> ProfilZone {
        x < zonenGrenzen[0] ? .schlaf : x < zonenGrenzen[1] ? .wohn : .regal
    }

    /// Scroll offset (design units) at which the zone fills the screen: its objects are all in view.
    static func anker(_ z: ProfilZone) -> CGFloat {
        switch z {
        case .schlaf: 0
        case .wohn: 254
        case .regal: weltBreite - ansichtBreite
        }
    }
}

/// How the panorama sits on the screen: scale, scene height, the slow wall, the snap points.
enum ProfilPanoramaLayout {
    /// The wall moves at this share of the furniture's speed (1 = no depth).
    static let wandFaktor: CGFloat = 0.6

    static let maxOffset: CGFloat = ProfilSlots.weltBreite - ProfilSlots.ansichtBreite

    /// Points per design unit.
    static func massstab(breite: CGFloat) -> CGFloat { breite / ProfilSlots.ansichtBreite }

    /// The scene is as tall as its width asks for, so it shows whole, anchored to the top.
    static func szeneHoehe(breite: CGFloat) -> CGFloat { ProfilSlots.hoehe * massstab(breite: breite) }

    /// Where the wall layer's left edge sits in the scrolled world (design units), for a scroll offset.
    static func wandVersatz(scroll: CGFloat) -> CGFloat { (1 - wandFaktor) * min(max(scroll, 0), maxOffset) }

    /// The wall is wide enough to cover the screen at the far right.
    static let wandBreite: CGFloat = ProfilSlots.ansichtBreite + maxOffset * wandFaktor

    /// The anchor nearest to `offset`: where the swipe comes to rest.
    static func naechsterAnker(_ offset: CGFloat) -> CGFloat {
        ProfilZone.allCases.map(ProfilSlots.anker).min { abs($0 - offset) < abs($1 - offset) } ?? 0
    }

    /// The zone whose anchor is nearest to `offset` (for the dots / tabs).
    static func zone(offset: CGFloat) -> ProfilZone {
        ProfilZone.allCases.min { abs(ProfilSlots.anker($0) - offset) < abs(ProfilSlots.anker($1) - offset) } ?? .schlaf
    }
}
