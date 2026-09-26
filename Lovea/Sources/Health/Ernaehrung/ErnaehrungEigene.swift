import SwiftUI

/// Eigenes Lebensmittel anlegen oder bearbeiten, Werte pro 100 g/ml.
struct EigenesLebensmittelEditor: View {
    let start: Lebensmittel?
    let fertig: (Lebensmittel) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var marke: String
    @State private var barcodeText: String
    @State private var fluessig: Bool
    @State private var kcal: String
    @State private var protein: String
    @State private var kohlenhydrate: String
    @State private var zucker: String
    @State private var fett: String
    @State private var gesFett: String
    @State private var ballaststoffe: String
    @State private var salz: String
    @State private var portionMenge: String
    @State private var portionName: String
    @State private var packungMenge: String
    @State private var loeschenFragen = false

    init(start: Lebensmittel? = nil, barcode: String? = nil, fertig: @escaping (Lebensmittel) -> Void = { _ in }) {
        self.start = start
        self.fertig = fertig
        _name = State(initialValue: start?.name ?? "")
        _marke = State(initialValue: start?.marke ?? "")
        _barcodeText = State(initialValue: start?.barcode ?? barcode ?? "")
        _fluessig = State(initialValue: start?.fluessig ?? false)
        _kcal = State(initialValue: start.map { ErnaehrungLogik.zahl($0.pro100.kcal) } ?? "")
        _protein = State(initialValue: start.map { ErnaehrungLogik.zahl($0.pro100.protein) } ?? "")
        _kohlenhydrate = State(initialValue: start.map { ErnaehrungLogik.zahl($0.pro100.kohlenhydrate) } ?? "")
        _zucker = State(initialValue: start?.pro100.zucker.map(ErnaehrungLogik.zahl) ?? "")
        _fett = State(initialValue: start.map { ErnaehrungLogik.zahl($0.pro100.fett) } ?? "")
        _gesFett = State(initialValue: start?.pro100.gesFett.map(ErnaehrungLogik.zahl) ?? "")
        _ballaststoffe = State(initialValue: start?.pro100.ballaststoffe.map(ErnaehrungLogik.zahl) ?? "")
        _salz = State(initialValue: start?.pro100.salz.map(ErnaehrungLogik.zahl) ?? "")
        _portionMenge = State(initialValue: start?.portionMenge.map(ErnaehrungLogik.zahl) ?? "")
        _portionName = State(initialValue: start?.portionName ?? "")
        _packungMenge = State(initialValue: start?.packungMenge.map(ErnaehrungLogik.zahl) ?? "")
    }

