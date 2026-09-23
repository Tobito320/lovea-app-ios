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
        let farbe = WidgetStil.farbe(person)
        let tage = entry.stand.gymLetzte7[person] ?? []
        let heute = WidgetDatum.heute()
        let heuteErledigt = tage.first(where: { $0.datum == heute })?.erledigt ?? false
        let ziel = entry.stand.zielGymWoche[person] ?? 3
        let erledigtAnzahl = tage.filter(\.erledigt).count

        VStack(alignment: .leading, spacing: 6) {
            WidgetKopf(titel: "Gym-Woche", symbol: "figure.strengthtraining.traditional", farbe: farbe)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(erledigtAnzahl)").widgetZahl().widgetAccentable()
                Text("von \(ziel)").widgetEtikett()
            }
            GymTageReihe(tage: tage, heute: heute, farbe: farbe, groesse: 14)
            Spacer(minLength: 0)
            Button(intent: GymHeuteIntent()) {
                Label(heuteErledigt ? "Erledigt" : "Abhaken", systemImage: heuteErledigt ? "checkmark.circle.fill" : "circle")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(heuteErledigt ? .green : farbe)
        }
        .widgetURL(URL(string: "lovea://health"))
        .widgetHintergrund(farbe)
    }
}

/// Mo–So als Punkte, erledigte Tage gefüllt mit Haken, heute umrandet. Auch vom Gym-Duell genutzt.
struct GymTageReihe: View {
    let tage: [WidgetStand.TagEintrag]
    let heute: String
    let farbe: Color
    let groesse: CGFloat

    var body: some View {
        HStack(spacing: 3) {
            ForEach(tage, id: \.datum) { tag in
                ZStack {
                    Circle().fill(tag.erledigt ? farbe : Color.secondary.opacity(0.18))
                    if tag.erledigt {
                        Image(systemName: "checkmark").font(.system(size: groesse * 0.5, weight: .bold)).foregroundStyle(.white)
                    }
                    if tag.datum == heute { Circle().stroke(farbe, lineWidth: 1.5).padding(-2) }
                }
                .frame(width: groesse, height: groesse)
                .widgetAccentable(tag.erledigt)
            }
        }
    }
}
