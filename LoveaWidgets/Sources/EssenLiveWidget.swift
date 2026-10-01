import ActivityKit
import SwiftUI
import WidgetKit

/// Kalorien und Protein des Tages in der Dynamic Island und auf dem Sperrbildschirm.
/// Tipp öffnet die Ernährung (`lovea://essen`).
struct EssenLiveWidget: Widget {
    private static let akzent = Color(red: 0.13, green: 0.86, blue: 0.66)
    private static let link = URL(string: "lovea://essen")

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EssenAktivitaet.self) { kontext in
            HStack(spacing: 14) {
                ring(kontext.state).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(kontext.state.kcal) / \(kontext.state.kcalZiel) kcal").font(.headline)
                    proteinBalken(kontext.state).frame(height: 6)
                }
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.6))
            .widgetURL(Self.link)
        } dynamicIsland: { kontext in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Essen", systemImage: "fork.knife").font(.headline).foregroundStyle(Self.akzent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(uebrig(kontext.state)) kcal übrig").font(.subheadline.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        makro("Eiweiß", kontext.state.proteinG, kontext.state.proteinZiel)
                        makro("Kohlenhydrate", kontext.state.kohlenhydrateG, kontext.state.kohlenhydrateZiel)
                        makro("Fett", kontext.state.fettG, kontext.state.fettZiel)
                    }
                }
            } compactLeading: {
                Image(systemName: "fork.knife").foregroundStyle(Self.akzent)
            } compactTrailing: {
                Text("\(uebrig(kontext.state))").monospacedDigit()
            } minimal: {
                ring(kontext.state)
            }
            .widgetURL(Self.link)
        }
    }

    private func uebrig(_ s: EssenAktivitaet.ContentState) -> Int { max(0, s.kcalZiel - s.kcal) }

    private func ring(_ s: EssenAktivitaet.ContentState) -> some View {
        let anteil = s.kcalZiel > 0 ? min(1, Double(s.kcal) / Double(s.kcalZiel)) : 0
        return ZStack {
            Circle().stroke(Color.white.opacity(0.25), lineWidth: 4)
            Circle().trim(from: 0, to: anteil).stroke(Self.akzent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }

    private func proteinBalken(_ s: EssenAktivitaet.ContentState) -> some View {
        let anteil = s.proteinZiel > 0 ? min(1, Double(s.proteinG) / Double(s.proteinZiel)) : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.25))
                Capsule().fill(Self.akzent).frame(width: geo.size.width * anteil)
            }
        }
    }

    private func makro(_ titel: String, _ g: Int, _ ziel: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(g)/\(ziel) g").font(.caption.weight(.semibold)).monospacedDigit()
            Text(titel).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
