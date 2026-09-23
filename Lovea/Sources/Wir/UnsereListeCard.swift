import SwiftUI

/// Spec 8.1 Nr. 6 / 8.5: gemeinsame Wunschliste mit „geschafft" und der Date-Würfel (Liste +
/// die 40 Ideen der Web-App, meidet die letzten 5). „Machen wir" trägt ein Treffen ein.
struct UnsereListeCard: View {
    let wir = WirModell.shared
    @State private var gewuerfelt: WirModell.WuerfelEintrag?
    @State private var wuerfelDreht = false
    @State private var zeigtMachenWir = false
    @State private var zeigtListe = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Unsere Liste")
                    .font(.headline)
                Spacer()
                Button("Alle ansehen") { zeigtListe = true }
                    .font(.caption)
            }

            if let gewuerfelt {
                Text(gewuerfelt.text)
                    .font(.subheadline.weight(.medium))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.loveaRose.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 10) {
                Button {
                    wuerfeln()
                } label: {
                    Label("Würfeln", systemImage: "die.face.5.fill")
                        .rotationEffect(.degrees(wuerfelDreht ? 360 : 0))
                }
                .buttonStyle(.bordered)

                if gewuerfelt != nil {
                    Button("Machen wir") { zeigtMachenWir = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.loveaRose)
                }
            }
            .frame(minHeight: 44)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $zeigtMachenWir) {
            if let gewuerfelt { MachenWirBlatt(text: gewuerfelt.text) }
        }
        .sheet(isPresented: $zeigtListe) { ListenBlatt() }
    }

    private func wuerfeln() {
        withAnimation(.easeInOut(duration: 0.4)) { wuerfelDreht.toggle() }
        gewuerfelt = wir.wuerfeln()
    }
}

private struct ListenBlatt: View {
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
                            Text(eintrag.text)
                                .strikethrough(eintrag.geschafft)
                            Spacer()
                        }
                        .foregroundStyle(eintrag.geschafft ? .secondary : .primary)
                    }
                    .buttonStyle(.plain)
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
private struct MachenWirBlatt: View {
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
                        Button(tag) {
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
