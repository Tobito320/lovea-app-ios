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
                HStack(spacing: 12) {
                    SchritteRing(name: eigene == "ahmed" ? "Ahmed" : "Annika", schritte: entry.stand.schritteHeute[eigene], ziel: entry.stand.zielSchritte[eigene] ?? 10_000)
                    SchritteRing(name: partner == "ahmed" ? "Ahmed" : "Annika", schritte: entry.stand.schritteHeute[partner], ziel: entry.stand.zielSchritte[partner] ?? 10_000)
                }
            }
        }
        .widgetURL(URL(string: "lovea://health"))
        .containerBackground(.background, for: .widget)
    }
}

/// `schritte == nil` ("Health nicht erlaubt oder keine Daten") zeigt "–", nie 0 (Review-Fokus 4).
private struct SchritteRing: View {
    let name: String
    let schritte: Int?
    let ziel: Int

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 5)
                if let schritte {
                    Circle()
                        .trim(from: 0, to: min(1, Double(schritte) / Double(max(ziel, 1))))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 44, height: 44)
            Text(name).font(.caption2).bold()
            Text(schritte.map { "\($0)" } ?? "–").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
