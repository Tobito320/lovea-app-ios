import SwiftUI

/// Spec 8.1 Nr. 1: „Noch 3 Tage bis …" mit dem nächsten Herz-Tag. Bewusst ohne „Tage zusammen"
/// und ohne Flamme — die stehen laut Spec nicht auf Home.
struct NaechstesTreffenCard: View {
    let kalender = KalenderModell.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kalender.naechstesTreffen == nil ? "heart" : "heart.fill")
                .font(.title2)
                .foregroundStyle(Color.loveaRose)
            VStack(alignment: .leading, spacing: 2) {
                if let treffen = kalender.naechstesTreffen {
                    Text(countdownText(treffen.datum))
                        .font(.headline)
                    if let was = treffen.wasMachenWir, !was.isEmpty {
                        Text(was)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Noch kein Treffen geplant")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Color.loveaRose.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private func countdownText(_ datum: String) -> String {
        let tage = Datum.tageZwischen(Datum.text(Date()), datum)
        switch tage {
        case ..<0: return "Euer Treffen"
        case 0: return "Heute ist euer Treffen"
        case 1: return "Noch 1 Tag bis zu eurem Treffen"
        default: return "Noch \(tage) Tage bis zu eurem Treffen"
        }
    }
}
