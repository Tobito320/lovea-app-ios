import SwiftUI

/// Snapchat-style header (Z-4.4): partner figure, name, online/last-seen, pinned bar, media menu,
/// streak badge (Z-6.5).
struct ChatKopfzeile: View {
    let ich: Person
    let partner: Person
    let modell: ChatModell
    let onSpringeZu: (String) -> Void
    @Binding var profilOffen: Bool
    @State private var medienOffen = false
    @State private var hintergrundOffen = false
    @State private var spieleOffen = false

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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(partner.name), \(statusText), \(FigurenModell.shared.anzeige(partner).haupt.titel)")
                .accessibilityHint("Profil öffnen")
                .accessibilityAddTraits(.isButton)

                Spacer()

                StreakAnzeige(modell: modell)

                Menu {
                    Button("Medien", systemImage: "photo.on.rectangle") { medienOffen = true }
                    Button("Chat-Hintergrund", systemImage: "photo.artframe") { hintergrundOffen = true }
                } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 36, minHeight: 44) }
                .accessibilityLabel("Mehr")
                .sheet(isPresented: $medienOffen) { MedienUebersicht(ich: ich) }
                .sheet(isPresented: $hintergrundOffen) { ChatHintergrundEinstellung(ich: ich) }

                Button { spieleOffen = true } label: { Image(systemName: "gamecontroller.fill").frame(minWidth: 36, minHeight: 44) }
                    .accessibilityLabel("Spiel starten")
                    .sheet(isPresented: $spieleOffen) { SpieleStarter() }
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

/// Streak-Badge (Z-6.5): Flamme (einstellbar über `flamme`, Standard 🔥) + Tage, Sanduhr ab 20 Uhr,
/// solange heute noch nicht beide gesendet haben. `TimelineView` re-evaluates `modell.streak` once
/// a minute — without it, the hourglass would only appear at 20:00 by coincidence, whenever some
/// unrelated op happens to redraw the header next.
private struct StreakAnzeige: View {
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
