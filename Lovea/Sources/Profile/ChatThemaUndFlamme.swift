import SwiftUI

/// Z-23.2: pick from OWNED chat themes (bought in the Shop) — introduces `chat.theme`, rendered as
/// the chat background in `ChatHintergrundAnsicht` (Brief I.1).
struct ChatThemaAuswahl: View {
    let ich: Person
    @Environment(\.dismiss) private var dismiss
    @State private var gewaehlt = 0

    /// Shared last-wins, same as the actual rendering — highlights whichever theme is really
    /// showing right now, not just what THIS person last picked.
    private var aktuell: String {
        guard case .string(let id)? = EinstellungenModell.shared.geteilt("chat.theme") else { return "" }
        return id
    }
    private var besitzt: [ChatTheme] {
        let ergebnis = PunkteModell.shared.einkaufsStand(preis: { ShopKatalog.artikel($0)?.preis }).besitz
        return ChatThemes.alle.filter { ergebnis.besitzt($0.id, ich) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if besitzt.isEmpty {
                    ContentUnavailableView("Noch kein Chat-Thema", systemImage: "paintpalette", description: Text("Kauf eins im Shop."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
                            ForEach(besitzt) { thema in
                                Button {
                                    EinstellungenModell.shared.setzen("chat.theme", .string(thema.id))
                                    gewaehlt += 1
                                } label: {
                                    VStack(spacing: 4) {
                                        ChatThemePreviewView(thema: thema)
                                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(aktuell == thema.id ? Color.loveaRose : .clear, lineWidth: 3))
                                        Text(thema.name).font(.caption2.weight(.semibold))
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(thema.name)
                                .accessibilityAddTraits(aktuell == thema.id ? .isSelected : [])
                            }
                        }
                        .padding(16)
                        if !aktuell.isEmpty {
                            Button("Kein Thema", role: .destructive) {
                                EinstellungenModell.shared.setzen("chat.theme", .string(""))
                                gewaehlt += 1
                            }
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            .navigationTitle("Chat-Thema")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .sensoryFeedback(.selection, trigger: gewaehlt)
        }
    }
}

/// Z-23.2: extends the existing `flamme` setting (already read by the profile streak chip) with a
/// grid of OWNED flames from the Shop — same key as the free-text emoji field in Einstellungen
/// (`FlammeEditor`), so this doesn't duplicate a mechanism, just adds a second way to set it.
struct BesitzFlammenAuswahl: View {
    let ich: Person
    @Environment(\.dismiss) private var dismiss
    @State private var gewaehlt = 0

    private var aktuell: String { EinstellungenModell.shared.string("flamme", default: "🔥", von: ich) }
    private var besitzt: [Flamme] {
        let ergebnis = PunkteModell.shared.einkaufsStand(preis: { ShopKatalog.artikel($0)?.preis }).besitz
        return Flammen.alle.filter { ergebnis.besitzt($0.id, ich) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if besitzt.isEmpty {
                    ContentUnavailableView("Noch keine Flamme gekauft", systemImage: "flame", description: Text("Kauf eine im Shop, oder trag ein eigenes Emoji in den Einstellungen ein."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 10)], spacing: 10) {
                            ForEach(besitzt) { flamme in
                                Button {
                                    EinstellungenModell.shared.setzen("flamme", .string(flamme.symbol))
                                    gewaehlt += 1
                                } label: {
                                    FlammenPreviewView(flamme: flamme)
                                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(aktuell == flamme.symbol ? Color.loveaRose : .clear, lineWidth: 3))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(flamme.name)
                                .accessibilityAddTraits(aktuell == flamme.symbol ? .isSelected : [])
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Deine Flamme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .sensoryFeedback(.selection, trigger: gewaehlt)
        }
    }
}
