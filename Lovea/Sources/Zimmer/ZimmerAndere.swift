import Foundation

/// Where the other person is, for the small figure in the room (and for the p58 scene): in sports
/// clothes after the gym check-in, in bed when asleep, else at home. Pure, so it is testable.
enum ZimmerAndere {
    enum Wo: Equatable, Sendable {
        case zuhause, sport, bett

        var text: String {
            switch self {
            case .zuhause: "zu Hause"
            case .sport: "beim Sport"
            case .bett: "im Bett"
            }
        }

        var figur: FigurZustand {
            switch self {
            case .zuhause: .ruhig
            case .sport: .gym
            case .bett: .schlaeft
            }
        }
    }

    /// Bed wins (the sleeper's phone decides, `SchlafLogik`), then the gym: at the gym right now
    /// (`ort` is the place category) or checked in today until 22:00; everything else is home.
    static func bestimmen(schlaf: SchlafZustand, ort: String?, gymHeute: Bool, stunde: Int) -> Wo {
        if schlaf != .wach { return .bett }
        if ort == "gym" || (gymHeute && stunde < 22) { return .sport }
        return .zuhause
    }
}
