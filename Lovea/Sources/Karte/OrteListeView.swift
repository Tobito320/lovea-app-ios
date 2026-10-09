import SwiftUI
import UIKit

/// Places list (Z-8.4): rename, delete, "melden" (Ankunft/Verlassen/beides/nichts) per place.
/// iOS-Settings style, grouped per person, pushed from `EinstellungenView` (not a sheet from the map).
struct OrteListeView: View {
    private let orte = OrteModell.shared

    var body: some View {
        List {
            if orte.orte.isEmpty {
                ContentUnavailableView("Keine Orte", systemImage: "mappin.slash", description: Text("Vorschläge erscheinen automatisch auf der Karte."))
            } else {
                ForEach(Person.allCases, id: \.self) { person in
                    let orteVonPerson = orte.orte.filter { $0.person == person }
                    if !orteVonPerson.isEmpty {
                        Section(person.name) {
                            ForEach(orteVonPerson) { ort in
                                OrtZeile(ort: ort)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Orte")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Text("Melden schickt eine stille Nachricht, wenn jemand an einem Ort ankommt oder ihn verlässt.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
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
        HStack(spacing: 12) {
            Image(systemName: OrteKategorien.symbol(ort.kategorie))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            TextField("Name", text: $name)
                .focused($bearbeitet)
                .onSubmit { OrteModell.shared.umbenennen(ort, name: name) }
                .onChange(of: bearbeitet) { _, aktiv in
                    if !aktiv, name != ort.name, !name.isEmpty { OrteModell.shared.umbenennen(ort, name: name) }
                }
            Spacer()
            Menu {
                Picker("Melden", selection: Binding(
                    get: { ort.melden },
                    set: { OrteModell.shared.meldenSetzen(ort, $0) }
                )) {
                    Text("Beides").tag("beides")
                    Text("Nur Ankunft").tag("ankunft")
                    Text("Nur Verlassen").tag("verlassen")
                    Text("Nichts").tag("nichts")
                }
            } label: {
                Text(meldenTitel)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions {
            Button("Löschen", role: .destructive) { OrteModell.shared.loeschen(ort) }
            Button("Melden") { meldenPerMail() }
                .tint(.orange)
        }
    }

    private var meldenTitel: String {
        switch ort.melden {
        case "ankunft": "Nur Ankunft"
        case "verlassen": "Nur Verlassen"
        case "nichts": "Nichts"
        default: "Beides"
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
