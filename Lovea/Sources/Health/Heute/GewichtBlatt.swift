import SwiftUI

/// Gewicht eintragen. Oben der letzte Wert groß mit der Änderung zur Messung davor, dann das Feld (mit dem letzten
/// Wert vorbelegt) mit Plus und Minus in 0,1 kg, unten die Kurve. "78,4" wird als 784 Zehntel-kg gespeichert
/// (`GewichtText`). Akku: kein Timer und kein Netz, Halten wiederholt der Button selbst.
struct GewichtBlatt: View {
    let werte: [String: Int]
    let speichern: (Int) -> Void
    @State private var text: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var fokus: Bool

    init(werte: [String: Int], speichern: @escaping (Int) -> Void) {
        self.werte = werte
        self.speichern = speichern
        _text = State(initialValue: MessLogik.punkte(werte).last.map { GewichtText.feld($0.zehntel) } ?? "")
    }

    private var zehntel: Int? { GewichtText.zehntel(text) }

    var body: some View {
        let punkte = MessLogik.punkte(werte)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let letzter = punkte.last { stand(letzter) }
                    eingabe
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { if text.isEmpty { fokus = true } }
            .navigationTitle("Gewicht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        if let zehntel { speichern(zehntel) }
                        dismiss()
                    }
                    .disabled(zehntel == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func stand(_ letzter: MessPunkt) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(GewichtText.feld(letzter.zehntel)).font(.largeTitle.bold().monospacedDigit())
                Text("kg").font(.title3).foregroundStyle(.secondary)
            }
            if let a = GewichtLogik.aenderung(werte) {
                Text(GewichtText.aenderung(a.zehntel, seit: a.seit)).font(.title3.weight(.medium).monospacedDigit())
            }
            Text(Datum.anzeige(letzter.tag)).font(.subheadline).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var eingabe: some View {
        HStack(spacing: 12) {
            knopf("minus", "Weniger", -1)
            TextField("Gewicht in kg", text: $text)
                .keyboardType(.decimalPad)
                .focused($fokus)
                .multilineTextAlignment(.center)
                .font(.title.bold().monospacedDigit())
                .frame(minHeight: 44)
                .accessibilityLabel("Gewicht in Kilogramm")
            knopf("plus", "Mehr", 1)
        }
    }

    /// 52 pt Tippfläche. `buttonRepeatBehavior`: Halten zählt weiter, ohne eigenen Timer.
    private func knopf(_ symbol: String, _ name: String, _ delta: Int) -> some View {
        Button {
            if let neu = GewichtLogik.schritt(text, delta) {
                text = neu
                Haptik.auswahl()
            }
        } label: {
            Image(systemName: symbol).font(.title2.weight(.semibold)).frame(width: 52, height: 52)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .buttonRepeatBehavior(.enabled)
        .disabled(zehntel == nil)
        .accessibilityLabel("\(name), 0,1 Kilogramm")
    }
}
