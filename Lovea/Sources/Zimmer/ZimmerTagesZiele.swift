import Foundation

/// p70 (40): three small goals a day: gym, water, one letter written. Each one done makes the room a
/// bit livelier: the plant grows a step and blooms when all three are done, and the lamp glows warmer
/// in the evening. Pure values; `ZimmerLebenModell.tagesZiele` reads them from the app's models.
struct ZimmerTagesZiele: Equatable, Sendable {
    var gym = false
    var wasser = false
    var brief = false

    var anzahl: Int { [gym, wasser, brief].filter { $0 }.count }

    /// Plant level (0 seedling ... 4 bloom): one step per goal, the third one is the bloom.
    var pflanzenStufe: Int { anzahl == 3 ? 4 : anzahl }

    /// How much stronger the lamp glows: 1 without any goal, 1.45 with all three.
    var lampenFaktor: Double { 1 + 0.15 * Double(anzahl) }

    var text: String {
        func zeile(_ name: String, _ geschafft: Bool) -> String { "\(name) \(geschafft ? "geschafft" : "offen")" }
        return "Heute: " + [zeile("Gym", gym), zeile("Wasser", wasser), zeile("Brief", brief)].joined(separator: ", ")
    }

    /// The water goal counts when it is set and reached.
    static func wasserErreicht(anzahl: Int, ziel: Int) -> Bool { ziel > 0 && anzahl >= ziel }

    /// Has `ich` written a letter on `heute`? `tag` turns a time into `yyyy-MM-dd`.
    static func briefGeschrieben(_ briefe: [Brief], von ich: Person, heute: String, tag: (Date) -> String = Datum.text) -> Bool {
        briefe.contains { $0.von == ich && tag($0.zeit) == heute }
    }
}

/// p70 (41): the streak as a candle next to the plant. The flame grows with the shared streak; without
/// a streak the candle is out. (A streak protection is left out on purpose: it would change how
/// `HabitLogik.serie` counts, and with it the points.)
enum ZimmerKerze {
    /// 0 out, 1 small (1 to 2 days), 2 normal (3 to 13), 3 big (14 and more).
    static func flamme(serie: Int) -> Int {
        switch serie {
        case ..<1: 0
        case 1...2: 1
        case 3...13: 2
        default: 3
        }
    }
}
