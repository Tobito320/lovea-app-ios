import SwiftUI

/// Einstiege im Home-Tab: "Briefe" (Öffne, wenn ...) und "Sprachpost". Punkt/Zahl zeigt Ungeöffnetes und Ungehörtes.
struct NaeheKarte: View {
    let briefe = BriefeSpeicher.shared
    let post = SprachpostSpeicher.shared

    var body: some View {
        VStack(spacing: 0) {
            zeile("Briefe", symbol: "envelope.fill", anzahl: briefe.ungeoeffnet, ziel: BriefeView())
            Divider().padding(.leading, 56)
            zeile("Sprachpost", symbol: "waveform.circle.fill", anzahl: post.ungehoert, ziel: SprachpostView())
        }
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func zeile<Ziel: View>(_ titel: String, symbol: String, anzahl: Int, ziel: Ziel) -> some View {
        NavigationLink {
            ziel
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32)
                Text(titel).font(.headline)
                Spacer()
                if anzahl > 0 {
                    Text("\(anzahl)")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(Color.accentColor, in: .capsule)
                }
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(anzahl > 0 ? "\(titel), \(anzahl) neu" : titel)
    }
}
