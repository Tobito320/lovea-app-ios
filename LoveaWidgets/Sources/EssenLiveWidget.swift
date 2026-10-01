import ActivityKit
import SwiftUI
import WidgetKit

/// Sperrbildschirm wie ein Mix aus unserem Ring und YAZIOs Mahlzeiten-Zeile: oben Ring + kcal +
/// Balken + Protein, darunter die vier Mahlzeiten mit eigenem Ring, Symbol und Haken/Plus-Marke.
/// Jede Mahlzeit ist ein eigener `Link` zu `lovea://essen?mahlzeit=<rawValue>` (öffnet direkt das
/// Hinzufügen-Blatt dafür), der Rest der Karte zu `lovea://essen` (öffnet das Tagebuch).
struct EssenLiveWidget: Widget {
    private static let akzent = Color(red: 0.13, green: 0.86, blue: 0.66)
    private static let link = URL(string: "lovea://essen")!

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EssenAktivitaet.self) { kontext in
            VStack(alignment: .leading, spacing: 10) {
                topZeile(kontext.state)
                mahlzeitenZeile(kontext.state)
            }
            .padding(14)
            .activityBackgroundTint(Color.black.opacity(0.6))
            .widgetURL(Self.link)
        } dynamicIsland: { kontext in
            DynamicIsland {
                // iOS zeigt eine laufende Live Activity immer in der Dynamic Island, das lässt sich
                // pro Aktivität nicht abschalten (Ahmed, 01.10.: "Essen sollte nicht in Dynamic
                // Island"). Darum hier nur das Systemminimum: Expanded zeigt dieselbe Kopfzeile wie
                // der Sperrbildschirm, compact/minimal nur einen winzigen Ring.
                DynamicIslandExpandedRegion(.center) { topZeile(kontext.state) }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                ring(anteil: kcalAnteil(kontext.state), durchmesser: 12, lineWidth: 2)
            } minimal: {
                ring(anteil: kcalAnteil(kontext.state), durchmesser: 12, lineWidth: 2)
            }
            .widgetURL(Self.link)
        }
    }

    // MARK: - Kopfzeile (Sperrbildschirm oben + Dynamic Island expanded)

    private func topZeile(_ s: EssenAktivitaet.ContentState) -> some View {
        HStack(spacing: 14) {
            ring(anteil: kcalAnteil(s), durchmesser: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(s.kcal) / \(s.kcalZiel) kcal").font(.headline)
                balken(anteil: proteinAnteil(s)).frame(height: 5)
                Text("\(s.proteinG) / \(s.proteinZiel) g Protein").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Mahlzeiten (nur Sperrbildschirm, wie YAZIO)

    private func mahlzeitenZeile(_ s: EssenAktivitaet.ContentState) -> some View {
        HStack(spacing: 10) {
            ForEach(EssenMahlzeitAnzeige.allCases, id: \.self) { m in
                Link(destination: URL(string: "lovea://essen?mahlzeit=\(m.rawValue)") ?? Self.link) {
                    mahlzeitZelle(m, kcal: kcal(s, m), ziel: s.kcalZiel)
                }
                .accessibilityLabel("\(m.name), \(kcal(s, m)) kcal")
            }
        }
    }

    private func mahlzeitZelle(_ m: EssenMahlzeitAnzeige, kcal: Int, ziel: Int) -> some View {
        let mahlzeitZiel = Double(ziel) * m.anteil
        let anteil = mahlzeitZiel > 0 ? min(1, Double(kcal) / mahlzeitZiel) : 0
        // ponytail: "hat Einträge" grob aus kcal > 0 abgeleitet (ein 0-kcal-Eintrag, z. B. nur Wasser,
        // zeigt dann noch ein Plus statt eines Hakens) — eigenes Zähl-Feld wäre für die Anzeige zu viel.
        let erledigt = kcal > 0
        return VStack(spacing: 3) {
            ZStack {
                ring(anteil: anteil, durchmesser: 28, lineWidth: 2.5)
                Image(systemName: m.symbol).font(.system(size: 11)).foregroundStyle(.white)
                Image(systemName: erledigt ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(erledigt ? Self.akzent : .white.opacity(0.7))
                    .background(Circle().fill(Color.black.opacity(0.6)).frame(width: 12, height: 12))
                    .offset(x: 12, y: 12)
            }
            Text("\(kcal) kcal").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Hilfen

    private func kcal(_ s: EssenAktivitaet.ContentState, _ m: EssenMahlzeitAnzeige) -> Int {
        let i = EssenMahlzeitAnzeige.allCases.firstIndex(of: m) ?? 0
        return i < s.mahlzeitenKcal.count ? s.mahlzeitenKcal[i] : 0
    }

    private func kcalAnteil(_ s: EssenAktivitaet.ContentState) -> Double {
        s.kcalZiel > 0 ? min(1, Double(s.kcal) / Double(s.kcalZiel)) : 0
    }

    private func proteinAnteil(_ s: EssenAktivitaet.ContentState) -> Double {
        s.proteinZiel > 0 ? min(1, Double(s.proteinG) / Double(s.proteinZiel)) : 0
    }

    private func ring(anteil: Double, durchmesser: CGFloat = 44, lineWidth: CGFloat = 4) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.25), lineWidth: lineWidth)
            Circle().trim(from: 0, to: anteil).stroke(Self.akzent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: durchmesser, height: durchmesser)
    }

    private func balken(anteil: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.25))
                Capsule().fill(Self.akzent).frame(width: geo.size.width * anteil)
            }
        }
    }
}
