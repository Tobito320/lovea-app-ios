import SwiftUI

/// A person's plan: the week and the training days. Only the owner edits; the partner reads.
struct TrainingsPlanView: View {
    let person: Person
    /// Aus Health: öffnet die Gym-Einheit oder den Verlauf im selben Stapel.
    var oeffnen: (HealthZiel) -> Void = { _ in }
    @State private var bearbeiten: TrainingsTag?

    private var modell: TrainingModell { TrainingModell.shared }
    private var eigener: Bool { person == Raum.shared.ich }

    var body: some View {
        let plan = modell.plan(person)
        List {
            if eigener { gymSektion }
            Section {
                WochenLeiste(plan: plan, setzen: eigener ? setzenAktion(plan) : nil)
            } header: {
                Text("Woche")
            } footer: {
                Text(eigener ? "Tipp auf einen Tag: Training oder Ruhetag." : "")
            }
            if eigener { hinweise(plan) }
            Section("Trainingstage") {
                if plan.tage.isEmpty { leer }
                ForEach(plan.tage) { tag in
                    Button { bearbeiten = tag } label: { TagZeile(tag: tag, farbe: TagFarbe.farbe(TagFarbe.index(tag, in: plan))) }
                        .buttonStyle(.plain)
                }
                .onDelete(perform: eigener ? loeschenAktion(plan) : nil)
            }
            if eigener {
                Section {
                    NavigationLink {
                        TrainingsPlanView(person: person.partner)
                    } label: {
                        Label("Plan von \(person.partner.name)", systemImage: "person.2")
                    }
                }
            }
        }
        .navigationTitle(eigener ? "Mein Trainingsplan" : "Plan von \(person.name)")
        .toolbar {
            if eigener {
                ToolbarItem(placement: .primaryAction) {
                    Button("Neuer Tag", systemImage: "plus") { neuerTag() }
                }
            }
        }
        .sheet(item: $bearbeiten) { TagEditor(tag: $0, bearbeitbar: eigener) }
        // Die GIFs des eigenen Plans vorab, damit sie im Gym offline laufen.
        .task(id: plan) { if eigener { await UebungsMedien.vorladen(plan.tage.flatMap(\.uebungen).map(\.uebung)) } }
    }

    /// Einchecken, oder laufend: weiter trainieren und mit einem Tipp auschecken (Ahmed, 27.09.).
    @ViewBuilder
    private var gymSektion: some View {
        Section {
            if let s = modell.laufende(person) {
                Button { oeffnen(.gymSession(s.id)) } label: {
                    Label("Weiter trainieren · seit \(Datum.uhrzeit(s.start))", systemImage: "figure.strengthtraining.traditional")
                }
                Button(role: .destructive) {
                    modell.auschecken(s.id)
                    Haptik.erfolg()
                } label: {
                    Label("Auschecken", systemImage: "door.left.hand.open")
                }
                if s.laeufe.isEmpty {
                    Button("Einchecken rückgängig", systemImage: "arrow.uturn.backward") {
                        modell.loeschen(s)
                        Haptik.leicht()
                    }
                    .foregroundStyle(.secondary)
                }
            } else {
                // Gerade ausgecheckt (letzte 2 h): mit einem Tipp zurück ins Training.
                // Nur solange die Einheit danach noch als laufend gilt (`TrainingLogik.langNach`).
                if let zuletzt = modell.sessions(person).first, let ende = zuletzt.ende,
                   Date().timeIntervalSince(ende) < 2 * 3600, Date().timeIntervalSince(zuletzt.start) < TrainingLogik.langNach {
                    Button {
                        modell.auscheckenRueckgaengig(zuletzt.id)
                        Haptik.erfolg()
                        oeffnen(.gymSession(zuletzt.id))
                    } label: {
                        Label("Ausgecheckt um \(Datum.uhrzeit(ende)) · Rückgängig", systemImage: "arrow.uturn.backward")
                    }
                }
                if let v = modell.vergessene(person) {
                    Button {
                        modell.auschecken(v.id)
                        Haptik.erfolg()
                    } label: {
                        Label("Auschecken vergessen? Jetzt auschecken", systemImage: "exclamationmark.triangle.fill")
                    }
                    .tint(.orange)
                }
                Button {
                    let id = modell.einchecken(tag: modell.heutigerTag(person)?.id)
                    Haptik.erfolg()
                    oeffnen(.gymSession(id))
                } label: {
                    Label("Im Gym einchecken", systemImage: "figure.strengthtraining.traditional")
                        .font(.headline)
                }
            }
            Button { oeffnen(.gymVerlauf) } label: {
                Label("Verlauf", systemImage: "clock.arrow.circlepath")
            }
        }
    }

