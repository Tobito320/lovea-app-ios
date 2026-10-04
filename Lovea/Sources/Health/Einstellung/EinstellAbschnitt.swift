import SwiftUI

/// Die eine Einhänge-Stelle für `WorkoutUebungView`: "So geht's" (wenn es einen Hinweis gibt) und
/// "Meine Einstellung" mit Blatt zum Ändern.
struct EinstellAbschnitt: View {
    let person: Person
    let uebung: PlanUebung
    @State private var blatt = false
    private var gedaechtnis: EinstellGedaechtnis { .shared }
    private var studio: GymStudio { StudioGedaechtnis.shared.studio(person) }
    private var schluessel: String { EinstellGedaechtnis.uebungsSchluessel(uebung) }

    var body: some View {
        Section {
            if let h = EinstellHinweise.finden(uebung) { SoGehtsKarte(hinweis: h, studio: studio) }
            MeineEinstellungKarte(werte: gedaechtnis.werte(person, studio, uebung: schluessel), studio: studio) { blatt = true }
                .sheet(isPresented: $blatt) {
                    EinstellBlatt(titel: uebung.anzeigeName, studio: studio, start: gedaechtnis.werte(person, studio, uebung: schluessel) ?? EinstellWerte()) {
                        gedaechtnis.setzen($0, person, studio, uebung: schluessel)
                    }
                    .presentationDetents([.medium])
                }
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}

/// Eingabe: drei Zähler (leer = nicht gesetzt) und eine freie Notiz.
struct EinstellBlatt: View {
    let titel: String
    let studio: GymStudio
    let speichern: (EinstellWerte) -> Void
    @State private var werte: EinstellWerte
    @Environment(\.dismiss) private var dismiss

    init(titel: String, studio: GymStudio, start: EinstellWerte, speichern: @escaping (EinstellWerte) -> Void) {
        self.titel = titel
        self.studio = studio
        self.speichern = speichern
        _werte = State(initialValue: start)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(studio.name) {
                    zaehler("Bankstufe", $werte.bankstufe)
                    zaehler("Sitzhöhe", $werte.sitzhoehe)
                    zaehler("Polster", $werte.polster)
                    TextField("Notiz", text: $werte.notiz, axis: .vertical)
                }
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { speichern(werte); dismiss() } }
            }
        }
    }

    private func zaehler(_ titel: String, _ wert: Binding<Int?>) -> some View {
        HStack {
            Text(titel)
            Spacer()
            if let v = wert.wrappedValue {
                Stepper("\(v)", value: Binding(get: { v }, set: { wert.wrappedValue = max(0, $0) }), in: 0...99).fixedSize()
                Button { wert.wrappedValue = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain)
            } else {
                Button("Setzen") { wert.wrappedValue = 1 }.buttonStyle(.bordered)
            }
        }
    }
}
