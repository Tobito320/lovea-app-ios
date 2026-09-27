import SwiftUI

/// Kritzel-Duell im Rückblick: jede Runde mit beiden Bildern und den Herzen. Ein Bild öffnet groß,
/// oben rechts "…" schickt es in den Chat oder speichert es in Aufnahmen.
// ponytail: ohne Wort je Runde, die Wortwahl (`spiel.zug`) wird nicht gespeichert.
struct DuellRueckblick: View {
    let spiel: SpieleModell.Spiel
    @Environment(\.dismiss) private var dismiss

    private var runden: [Int] { spiel.bilder.keys.sorted() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(runden.enumerated()), id: \.element) { i, r in
                        let bilder = spiel.bilder[r] ?? [:]
                        let stimmen = spiel.stimmen[r] ?? [:]
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Runde \(i + 1)").font(.headline)
                            HStack(spacing: 10) {
                                ForEach([Person.ahmed, .annika], id: \.self) { p in
                                    if let id = bilder[p] {
                                        NavigationLink {
                                            DuellBildAnsicht(medienId: id, titel: "\(p.name) · Runde \(i + 1)")
                                        } label: {
                                            DuellBildKachel(medienId: id, name: p.name, herzen: stimmen.values.filter { $0 == p }.count)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Kritzel-Duell")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
    }
}

struct DuellBildKachel: View {
    let medienId: String
    let name: String
    let herzen: Int

    var body: some View {
        VStack(spacing: 6) {
            SpielBild(medienId: medienId)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottomTrailing) {
                    if herzen > 0 {
                        Label("\(herzen)", systemImage: "heart.fill")
                            .font(.caption.bold())
                            .padding(6)
                            .background(.regularMaterial, in: Capsule())
                            .foregroundStyle(Color.loveaRose)
                            .padding(6)
                    }
                }
            Text(name).font(.subheadline).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bild von \(name)")
    }
}

/// Ein Duell-Bild groß, mit "…" oben rechts.
struct DuellBildAnsicht: View {
    let medienId: String
    let titel: String
    @State private var hinweis: String?

    // Duell-Bilder sind immer 1024 × 1024 (`DuellZeichnen`).
    private var eintrag: ChatModell.MedienEintrag {
        ChatModell.MedienEintrag(id: medienId, typ: "foto", breite: 1024, hoehe: 1024)
    }

    var body: some View {
        SpielBild(medienId: medienId)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(16)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if let hinweis {
                    Text(hinweis)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            ChatModell.shared.medienSenden([eintrag])
                            Haptik.erfolg()
                            zeigen("In den Chat geschickt")
                        } label: {
                            Label("In den Chat senden", systemImage: "bubble.left.and.bubble.right")
                        }
                        Button {
                            Task { await speichern() }
                        } label: {
                            Label("In Aufnahmen speichern", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Mehr")
                }
            }
    }

    private func speichern() async {
        do {
            try await AufnahmenSpeichern.speichern([eintrag])
            Haptik.erfolg()
            zeigen("In Aufnahmen gespeichert")
        } catch AufnahmenSpeichern.Fehler.keineErlaubnis {
            Haptik.warnung()
            zeigen("Kein Zugriff auf Fotos. In den Einstellungen erlauben.")
        } catch {
            Haptik.warnung()
            zeigen("Speichern hat nicht geklappt")
        }
    }

    private func zeigen(_ text: String) {
        withAnimation(Feder.federnd) { hinweis = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(Feder.federnd) { if hinweis == text { hinweis = nil } }
        }
    }
}
