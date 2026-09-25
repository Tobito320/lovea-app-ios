import AppIntents
import Foundation
import SwiftUI
import WidgetKit

/// Spec 10 "Gym Ahmed vs. Annika" (mittel, interaktiv): beide Wochen nebeneinander, Ziel, heute
/// abhakbar — nur die eigene Spalte hat den Knopf, die des Partners ist reine Anzeige.
struct GymDuellWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GymDuell", provider: WidgetStandProvider()) { entry in
            GymDuellView(entry: entry)
        }
        .configurationDisplayName("Gym: Ahmed vs. Annika")
        .description("Beide Gym-Wochen nebeneinander, heute direkt abhakbar.")
        .supportedFamilies([.systemMedium])
    }
}

private struct GymDuellView: View {
    let entry: WidgetStandEntry

    var body: some View {
        let eigene = entry.stand.eigenePerson
        let partner = eigene == "ahmed" ? "annika" : "ahmed"
        HStack(spacing: 16) {
            GymSpalte(stand: entry.stand, person: eigene, eigene: true)
            Divider()
            GymSpalte(stand: entry.stand, person: partner, eigene: false)
        }
        .widgetURL(URL(string: "lovea://health"))
        .widgetHintergrund(WidgetStil.rose)
    }
}

private struct GymSpalte: View {
    let stand: WidgetStand
    let person: String
    let eigene: Bool

    var body: some View {
        let farbe = WidgetStil.farbe(person)
        let tage = stand.gymLetzte7[person] ?? []
        let heute = WidgetDatum.heute()
        let erledigtAnzahl = tage.filter(\.erledigt).count
        let ziel = stand.zielGymWoche[person] ?? 3
        let heuteErledigt = tage.first(where: { $0.datum == heute })?.erledigt ?? false

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                WidgetKopf(titel: WidgetStil.name(person), symbol: "figure.strengthtraining.traditional", farbe: farbe)
                Spacer(minLength: 0)
                if eigene {
                    Button(intent: GymHeuteIntent()) {
                        Image(systemName: heuteErledigt ? "checkmark.circle.fill" : "circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(heuteErledigt ? .green : farbe)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(erledigtAnzahl)").widgetZahl(30).widgetAccentable()
                Text("von \(ziel)").widgetEtikett()
            }
            Spacer(minLength: 0)
            GymTageReihe(tage: tage, heute: heute, farbe: farbe, groesse: 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
