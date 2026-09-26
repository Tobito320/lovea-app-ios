import SwiftUI

/// Ziele einrichten oder ändern (Teil 5): Körperdaten, Aktivität, Richtung/Tempo, Makro-Profil,
/// Vorschau der berechneten Werte, optional eigene Werte, Fasten.
struct ErnaehrungZieleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var z: ErnaehrungsZiele
    @State private var gewichtText: String
    @State private var eigeneWerte: Bool

    private var ich: Person { ErnaehrungModell.shared.ich }

    init() {
        let modell = ErnaehrungModell.shared
        let ich = modell.ich
        let start = modell.ziele(ich)
        let kg = modell.gewichtKg(ich) ?? 75
        _z = State(initialValue: start)
        _gewichtText = State(initialValue: ErnaehrungLogik.zahl(kg))
        _eigeneWerte = State(initialValue: start.eingerichtet && start.kcal != ErnaehrungLogik.berechnet(start, kg: kg).kcal)
    }

    /// Eingetragenes neues Gewicht, sonst das gespeicherte, sonst 75 kg als Annahme für die Vorschau.
    private var vorschauKg: Double {
        if let zehntel = GewichtText.zehntel(gewichtText) { return Double(zehntel) / 10 }
        return ErnaehrungModell.shared.gewichtKg(ich) ?? 75
    }

    private var ohneGewicht: Bool { GewichtText.zehntel(gewichtText) == nil && ErnaehrungModell.shared.gewichtKg(ich) == nil }
    private var vorschau: ErnaehrungsZiele { ErnaehrungLogik.berechnet(z, kg: vorschauKg) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Geschlecht", selection: $z.geschlecht) {
                        Text("Mann").tag(0)
                        Text("Frau").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Stepper("Alter: \(z.alter)", value: $z.alter, in: 14...100)
                    Stepper("Größe: \(z.groesseCm) cm", value: $z.groesseCm, in: 120...230)
                }
                gewichtSection
                aktivitaetSection
                Section {
                    Picker("Ziel", selection: $z.richtung) {
                        Text("Abnehmen").tag(0)
                        Text("Halten").tag(1)
                        Text("Zunehmen").tag(2)
                    }
                    .pickerStyle(.segmented)
                    if z.richtung != 1 {
                        Picker("Tempo", selection: $z.tempo) {
                            Text("250 g/Woche").tag(250)
                            Text("500 g/Woche").tag(500)
                            Text("750 g/Woche").tag(750)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Section {
                    Picker("Makro-Profil", selection: $z.makroProfil) {
                        ForEach(ErnaehrungLogik.makroProfile.indices, id: \.self) { i in
                            Text(ErnaehrungLogik.makroProfile[i].name).tag(i)
                        }
                    }
                }
                vorschauSection
                eigeneWerteSection
                Section("Fasten") {
                    Picker("Fastenfenster", selection: $z.fastenStunden) {
                        Text("Aus").tag(0)
                        Text("12:12").tag(12)
                        Text("14:10").tag(14)
                        Text("16:8").tag(16)
                        Text("18:6").tag(18)
                        Text("20:4").tag(20)
                    }
                }
            }
            .navigationTitle("Ziele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { sichern() } }
            }
        }
    }

    private var gewichtSection: some View {
        Section {
            if let aktuell = ErnaehrungModell.shared.gewichtKg(ich) {
                LabeledContent("Aktuelles Gewicht", value: "\(ErnaehrungLogik.zahl(aktuell)) kg")
            }
            TextField("Neues Gewicht in kg", text: $gewichtText)
                .keyboardType(.decimalPad)
                .accessibilityLabel("Neues Gewicht in Kilogramm")
        }
    }

    private var aktivitaetSection: some View {
        Section {
            Picker("Aktivität", selection: $z.aktivitaet) {
                ForEach(ErnaehrungLogik.aktivitaeten.indices, id: \.self) { i in
                    Text(ErnaehrungLogik.aktivitaeten[i].name).tag(i)
                }
            }
        } footer: {
            let i = min(max(z.aktivitaet, 0), ErnaehrungLogik.aktivitaeten.count - 1)
            Text(ErnaehrungLogik.aktivitaeten[i].text)
        }
    }

    private var vorschauSection: some View {
        Section {
            LabeledContent("Kalorien", value: "\(vorschau.kcal) kcal")
            LabeledContent("Protein", value: "\(vorschau.protein) g")
            LabeledContent("Kohlenhydrate", value: "\(vorschau.kohlenhydrate) g")
            LabeledContent("Fett", value: "\(vorschau.fett) g")
        } header: {
            Text("Vorschau")
        } footer: {
            if ohneGewicht { Text("Ohne Gewicht wird mit 75 kg gerechnet.") }
        }
    }

    private var eigeneWerteSection: some View {
        Section {
            Toggle("Eigene Werte", isOn: $eigeneWerte)
            if eigeneWerte {
                LabeledContent("Kalorien") {
                    TextField("kcal", value: $z.kcal, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                }
                LabeledContent("Protein") {
                    TextField("g", value: $z.protein, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                }
                LabeledContent("Kohlenhydrate") {
                    TextField("g", value: $z.kohlenhydrate, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                }
                LabeledContent("Fett") {
                    TextField("g", value: $z.fett, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private func sichern() {
        let neu = eigeneWerte ? z : ErnaehrungLogik.berechnet(z, kg: vorschauKg)
        ErnaehrungModell.shared.zieleSichern(neu)
        if let zehntel = GewichtText.zehntel(gewichtText) {
            HealthModell.shared.setzeHabit(Habit.gewicht.id, datum: Datum.text(Date()), wert: zehntel)
        }
        Haptik.erfolg()
        dismiss()
    }
}
