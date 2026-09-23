import SwiftUI

/// Z-9.5: „Termin anlegen" — sendet `termin.setzen`.
struct TerminEditor: View {
    let datum: String
    @Environment(\.dismiss) private var dismiss

    @State private var titel = ""
    @State private var typ = "sonstiges"
    @State private var fuer: Set<Person> = [Raum.shared.ich ?? .ahmed]
    @State private var hatZeit = false
    @State private var start = Date()
    @State private var ende = Date()

    private static let typen = ["schule", "arbeit", "fahrschule", "sonstiges"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Was") {
                    TextField("Titel", text: $titel)
                    Picker("Art", selection: $typ) {
                        ForEach(Self.typen, id: \.self) { Text($0.capitalized) }
                    }
                }
                Section("Für") {
                    ForEach(Person.allCases, id: \.self) { person in
                        Toggle(person.name, isOn: Binding(
                            get: { fuer.contains(person) },
                            set: { an in if an { fuer.insert(person) } else { fuer.remove(person) } }
                        ))
                    }
                }
                Section("Uhrzeit") {
                    Toggle("Mit Uhrzeit", isOn: $hatZeit)
                    if hatZeit {
                        DatePicker("Von", selection: $start, displayedComponents: .hourAndMinute)
                        DatePicker("Bis", selection: $ende, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle("Termin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { sichern() }
                        .disabled(titel.trimmingCharacters(in: .whitespaces).isEmpty || fuer.isEmpty)
                }
            }
        }
    }

    private func sichern() {
        let termin = Termin(
            id: UUID().uuidString,
            fuer: fuer.map(\.rawValue),
            titel: titel,
            typ: typ,
            datum: datum,
            start: hatZeit ? Self.uhrzeitText(start) : nil,
            ende: hatZeit ? Self.uhrzeitText(ende) : nil
        )
        Raum.shared.senden("termin.setzen", termin)
        dismiss()
    }

    static func uhrzeitText(_ datum: Date) -> String {
        let komponenten = Datum.kalender.dateComponents([.hour, .minute], from: datum)
        return String(format: "%02d:%02d", komponenten.hour ?? 0, komponenten.minute ?? 0)
    }
}

/// Z-9.5: „Ausnahme setzen" (krank, Urlaub, frei, verschoben) — sendet `ausnahme.setzen`.
struct AusnahmeEditor: View {
    let datum: String
    @Environment(\.dismiss) private var dismiss

    @State private var person = Raum.shared.ich ?? .ahmed
    @State private var status = "krank"
    @State private var bisDatum = false
    @State private var bis: Date
    @State private var hatZeit = false
    @State private var start = Date()
    @State private var ende = Date()

    init(datum: String) {
        self.datum = datum
        _bis = State(initialValue: Datum.datum(datum))
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Für", selection: $person) {
                    ForEach(Person.allCases, id: \.self) { Text($0.name).tag($0) }
                }
                Picker("Status", selection: $status) {
                    Text("Krank").tag("krank")
                    Text("Urlaub").tag("urlaub")
                    Text("Frei").tag("frei")
                    Text("Verschoben").tag("verschoben")
                }
                if status == "urlaub" {
                    Toggle("Bis anderes Datum", isOn: $bisDatum)
                    if bisDatum {
                        DatePicker("Bis", selection: $bis, in: Datum.datum(datum)..., displayedComponents: .date)
                    }
                }
                if status == "verschoben" {
                    Toggle("Neue Uhrzeit", isOn: $hatZeit)
                    if hatZeit {
                        DatePicker("Von", selection: $start, displayedComponents: .hourAndMinute)
                        DatePicker("Bis", selection: $ende, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle("Ausnahme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { sichern() } }
            }
        }
    }

    private func sichern() {
        let ausnahme = Ausnahme(
            person: person.rawValue,
            datum: datum,
            musterId: nil,
            status: status,
            bisDatum: (status == "urlaub" && bisDatum) ? Datum.text(bis) : nil,
            start: (status == "verschoben" && hatZeit) ? TerminEditor.uhrzeitText(start) : nil,
            ende: (status == "verschoben" && hatZeit) ? TerminEditor.uhrzeitText(ende) : nil
        )
        Raum.shared.senden("ausnahme.setzen", ausnahme)
        dismiss()
    }
}
