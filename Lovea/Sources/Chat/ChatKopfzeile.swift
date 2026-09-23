import SwiftUI

/// Conversation header (Block 18), placed next to the system back button: partner figure, name and
/// status. Tap opens the partner profile; Medien, Chat-Hintergrund and search live there now.
struct ChatPartnerKopf: View {
    let partner: Person
    let modell: ChatModell
    let onTippen: () -> Void

    var body: some View {
        let zustand = FigurenModell.shared.anzeige(partner).haupt
        Button { ChatHaptik.leicht(); onTippen() } label: {
            HStack(spacing: 8) {
                FigurView(FigurenModell.shared.aussehen(partner), zustand: zustand, groesse: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text(partner.name).font(.headline).lineLimit(1)
                    Text(statusText(zustand))
                        .font(.caption)
                        .foregroundStyle(zustand == .tippt ? Color.person(partner) : Color.secondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(partner.name), \(statusText(zustand))")
        .accessibilityHint("Profil öffnen")
        .accessibilityAddTraits(.isButton)
    }

    private func statusText(_ zustand: FigurZustand) -> String {
        if zustand == .tippt { return "tippt …" }
        if Raum.shared.partnerDa { return "online" }
        guard let zuletzt = modell.letzteAktivitaet[partner] else { return "offline" }
        return "zuletzt \(zuletzt.formatted(.relative(presentation: .named)))"
    }
}

/// Pinned messages (Z-4.4) as a slim bar under the header; tap jumps there.
struct ChatAngeheftetLeiste: View {
    let modell: ChatModell
    let onSpringeZu: (String) -> Void

    var body: some View {
        if !modell.angeheftete.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(modell.angeheftete) { nachricht in
                        Button { ChatHaptik.auswahl(); onSpringeZu(nachricht.id) } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pin.fill")
                                Text(nachricht.text ?? ChatVorschau.inhalt(nachricht)).lineLimit(1)
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
                .padding(.vertical, 6)
            }
        }
    }
}

/// Streak-Badge (Z-6.5): Flamme (einstellbar über `flamme`, Standard 🔥) + Tage, Sanduhr ab 20 Uhr,
/// solange heute noch nicht beide gesendet haben. `TimelineView` re-evaluates `modell.streak` once
/// a minute — without it, the hourglass would only appear at 20:00 by coincidence, whenever some
/// unrelated op happens to redraw the header next.
struct ChatStreakAnzeige: View {
    let modell: ChatModell

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let streak = modell.streak
            if streak.tage > 0 {
                HStack(spacing: 3) {
                    Text(EinstellungenModell.shared.string("flamme", default: "🔥"))
                    Text("\(streak.tage)").font(.subheadline.bold())
                    if streak.laeuftAb { Image(systemName: "hourglass").foregroundStyle(.secondary) }
                }
                .font(.subheadline)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Streak \(streak.tage) \(streak.tage == 1 ? "Tag" : "Tage")\(streak.laeuftAb ? ", läuft heute ab" : "")")
            }
        }
    }
}
