import SwiftUI

/// p70 (33): bouquets wilt slowly. Each bouquet carries the day it was put there (`ZimmerStraeusse.frisch`);
/// from that day on it is fresh for a few days, then tired, then wilted. Putting it there again, or a
/// gift from the other one, makes it fresh. Pure logic: no clock in here, `heute` comes from outside.
enum StraussFrische: Equatable, Sendable {
    case frisch, muede, welk

    static let muedeNachTagen = 4
    static let welkNachTagen = 8

    static func stufe(tage: Int) -> StraussFrische {
        if tage >= welkNachTagen { return .welk }
        return tage >= muedeNachTagen ? .muede : .frisch
    }

    /// Whole days from `gestellt` to `heute` (both `yyyy-MM-dd`); nil for anything unreadable.
    static func tage(seit gestellt: String?, bis heute: String) -> Int? {
        guard let a = tag(gestellt), let b = tag(heute) else { return nil }
        return Datum.kalender.dateComponents([.day], from: a, to: b).day
    }

    /// No date (an arrangement from before p70) or an unreadable one counts as fresh.
    static func von(gestellt: String?, heute: String) -> StraussFrische {
        guard let t = tage(seit: gestellt, bis: heute) else { return .frisch }
        return stufe(tage: max(t, 0))
    }

    /// `Datum.datum` would crash on a bad string, and these come from a synced setting.
    private static func tag(_ text: String?) -> Date? {
        guard let teile = text?.split(separator: "-").compactMap({ Int($0) }), teile.count == 3 else { return nil }
        return Datum.kalender.date(from: DateComponents(year: teile[0], month: teile[1], day: teile[2]))
    }

    /// How the drawing is toned down: less colour, the bouquet leans over a little.
    var saettigung: Double {
        switch self {
        case .frisch: 1
        case .muede: 0.7
        case .welk: 0.35
        }
    }

    var neigung: Double {
        switch self {
        case .frisch: 0
        case .muede: 4
        case .welk: 11
        }
    }

    var name: String {
        switch self {
        case .frisch: "frisch"
        case .muede: "müde"
        case .welk: "welk"
        }
    }
}

/// A fresh bouquet is drawn exactly as before (no extra layer); the others fade and lean on their stems.
struct StraussWelke: ViewModifier {
    let frische: StraussFrische

    @ViewBuilder
    func body(content: Content) -> some View {
        if frische == .frisch {
            content
        } else {
            content
                .saturation(frische.saettigung)
                .rotationEffect(.degrees(frische.neigung), anchor: .bottom)
        }
    }
}
