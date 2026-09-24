import Foundation

/// Brief Z: the doodle a drawing figure puts on its tablet, stroke by stroke, then a short pause,
/// a fade and it starts over. Pure timing and geometry, so the pencil hand (`FigurView` pose) and
/// the strokes on the screen read the same numbers. Screen coordinates are centred, 56 x 36.
/// Alone: a wave, a heart in two strokes and a swoosh. Together (`FigurExtra.mitzeichnen`) both
/// screens show one shared picture: Annika draws the left half of the heart, Ahmed the right.
enum ZeichenStriche {
    struct Strich: Sendable {
        let a, c1, c2, b: CGPoint
        let farbe: UInt32
    }

    static let periode: Double = 8
    static let dauer: Double = 1.3
    static let ausblenden: Double = 0.8
    /// The still frame (Reduce Motion, render boards): three strokes done, the last under way.
    static let stillZeit: Double = 4.2

    static func striche(zusammen: Bool) -> [Strich] {
        zusammen ? gemeinsam : allein
    }

    private static let allein: [Strich] = [
        Strich(a: CGPoint(x: -23, y: -5), c1: CGPoint(x: -15, y: -16), c2: CGPoint(x: -8, y: 5), b: CGPoint(x: 0, y: -7), farbe: 0x7FB6E8),
        herzHaelfte(CGPoint(x: 9, y: -3), 7.5, links: true, farbe: 0xFF3B5C),
        herzHaelfte(CGPoint(x: 9, y: -3), 7.5, links: false, farbe: 0xFF3B5C),
        Strich(a: CGPoint(x: -22, y: 11), c1: CGPoint(x: -9, y: 5), c2: CGPoint(x: 6, y: 16), b: CGPoint(x: 19, y: 9), farbe: 0xF5C542),
    ]

    private static let gemeinsam: [Strich] = [
        herzHaelfte(CGPoint(x: -3, y: -1), 11, links: true, farbe: 0xFF3B5C),
        herzHaelfte(CGPoint(x: -3, y: -1), 11, links: false, farbe: 0xFF3B5C),
        Strich(a: CGPoint(x: -24, y: 13), c1: CGPoint(x: -19, y: 5), c2: CGPoint(x: -15, y: 16), b: CGPoint(x: -9, y: 9), farbe: 0x7FB6E8),
        Strich(a: CGPoint(x: 4, y: 11), c1: CGPoint(x: 9, y: 17), c2: CGPoint(x: 13, y: 5), b: CGPoint(x: 19, y: 12), farbe: 0xF5C542),
    ]

    /// One lobe of a heart as a single curve, from the tip at the bottom up to the dip on top.
    private static func herzHaelfte(_ c: CGPoint, _ s: CGFloat, links: Bool, farbe: UInt32) -> Strich {
        let x: CGFloat = links ? -1 : 1
        return Strich(
            a: CGPoint(x: c.x, y: c.y + 0.9 * s), c1: CGPoint(x: c.x + x * 1.45 * s, y: c.y + 0.05 * s),
            c2: CGPoint(x: c.x + x * 0.95 * s, y: c.y - 1.35 * s), b: CGPoint(x: c.x, y: c.y - 0.4 * s), farbe: farbe
        )
    }

    /// Seconds into the running cycle.
    static func zyklus(_ zeit: Double) -> Double {
        let c = zeit.truncatingRemainder(dividingBy: periode)
        return c < 0 ? c + periode : c
    }

    /// How far each stroke is drawn (0…1) at `zeit`.
    static func fortschritt(zeit: Double, anzahl: Int) -> [CGFloat] {
        let c = zyklus(zeit)
        return (0..<anzahl).map { i in CGFloat(min(max((c - Double(i) * dauer) / dauer, 0), 1)) }
    }

    /// The whole picture fades out at the end of the cycle.
    static func deckkraft(zeit: Double) -> Double {
        min(1, (periode - zyklus(zeit)) / ausblenden)
    }

    /// Which strokes this figure's own pencil draws; the other ones appear from the partner's.
    static func eigene(person: Person, zusammen: Bool, anzahl: Int) -> [Int] {
        guard zusammen else { return Array(0..<anzahl) }
        let rest = person == .ahmed ? 1 : 0
        return (0..<anzahl).filter { $0 % 2 == rest }
    }

    static func punkt(_ s: Strich, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let a = u * u * u
        let b = 3 * u * u * t
        let c = 3 * u * t * t
        let d = t * t * t
        return CGPoint(x: a * s.a.x + b * s.c1.x + c * s.c2.x + d * s.b.x, y: a * s.a.y + b * s.c1.y + c * s.c2.y + d * s.b.y)
    }

    /// Where the own pencil tip is: on the stroke it is drawing, else lifted a little off the end
    /// of its last one (or above the start of its first), bobbing gently while it waits.
    static func spitze(zeit: Double, striche: [Strich], eigene: [Int]) -> CGPoint {
        let f = fortschritt(zeit: zeit, anzahl: striche.count)
        if let i = eigene.first(where: { f[$0] > 0 && f[$0] < 1 }) { return punkt(striche[i], f[i]) }
        let schwebt = CGFloat(sin(zeit * 2.6)) * 1.2
        let ruhe = eigene.last(where: { f[$0] >= 1 }).map { striche[$0].b } ?? eigene.first.map { striche[$0].a } ?? .zero
        return CGPoint(x: ruhe.x + 3, y: ruhe.y - 4 + schwebt)
    }

    /// A sparkle at the end of each stroke for 0.6 s after it is finished, `staerke` 1 → 0.
    static func funken(zeit: Double, striche: [Strich]) -> [(punkt: CGPoint, farbe: UInt32, staerke: CGFloat)] {
        let c = zyklus(zeit)
        return striche.indices.compactMap { i -> (punkt: CGPoint, farbe: UInt32, staerke: CGFloat)? in
            let seit = c - Double(i + 1) * dauer
            guard seit >= 0, seit < 0.6 else { return nil }
            return (striche[i].b, striche[i].farbe, CGFloat(1 - seit / 0.6))
        }
    }
}
