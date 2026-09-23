import SwiftUI

/// Snapchat-style header (Z-4.4): partner figure, name, online/last-seen, pinned bar.
/// Flame stays empty until Block 6 computes the streak; the games button is a Block 14 placeholder.
struct ChatKopfzeile: View {
    let partner: Person
    let modell: ChatModell
    let onSpringeZu: (String) -> Void
    @Binding var profilOffen: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { profilOffen = true } label: {
                    HStack(spacing: 10) {
                        FigurView(FigurenModell.shared.aussehen(partner), zustand: FigurenModell.shared.anzeige(partner).haupt, groesse: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(partner.name).font(.headline)
                            Text(statusText).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button {} label: { Image(systemName: "gamecontroller.fill") }
                    .disabled(true) // ponytail: Spiele im Chat kommen in Block 14
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if !modell.angeheftete.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(modell.angeheftete) { nachricht in
                            Button { onSpringeZu(nachricht.id) } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "pin.fill")
                                    Text(nachricht.text ?? "Nachricht").lineLimit(1)
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.thinMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 6)
            }

            SyncStatusZeile()
            Divider()
        }
        .background(.bar)
    }

    private var statusText: String {
        if Raum.shared.partnerDa { return "online" }
        guard let zuletzt = modell.letzteAktivitaet[partner] else { return "offline" }
        return "zuletzt \(zuletzt.formatted(.relative(presentation: .named)))"
    }
}
