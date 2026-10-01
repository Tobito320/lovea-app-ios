import SwiftUI

// MARK: - Health card

/// What the training card shows; built by `TrainingKarte`, fixed in the render board.
struct TrainingKartenStand {
    var heute: TrainingsTag? = nil
    var laufend: GymSession? = nil
    var laufendTag: TrainingsTag? = nil
    var vergessen: GymSession? = nil
    var planLeer: Bool
    var heuteRuhe = false
    var planHinweis: String? = nil
    var partner: String? = nil
    var jetzt: Date
}

struct TrainingKartenAktionen {
    var einchecken: () -> Void = {}
    var oeffnen: (GymSession) -> Void = { _ in }
    var plan: () -> Void = {}
    var verlauf: () -> Void = {}
    var endeEintragen: (GymSession) -> Void = { _ in }
    var jetztAuschecken: (GymSession) -> Void = { _ in }
}

/// Pure card body (render board).
struct TrainingKarteInhalt: View {
    let stand: TrainingKartenStand
    var aktionen = TrainingKartenAktionen()

    private static let gruen = HabitFarbe.mint.farbe

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            kopf
            if let s = stand.laufend {
                laufend(s)
            } else {
                if let s = stand.vergessen { vergessen(s) }
                bereit
            }
            if let text = stand.partner {
                Label(text, systemImage: "person.2.fill").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .healthKarte(Self.gruen)
    }

    private var kopf: some View {
        HStack(spacing: 0) {
            Label("Training", systemImage: "dumbbell.fill")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Spacer()
            symbolKnopf("clock.arrow.circlepath", "Verlauf", aktionen.verlauf)
        }
    }

    private func symbolKnopf(_ symbol: String, _ titel: String, _ aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol).font(.body.weight(.semibold)).frame(width: 44, height: 44)
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(titel)
    }

    private var bereit: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(heuteText).font(.headline)
            if let t = stand.heute, !t.uebungen.isEmpty {
                Text(t.uebungen.map(\.anzeigeName).joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let hinweis = stand.planHinweis {
                Button(action: aktionen.plan) {
                    Label {
                        Text(hinweis).font(.footnote).multilineTextAlignment(.leading)
                    } icon: {
                        Image(systemName: "lightbulb.fill").foregroundStyle(Color.yellow)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.federnd)
                .foregroundStyle(Color.primary)
                .accessibilityHint("Öffnet den Trainingsplan")
            }
            Button(action: aktionen.plan) {
                Label(stand.planLeer ? "Trainingsplan anlegen" : "Trainingsplan ansehen", systemImage: "list.bullet.clipboard")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(Self.gruen)
            Button(action: aktionen.einchecken) {
                Label("Training starten", systemImage: "figure.strengthtraining.traditional")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Self.gruen)
        }
    }

    private var heuteText: String {
        if stand.planLeer { return "Noch kein Trainingsplan" }
        guard let t = stand.heute else { return stand.heuteRuhe ? "Heute ist Ruhetag" : "Heute ist noch nicht geplant" }
        return "Heute: \(t.name) · \(t.uebungen.count) Übungen"
    }

    private func laufend(_ s: GymSession) -> some View {
        let tag = stand.laufendTag
        let fertig = tag?.uebungen.filter { s.erledigt($0.id) }.count ?? 0
        let jetztName = s.aktiv.flatMap { a in tag?.uebungen.first { $0.id == a.plan }?.anzeigeName }
        return Button { aktionen.oeffnen(s) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Im Gym seit \(Datum.uhrzeit(s.start))").font(.headline)
                    Spacer()
                    Text(TrainingLogik.dauerText(stand.jetzt.timeIntervalSince(s.start)))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let tag {
                    Text("\(tag.name) · \(fertig) von \(tag.uebungen.count) fertig").font(.subheadline).foregroundStyle(.secondary)
                }
                if let jetztName {
                    Text("Jetzt: \(jetztName)").font(.subheadline.weight(.semibold)).foregroundStyle(Self.gruen)
                }
                HStack {
                    Text("Weiter trainieren").font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.federnd)
    }

    private func vergessen(_ s: GymSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Auschecken vergessen?", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("Eingecheckt \(TrainingLogik.tagText(s.start, jetzt: stand.jetzt)) um \(Datum.uhrzeit(s.start)), danach nicht ausgecheckt.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Endzeit eintragen") { aktionen.endeEintragen(s) }.buttonStyle(.borderedProminent)
                Button("Jetzt auschecken") { aktionen.jetztAuschecken(s) }.buttonStyle(.bordered)
            }
            .tint(.orange)
        }
    }
}

