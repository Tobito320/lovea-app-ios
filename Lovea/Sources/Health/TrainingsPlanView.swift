import SwiftUI

/// A person's plan: the week and the training days. Only the owner edits; the partner reads.
struct TrainingsPlanView: View {
    let person: Person
    @State private var bearbeiten: TrainingsTag?

    private var modell: TrainingModell { TrainingModell.shared }
    private var eigener: Bool { person == Raum.shared.ich }

    var body: some View {
        let plan = modell.plan(person)
        List {
            Section {
                WochenLeiste(plan: plan)
            } header: {
                Text("Woche")
            } footer: {
                Text("Tage ohne Training sind Ruhetage.")
            }
            Section("Trainingstage") {
                if plan.tage.isEmpty { leer }
                ForEach(plan.tage) { tag in
                    Button { bearbeiten = tag } label: { TagZeile(tag: tag) }
                        .buttonStyle(.plain)
                }
                .onDelete(perform: eigener ? loeschenAktion(plan) : nil)
            }
        }
        .navigationTitle(eigener ? "Mein Trainingsplan" : "Plan von \(person.name)")
        .toolbar {
            if eigener {
                ToolbarItem(placement: .primaryAction) {
                    Button("Neuer Tag", systemImage: "plus") {
                        bearbeiten = TrainingsTag(id: UUID().uuidString, name: "", wochentage: [], uebungen: [])
                    }
                }
            }
        }
        .sheet(item: $bearbeiten) { TagEditor(tag: $0, bearbeitbar: eigener) }
    }

    private var leer: some View {
        Text(eigener ? "Noch kein Tag. Leg zum Beispiel \"Push\" oder \"Beine\" an." : "\(person.name) hat noch keinen Plan.")
            .foregroundStyle(.secondary)
    }

    private func loeschenAktion(_ plan: TrainingsPlan) -> (IndexSet) -> Void {
        { loeschen($0, aus: plan) }
    }

    private func loeschen(_ stellen: IndexSet, aus plan: TrainingsPlan) {
        var neu = plan
        neu.tage.remove(atOffsets: stellen)
        modell.planSichern(neu)
        Haptik.leicht()
    }
}

/// Mo to So with the day's name or "Ruhe"; today stands out.
struct WochenLeiste: View {
    let plan: TrainingsPlan
    var heute: Int = Datum.wochentag(Datum.text(Date()))

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { w in spalte(w) }
        }
        .padding(.vertical, 4)
    }

    private func spalte(_ w: Int) -> some View {
        let tag = plan.tage.first { $0.wochentage.contains(w) }
        return VStack(spacing: 4) {
            Text(HabitLogik.wochentagKuerzel[w - 1])
                .font(.caption.weight(w == heute ? .bold : .semibold))
                .foregroundStyle(w == heute ? Color.primary : Color.secondary)
            Text(tag?.name ?? "Ruhe")
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tag == nil ? Color(uiColor: .tertiarySystemFill) : HabitFarbe.mint.farbe.opacity(0.25))
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(TrainingLogik.wochentagName[w - 1]): \(tag?.name ?? "Ruhetag")")
    }
}

/// "Push · Mo, Do" and the exercises in one line.
struct TagZeile: View {
    let tag: TrainingsTag

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(tag.name.isEmpty ? "Ohne Namen" : tag.name).font(.headline)
                Spacer()
                Text(TrainingLogik.wochentageText(tag.wochentage)).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(tag.uebungen.isEmpty ? "Noch keine Übungen" : tag.uebungen.map(\.anzeigeName).joined(separator: " · "))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}