    private var kannSichern: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && ErnaehrungLogik.eingabe(kcal) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lebensmittel") {
                    TextField("Name", text: $name)
                    TextField("Marke", text: $marke)
                    TextField("Barcode", text: $barcodeText).keyboardType(.numberPad)
                    Toggle("Flüssig (pro 100 ml)", isOn: $fluessig)
                }
                Section("Pro 100 \(fluessig ? "ml" : "g")") {
                    zahlfeld("Kalorien (kcal)", $kcal)
                    zahlfeld("Protein (g)", $protein)
                    zahlfeld("Kohlenhydrate (g)", $kohlenhydrate)
                    zahlfeld("davon Zucker (g)", $zucker)
                    zahlfeld("Fett (g)", $fett)
                    zahlfeld("davon gesättigt (g)", $gesFett)
                    zahlfeld("Ballaststoffe (g)", $ballaststoffe)
                    zahlfeld("Salz (g)", $salz)
                }
                Section("Portion") {
                    zahlfeld("Menge (\(fluessig ? "ml" : "g"))", $portionMenge)
                    TextField("Name (z. B. Scheibe)", text: $portionName)
                }
                Section("Packung") {
                    zahlfeld("Packungsgröße (\(fluessig ? "ml" : "g"))", $packungMenge)
                }
                if start != nil {
                    Section {
                        Button("Löschen", systemImage: "trash", role: .destructive) { loeschenFragen = true }
                    }
                }
            }
            .navigationTitle(start == nil ? "Neues Lebensmittel" : "Lebensmittel bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { sichern() }.disabled(!kannSichern) }
            }
            .confirmationDialog("Lebensmittel löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { loeschen() }
            }
        }
    }

    private func zahlfeld(_ titel: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(titel)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
        }
    }

    private func sichern() {
        guard let kcalWert = ErnaehrungLogik.eingabe(kcal) else { return }
        let werte = Naehrwerte(kcal: kcalWert, protein: ErnaehrungLogik.eingabe(protein) ?? 0,
                               kohlenhydrate: ErnaehrungLogik.eingabe(kohlenhydrate) ?? 0, fett: ErnaehrungLogik.eingabe(fett) ?? 0,
                               zucker: ErnaehrungLogik.eingabe(zucker), ballaststoffe: ErnaehrungLogik.eingabe(ballaststoffe),
                               salz: ErnaehrungLogik.eingabe(salz), gesFett: ErnaehrungLogik.eingabe(gesFett))
        let id = start?.id ?? "eigen-\(UUID().uuidString)"
        let titel = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = Lebensmittel(id: id, name: titel.isEmpty ? "Ohne Namen" : titel,
                             marke: leer(marke), barcode: leer(barcodeText), fluessig: fluessig, pro100: werte,
                             portionMenge: ErnaehrungLogik.eingabe(portionMenge), portionName: leer(portionName),
                             packungMenge: ErnaehrungLogik.eingabe(packungMenge))
        ErnaehrungModell.shared.eigenesSichern(l)
        Haptik.erfolg()
        dismiss()
        fertig(l)
    }

    private func loeschen() {
        if let l = start { ErnaehrungModell.shared.eigenesLoeschen(l) }
        dismiss()
    }

    private func leer(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

/// Eigenes Rezept: Name, Portionen, Zutaten mit Menge/Einheit, Nährwerte pro Portion live.
struct RezeptEditor: View {
    let start: Rezept?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var portionen: Int
    @State private var zutaten: [Zutat]
    @State private var zutatSucheOffen = false
    @State private var mengeFuer: Lebensmittel?
    /// Gewählt in der Suche; das Mengen-Blatt geht erst auf, wenn die Suche ganz zu ist.
    @State private var gewaehlt: Lebensmittel?
    @State private var bearbeiteZutat: Zutat?
    @State private var loeschenFragen = false

    init(start: Rezept? = nil) {
        self.start = start
        _name = State(initialValue: start?.name ?? "")
        _portionen = State(initialValue: start?.portionen ?? 4)
        _zutaten = State(initialValue: start?.zutaten ?? [])
    }

    private var kannSichern: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !zutaten.isEmpty }

    private var naehrwertePortion: Naehrwerte {
        let rezept = Rezept(id: start?.id ?? "neu", name: name, portionen: portionen, zutaten: zutaten, geloescht: nil)
        let lebensmittel = ErnaehrungLogik.alsLebensmittel(rezept)
        return ErnaehrungLogik.naehrwerte(lebensmittel, menge: 1, einheit: .portion)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Stepper("Portionen: \(portionen)", value: $portionen, in: 1...20)
                }
                Section("Zutaten") {
                    ForEach(zutaten) { z in zutatZeile(z) }
                        .onDelete { zutaten.remove(atOffsets: $0) }
                    Button("Zutat hinzufügen", systemImage: "plus") { zutatSucheOffen = true }
                }
                if !zutaten.isEmpty {
                    Section("Pro Portion") { naehrwerteListe }
                }
                if start != nil {
                    Section {
                        Button("Löschen", systemImage: "trash", role: .destructive) { loeschenFragen = true }
                    }
                }
            }
            .navigationTitle(start == nil ? "Neues Rezept" : "Rezept bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { sichern() }.disabled(!kannSichern) }
            }
            .sheet(isPresented: $zutatSucheOffen, onDismiss: {
                mengeFuer = gewaehlt
                gewaehlt = nil
            }) {
                ZutatSucheBlatt { l in gewaehlt = l }
            }
            .sheet(item: $mengeFuer) { l in
                let startMenge = ErnaehrungLogik.startMenge(l)
                ZutatMengeBlatt(lebensmittel: l, menge: startMenge.menge, einheit: startMenge.einheit) { menge, einheit in
                    zutaten.append(Zutat(id: UUID().uuidString, lebensmittel: l, menge: menge, einheit: einheit))
                }
            }
            .sheet(item: $bearbeiteZutat) { z in
                ZutatMengeBlatt(lebensmittel: z.lebensmittel, menge: z.menge, einheit: z.einheit) { menge, einheit in
                    guard let idx = zutaten.firstIndex(where: { $0.id == z.id }) else { return }
                    zutaten[idx].menge = menge
                    zutaten[idx].einheit = einheit
                }
            }
            .confirmationDialog("Rezept löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { loeschen() }
            }
        }
    }

    private func zutatZeile(_ z: Zutat) -> some View {
        Button { bearbeiteZutat = z } label: {
            HStack {
                Text(z.lebensmittel.anzeigeName).foregroundStyle(.primary)
                Spacer()
                Text(ErnaehrungLogik.mengeText(z.menge, z.einheit, z.lebensmittel)).foregroundStyle(.secondary)
            }
        }
    }

    private var naehrwerteListe: some View {
        let n = naehrwertePortion
        return Group {
            LabeledContent("Kalorien", value: "\(Int(n.kcal.rounded())) kcal")
            LabeledContent("Protein", value: "\(ErnaehrungLogik.zahl(n.protein)) g")
            LabeledContent("Kohlenhydrate", value: "\(ErnaehrungLogik.zahl(n.kohlenhydrate)) g")
            LabeledContent("Fett", value: "\(ErnaehrungLogik.zahl(n.fett)) g")
        }
    }

    private func sichern() {
        let id = start?.id ?? UUID().uuidString
        let r = Rezept(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), portionen: portionen,
                       zutaten: zutaten, geloescht: nil)
        ErnaehrungModell.shared.rezeptSichern(r)
        Haptik.erfolg()
        dismiss()
    }

    private func loeschen() {
        if let r = start { ErnaehrungModell.shared.rezeptLoeschen(r) }
        dismiss()
    }
}

