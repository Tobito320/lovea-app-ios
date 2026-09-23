import SwiftUI
import UIKit

/// Places list (Z-8.4): rename, delete, "melden" (Ankunft/Verlassen/beides/nichts) per place.
struct OrteListeView: View {
    @Environment(\.dismiss) private var dismiss
    private let orte = OrteModell.shared

    var body: some View {
        NavigationStack {
            List {
                if orte.orte.isEmpty {
                    ContentUnavailableView("Keine Orte", systemImage: "mappin.slash", description: Text("Vorschläge erscheinen automatisch auf der Karte."))
                } else {
                    ForEach(orte.orte) { ort in
                        OrtZeile(ort: ort)
                    }
                }
            }
            .navigationTitle("Orte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
    }
}

private struct OrtZeile: View {
    let ort: Ort
    @State private var name: String
    @FocusState private var bearbeitet: Bool

    init(ort: Ort) {
        self.ort = ort
        _name = State(initialValue: ort.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Name", text: $name)
                .focused($bearbeitet)
                .font(.headline)
                .onSubmit { OrteModell.shared.umbenennen(ort, name: name) }
                .onChange(of: bearbeitet) { _, aktiv in
                    if !aktiv, name != ort.name, !name.isEmpty { OrteModell.shared.umbenennen(ort, name: name) }
                }
            Picker("Melden", selection: Binding(
                get: { ort.melden },
                set: { OrteModell.shared.meldenSetzen(ort, $0) }
            )) {
                Text("Beides").tag("beides")
                Text("Nur Ankunft").tag("ankunft")
                Text("Nur Verlassen").tag("verlassen")
                Text("Nichts").tag("nichts")
            }
            .pickerStyle(.menu)
            .font(.subheadline)
        }
        .swipeActions {
            Button("Löschen", role: .destructive) { OrteModell.shared.loeschen(ort) }
            Button("Melden") { meldenPerMail() }
                .tint(.orange)
        }
    }

    /// "Melden" per Ort (Z-8.4): ein falsch erkannter Ort geht als Feedback per Mail raus,
    /// es gibt keinen eigenen Melde-Server in diesem Block.
    private func meldenPerMail() {
        let name = ort.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ort.name
        guard let url = URL(string: "mailto:ahmedhdplay12345@gmail.com?subject=Lovea%20Ort%20melden&body=\(name)") else { return }
        UIApplication.shared.open(url)
    }
}