/// One day: name, weekdays, exercises in order. "Sichern" sends the whole plan once.
struct TagEditor: View {
    @State var tag: TrainingsTag
    let bearbeitbar: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var sucheOffen = false
    @State private var sortieren = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("z. B. Push", text: $tag.name) }
                Section("Wochentage") { wochentage }
                uebungen
            }
            .disabled(!bearbeitbar)
            .environment(\.editMode, .constant(sortieren ? .active : .inactive))
            .navigationTitle(tag.name.isEmpty ? "Neuer Tag" : tag.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { leiste }
            .sheet(isPresented: $sucheOffen) {
                UebungsSuche { tag.uebungen.append($0) }
            }
        }
    }

    @ToolbarContentBuilder
    private var leiste: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button(bearbeitbar ? "Abbrechen" : "Fertig") { dismiss() } }
        if bearbeitbar {
            ToolbarItem(placement: .confirmationAction) { Button("Sichern") { sichern() } }
        }
    }

    private var wochentage: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { w in tagKnopf(w) }
        }
    }

    private func tagKnopf(_ w: Int) -> some View {
        let an = tag.wochentage.contains(w)
        return Button {
            if an { tag.wochentage.removeAll { $0 == w } } else { tag.wochentage = (tag.wochentage + [w]).sorted() }
            Haptik.auswahl()
        } label: {
            Text(HabitLogik.wochentagKuerzel[w - 1])
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Circle().fill(an ? Color.accentColor : Color(uiColor: .tertiarySystemFill)))
                .foregroundStyle(an ? Color.white : Color.primary)
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(TrainingLogik.wochentagName[w - 1])
        .accessibilityAddTraits(an ? .isSelected : [])
    }

    private var uebungen: some View {
        Section {
            ForEach($tag.uebungen) { $u in
                NavigationLink { SaetzeEditor(uebung: $u) } label: { planZeile(u) }
            }
            .onMove { tag.uebungen.move(fromOffsets: $0, toOffset: $1) }
            .onDelete { tag.uebungen.remove(atOffsets: $0) }
            if bearbeitbar {
                Button("Übung hinzufügen", systemImage: "plus") { sucheOffen = true }
            }
        } header: {
            HStack {
                Text("Übungen")
                Spacer()
                if bearbeitbar && tag.uebungen.count > 1 {
                    Button(sortieren ? "Fertig" : "Reihenfolge") { sortieren.toggle() }
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
                }
            }
        }
    }

    private func planZeile(_ u: PlanUebung) -> some View {
        HStack(spacing: 12) {
            if u.katalog != nil {
                UebungVorschau(id: u.uebung).frame(width: 44, height: 44).clipShape(.rect(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "dumbbell.fill").frame(width: 44, height: 44).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(u.anzeigeName).lineLimit(2)
                Text(TrainingLogik.saetzeText(u)).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func sichern() {
        var fertig = tag
        fertig.name = fertig.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if fertig.name.isEmpty { fertig.name = "Training" }
        let modell = TrainingModell.shared
        modell.planSichern(TrainingLogik.tagSetzen(modell.plan(Raum.shared.ich ?? .ahmed), fertig))
        Haptik.erfolg()
        dismiss()
    }
}

/// Sets of one plan exercise (or minutes for cardio), with the GIF on top.
struct SaetzeEditor: View {
    @Binding var uebung: PlanUebung

    var body: some View {
        Form {
            if let url = UebungsKatalog.gif(uebung.uebung) {
                Section {
                    AnimiertesGif(url: url, fuellen: false)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .listRowInsets(EdgeInsets())
                }
            }
            if uebung.istCardio {
                Section("Dauer") {
                    Stepper(value: minuten, in: 5...180, step: 5) { Text("\(uebung.minuten ?? 20) min").monospacedDigit() }
                }
            } else {
                Section { SaetzeListe(saetze: $uebung.saetze) } header: { Text("Sätze") } footer: {
                    Text("Failure heißt: bis nichts mehr geht.")
                }
            }
        }
        .navigationTitle(uebung.anzeigeName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var minuten: Binding<Int> {
        Binding { uebung.minuten ?? 20 } set: { uebung.minuten = $0 }
    }
}

/// The set rows with add and swipe-delete. Index-safe bindings: a row being removed may still
/// ask for its index once.
struct SaetzeListe: View {
    @Binding var saetze: [PlanSatz]

    var body: some View {
        ForEach(saetze.indices, id: \.self) { i in SatzZeile(nummer: i + 1, satz: satz(i)) }
            .onDelete { saetze.remove(atOffsets: $0) }
        Button("Satz hinzufügen", systemImage: "plus") {
            saetze.append(saetze.last ?? PlanSatz(wdh: 10, kg: nil, failure: false))
            Haptik.leicht()
        }
    }

    private func satz(_ i: Int) -> Binding<PlanSatz> {
        Binding {
            saetze.indices.contains(i) ? saetze[i] : PlanSatz(wdh: 0, kg: nil, failure: false)
        } set: {
            if saetze.indices.contains(i) { saetze[i] = $0 }
        }
    }
}

/// "Satz 1", reps stepper, kg field, failure toggle.
struct SatzZeile: View {
    let nummer: Int
    @Binding var satz: PlanSatz

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Satz \(nummer)").font(.subheadline.weight(.semibold))
                Spacer()
                Toggle("Failure", isOn: $satz.failure)
                    .toggleStyle(.button)
                    .font(.caption.weight(.semibold))
                    .tint(.orange)
            }
            HStack(spacing: 8) {
                Stepper(value: $satz.wdh, in: 1...100) { Text("\(satz.wdh) Wdh.").monospacedDigit() }
                TextField("kg", value: $satz.kg, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                Text("kg").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
