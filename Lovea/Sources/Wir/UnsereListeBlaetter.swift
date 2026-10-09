import SwiftUI

/// Das Blatt „Machen wir“ der Date-Ideen. Die alte Wunschliste lebt jetzt in den Date-Ideen und Notizen (`WirMigration`).
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
