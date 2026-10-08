import CoreGraphics
import Foundation

/// p58: the shared home scene in the profile. This file is only logic, no drawing: the hour picks the
/// time of day, the time of day picks who stands where, and every 20 to 60 s the next step follows.
/// The scene (`ZuhauseBuehne`) just reads it, so every rule here has a test.
enum Tageszeit: CaseIterable, Sendable {
    case morgen, tag, abend, nacht

    /// `stunde` 0 to 23, Berlin: 7 to 11 morning, 11 to 19 day, 19 to 22 evening, the rest night.
    init(stunde: Int) {
        switch stunde {
        case 7..<11: self = .morgen
        case 11..<19: self = .tag
        case 19..<22: self = .abend
        default: self = .nacht
        }
    }

    static func um(_ datum: Date) -> Tageszeit {
        Tageszeit(stunde: Calendar.berlin.component(.hour, from: datum))
    }

    /// The hours a time of day begins; the next one ends the current.
    static let grenzen = [7, 11, 19, 22]

    /// Dark room, lit lamp, moon in the window.
    var dunkel: Bool { self == .nacht || self == .abend }

    /// Seconds until the next time of day starts (`stunde` and `minute` as the clock shows).
    static func sekundenBisWechsel(stunde: Int, minute: Int) -> TimeInterval {
        let jetzt = stunde * 60 + minute
        let naechste = grenzen.map { $0 * 60 }.first { $0 > jetzt } ?? (grenzen[0] * 60 + 24 * 60)
        return TimeInterval((naechste - jetzt) * 60)
    }
}

/// Where someone can be. `bett`: lying or sitting in it (the walk ends at its edge).
enum Platz: CaseIterable, Sendable {
    case bett, sofa, fenster, blumen
}

/// A small gesture of Annika's after she arrived.
enum ZuhauseGeste: Sendable {
    case winken, herz, kuss
}

struct Aufstellung: Equatable, Sendable {
    var annika: Platz
    var ahmed: Platz
    var geste: ZuhauseGeste?

    func platz(_ p: Person) -> Platz { p == .annika ? annika : ahmed }
}

enum ZuhauseAblauf {
    /// How long a step lasts before the next change: 20 to 60 s.
    static let wartezeiten: ClosedRange<TimeInterval> = 20...60

    private static func a(_ annika: Platz, _ ahmed: Platz, _ geste: ZuhauseGeste? = nil) -> Aufstellung {
        Aufstellung(annika: annika, ahmed: ahmed, geste: geste)
    }

    /// The steps of a time of day, in order, then round again. The first one is the resting scene
    /// (low power mode, Reduce Motion). Evening and night keep both in bed: one step, nothing moves.
    static func abfolge(_ zeit: Tageszeit) -> [Aufstellung] {
        switch zeit {
        case .morgen:
            [a(.fenster, .sofa, .winken), a(.blumen, .sofa, .herz), a(.sofa, .sofa, .kuss), a(.fenster, .fenster, .herz)]
        case .tag:
            [a(.sofa, .sofa, .herz), a(.blumen, .sofa, .winken), a(.fenster, .sofa), a(.bett, .sofa), a(.blumen, .fenster, .herz), a(.sofa, .fenster, .winken)]
        case .abend, .nacht:
            [a(.bett, .bett)]
        }
    }

    static func aufstellung(_ zeit: Tageszeit, schritt: Int) -> Aufstellung {
        let schritte = abfolge(zeit)
        return schritte[((schritt % schritte.count) + schritte.count) % schritte.count]
    }

    /// The scene without any movement.
    static func ruhestand(_ zeit: Tageszeit) -> Aufstellung { aufstellung(zeit, schritt: 0) }

    /// True when a time of day has several steps, i.e. when there is anything to move.
    static func bewegt(_ zeit: Tageszeit) -> Bool { abfolge(zeit).count > 1 }

    /// Seconds to wait after step `schritt`, spread over 20 to 60 s without a random source.
    static func wartezeit(schritt: Int) -> TimeInterval {
        wartezeiten.lowerBound + TimeInterval(((schritt * 17 + 5) % 41 + 41) % 41)
    }
}

/// Where the feet stand, in the scene's design space (390 x 430, `ZuhauseZeichnung`).
enum ZuhauseOrte {
    static let fussY: CGFloat = 334
    /// A standing figure's height; its feet are at 98 % of it.
    static let figurHoehe: CGFloat = 190
    /// Sitting on the sofa: head and chest only, the lower edge hides behind the seat's front cushion.
    static let sitzHoehe: CGFloat = 104
    static let sitzKante: CGFloat = 298
    /// Where the pair stands (hug, kiss) when they are together for real.
    static let paarX: CGFloat = 195
    /// Walking speed in design points per second and the limits of one walk.
    static let tempo: CGFloat = 70
    static let gehgrenzen: ClosedRange<TimeInterval> = 1.4...3.4

    private static func mitte(_ p: Platz) -> CGFloat {
        switch p {
        case .bett: 110
        case .blumen: 158
        case .fenster: 252
        case .sofa: 338
        }
    }

    /// Annika left of Ahmed, so two at one place never stand in the same spot.
    static func fuss(_ p: Platz, _ person: Person) -> CGPoint {
        let halb: CGFloat = p == .sofa ? 22 : 24
        return CGPoint(x: mitte(p) + (person == .annika ? -halb : halb), y: fussY)
    }

    static func gehdauer(von: Platz, nach: Platz, _ person: Person) -> TimeInterval {
        guard von != nach else { return 0 }
        let weg = abs(fuss(von, person).x - fuss(nach, person).x)
        return min(max(TimeInterval(weg / tempo), gehgrenzen.lowerBound), gehgrenzen.upperBound)
    }
}

/// Which bouquets stand where. The IDs come from the flower feature (p59); the scene only places
/// them and draws each one with `StraussView(id:)`.
struct ZuhauseStraeusse: Equatable, Sendable {
    /// The dresser has three places, left to right.
    static let schrankPlaetze = 3

    /// Up to 3 IDs for the dresser; more are ignored, fewer leave places empty.
    var schrank: [String] = []
    /// The one vase on the table, empty without an ID.
    var vase: String?

    var imSchrank: [String] { Array(schrank.prefix(Self.schrankPlaetze)) }
}