    @ViewBuilder
    private var leer: some View {
        Text(eigener ? "Noch kein Tag. Leg zum Beispiel \"Push\" oder \"Beine\" an." : "\(person.name) hat noch keinen Plan.")
            .foregroundStyle(.secondary)
        if eigener {
            Button("Ersten Trainingstag anlegen", systemImage: "plus.circle.fill") { neuerTag() }
        }
    }

    private func neuerTag() {
        bearbeiten = TrainingsTag(id: UUID().uuidString, name: "", wochentage: [], uebungen: [])
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

    @ViewBuilder
    private func hinweise(_ plan: TrainingsPlan) -> some View {
        let liste = RuhetagLogik.hinweise(plan)
        if !liste.isEmpty {
            Section("Vorschlag") {
                ForEach(liste) { h in
                    PlanHinweisZeile(hinweis: h) { uebernehmen(h, plan) }
                }
            }
        }
    }

    private func setzenAktion(_ plan: TrainingsPlan) -> (Int, String?) -> Void {
        { w, tag in
            modell.planSichern(RuhetagLogik.setzen(plan, w, tag: tag))
            Haptik.auswahl()
        }
    }

    private func uebernehmen(_ h: PlanHinweis, _ plan: TrainingsPlan) {
        guard let t = h.tausch, t.count == 2 else { return }
        modell.planSichern(RuhetagLogik.tauschen(plan, t[0], t[1]))
        Haptik.erfolg()
    }
}

/// Mo to So: the training day's name, "Ruhe", or an orange "?" while still open. Own plan: tapping
/// a day opens a menu to make it a training day or a rest day.
struct WochenLeiste: View {
    let plan: TrainingsPlan
    var heute: Int = Datum.wochentag(Datum.text(Date()))
    var setzen: ((Int, String?) -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { w in spalte(w) }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func spalte(_ w: Int) -> some View {
        if let setzen {
            Menu {
                menue(w, setzen)
            } label: {
                inhalt(w)
            }
            .accessibilityHint("Training oder Ruhetag festlegen")
        } else {
            inhalt(w)
        }
    }

    @ViewBuilder
    private func menue(_ w: Int, _ aktion: @escaping (Int, String?) -> Void) -> some View {
        ForEach(plan.tage) { t in
            Button(t.name.isEmpty ? "Ohne Namen" : t.name, systemImage: "dumbbell") { aktion(w, t.id) }
        }
        Button("Ruhetag", systemImage: "bed.double") { aktion(w, nil) }
    }

    private func inhalt(_ w: Int) -> some View {
        let art = RuhetagLogik.art(plan, w)
        let form = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return VStack(spacing: 4) {
            Text(HabitLogik.wochentagKuerzel[w - 1])
                .font(.caption.weight(w == heute ? .bold : .semibold))
                .foregroundStyle(w == heute ? Color.primary : Color.secondary)
            Text(titel(art))
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(form.fill(farbe(art)))
                .overlay {
                    if art == .offen { form.strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 1, dash: [3, 2])) }
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(TrainingLogik.wochentagName[w - 1]): \(beschreibung(art))")
    }

    private func titel(_ art: TagArt) -> String {
        switch art {
        case .training(let t): return t.name.isEmpty ? "Training" : t.name
        case .ruhe: return "Ruhe"
        case .offen: return "?"
        }
    }

    private func beschreibung(_ art: TagArt) -> String {
        switch art {
        case .training(let t): return t.name.isEmpty ? "Training" : t.name
        case .ruhe: return "Ruhetag"
        case .offen: return "noch nicht geplant"
        }
    }

    private func farbe(_ art: TagArt) -> Color {
        switch art {
        case .training: return HabitFarbe.mint.farbe.opacity(0.25)
        case .ruhe: return Color(uiColor: .tertiarySystemFill)
        case .offen: return Color.orange.opacity(0.15)
        }
    }
}

/// A rest-day hint with the lightbulb; "Übernehmen" when it carries a swap.
struct PlanHinweisZeile: View {
    let hinweis: PlanHinweis
    var uebernehmen: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(hinweis.text).font(.subheadline)
            } icon: {
                Image(systemName: "lightbulb.fill").foregroundStyle(Color.yellow)
            }
            if hinweis.tausch != nil {
                Button("Übernehmen", action: uebernehmen)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

/// "Push · Mo, Do" and the exercises in one line.
extension TagFarbe {
    static func farbe(_ index: Int) -> Color {
        [Color.blue, .orange, .pink, .teal, .yellow, .purple][min(max(index, 0), anzahl)]
    }
}

struct TagZeile: View {
    let tag: TrainingsTag
    var farbe: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(farbe).frame(width: 12, height: 12)
                Text(tag.name.isEmpty ? "Ohne Namen" : tag.name).font(.headline)
                Spacer()
                Text(tag.wochentage.isEmpty ? "flexibel" : TrainingLogik.wochentageText(tag.wochentage))
                    .font(.subheadline).foregroundStyle(.secondary)
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
    @State private var modus: EditMode = .inactive
    @State private var kopierenOffen = false

    var body: some View {
        NavigationStack {
            Form {
                // Nur Name und Wochentage sperren: `.disabled` auf der ganzen Form sperrt auch das Scrollen
                // (Plan von Annika ließ sich nicht runterscrollen).
                Section("Name") { TextField("z. B. Push", text: $tag.name) }.disabled(!bearbeitbar)
                Section {
                    wochentage
                } header: {
                    Text("Wochentage")
                } footer: {
                    Text("Ohne Wochentag ist der Tag flexibel: an jedem Tag trainierbar, auch als Extra-Tag.")
                }
                .disabled(!bearbeitbar)
                uebungen
            }
            .environment(\.editMode, $modus)
            .navigationTitle(tag.name.isEmpty ? "Neuer Tag" : tag.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { leiste }
            .sheet(isPresented: $kopierenOffen) {
                KopierenBlatt(tage: andereTage) { tag.uebungen += $0 }
            }
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
                NavigationLink {
                    SaetzeEditor(uebung: $u, bearbeitbar: bearbeitbar) { tag.uebungen.removeAll { $0.id == u.id } }
                } label: { planZeile(u) }
                // Eigene Wisch-Aktion statt onDelete: der feste editMode oben schaltet onDelete ab
                // (Übungen ließen sich nicht löschen).
                .swipeActions {
                    if bearbeitbar {
                        Button("Löschen", systemImage: "trash", role: .destructive) { tag.uebungen.removeAll { $0.id == u.id } }
                    }
                }
                .swipeActions(edge: .leading) {
                    if bearbeitbar {
                        Button("Doppeln", systemImage: "plus.square.on.square") { doppeln(u) }.tint(.blue)
                    }
                }
            }
            .onMove(perform: bearbeitbar ? { tag.uebungen.move(fromOffsets: $0, toOffset: $1) } : nil)
            if bearbeitbar {
                Button("Übung hinzufügen", systemImage: "plus") { sucheOffen = true }
                if andereTage.contains(where: { !$0.uebungen.isEmpty }) {
                    Button("Von anderem Tag kopieren", systemImage: "doc.on.doc") { kopierenOffen = true }
                }
            }
        } header: {
            HStack {
                Text("Übungen")
                Spacer()
                if bearbeitbar && tag.uebungen.count > 1 {
                    Button(modus.isEditing ? "Fertig" : "Reihenfolge") {
                        withAnimation { modus = modus.isEditing ? .inactive : .active }
                    }
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
                }
            }
        }
    }

    /// Die anderen Tage des eigenen Plans (Quelle für "Von anderem Tag kopieren").
    private var andereTage: [TrainingsTag] {
        TrainingModell.shared.plan(Raum.shared.ich ?? .ahmed).tage.filter { $0.id != tag.id }
    }

    private func doppeln(_ u: PlanUebung) {
        guard let i = tag.uebungen.firstIndex(where: { $0.id == u.id }) else { return }
        tag.uebungen.insert(contentsOf: TrainingLogik.kopien([u], mitSaetzen: true), at: i + 1)
        Haptik.leicht()
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
    var bearbeitbar = true
    var entfernen: () -> Void = {}

    /// Änderungen erst mit "Fertig" übernehmen, "Abbrechen" verwirft sie (Ahmed, 27.09.).
    @State private var entwurf: PlanUebung
    @State private var variantenOffen = false
    @Environment(\.dismiss) private var dismiss

    init(uebung: Binding<PlanUebung>, bearbeitbar: Bool = true, entfernen: @escaping () -> Void = {}) {
        _uebung = uebung
        self.bearbeitbar = bearbeitbar
        self.entfernen = entfernen
        _entwurf = State(initialValue: uebung.wrappedValue)
    }

    var body: some View {
        Form {
            if entwurf.katalog != nil {
                Section {
                    UebungGif(id: entwurf.uebung)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                }
            }
            Group {
                if entwurf.istCardio {
                    Section("Dauer") {
                        Stepper(value: minuten, in: 5...180, step: 5) { Text("\(entwurf.minuten ?? 20) min").monospacedDigit() }
                    }
                } else {
                    Section { SaetzeListe(saetze: $entwurf.saetze) } header: { Text("Sätze") } footer: {
                        Text("Failure heißt: bis nichts mehr geht.")
                    }
                }
            }
            .disabled(!bearbeitbar)
            if bearbeitbar {
                Section {
                    if let u = entwurf.katalog, !UebungsKatalog.alternativen(zu: u).isEmpty {
                        Button("Andere Variante wählen", systemImage: "arrow.triangle.2.circlepath") { variantenOffen = true }
                    }
                    Button("Übung entfernen", systemImage: "trash", role: .destructive) {
                        entfernen()
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(entwurf.anzeigeName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(bearbeitbar)
        .toolbar {
            if bearbeitbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        uebung = entwurf
                        Haptik.erfolg()
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $variantenOffen) {
            if let u = entwurf.katalog {
                VariantenBlatt(uebung: u) { neu in
                    entwurf.uebung = neu.id
                    entwurf.name = nil
                }
            }
        }
    }

    private var minuten: Binding<Int> {
        Binding { entwurf.minuten ?? 20 } set: { entwurf.minuten = $0 }
    }
}

/// Übungen aus anderen Tagen auswählen (eine, mehrere oder alle eines Tages) und hineinkopieren.
struct KopierenBlatt: View {
    let tage: [TrainingsTag]
    let uebernehmen: ([PlanUebung]) -> Void

    @State private var auswahl: Set<String> = []
    @State private var mitSaetzen = true
    @Environment(\.dismiss) private var dismiss

    private var plan: TrainingsPlan { TrainingModell.shared.plan(Raum.shared.ich ?? .ahmed) }
    private var gewaehlt: [PlanUebung] { tage.flatMap(\.uebungen).filter { auswahl.contains($0.id) } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Sätze und Gewichte mitnehmen", isOn: $mitSaetzen)
                }
                ForEach(tage.filter { !$0.uebungen.isEmpty }) { t in
                    Section {
                        ForEach(t.uebungen) { u in zeile(u) }
                    } header: {
                        kopf(t)
                    }
                }
            }
            .navigationTitle("Von anderem Tag kopieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(auswahl.isEmpty ? "Übernehmen" : "Übernehmen (\(auswahl.count))") {
                        uebernehmen(TrainingLogik.kopien(gewaehlt, mitSaetzen: mitSaetzen))
                        Haptik.erfolg()
                        dismiss()
                    }
                    .disabled(auswahl.isEmpty)
                }
            }
        }
    }

    private func kopf(_ t: TrainingsTag) -> some View {
        let alle = t.uebungen.allSatisfy { auswahl.contains($0.id) }
        return HStack {
            Circle().fill(TagFarbe.farbe(TagFarbe.index(t, in: plan))).frame(width: 10, height: 10)
            Text(t.name.isEmpty ? "Ohne Namen" : t.name)
            Spacer()
            Button(alle ? "Keine" : "Alle") {
                for u in t.uebungen {
                    if alle { auswahl.remove(u.id) } else { auswahl.insert(u.id) }
                }
                Haptik.auswahl()
            }
            .font(.footnote.weight(.semibold))
            .textCase(nil)
        }
    }

    private func zeile(_ u: PlanUebung) -> some View {
        let an = auswahl.contains(u.id)
        return Button {
            if an { auswahl.remove(u.id) } else { auswahl.insert(u.id) }
            Haptik.auswahl()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: an ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(an ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(u.anzeigeName).foregroundStyle(Color.primary)
                    Text(u.istCardio ? "\(u.minuten ?? 20) min" : "\(u.saetze.count) Sätze").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(an ? .isSelected : [])
    }
}

/// "Gefällt mir nicht": andere Übungen für denselben Muskel (sitzend, stehend, Kabel, Maschine …).
struct VariantenBlatt: View {
    let uebung: Uebung
    let waehlen: (Uebung) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(UebungsKatalog.alternativen(zu: uebung)) { u in
                Button {
                    waehlen(u)
                    Haptik.erfolg()
                    dismiss()
                } label: { UebungZeile(uebung: u) }
                .buttonStyle(.plain)
            }
            .navigationTitle("Statt \(uebung.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
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
