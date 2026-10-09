import SwiftUI
import UIKit

// Shared look of the Health tab (Spec 3.1): tinted gradient cards in the content layer (no glass),
// the eight habit tints, month paging and German number texts.

extension HabitFarbe {
    /// Darker in light mode (≥ 3 : 1 on white for symbols), brighter in dark mode.
    var farbe: Color {
        let hex: (hell: UInt32, dunkel: UInt32) = switch self {
        case .mint: (0x0F9D7A, 0x3DDBB0)
        case .amber: (0xC77800, 0xFFB340)
        case .indigo: (0x4B4FD1, 0x8E91FF)
        case .rose: (0xD6336C, 0xFF7AA8)
        case .himmel: (0x1C7FD6, 0x5AC8FA)
        case .limette: (0x5E9E00, 0xA6E22E)
        case .koralle: (0xE0533D, 0xFF8A70)
        case .grau: (0x6E6E73, 0xAEAEB2)
        }
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? uiFarbe(hex.dunkel) : uiFarbe(hex.hell) })
    }

    /// Unknown values from a newer build fall back to grey instead of failing.
    static func von(_ wert: String) -> HabitFarbe { HabitFarbe(rawValue: wert) ?? .grau }
}

extension Habit {
    var tint: Color { HabitFarbe.von(farbe).farbe }
}

extension Color {
    /// Glyphs on a filled habit tint: white on the darker light-mode tints, black on the bright dark ones.
    static let aufHabitFarbe = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .black : .white })
}

private func uiFarbe(_ hex: UInt32) -> UIColor {
    UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

/// HabitLink card: soft vertical tint over the grouped surface, 1 pt lighter border, radius 22.
struct HealthKarte: ViewModifier {
    var farbe: Color
    @Environment(\.colorSchemeContrast) private var kontrast

    func body(content: Content) -> some View {
        let form = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return content.background {
            form.fill(Color(uiColor: .secondarySystemBackground))
                .overlay(form.fill(LinearGradient(colors: [farbe.opacity(0.26), farbe.opacity(0.06)], startPoint: .top, endPoint: .bottom)))
                .overlay(form.strokeBorder(farbe.opacity(kontrast == .increased ? 0.7 : 0.22), lineWidth: 1))
        }
    }
}

extension View {
    func healthKarte(_ farbe: Color = .gray) -> some View { modifier(HealthKarte(farbe: farbe)) }
}

/// Months side by side, swipe to page, the last page is the current month (never the future).
struct MonatsPager<Inhalt: View>: View {
    // ponytail: 12 months back; derive from the first data day if older months are ever needed.
    var anzahl = 12
    @ViewBuilder let inhalt: (_ monateZurueck: Int) -> Inhalt

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach((0..<anzahl).reversed(), id: \.self) { zurueck in
                    inhalt(zurueck).containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.trailing)
    }
}

/// "Mo" … "So" above a 7-column grid.
struct WochentagsKopf: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(HabitLogik.wochentagKuerzel, id: \.self) { kuerzel in
                Text(kuerzel).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

enum HealthText {
    private static let deutsch = Locale(identifier: "de_DE")

    static func zahl(_ n: Int) -> String { n.formatted(.number.locale(deutsch)) }

    /// Above chart bars: "950", "8,6k", "12k".
    static func kurz(_ n: Int) -> String {
        if n < 1000 { return "\(n)" }
        if n < 10_000 { return (Double(n) / 1000).formatted(.number.precision(.fractionLength(1)).locale(deutsch)) + "k" }
        return "\(Int((Double(n) / 1000).rounded()))k"
    }

    /// "5,1 km · 7 Etagen", parts left out when missing.
    static func strecke(km: Double?, etagen: Int?) -> String? {
        let teile = [
            km.map { $0.formatted(.number.precision(.fractionLength(1)).locale(deutsch)) + " km" },
            etagen.map { $0 == 1 ? "1 Etage" : "\($0) Etagen" },
        ].compactMap { $0 }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }

    /// "September 2026" for the month that `gitter` (from `HealthLogik.monatsGitter`) shows.
    static func monat(_ gitter: [String?]) -> String {
        guard let erster = gitter.compactMap({ $0 }).first else { return "" }
        let stil = Date.FormatStyle(locale: deutsch, calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
        return Datum.datum(erster).formatted(stil.month(.wide).year())
    }

    static func tagesnummer(_ tag: String) -> String { String(Int(tag.suffix(2)) ?? 0) }
}