// MARK: - Times and history

/// Correct check-in and checkout later, or delete a session that was a mistake.
struct ZeitenBlatt: View {
    let session: GymSession

    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var ende: Date
    @State private var loeschenFrage = false

    init(session: GymSession) {
        self.session = session
        _start = State(initialValue: session.start)
        _ende = State(initialValue: session.ende ?? min(Date(), session.start.addingTimeInterval(90 * 60)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Eingecheckt", selection: $start, in: ...Date())
                    DatePicker("Ausgecheckt", selection: $ende, in: start...max(start, Date()))
                    LabeledContent("Dauer", value: TrainingLogik.dauerText(max(0, ende.timeIntervalSince(start))))
                }
                Section {
                    Button("Einheit löschen", role: .destructive) { loeschenFrage = true }
                }
            }
            .navigationTitle(Datum.anzeige(Datum.text(session.start)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { sichern() } }
            }
            .confirmationDialog("Einheit löschen?", isPresented: $loeschenFrage, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    TrainingModell.shared.loeschen(session)
                    Haptik.warnung()
                    dismiss()
                }
            }
        }
    }

    private func sichern() {
        TrainingModell.shared.zeitenAendern(session, start: start, ende: max(ende, start))
        Haptik.erfolg()
        dismiss()
    }
}

/// Nur die Startzeit eines laufenden Trainings ändern ("ich habe schon vor 20 Minuten angefangen").
/// Sendet nur den Check-in neu, das Training läuft weiter (`zeitenAendern` ohne Ende).
struct StartzeitBlatt: View {
    let session: GymSession

    @Environment(\.dismiss) private var dismiss
    @State private var start: Date

    init(session: GymSession) {
        self.session = session
        _start = State(initialValue: session.start)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Gestartet", selection: $start, in: min(session.start, TrainingLogik.fruehesterStart(jetzt: Date()))...Date())
                } footer: {
                    Text("Das Training läuft weiter. Nur die Startzeit ändert sich, höchstens drei Stunden zurück.")
                }
            }
            .navigationTitle("Startzeit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        TrainingModell.shared.zeitenAendern(session, start: start, ende: nil)
                        Haptik.erfolg()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Welche Einheit von wem der Verlauf öffnet.
struct GymVerlaufZiel: Hashable {
    var person: Person
    var session: String
}

/// Vergangene Einheiten, neueste zuerst: die eigenen und die des Partners (nur lesen). Tipp öffnet
/// die Einheit mit allen Sätzen, das Plus trägt ein Training von Hand nach.
struct GymVerlaufView: View {
    @State private var person: Person?
    @State private var offen: GymVerlaufZiel?
    @State private var nachtragenOffen = false
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        let modell = TrainingModell.shared
        let wer = person ?? ich
        let sessions = modell.sessions(wer)
        List {
            Picker("Wessen Verlauf", selection: Binding { wer } set: { person = $0 }) {
                Text("Ich").tag(ich)
                Text(ich.partner.name).tag(ich.partner)
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)
            if !sessions.isEmpty {
                let heute = Datum.text(Date())
                HStack(spacing: 28) {
                    kennzahl("Diese Woche", "\(TrainingLogik.dieseWoche(sessions, heute: heute))")
                    kennzahl("Serie", serieText(TrainingLogik.serieWochen(sessions, heute: heute)))
                    kennzahl("Gesamt", "\(sessions.count)")
                }
                .listRowSeparator(.hidden)
                let trainingstage = Set(sessions.map { Datum.text($0.start) })
                MonatsPager { zurueck in
                    GymMonat(tage: trainingstage, heute: heute, monateZurueck: zurueck).padding(.horizontal, 4)
                }
                .listRowSeparator(.hidden)
            }
            if sessions.isEmpty {
                Text(wer == ich ? "Noch keine Einheit. Starte ein Training, dann steht es hier." : "\(wer.name) hat noch kein Training.")
                    .foregroundStyle(.secondary)
            }
            ForEach(sessions) { s in
                Button { offen = GymVerlaufZiel(person: wer, session: s.id) } label: {
                    GymVerlaufZeile(session: s, tag: modell.tag(wer, id: s.tag))
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Verlauf")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Training nachtragen", systemImage: "plus") { nachtragenOffen = true }
            }
        }
        .navigationDestination(item: $offen) { WorkoutRueckblick(person: $0.person, sessionId: $0.session) }
        .sheet(isPresented: $nachtragenOffen) { NachtragenBlatt() }
    }
}

