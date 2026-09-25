import Foundation
import SwiftUI
import WidgetKit

/// Spec 10 "Punkte und Challenge" (mittel): Punktestand beider, laufende "Gemeinsam Woche"-Challenge.
struct PunkteChallengeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PunkteChallenge", provider: WidgetStandProvider()) { entry in
            PunkteChallengeView(entry: entry)
        }
        .configurationDisplayName("Punkte und Challenge")
        .description("Punktestand beider und die laufende Challenge.")
        .supportedFamilies([.systemMedium])
    }
}

private struct PunkteChallengeView: View {
    let entry: WidgetStandEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetKopf(titel: "Punkte", symbol: "star.circle.fill", farbe: WidgetStil.rose)
            HStack(alignment: .top, spacing: 16) {
                PunkteSpalte(person: "ahmed", punkte: entry.stand.punkte["ahmed"])
                PunkteSpalte(person: "annika", punkte: entry.stand.punkte["annika"])
                Divider()
                ChallengeAnzeige(stand: entry.stand)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "lovea://health"))
        .widgetHintergrund(WidgetStil.rose)
    }
}

private struct PunkteSpalte: View {
    let person: String
    let punkte: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(punkte.map { $0.formatted() } ?? "–").widgetZahl(26).foregroundStyle(WidgetStil.farbe(person)).widgetAccentable()
            Text(WidgetStil.name(person)).widgetEtikett()
        }
    }
}

private struct ChallengeAnzeige: View {
    let stand: WidgetStand

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Gemeinsam Woche").widgetEtikett()
            if let ziel = stand.gemeinsamZielWoche, let schritte = stand.gemeinsamSchritteWoche {
                Text("\(schritte.formatted())").widgetZahl(20)
                ProgressView(value: min(1, Double(schritte) / Double(max(ziel, 1))))
                    .tint(WidgetStil.rose)
                    .widgetAccentable()
                Text("von \(ziel.formatted())").widgetEtikett()
            } else {
                Text("–").widgetZahl(20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
