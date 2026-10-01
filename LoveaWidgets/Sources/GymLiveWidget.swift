import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Laufendes Training in der Dynamic Island und auf dem Sperrbildschirm: Übung, Satz, Gewicht und die
/// laufende Satz- oder Pausenzeit (wie Hevy).
/// Tipp öffnet die Einheit (`lovea://gym`).
struct GymLiveWidget: Widget {
    private static let gruen = Color(red: 0.36, green: 0.85, blue: 0.66)
    private static let link = URL(string: "lovea://gym")

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymAktivitaet.self) { kontext in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(kontext.attributes.tagName, systemImage: "dumbbell.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Self.gruen)
                    Spacer(minLength: 8)
                    Text(kontext.attributes.start, style: .timer)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kontext.state.uebung ?? "Training läuft").font(.headline).lineLimit(1)
                        Text(zeile(kontext.state)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    uhr(kontext.state).font(.title.bold().monospacedDigit())
                    knopf(kontext.state)
                }
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
                    uhr(kontext.state, sonst: kontext.attributes.start).font(.headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        Text([kontext.state.uebung, zeile(kontext.state)].compactMap { $0 }.joined(separator: " · ")).font(.subheadline).lineLimit(2)
                        Spacer(minLength: 4)
                        knopf(kontext.state)
                    }
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundStyle(Self.gruen)
            } compactTrailing: {
                uhr(kontext.state, sonst: kontext.attributes.start, breite: 56).monospacedDigit()
            } minimal: {
                Image(systemName: "dumbbell.fill").foregroundStyle(Self.gruen)
            }
            .widgetURL(Self.link)
        }
    }

    /// "Satz 2 von 3 · 32 kg × 12", in der Pause mit "Pause" davor; sonst der Stand der Übungen.
    private func zeile(_ s: GymAktivitaet.ContentState) -> String {
        guard let satz = s.satz, let saetze = s.saetze, let zeile = s.zeile else {
            return s.gesamt > 0 ? "\(s.fertig) von \(s.gesamt) Übungen fertig" : "Training läuft"
        }
        let pause = s.pause == true ? "Pause · " : ""
        return "\(pause)Satz \(satz) von \(saetze) · \(zeile)"
    }

    /// Ein Tipp macht den nächsten Schritt, ohne die App zu öffnen: läuft ein Satz, hakt er ihn ab,
    /// sonst startet er den Satz, der dran ist. Kein Knopf bei Cardio oder wenn alles fertig ist.
    @ViewBuilder
    private func knopf(_ s: GymAktivitaet.ContentState) -> some View {
        if s.satz != nil {
            let laeuft = s.seit != nil && s.pause != true
            Button(intent: GymSchrittIntent()) {
                Image(systemName: laeuft ? "checkmark" : "play.fill")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.black)
            .background(Self.gruen, in: .rect(cornerRadius: 12, style: .continuous))
            .accessibilityLabel(laeuft ? "Satz fertig" : "Satz starten")
        }
    }

    /// Satzzeit zählt hoch, eine Pause mit Ziel rückwärts. Ohne laufende Uhr `sonst` (die Zeit im Gym) oder nichts.
    @ViewBuilder
    private func uhr(_ s: GymAktivitaet.ContentState, sonst: Date? = nil, breite: CGFloat = 96) -> some View {
        Group {
            if let seit = s.seit, let bis = s.bis, bis > seit {
                Text(timerInterval: seit...bis, countsDown: true)
            } else if let start = s.seit ?? sonst {
                Text(start, style: .timer)
            }
        }
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: breite, alignment: .trailing)
    }
}
