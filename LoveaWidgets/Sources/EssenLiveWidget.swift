import ActivityKit
import SwiftUI
import WidgetKit

/// Sperrbildschirm wie ein Mix aus unserem Ring und YAZIOs Mahlzeiten-Zeile: oben unser Ring + kcal +
/// Balken + Protein, darunter die vier Mahlzeiten 1:1 wie YAZIO (Emoji-Bild, blauer Ring, blaue
/// Haken/Plus-Marke, Name, kcal). Jede Mahlzeit ist ein eigener `Link` zu
/// `lovea://essen?mahlzeit=<rawValue>` (öffnet direkt das Hinzufügen-Blatt dafür), der Rest der Karte
/// zu `lovea://essen` (öffnet das Tagebuch).
struct EssenLiveWidget: Widget {
    private static let akzent = Color(red: 0.13, green: 0.86, blue: 0.66)
    private static let blau = Color(red: 0.18, green: 0.52, blue: 0.98)
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
        } dynamicIsland: { _ in
            // R10 (Ahmed, 01.10.: "kein Essen im Dynamic Island, nur Gym wenn gestartet"). iOS zeigt
            // eine laufende Live Activity immer irgendwie in der Dynamic Island, das lässt sich pro
            // Aktivität nicht abschalten — darum hier überall `EmptyView`, das Systemminimum.
            // `EssenLive` sorgt zusätzlich dafür, dass während eines laufenden Gym-Trainings gar
            // keine Essen-Aktivität läuft (siehe `EssenLive.aktion`/`gymLaeuft`).
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { EmptyView() }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                EmptyView()
            } minimal: {
                EmptyView()
            }
        }
    }

    // MARK: - Kopfzeile (unverändert aus R8: Ring + kcal + Protein-Balken)

    private func topZeile(_ s: EssenAktivitaet.ContentState) -> some View {
        HStack(spacing: 14) {
            ring(anteil: kcalAnteil(s), farbe: Self.akzent, durchmesser: 40, lineWidth: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(s.kcal) / \(s.kcalZiel) kcal").font(.headline)
                balken(anteil: proteinAnteil(s)).frame(height: 5)
                Text("\(s.proteinG) / \(s.proteinZiel) g Protein").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Mahlzeiten (1:1 wie YAZIO: Frühstück, Mittagessen, Abendessen | Snacks)

    private func mahlzeitenZeile(_ s: EssenAktivitaet.ContentState) -> some View {
        HStack(spacing: 8) {
            mahlzeitLink(s, .fruehstueck)
            mahlzeitLink(s, .mittag)
            mahlzeitLink(s, .abend)
            Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 46)
            mahlzeitLink(s, .snack)
        }
    }

    private func mahlzeitLink(_ s: EssenAktivitaet.ContentState, _ m: EssenMahlzeitAnzeige) -> some View {
        Link(destination: URL(string: "lovea://essen?mahlzeit=\(m.rawValue)") ?? Self.link) {
            mahlzeitZelle(m, kcal: kcal(s, m), ziel: s.kcalZiel)
        }
        .accessibilityLabel("\(m.name), \(kcal(s, m)) kcal")
    }

    private func mahlzeitZelle(_ m: EssenMahlzeitAnzeige, kcal: Int, ziel: Int) -> some View {
        let mahlzeitZiel = Double(ziel) * m.anteil
        let anteil = mahlzeitZiel > 0 ? min(1, Double(kcal) / mahlzeitZiel) : 0
        // ponytail: "hat Einträge" grob aus kcal > 0 abgeleitet (ein 0-kcal-Eintrag, z. B. nur Wasser,
        // zeigt dann noch ein Plus statt eines Hakens) — eigenes Zähl-Feld wäre für die Anzeige zu viel.
        let erledigt = kcal > 0
        return VStack(spacing: 3) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    ring(anteil: anteil, farbe: Self.blau, durchmesser: 46, lineWidth: 3)
                    Text(m.emoji).font(.system(size: 20))
                }
                Image(systemName: erledigt ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 15))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Self.blau)
                    .offset(x: 3, y: 3)
            }
            Text(m.name).font(.caption2.weight(erledigt ? .bold : .regular)).foregroundStyle(erledigt ? .white : .secondary)
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

    private func ring(anteil: Double, farbe: Color, durchmesser: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.22), lineWidth: lineWidth)
            Circle().trim(from: 0, to: anteil).stroke(farbe, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
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
