import ActivityKit
import SwiftUI
import WidgetKit

/// Laufendes Training in der Dynamic Island und auf dem Sperrbildschirm: Zeit im Gym, aktuelle Übung.
/// Tipp öffnet die Einheit (`lovea://gym`).
struct GymLiveWidget: Widget {
    private static let gruen = Color(red: 0.36, green: 0.85, blue: 0.66)
    private static let link = URL(string: "lovea://gym")

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymAktivitaet.self) { kontext in
            HStack(spacing: 14) {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(Self.gruen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Im Gym · \(kontext.attributes.tagName)").font(.headline)
                    Text(zeile(kontext.state)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(kontext.attributes.start, style: .timer)
                    .font(.title2.bold().monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110, alignment: .trailing)
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.6))
            .widgetURL(Self.link)
        } dynamicIsland: { kontext in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Gym", systemImage: "dumbbell.fill").font(.headline).foregroundStyle(Self.gruen)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(kontext.attributes.start, style: .timer)
                        .font(.headline.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(kontext.attributes.tagName) · \(zeile(kontext.state))").font(.subheadline).lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundStyle(Self.gruen)
            } compactTrailing: {
                Text(kontext.attributes.start, style: .timer)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "dumbbell.fill").foregroundStyle(Self.gruen)
            }
            .widgetURL(Self.link)
        }
    }

    private func zeile(_ s: GymAktivitaet.ContentState) -> String {
        let stand = s.gesamt > 0 ? "\(s.fertig) von \(s.gesamt) fertig" : "Training läuft"
        guard let uebung = s.uebung else { return stand }
        return "Jetzt: \(uebung) · \(stand)"
    }
}
