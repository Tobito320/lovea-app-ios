import CoreGraphics
import Foundation

/// p70: the small rules behind the home scene's extras, as pure logic so each one has a test:
/// idle life of the figures (14), the offline partner asleep in bed (15), the heart on a tap on the
/// partner's mood bubble (18) and the haptic when the panorama snaps to a zone (19).
enum ZuhauseSzeneLogik {
    // MARK: Idle life (14)

    /// Frames per second while walking or making a gesture, and while standing about (blink, breathe).
    static let bewegtRate: Double = 15
    static let leerlaufRate: Double = 8

    /// Walking and gestures run as before. Standing about only blinks and breathes: slowly, and only
    /// while the scene is active (on screen, app in front, no Low Power Mode, no Reduce Motion).
    static func bewegung(geht: Bool, geste: Bool, aktiv: Bool) -> (animiert: Bool, bildrate: Double) {
        if geht || geste { return (true, bewegtRate) }
        return (aktiv, aktiv ? leerlaufRate : bewegtRate)
    }

    // MARK: Offline partner sleeps in bed (15)

    /// Only the other one: whoever holds the phone is awake. Without a connection nobody knows
    /// whether the partner is there, so nobody is sent to bed.
    static func schlaeftOffline(_ p: Person, ich: Person?, verbunden: Bool, partnerDa: Bool) -> Bool {
        guard verbunden, let ich else { return false }
        return p == ich.partner && !partnerDa
    }

    /// Who is in the bed: both when the scene has them lie there, otherwise only the offline sleeper.
    static func liegende(beide: Bool, schlaefer: Person?) -> [Person] {
        if beide { return [Person.annika, Person.ahmed] }
        if let schlaefer { return [schlaefer] }
        return []
    }

    /// Where the pillows are in the bed (design units, bed space 300 wide).
    static func kissenX(_ p: Person) -> CGFloat { p == .annika ? 112 : 188 }

    /// The pillows left empty: a sleeper brings their own, whoever sits up leans on theirs.
    static func leereKissen(schlafende: Set<Person>) -> [CGFloat] {
        [Person.annika, Person.ahmed].filter { !schlafende.contains($0) }.map { kissenX($0) }
    }

    // MARK: Heart on the partner's mood (18)

    static let herzPause: TimeInterval = 10

    /// One tap sends one heart op; a second tap within `herzPause` s only gets the haptic.
    static func herzErlaubt(letztes: Date?, jetzt: Date) -> Bool {
        guard let letztes else { return true }
        return jetzt.timeIntervalSince(letztes) >= herzPause
    }

    // MARK: Zone haptic (19)

    /// A tab tap already gave its own haptic and then scrolls to the zone: no second one for that jump.
    static func zonenHaptik(sekundenSeitTab: TimeInterval) -> Bool { sekundenSeitTab > 1.2 }
}
