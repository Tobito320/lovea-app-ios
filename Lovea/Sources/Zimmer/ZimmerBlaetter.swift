import SwiftUI

/// What opens when a room object is tapped.
enum ZimmerBlatt: Identifiable {
    case kalender(String)
    case foto(medienId: String, titel: String)
    case pokale, film, ziel
    case info(titel: String, text: String)

    var id: String { "\(self)" }
}

struct ZimmerBlattInhalt: View {
    let blatt: ZimmerBlatt

    var body: some View {
        switch blatt {
        case .kalender(let tag): NavigationStack { TagNeu(tag: tag) }
        case .foto(let medienId, let titel):
            VStack(spacing: 14) {
                ProfilFoto(medienId: medienId).aspectRatio(0.8, contentMode: .fit).clipShape(.rect(cornerRadius: 20))
                Text(titel).font(.headline)
            }
            .padding()
        case .pokale: ZimmerPokaleBlatt()
        case .film: ZimmerFilmBlatt()
        case .ziel: ZimmerZielBlatt()
        case .info(let titel, let text):
            VStack(spacing: 8) {
                Text(titel).font(.title3.bold())
                Text(text).multilineTextAlignment(.center)
            }
            .padding()
            .presentationDetents([.height(180)])
        }
    }
}

private struct ZimmerPokaleBlatt: View {
    var body: some View {
        let pokale = ZimmerPokale.aus(SpieleModell.shared.bilanz)
        NavigationStack {
            List(pokale) { p in
                HStack {
                    Label(p.art.titel, systemImage: p.art.symbol)
                    Spacer()
                    Text("\(Person.ahmed.name) \(p.ahmed) : \(p.annika) \(Person.annika.name)").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .overlay {
                if pokale.isEmpty { ContentUnavailableView("Noch kein Pokal", systemImage: "trophy", description: Text("Gewinnt ein Spiel, dann steht hier der erste.")) }
            }
            .navigationTitle("Pokale")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ZimmerFilmBlatt: View {
    @State private var liste = ZimmerLebenModell.filme()
    @State private var titel = ""
    @State private var serie = false

    private func setzen(_ neu: [ZimmerFilm]) {
        liste = neu
        ZimmerLebenModell.schreiben(ZimmerLebenModell.filmeSchluessel, neu)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Film oder Serie", text: $titel)
                    Toggle("Serie", isOn: $serie)
                    Button("Hinzufügen") {
                        setzen(ZimmerFilme.hinzufuegen(liste, titel: titel, serie: serie))
                        titel = ""
                    }
                    .disabled(titel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Gemeinsam schauen") {
                    ForEach(liste) { f in
                        Button { setzen(ZimmerFilme.umschalten(liste, id: f.id)) } label: {
                            HStack {
                                Image(systemName: f.gesehen ? "checkmark.circle.fill" : "circle")
                                Text(f.titel).strikethrough(f.gesehen)
                                Spacer()
                                Image(systemName: f.serie ? "tv" : "film").foregroundStyle(.secondary)
                            }
                        }
                        .tint(.primary)
                        .swipeActions { Button("Löschen", role: .destructive) { setzen(ZimmerFilme.entfernen(liste, id: f.id)) } }
                    }
                }
            }
            .navigationTitle("Fernseher")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ZimmerZielBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ziel = ZimmerLebenModell.lesen(ZimmerLebenModell.zielSchluessel, als: ZimmerZiel.self)
        ?? ZimmerZiel(titel: "", koffer: false, ziel: 0, gespart: 0)

    var body: some View {
        NavigationStack {
            Form {
                TextField("Wofür sparen wir?", text: $ziel.titel)
                Picker("Form", selection: $ziel.koffer) {
                    Text("Glas").tag(false)
                    Text("Koffer").tag(true)
                }
                .pickerStyle(.segmented)
                TextField("Ziel in €", value: $ziel.ziel, format: .number).keyboardType(.decimalPad)
                Section(footer: Text(ziel.text)) {
                    TextField("Schon gespart in €", value: $ziel.gespart, format: .number).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Unser Ziel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        ZimmerLebenModell.schreiben(ZimmerLebenModell.zielSchluessel, ziel)
                        dismiss()
                    }
                    .disabled(ziel.titel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ziel.ziel <= 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
