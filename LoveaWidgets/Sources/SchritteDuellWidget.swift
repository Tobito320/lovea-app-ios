import Foundation
import SwiftUI
import WidgetKit

/// Spec 10 "Schritte-Duell" (klein, mittel) + Sperrbildschirm-Ring (accessoryCircular, eigene
/// Schritte) in einem Widget — spart ein achtes, fast identisches Widget.
struct SchritteDuellWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SchritteDuell", provider: WidgetStandProvider()) { entry in
            SchritteDuellView(entry: entry)
        }
        .configurationDisplayName("Schritte-Duell")
        .description("Zwei Ringe mit den heutigen Schritten.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

private struct SchritteDuellView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetStandEntry

    private var eigene: String { entry.stand.eigenePerson }
    private var partner: String { eigene == "ahmed" ? "annika" : "ahmed" }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                SchritteLockscreen(stand: entry.stand)
            default:
                VStack(alignment: .leading, spacing: 8) {
                    WidgetKopf(titel: "Schritte heute", symbol: "figure.walk", farbe: WidgetStil.farbe(eigene))
                    HStack(alignment: .top, spacing: 8) {
                        SchritteRing(stand: entry.stand, person: eigene)
                        SchritteRing(stand: entry.stand, person: partner)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .widgetURL(URL(string: "lovea://health"))
        .widgetHintergrund(WidgetStil.farbe(eigene))
    }
}

/// `schritte == nil` ("Health nicht erlaubt oder keine Daten") zeigt "–", nie 0 (Review-Fokus 4).
private struct SchritteRing: View {
    let stand: WidgetStand
    let person: String

    var body: some View {
        let schritte = stand.schritteHeute[person]
        let ziel = stand.zielSchritte[person] ?? 10_000
        let farbe = WidgetStil.farbe(person)
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(farbe.opacity(0.18), lineWidth: 6)
                if let schritte {
                    Circle()
                        .trim(from: 0, to: min(1, Double(schritte) / Double(max(ziel, 1))))
                        .stroke(farbe, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .widgetAccentable()
                }
                Text(WidgetStil.name(person)).font(.system(size: 10, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 6)
            }
            .frame(width: 46, height: 46)
            Text(schritte.map { $0.formatted() } ?? "–").widgetZahl(17).lineLimit(1).minimumScaleFactor(0.7)
            if let extras = extrasText {
                ViewThatFits(in: .horizontal) {
                    Text(extras.joined(separator: " · "))
                    VStack(spacing: 0) { ForEach(extras, id: \.self) { Text($0) } }
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// "4,2 km", "7 Etagen"; nil when neither is known.
    private var extrasText: [String]? {
        let teile = [
            stand.kmHeute?[person].map { "\($0.formatted(.number.precision(.fractionLength(1)))) km" },
            stand.etagenHeute?[person].map { "\($0) Etagen" },
        ].compactMap { $0 }
        return teile.isEmpty ? nil : teile
    }
}

private struct SchritteLockscreen: View {
    let stand: WidgetStand
    var body: some View {
        let person = stand.eigenePerson
        let schritte = stand.schritteHeute[person]
        let ziel = max(stand.zielSchritte[person] ?? 10_000, 1)
        Gauge(value: Double(schritte ?? 0), in: 0...Double(ziel)) {
            Image(systemName: "figure.walk")
        } currentValueLabel: {
            Text(schritte.map { $0 >= 1000 ? "\($0 / 1000)k" : "\($0)" } ?? "–")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}
