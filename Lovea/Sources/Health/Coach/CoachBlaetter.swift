import SwiftUI

// Health-Coach, Blätter, die erst auf Tipp aufgehen: Suche im Verlauf, Verlauf teilen, angeheftete Antworten.
// Akku: Alles wird erst beim Öffnen des Blatts gerechnet, nichts läuft im Hintergrund.

struct CoachSucheBlatt: View {
    let nachrichten: [CoachNachricht]
    /// Id der gewählten Nachricht; der Chat scrollt dorthin.
    let waehlen: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var begriff = ""

    private var treffer: [CoachNachricht] {
        Array(CoachLokal.suche(nachrichten, begriff: begriff).reversed().prefix(60))
    }

    var body: some View {
        let gefunden = treffer
        let leer = begriff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        NavigationStack {
            List {
                if leer {
                    Text("Suche in deinem Verlauf.").foregroundStyle(.secondary)
                } else if gefunden.isEmpty {
                    Text("Nichts gefunden.").foregroundStyle(.secondary)
                } else {
                    ForEach(gefunden) { nachricht in
                        Button {
                            waehlen(nachricht.id)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(nachricht.rolle == .du ? "Du" : "Coach") · \(CoachAnzeige.zeitText(nachricht.zeit))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(CoachText.vorschau(nachricht.text, maximal: 140))
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
            .navigationTitle("Suche")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $begriff, placement: .navigationBarDrawer(displayMode: .always), prompt: "Im Verlauf suchen")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

struct CoachExportBlatt: View {
    /// Fertiger Text (`CoachLokal.export`); leer, wenn es noch nichts gibt.
    let text: String

    @Environment(\.dismiss) private var dismiss

    private static let vorschauZeichen = 4000

    var body: some View {
        NavigationStack {
            ScrollView {
                if text.isEmpty {
                    Text("Noch nichts im Verlauf.").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(20)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(text.prefix(Self.vorschauZeichen)))
                            .font(.footnote)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if text.count > Self.vorschauZeichen {
                            Text("Vorschau gekürzt. Teilen enthält den ganzen Verlauf.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Verlauf teilen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                if !text.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        ShareLink(item: text) { Label("Teilen", systemImage: "square.and.arrow.up") }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct CoachGemerktBlatt: View {
    @Environment(\.dismiss) private var dismiss

    private var modell: CoachModell { .shared }

    var body: some View {
        let liste = Array(modell.gemerkteNachrichten.reversed())
        NavigationStack {
            List {
                if liste.isEmpty {
                    Text("Noch nichts angeheftet. Halte eine Nachricht gedrückt und wähle Anheften.").foregroundStyle(.secondary)
                } else {
                    Section {
                        ForEach(liste) { nachricht in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(nachricht.rolle == .du ? "Du" : "Coach") · \(CoachAnzeige.zeitText(nachricht.zeit))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(CoachText.vorschau(nachricht.text, maximal: 300)).font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .swipeActions {
                                Button("Lösen", role: .destructive) { loesen(nachricht) }
                            }
                            .contextMenu {
                                Button("Kopieren", systemImage: "doc.on.doc") {
                                    UIPasteboard.general.string = CoachAnzeige.kopierText(nachricht.text)
                                }
                                Button("Lösen", systemImage: "pin.slash", role: .destructive) { loesen(nachricht) }
                            }
                        }
                    } footer: {
                        Text("Nach links wischen zum Lösen.")
                    }
                }
            }
            .navigationTitle("Angeheftet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func loesen(_ nachricht: CoachNachricht) {
        modell.setzen(.gemerkt, CoachLokal.schluessel(nachricht.text), an: false)
        Haptik.leicht()
    }
}
