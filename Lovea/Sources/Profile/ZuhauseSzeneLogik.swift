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

/// Szene belebt: the switch in Einstellungen and where a tap or drag on one's own figure sends it.
/// Pure, so each rule has a test. The walking itself is `ZuhauseBuehne.lauf()`.
enum ZuhauseBelebung {
    static let schluessel = "lovea.szeneBelebt"

    /// Default on; Low Power Mode and Reduce Motion switch the walking off in the stage on their own.
    static var an: Bool { UserDefaults.standard.object(forKey: schluessel) as? Bool ?? true }

    /// The figures walk by themselves only with the switch on and the scene active (app in front,
    /// profile visible, no Low Power Mode, no Reduce Motion).
    static func laeuft(an: Bool, aktiv: Bool) -> Bool { an && aktiv }

    /// The place whose feet are closest to a drop at world x (a drag on one's own figure).
    static func naechsterPlatz(x: CGFloat, person: Person, welt: ProfilWelt) -> Platz {
        Platz.allCases.min { abs(ZuhauseOrte.fuss($0, person, welt: welt).x - x) < abs(ZuhauseOrte.fuss($1, person, welt: welt).x - x) } ?? .sofa
    }

    /// A tap on one's own figure: on to the next place.
    static func weiter(von platz: Platz) -> Platz {
        let alle = Platz.allCases
        return alle[((alle.firstIndex(of: platz) ?? 0) + 1) % alle.count]
    }
}

/// Kontextszenen: where the two are right now decides what the panorama shows. Pure, tested in
/// `ZuhauseKontextTests`. Only the gym changes the picture when one is away (split: room left, gym
/// cutout right); a partner at work or school simply stays as the room has always shown them. When both
/// are away the room is empty and a note says where they are.
enum ZuhauseKontext: Equatable, Sendable {
    case daheim
    /// `weg` trains, `daheim` is in the room.
    case gymGeteilt(daheim: Person, weg: Person)
    case beideWeg(notiz: String)

    /// Where somebody can be away to; `nil` is home or any state that says nothing about a place.
    static func wegOrt(_ z: FigurZustand?) -> String? {
        switch z {
        case .gym: "im Gym"
        case .arbeit: "in der Arbeit"
        case .schule: "in der Schule"
        case .fahrschule: "in der Fahrschule"
        case .supermarkt: "im Supermarkt"
        default: nil
        }
    }

    static func bestimme(ahmed: FigurZustand?, annika: FigurZustand?) -> ZuhauseKontext {
        let a = wegOrt(ahmed), b = wegOrt(annika)
        switch (a, b) {
        case (let x?, let y?): return .beideWeg(notiz: "Ahmed \(x), Annika \(y)")
        case (_?, nil): return ahmed == .gym ? .gymGeteilt(daheim: .annika, weg: .ahmed) : .daheim
        case (nil, _?): return annika == .gym ? .gymGeteilt(daheim: .ahmed, weg: .annika) : .daheim
        case (nil, nil): return .daheim
        }
    }

    /// Who is not in the room.
    var abwesende: Set<Person> {
        switch self {
        case .daheim: []
        case .gymGeteilt(_, let weg): [weg]
        case .beideWeg: [.ahmed, .annika]
        }
    }

    /// The gym cutout in world units (right half of the 1000 x 430 world, inside the margins).
    static let gymAusschnitt = CGRect(x: 560, y: 60, width: 420, height: 340)
}
