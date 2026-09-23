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
        HStack(spacing: 16) {
            PunkteSpalte(name: "Ahmed", punkte: entry.stand.punkte["ahmed"])
            PunkteSpalte(name: "Annika", punkte: entry.stand.punkte["annika"])
            Divider()
            ChallengeAnzeige(stand: entry.stand)
        }
        .padding(4)
        .widgetURL(URL(string: "lovea://health"))
        .containerBackground(.background, for: .widget)
    }
}

private struct PunkteSpalte: View {
    let name: String
    let punkte: Int?

    var body: some View {
        VStack(spacing: 2) {
            Text(name).font(.caption2).foregroundStyle(.secondary)
            Text(punkte.map { "\($0)" } ?? "–").font(.title3).bold()
        }
    }
}

private struct ChallengeAnzeige: View {
    let stand: WidgetStand

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Gemeinsam Woche").font(.caption2).foregroundStyle(.secondary)
            if let ziel = stand.gemeinsamZielWoche, let schritte = stand.gemeinsamSchritteWoche {
                ProgressView(value: min(1, Double(schritte) / Double(max(ziel, 1))))
                Text("\(schritte) / \(ziel)").font(.caption2)
            } else {
                Text("–").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