/// Ein Monat als Gitter, Trainingstage gefüllt. Wischen blättert zurück (`MonatsPager`).
struct GymMonat: View {
    let tage: Set<String>
    let heute: String
    let monateZurueck: Int

    private static let spalten = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let gitter = HealthLogik.monatsGitter(heute: heute, monateZurueck: monateZurueck)
        VStack(alignment: .leading, spacing: 8) {
            Text(HealthText.monat(gitter)).font(.subheadline.weight(.semibold))
            WochentagsKopf()
            LazyVGrid(columns: Self.spalten, spacing: 4) {
                ForEach(gitter.indices, id: \.self) { i in zelle(gitter[i]) }
            }
        }
    }

    @ViewBuilder
    private func zelle(_ tag: String?) -> some View {
        if let tag {
            let an = tage.contains(tag)
            Text(HealthText.tagesnummer(tag))
                .font(.footnote.weight(an ? .bold : .regular).monospacedDigit())
                .foregroundStyle(an ? Color.white : tag == heute ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(an ? Color.blue : Color.clear, in: .circle)
                .accessibilityLabel("\(Datum.anzeige(tag))\(an ? ", Training" : "")")
        } else {
            Color.clear.frame(minHeight: 32)
        }
    }
}

private func kennzahl(_ titel: String, _ wert: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(titel).font(.caption).foregroundStyle(.secondary)
        Text(wert).font(.title3.weight(.semibold).monospacedDigit())
    }
    .accessibilityElement(children: .combine)
}

private func serieText(_ wochen: Int) -> String {
    wochen == 1 ? "1 Woche" : "\(wochen) Wochen"
}

/// Eine Einheit zum Nachlesen: Zeiten, Volumen und jeder abgehakte Satz. Die eigene lässt sich in
/// den Zeiten korrigieren oder löschen, die des Partners nur lesen.
struct WorkoutRueckblick: View {
    let person: Person
    let sessionId: String
    @State private var zeiten: GymSession?

