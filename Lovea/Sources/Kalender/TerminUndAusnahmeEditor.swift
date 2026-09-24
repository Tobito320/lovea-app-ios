import SwiftUI

/// Z-9.5 / Z-42.2: Termin anlegen oder bearbeiten. Bearbeiten sendet `termin.setzen` mit derselben
/// `id`; die Faltung ersetzt den alten Termin, es entsteht kein Doppel.
struct TerminEditor: View {
    let bestehend: Termin?
    @Environment(\.dismiss) private var dismiss

    @State private var titel: String
    @State private var typ: String
    @State private var fuer: Set<Person>
    @State private var tag: Date
    @State private var start: String?
    @State private var ende: String?

    private static let typen = ["schule", "arbeit", "fahrschule", "sonstiges"]

    init(datum: String, termin: Termin? = nil) {
        bestehend = termin
        _titel = State(initialValue: termin?.titel ?? "")
        _typ = State(initialValue: termin?.typ ?? "sonstiges")
        _fuer = State(initialValue: termin.map { Set($0.fuer.compactMap(Person.init(rawValue:))) } ?? [Raum.shared.ich ?? .ahmed])
        _tag = State(initialValue: Datum.datum(termin?.datum ?? datum))
        _start = State(initialValue: termin?.start)
        _ende = State(initialValue: termin?.ende)
    }

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
                Section("Wann") {
                    DatePicker("Datum", selection: $tag, displayedComponents: .date)
                        .environment(\.timeZone, Datum.kalender.timeZone)
                    ZeitWahl(datum: Datum.text(tag), start: $start, ende: $ende, ohneZeit: "Ganztägig")
                }
            }
            .navigationTitle(bestehend == nil ? "Neuer Termin" : "Termin bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: sichern)
                        .disabled(titel.trimmingCharacters(in: .whitespaces).isEmpty || fuer.isEmpty)
                }
            }
        }
    }

    private func sichern() {
        let termin = Termin(
            id: bestehend?.id ?? UUID().uuidString,
            fuer: Person.allCases.filter(fuer.contains).map(\.rawValue),
            titel: titel.trimmingCharacters(in: .whitespaces),
            typ: typ,
            datum: Datum.text(tag),
            start: start,
            ende: start == nil ? nil : ende
        )
        Raum.shared.senden("termin.setzen", termin)
        Haptik.erfolg()
        dismiss()
    }
}

/// Z-9.5 / Z-42.2: Ausnahme setzen oder ändern (krank, Urlaub, frei, verschoben). Ändern behält den
/// Schlüssel (Person, Datum, Muster); wechselt die Person, wird die alte Ausnahme mit
/// `ausnahme.loeschen` zurückgenommen.
struct AusnahmeEditor: View {
    let datum: String
    let bestehend: Ausnahme?
    @Environment(\.dismiss) private var dismiss

    @State private var person: Person
    @State private var status: String
    @State private var bisDatum: Bool
    @State private var bis: Date
    @State private var start: String?
    @State private var ende: String?

    init(datum: String, ausnahme: Ausnahme? = nil) {
        let tag = ausnahme?.datum ?? datum
        self.datum = tag
        bestehend = ausnahme
        _person = State(initialValue: ausnahme.flatMap { Person(rawValue: $0.person) } ?? Raum.shared.ich ?? .ahmed)
        _status = State(initialValue: ausnahme?.status ?? "krank")
        _bisDatum = State(initialValue: ausnahme?.bisDatum != nil)
        _bis = State(initialValue: Datum.datum(ausnahme?.bisDatum ?? tag))
        _start = State(initialValue: ausnahme?.start)
        _ende = State(initialValue: ausnahme?.ende)
    }

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Ab", value: Datum.anzeige(datum))
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
                            .environment(\.timeZone, Datum.kalender.timeZone)
                    }
                }
                if status == "verschoben" {
                    ZeitWahl(datum: datum, start: $start, ende: $ende, ohneZeit: "Ohne neue Uhrzeit")
                }
            }
            .navigationTitle(bestehend == nil ? "Ausnahme" : "Ausnahme ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern", action: sichern) }
            }
        }
    }

    private func sichern() {
        let verschoben = status == "verschoben"
        let neu = Ausnahme(
            person: person.rawValue,
            datum: datum,
            musterId: bestehend?.musterId,
            status: status,
            bisDatum: (status == "urlaub" && bisDatum) ? Datum.text(bis) : nil,
            start: verschoben ? start : nil,
            ende: (verschoben && start != nil) ? ende : nil
        )
        if let alt = bestehend, AusnahmeSchluessel(alt) != AusnahmeSchluessel(neu) {
            Raum.shared.senden("ausnahme.loeschen", AusnahmeSchluessel(alt))
        }
        Raum.shared.senden("ausnahme.setzen", neu)
        Haptik.erfolg()
        dismiss()
    }
}

/// Arbeitszeit für einen Tag: von–bis, darunter die Netto-Zeit (30 min Pause gehen immer ab).
/// Speichert als Ausnahme „verschoben" auf genau diesen Arbeits-Block.
struct ArbeitszeitBlatt: View {
    let datum: String
    let block: Block
    @Environment(\.dismiss) private var dismiss
    @State private var von: Date
    @State private var bis: Date

    init(datum: String, block: Block) {
        self.datum = datum
        self.block = block
        let tag = Datum.datum(datum)
        func zeit(_ hhmm: String?, _ standard: Int) -> Date { tag.addingTimeInterval(Double((Datum.minuten(hhmm) ?? standard) * 60)) }
        _von = State(initialValue: zeit(block.start, 8 * 60))
        _bis = State(initialValue: zeit(block.ende, 16 * 60 + 30))
    }

    private var probe: Block { Block(titel: "", typ: "arbeit", start: Datum.uhrzeit(von), ende: Datum.uhrzeit(bis), status: "normal", quelle: "muster") }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Von", selection: $von, displayedComponents: .hourAndMinute)
                DatePicker("Bis", selection: $bis, displayedComponents: .hourAndMinute)
                if let netto = probe.arbeitNetto {
                    LabeledContent("Arbeitszeit", value: "\(netto / 60):\(String(format: "%02d", netto % 60)) h")
                        .font(.headline)
                    LabeledContent("Pause", value: "30 min")
                } else {
                    Text("Ende muss nach dem Beginn liegen").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Arbeitszeit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { sichern() }.disabled(probe.arbeitNetto == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func sichern() {
        guard let ich = Raum.shared.ich else { return }
        Raum.shared.senden("ausnahme.setzen", Ausnahme(
            person: ich.rawValue, datum: datum, musterId: block.musterId, status: "verschoben",
            bisDatum: nil, start: Datum.uhrzeit(von), ende: Datum.uhrzeit(bis)
        ))
        Haptik.erfolg()
        dismiss()
    }
}
