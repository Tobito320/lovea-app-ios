import SwiftUI

/// Körperwerte eines Tages eintragen: Gewicht (Gewicht-Habit) und weitere Werte (`koerper.setzen`).
/// Einmal pro Woche reicht, wie YAZIO es empfiehlt; leere Felder bleiben unverändert.
struct KoerperwerteBlatt: View {
    let tag: String

    @Environment(\.dismiss) private var dismiss
    @State private var gewicht: String
    @State private var werte: [KoerperArt: String]

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }

    init(tag: String) {
        self.tag = tag
        let modell = ErnaehrungModell.shared
        let ich = modell.ich
        let g = modell.gewicht(ich, bis: tag).flatMap { $0.datum == tag ? $0.zehntel : nil }
        _gewicht = State(initialValue: g.map { ErnaehrungLogik.zahl(Double($0) / 10) } ?? "")
        var start: [KoerperArt: String] = [:]
        for art in KoerperArt.allCases {
            if let w = modell.koerperwert(ich, art, bis: tag), w.datum == tag { start[art] = ErnaehrungLogik.zahl(w.wert) }
        }
        _werte = State(initialValue: start)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    feld("Gewicht", einheit: "kg", text: $gewicht)
                } footer: {
                    Text("Am besten einmal pro Woche, am selben Tag und zur gleichen Uhrzeit.")
                }
                Section("Weitere Körperwerte") {
                    ForEach(KoerperArt.allCases) { art in
                        feld(art.name, einheit: art.einheit, text: binding(art))
                    }
                }
            }
            .fontDesign(.rounded)
            .navigationTitle(tagTitel(tag))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichern() } }
            }
        }
        .presentationDetents([.large])
    }

    private func binding(_ art: KoerperArt) -> Binding<String> {
        Binding(get: { werte[art] ?? "" }, set: { werte[art] = $0 })
    }

    private func feld(_ titel: String, einheit: String, text: Binding<String>) -> some View {
        HStack {
            Text(titel)
            Spacer()
            TextField("–", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(einheit).foregroundStyle(.secondary).frame(width: 28, alignment: .leading)
        }
    }

    private func speichern() {
        if let zehntel = GewichtText.zehntel(gewicht) { modell.gewichtSetzen(zehntel: zehntel, datum: tag) }
        for art in KoerperArt.allCases {
            guard let text = werte[art], let wert = ErnaehrungLogik.eingabe(text), wert > 0 else { continue }
            modell.koerperwertSetzen(art, wert, datum: tag)
        }
        Haptik.erfolg()
        dismiss()
    }
}
