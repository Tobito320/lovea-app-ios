import SwiftUI

/// Die gemeinsame Wunschliste und das Blatt „Machen wir“. Der Würfel steht in den Date-Ideen (`DatesView`).
struct ListenBlatt: View {
    let wir = WirModell.shared
    @Environment(\.dismiss) private var dismiss
    @State private var neuerEintrag = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(wir.zustand.liste) { eintrag in
                    Button {
                        wir.listeAbhaken(eintrag, geschafft: !eintrag.geschafft)
                    } label: {
                        HStack {
                            Image(systemName: eintrag.geschafft ? "checkmark.circle.fill" : "circle")
                                .accessibilityHidden(true)
                            Text(eintrag.text)
                                .strikethrough(eintrag.geschafft)
                            Spacer()
                        }
                        .foregroundStyle(eintrag.geschafft ? .secondary : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(eintrag.geschafft ? "geschafft" : "offen")
                }
                Section {
                    HStack {
                        TextField("Neuer Wunsch", text: $neuerEintrag)
                        Button("Hinzufügen") {
                            wir.listeHinzufuegen(neuerEintrag)
                            neuerEintrag = ""
                        }
                        .disabled(neuerEintrag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Unsere Liste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }
}

/// „Machen wir" öffnet die Datumswahl mit den Vorschlägen aus `DateVorschlag.naechste` (Z-9.7).
struct MachenWirBlatt: View {
    let text: String
    let wir = WirModell.shared
    @Environment(\.dismiss) private var dismiss

    private var vorschlaege: [String] {
        DateVorschlag.naechste(daten: KalenderModell.shared.zustand.daten, ab: Datum.text(Date()))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Machen wir: \(text)") {
                    if vorschlaege.isEmpty {
                        Text("Keine gemeinsamen freien Abende in den nächsten 14 Tagen gefunden.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(vorschlaege, id: \.self) { tag in
                        Button(Datum.anzeige(tag)) {
                            wir.machenWir(text: text, datum: tag, uhrzeit: nil)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Datum wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
    }
}
