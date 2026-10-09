import SwiftUI
import WidgetKit

/// One calm look for all widgets. Compiles into both targets (Shared), so no `Color` extensions
/// here: the app already has `Color.person`/`Color.loveaRose`.
enum WidgetStil {
    /// Copy of `Color.loveaRose` (app target only).
    static let rose = Color(red: 0xFF / 255, green: 0x3B / 255, blue: 0x5C / 255)

    /// Copy of `Color.person` (app target only), keyed by `Person.rawValue`.
    static func farbe(_ person: String) -> Color {
        person == "annika"
            ? Color(red: 0xE0 / 255, green: 0x28 / 255, blue: 0x4A / 255)
            : Color(red: 0x2F / 255, green: 0x6F / 255, blue: 0xE4 / 255)
    }

    static func name(_ person: String) -> String { person == "ahmed" ? "Ahmed" : "Annika" }
}

extension View {
    /// Soft gradient behind the widget; the system drops it in tinted/clear/lock screen modes.
    func widgetHintergrund(_ farbe: Color) -> some View {
        containerBackground(for: .widget) {
            ZStack {
                Rectangle().fill(.background)
                LinearGradient(colors: [farbe.opacity(0.22), farbe.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    /// Small secondary label.
    func widgetEtikett() -> some View {
        font(.caption2.weight(.medium)).foregroundStyle(.secondary)
    }
}

extension Text {
    /// Big bold rounded number.
    func widgetZahl(_ groesse: CGFloat = 34) -> Text {
        font(.system(size: groesse, weight: .bold, design: .rounded)).monospacedDigit()
    }
}

/// Header: tinted symbol plus small uppercase title.
struct WidgetKopf: View {
    let titel: String
    let symbol: String
    let farbe: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(farbe).widgetAccentable()
            Text(titel.uppercased()).foregroundStyle(.secondary)
        }
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
    }
}