    var body: some View {
        let modell = TrainingModell.shared
        let liste = modell.workout(sessionId, person)
        if let s = modell.sessions(person).first(where: { $0.id == sessionId }) {
            List {
                Section {
                    LabeledContent("Zeit", value: zeit(s))
                    LabeledContent("Volumen", value: "\(TrainingLogik.kgText(WorkoutLogik.volumen(liste).rounded())) kg")
                    LabeledContent("Sätze", value: "\(WorkoutLogik.saetzeZahl(liste))")
                    if let kcal = s.kcal { LabeledContent("Aktive Kalorien", value: "\(kcal) kcal") }
                    if let puls = s.puls { LabeledContent("Puls im Schnitt", value: "\(puls)") }
                }
                ForEach(liste) { u in
                    Section(u.planUebung.anzeigeName) { saetze(u) }
                }
            }
            .navigationTitle(modell.tag(person, id: s.tag)?.name ?? Datum.anzeige(Datum.text(s.start)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if person == Raum.shared.ich {
                    ToolbarItem(placement: .primaryAction) { Button("Zeiten") { zeiten = s } }
                }
            }
            .sheet(item: $zeiten) { ZeitenBlatt(session: $0) }
        } else {
            ContentUnavailableView("Einheit nicht gefunden", systemImage: "dumbbell")
        }
    }

    private func zeit(_ s: GymSession) -> String {
        let tag = Datum.anzeige(Datum.text(s.start))
        guard let ende = s.ende else { return "\(tag), seit \(Datum.uhrzeit(s.start))" }
        return "\(tag), \(Datum.uhrzeit(s.start))–\(Datum.uhrzeit(ende))"
    }

    @ViewBuilder
    private func saetze(_ u: WorkoutUebung) -> some View {
        if u.planUebung.istCardio {
            Text(u.cardioFertig ? "\(u.planUebung.minuten ?? 20) min" : "nicht gemacht").foregroundStyle(u.cardioFertig ? Color.primary : Color.secondary)
        } else if u.fertigZahl == 0 {
            Text("nicht gemacht").foregroundStyle(.secondary)
        } else {
            ForEach(u.saetze.indices, id: \.self) { i in
                if u.saetze[i].ok == true { zeile(u, i) }
            }
        }
    }

    private func zeile(_ u: WorkoutUebung, _ i: Int) -> some View {
        let s = u.saetze[i]
        let zeiten = [s.sek.map { "Satz \(WorkoutLogik.zeitText($0))" }, s.pause.map { "Pause \(WorkoutLogik.zeitText($0))" }].compactMap { $0 }
        return HStack(spacing: 12) {
            Text(WorkoutLogik.nummer(u.saetze, i))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(s.kuerzel == nil ? Color.secondary : Color.orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(WorkoutLogik.satzText(s)).monospacedDigit()
                if !zeiten.isEmpty { Text(zeiten.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            if let rpe = s.rpe { Text("RPE \(TrainingLogik.kgText(rpe))").font(.subheadline).foregroundStyle(.secondary) }
        }
    }
}

/// Ein Training von Hand nachtragen: Tag, Start und Ende.
struct NachtragenBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var start = Date().addingTimeInterval(-90 * 60)
    @State private var ende = Date()
    @State private var tag: String?

    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        let tage = TrainingModell.shared.plan(ich).tage
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start", selection: $start, in: ...Date())
                    DatePicker("Ende", selection: $ende, in: start...max(start, Date()))
                    LabeledContent("Dauer", value: TrainingLogik.dauerText(max(0, ende.timeIntervalSince(start))))
                }
                if !tage.isEmpty {
                    Section {
                        Picker("Trainingstag", selection: $tag) {
                            Text("Ohne Tag").tag(String?.none)
                            ForEach(tage) { t in
                                Text(t.name.isEmpty ? "Ohne Namen" : t.name).tag(String?.some(t.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Training nachtragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        TrainingModell.shared.nachtragen(tag: tag, start: start, ende: max(ende, start))
                        Haptik.erfolg()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct GymVerlaufZeile: View {
    let session: GymSession
    let tag: TrainingsTag?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Datum.anzeige(Datum.text(session.start))).font(.headline)
            Text(zeit).font(.subheadline).foregroundStyle(session.ende == nil ? Color.orange : Color.secondary)
            if let tag {
                let fertig = tag.uebungen.filter { session.erledigt($0.id) }.count
                Text("\(tag.name) · \(fertig) von \(tag.uebungen.count) Übungen").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private var zeit: String {
        guard let ende = session.ende else { return "ab \(Datum.uhrzeit(session.start)), nicht ausgecheckt" }
        return "\(Datum.uhrzeit(session.start))–\(Datum.uhrzeit(ende)) · \(TrainingLogik.dauerText(ende.timeIntervalSince(session.start)))"
    }
}
