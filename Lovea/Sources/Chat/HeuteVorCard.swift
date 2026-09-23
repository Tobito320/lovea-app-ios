import SwiftUI
import UIKit

/// Z-27.3: "Heute vor …" card on Home and in the Chat tab. Empty (`EmptyView`) when nothing
/// matches — the caller doesn't need its own visibility check.
/// // ponytail: no jump to the exact message, only opens the conversation — that jump target lives
/// as private `@State` inside `Unterhaltung`.
struct HeuteVorCard: View {
    /// Home has no `offen` binding to a conversation, so it falls back to switching tabs; the Chat
    /// tab passes its own `offen = true` instead.
    var onOeffnen: (() -> Void)? = nil

    private var treffer: (nachricht: ChatModell.Nachricht, zeitraum: HeuteVorLogik.Zeitraum)? {
        HeuteVorLogik.auswahl(ChatModell.shared.nachrichten)
    }

    var body: some View {
        if let treffer {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if let onOeffnen { onOeffnen() } else { AppNavigation.shared.tabWunsch = "chat" }
            } label: {
                HStack(spacing: 12) {
                    vorschau(treffer.nachricht)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(treffer.zeitraum.titel).font(.subheadline.weight(.semibold))
                        Text(ChatVorschau.inhalt(treffer.nachricht)).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(treffer.zeitraum.titel): \(ChatVorschau.inhalt(treffer.nachricht))")
        }
    }

    @ViewBuilder
    private func vorschau(_ n: ChatModell.Nachricht) -> some View {
        if let medium = n.medien.first(where: { $0.typ == "foto" }) {
            MedienKachel(medium: medium, eigene: n.von == Raum.shared.ich)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