/// Menge und Einheit für eine Zutat, neu oder zum Ändern.
private struct ZutatMengeBlatt: View {
    let lebensmittel: Lebensmittel
    let uebernehmen: (Double, Einheit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var einheit: Einheit

    init(lebensmittel: Lebensmittel, menge: Double, einheit: Einheit, uebernehmen: @escaping (Double, Einheit) -> Void) {
        self.lebensmittel = lebensmittel
        self.uebernehmen = uebernehmen
        _text = State(initialValue: ErnaehrungLogik.zahl(menge))
        _einheit = State(initialValue: einheit)
    }

    private var zahl: Double? { ErnaehrungLogik.eingabe(text) }

    var body: some View {
        NavigationStack {
            Form {
                Section(lebensmittel.anzeigeName) {
                    HStack {
                        TextField("Menge", text: $text).keyboardType(.decimalPad)
                        Picker("Einheit", selection: $einheit) {
                            ForEach(ErnaehrungLogik.einheiten(lebensmittel), id: \.self) { e in
                                Text(ErnaehrungLogik.einheitName(e, lebensmittel)).tag(e)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Menge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        if let zahl, zahl > 0 { uebernehmen(zahl, einheit) }
                        dismiss()
                    }
                    .disabled(zahl == nil || zahl == 0)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Zutat wählen: Zuletzt, Eigene, sonst Open-Food-Facts-Suche auf Absenden.
private struct ZutatSucheBlatt: View {
    let gewaehlt: (Lebensmittel) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var offTreffer: [Lebensmittel] = []
    @State private var laedt = false
    @State private var fehler = false

    private var ich: Person { ErnaehrungModell.shared.ich }

    var body: some View {
        NavigationStack {
            List {
                if text.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section("Zuletzt") {
                        ForEach(ErnaehrungModell.shared.zuletzt(ich)) { l in zeile(l) }
                    }
                    Section("Eigene") {
                        ForEach(ErnaehrungModell.shared.eigene) { l in zeile(l) }
                    }
                } else {
                    Section {
                        ForEach(lokal) { l in zeile(l) }
                    }
                    Section {
                        if laedt {
                            ProgressView()
                        } else if fehler {
                            Button("Keine Verbindung. Nochmal versuchen?") { Task { await suchen() } }
                        } else {
                            ForEach(offTreffer) { l in zeile(l) }
                        }
                    }
                }
            }
            .searchable(text: $text, prompt: "Zutat suchen")
            .onSubmit(of: .search) { Task { await suchen() } }
            .navigationTitle("Zutat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
    }

    private var lokal: [Lebensmittel] {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return [] }
        var gesehen: Set<String> = []
        return (ErnaehrungModell.shared.eigene + ErnaehrungModell.shared.zuletzt(ich))
            .filter { $0.name.localizedCaseInsensitiveContains(t) }
            .filter { gesehen.insert($0.id).inserted }
    }

    private func zeile(_ l: Lebensmittel) -> some View {
        Button {
            gewaehlt(l)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(l.name).foregroundStyle(.primary)
                if let marke = l.marke { Text(marke).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    private func suchen() async {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        laedt = true
        fehler = false
        do {
            offTreffer = try await OFFClient.suchen(t)
        } catch {
            fehler = true
        }
        laedt = false
    }
}
