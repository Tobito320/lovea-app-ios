import Foundation

/// p70 (44): looking after the cat. Next to stroking (`KatzeLogik`) the cat wants to be fed: once a day
/// for the two of them, by whoever is first. The op ID carries day and person, like the stroke, so a
/// second tap, a second phone or a replay counts once. How the cat feels follows from that day:
/// fed and stroked it purrs, with only one of the two it is content, with neither it is hungry.
/// Optional in the log: an old app skips the op.
enum KatzePflege {
    static let art = "katze.fuettern"
    static let punkte = 5
    static let grund = "Katze gefüttert"

    struct D: Codable { var tag: String }

    enum Stimmung: Equatable, Sendable {
        case hungrig, zufrieden, schnurrt

        var text: String {
            switch self {
            case .hungrig: "hat Hunger"
            case .zufrieden: "ist zufrieden"
            case .schnurrt: "schnurrt"
            }
        }
    }

    static func opId(tag: String, von: Person) -> String { "katze-futter-\(tag)-\(von.rawValue)" }

    /// One entry per well-formed op; an op whose ID does not match day and person is ignored.
    static func eintraege(_ ops: [(id: String, tag: String, von: Person)]) -> [PunkteLogik.Eintrag] {
        var gesehen = Set<String>()
        return ops
            .filter { $0.id == opId(tag: $0.tag, von: $0.von) && gesehen.insert($0.id).inserted }
            .map { PunkteLogik.Eintrag(datum: $0.tag, von: $0.von, grund: grund, punkte: punkte) }
    }

    static func op(tag: String, von: Person) -> Op {
        let neu = Op.neu(art, D(tag: tag), von: von)
        return Op(id: opId(tag: tag, von: von), seq: nil, art: art, von: von, zeit: neu.zeit, d: neu.d)
    }

    /// `gefuettert` / `gestreichelt`: by anyone of the two today.
    static func stimmung(gefuettert: Bool, gestreichelt: Bool) -> Stimmung {
        switch (gefuettert, gestreichelt) {
        case (true, true): .schnurrt
        case (false, false): .hungrig
        default: .zufrieden
        }
    }

    /// The food bubble: an awake cat that is not fed yet and has nothing else to wish (the heart bubble of
    /// the stroke comes first).
    static func hungert(_ zustand: KatzenZustand, gefuettert: Bool, wuenscht: Bool) -> Bool {
        zustand != .schlaeft && !gefuettert && !wuenscht
    }

    /// What a tap does: the first one strokes, once stroked a hungry cat gets its food.
    static func fuettertBeimTippen(gestreichelt: Bool, gefuettert: Bool) -> Bool { gestreichelt && !gefuettert }

    /// A purring cat shows it only while it is awake.
    static func schnurrt(_ zustand: KatzenZustand, _ stimmung: Stimmung) -> Bool {
        zustand != .schlaeft && stimmung == .schnurrt
    }

    /// Spoken label of the cat, mood included.
    static func beschreibung(_ zustand: KatzenZustand, _ stimmung: Stimmung) -> String {
        zustand == .schlaeft ? "Katze, schläft" : "Katze, \(stimmung.text)"
    }
}
