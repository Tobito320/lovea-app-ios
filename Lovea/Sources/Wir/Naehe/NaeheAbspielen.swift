import SwiftUI

/// Play-Knopf mit Wellenform für eine hochgeladene Sprachaufnahme (Briefe, Sprachpost). Spielt nur nach
/// Tap, nie von allein. Holt die Datei bei Bedarf und nutzt den App-weiten `SprachSpieler`.
struct NaeheAbspielen: View {
    let medienId: String
    let dauer: Double
    let pegel: [Float]
    /// Lokale Datei (Entwurf vor dem Hochladen), sonst wird die Medien-ID geholt.
    var lokal: URL?
    var beimStart: () -> Void = {}

    @State private var laedt = false
    @State private var fehler = false

    private var spieler: SprachSpieler { .shared }
    private var spielt: Bool { spieler.spielt(medienId) }
    private var anteil: Double { dauer > 0 ? min(1, spieler.position(medienId) / dauer) : 0 }

    var body: some View {
        HStack(spacing: 12) {
            Button { Task { await schalten() } } label: {
                Group {
                    if laedt {
                        ProgressView()
                    } else {
                        Image(systemName: spielt ? "pause.fill" : "play.fill")
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .font(.title3.weight(.bold))
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.15), in: .circle)
                .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spielt ? "Pausieren" : "Abspielen")

            WellenformAnsicht(pegel: pegel, anteil: anteil)
                .frame(height: 28)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(fehler ? "Nicht geladen" : zeit(spieler.position(medienId) > 0 || spielt ? spieler.position(medienId) : dauer))
                .font(.caption.monospacedDigit())
                .foregroundStyle(fehler ? Color.red : Color.secondary)
                .frame(minWidth: 40, alignment: .trailing)
        }
        .frame(minHeight: 44)
    }

    private func schalten() async {
        if spielt { spieler.pausieren(); return }
        fehler = false
        let url: URL
        if let vorhanden = lokal ?? ChatMedien.eigeneQuellen[medienId] ?? Medien.lokal(medienId) {
            url = vorhanden
        } else {
            laedt = true
            defer { laedt = false }
            guard let geholt = try? await Medien.holen(medienId) else { fehler = true; return }
            url = geholt
        }
        spieler.spielen(id: medienId, url: url)
        beimStart()
    }

    private func zeit(_ s: TimeInterval) -> String { String(format: "%d:%02d", Int(s) / 60, Int(s) % 60) }
}

enum NaeheDatum {
    private static let format: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.setLocalizedDateFormatFromTemplate("d MMMM HH:mm")
        return f
    }()

    static func kurz(_ d: Date) -> String { format.string(from: d) }
}
