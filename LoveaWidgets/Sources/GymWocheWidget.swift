import AppIntents
import Foundation
import SwiftUI
import WidgetKit

/// Spec 10 "Gym-Woche" (klein, interaktiv): eigene 7 Tage, heute direkt abhakbar.
struct GymWocheWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GymWoche", provider: WidgetStandProvider()) { entry in
            GymWocheView(entry: entry)
        }
        .configurationDisplayName("Gym-Woche")
        .description("Deine Gym-Tage, heute direkt abhakbar.")
        .supportedFamilies([.systemSmall])
    }
}

private struct GymWocheView: View {
    let entry: WidgetStandEntry

    var body: some View {
        let person = entry.stand.eigenePerson
        let tage = entry.stand.gymLetzte7[person] ?? []
        let heute = WidgetDatum.heute()
        let heuteErledigt = tage.first(where: { $0.datum == heute })?.erledigt ?? false
        let ziel = entry.stand.zielGymWoche[person] ?? 3
        let erledigtAnzahl = tage.filter(\.erledigt).count

        VStack(alignment: .leading, spacing: 6) {
            Label("Gym-Woche", systemImage: "figure.strengthtraining.traditional")
                .font(.caption2).bold()
                .foregroundStyle(.secondary)
            GymTageReihe(tage: tage, heute: heute)
            Spacer(minLength: 0)
            Button(intent: GymHeuteIntent()) {
                Label(heuteErledigt ? "Erledigt" : "Abhaken", systemImage: heuteErledigt ? "checkmark.circle.fill" : "circle")
                    .font(.caption.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(heuteErledigt ? .green : .accentColor)
            Text("\(erledigtAnzahl) von \(ziel) diese Woche")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .widgetURL(URL(string: "lovea://health"))
        .containerBackground(.background, for: .widget)
    }
}

private struct GymTageReihe: View {
    let tage: [WidgetStand.TagEintrag]
    let heute: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tage, id: \.datum) { tag in
                Circle()
                    .fill(tag.erledigt ? Color.green : Color.secondary.opacity(0.25))
                    .overlay {
                        if tag.datum == heute { Circle().stroke(Color.accentColor, lineWidth: 2) }
                    }
                    .frame(width: 16, height: 16)
            }
        }
    }
}
