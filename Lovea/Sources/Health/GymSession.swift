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

/// Own past sessions, newest first; tap to correct times or delete.
struct GymVerlaufView: View {
    @State private var zeiten: GymSession?
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        let modell = TrainingModell.shared
        let sessions = modell.sessions(ich)
        List {
            if sessions.isEmpty {
                Text("Noch keine Einheit. Check im Gym ein, dann steht sie hier.").foregroundStyle(.secondary)
            }
            ForEach(sessions) { s in
                Button { zeiten = s } label: { GymVerlaufZeile(session: s, tag: modell.tag(ich, id: s.tag)) }
                    .buttonStyle(.plain)
            }
        }
        .navigationTitle("Verlauf")
        .sheet(item: $zeiten) { ZeitenBlatt(session: $0) }
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
