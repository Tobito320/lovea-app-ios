import SwiftUI

// MARK: - Health card

/// What the training card shows; built by `TrainingKarte`, fixed in the render board.
struct TrainingKartenStand {
    var heute: TrainingsTag? = nil
    var laufend: GymSession? = nil
    var laufendTag: TrainingsTag? = nil
    var vergessen: GymSession? = nil
    var planLeer: Bool
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

/// Health tab: today's day and check-in, or the running session; the forgotten-checkout hint;
/// one line about the partner.
struct TrainingKarte: View {
    let oeffnen: (HealthZiel) -> Void

    @State private var tagWahl = false
    @State private var ortWarnung = false
    @State private var zeiten: GymSession?

    private var modell: TrainingModell { TrainingModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { kontext in
            TrainingKarteInhalt(stand: stand(kontext.date), aktionen: aktionen)
        }
        .alert("Du bist nicht an deinem Gym", isPresented: $ortWarnung) {
            Button("Trotzdem einchecken") {
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    tagWaehlen()
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Laut deinem Standort bist du gerade woanders.")
        }
        .confirmationDialog("Welcher Trainingstag?", isPresented: $tagWahl, titleVisibility: .visible) {
            ForEach(modell.plan(ich).tage) { t in
                Button(t.name.isEmpty ? "Ohne Namen" : t.name) { starten(t.id) }
            }
            Button("Ohne Plan") { starten(nil) }
        }
        .sheet(item: $zeiten) { ZeitenBlatt(session: $0) }
    }

    private func stand(_ jetzt: Date) -> TrainingKartenStand {
        let laufend = modell.laufende(ich, jetzt: jetzt)
        return TrainingKartenStand(
            heute: modell.heutigerTag(ich), laufend: laufend, laufendTag: modell.tag(ich, id: laufend?.tag),
            vergessen: modell.vergessene(ich, jetzt: jetzt), planLeer: modell.plan(ich).tage.isEmpty,
            partner: partnerText(jetzt), jetzt: jetzt
        )
    }

    private var aktionen: TrainingKartenAktionen {
        TrainingKartenAktionen(
            einchecken: { einchecken() },
            oeffnen: { oeffnen(.gymSession($0.id)) },
            plan: { oeffnen(.trainingsPlan(ich)) },
            verlauf: { oeffnen(.gymVerlauf) },
            endeEintragen: { zeiten = $0 },
            jetztAuschecken: { s in
                modell.auschecken(s.id)
                Haptik.erfolg()
            }
        )
    }

    private func partnerText(_ jetzt: Date) -> String? {
        let p = ich.partner
        if let s = modell.laufende(p, jetzt: jetzt) {
            let uebung = s.aktiv.flatMap { a in modell.plan(p).tage.flatMap(\.uebungen).first { $0.id == a.plan } }
            return uebung.map { "\(p.name) trainiert gerade: \($0.anzeigeName)" } ?? "\(p.name) ist im Gym"
        }
        return modell.heutigerTag(p).map { "\(p.name) hat heute \($0.name)" }
    }

    private func einchecken() {
        let fix = Standort.shared.positionen[ich]
        if TrainingLogik.nichtImGym(orte: OrteModell.shared.orte, ich: ich, lat: fix?.lat, lon: fix?.lon, alter: fix?.sekundenAlt) {
            Haptik.warnung()
            ortWarnung = true
        } else {
            tagWaehlen()
        }
    }

    private func tagWaehlen() {
        if let t = modell.heutigerTag(ich) {
            starten(t.id)
        } else if modell.plan(ich).tage.isEmpty {
            starten(nil)
        } else {
            tagWahl = true
        }
    }

    private func starten(_ tag: String?) {
        let id = modell.einchecken(tag: tag)
        Haptik.erfolg()
        oeffnen(.gymSession(id))
    }
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
            symbolKnopf("list.bullet.clipboard", "Trainingsplan", aktionen.plan)
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
            Button(action: aktionen.einchecken) {
                Label("Im Gym einchecken", systemImage: "figure.strengthtraining.traditional")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Self.gruen)
        }
    }

    private var heuteText: String {
        if stand.planLeer { return "Noch kein Trainingsplan" }
        guard let t = stand.heute else { return "Heute ist Ruhetag" }
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

// MARK: - Session screen

enum UebungStand: Equatable {
    case offen, naechste, aktiv(seit: Date), fertig
}

struct GymAktionen {
    var starten: (PlanUebung) -> Void = { _ in }
    var fertig: (PlanUebung) -> Void = { _ in }
    var anpassen: (PlanUebung) -> Void = { _ in }
    var zuruecksetzen: (PlanUebung) -> Void = { _ in }
    var video: (PlanUebung) -> Void = { _ in }
    var auschecken: () -> Void = {}
}

/// The gym screen: the day's exercises in order, the next one highlighted, Start and Fertig,
/// checkout at the end.
struct GymSessionView: View {
    let sessionId: String

    @Environment(\.dismiss) private var dismiss
    @State private var video: Uebung?
    @State private var anpassen: PlanUebung?
    @State private var cardio: CardioEintrag?
    @State private var zeiten: GymSession?
    @State private var langFrage: GymSession?

    private var modell: TrainingModell { TrainingModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        inhalt
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $video) { u in
                NavigationStack { UebungDetail(uebung: u) }.presentationDetents([.medium, .large])
            }
            .sheet(item: $anpassen) { u in
                FertigBlatt(uebung: u) { saetze in
                    modell.fertig(sessionId, u, saetze: saetze)
                    Haptik.erfolg()
                }
            }
            .sheet(item: $cardio) { CardioFormular(eintrag: $0, bearbeitbar: true) }
            .sheet(item: $zeiten) { ZeitenBlatt(session: $0) }
            .alert("Warst du wirklich so lange im Gym?", isPresented: langFrageOffen, presenting: langFrage) { s in
                Button("Ja, stimmt") { auscheckenJetzt(s) }
                Button("Endzeit ändern") { zeiten = s }
                Button("Abbrechen", role: .cancel) {}
            } message: { s in
                Text("Eingecheckt um \(Datum.uhrzeit(s.start)), das sind \(TrainingLogik.dauerText(Date().timeIntervalSince(s.start))).")
            }
    }

    @ViewBuilder
    private var inhalt: some View {
        if let session = modell.sessions(ich).first(where: { $0.id == sessionId }) {
            ScrollView {
                TimelineView(.periodic(from: .now, by: 30)) { kontext in
                    GymSessionInhalt(session: session, tag: modell.tag(ich, id: session.tag), jetzt: kontext.date, aktionen: aktionen(session))
                }
            }
        } else {
            ContentUnavailableView("Einheit nicht gefunden", systemImage: "dumbbell")
        }
    }

    private var langFrageOffen: Binding<Bool> {
        Binding { langFrage != nil } set: { if !$0 { langFrage = nil } }
    }

    private func aktionen(_ s: GymSession) -> GymAktionen {
        GymAktionen(
            starten: { u in
                modell.starten(s.id, u)
                Haptik.mittel()
            },
            fertig: { u in fertig(u, s) },
            anpassen: { u in anpassen = u },
            zuruecksetzen: { u in
                modell.zuruecksetzen(s.id, u)
                Haptik.leicht()
            },
            video: { u in video = u.katalog },
            auschecken: { auschecken(s) }
        )
    }

    /// One tap: plan sets count as done. Treadmill or stairs: the Cardio form opens with the minutes.
    private func fertig(_ u: PlanUebung, _ s: GymSession) {
        modell.fertig(s.id, u, saetze: u.saetze)
        Haptik.erfolg()
        guard u.istCardio, let geraet = TrainingLogik.cardioGeraet(u.katalog) else { return }
        let start = s.aktiv?.plan == u.id ? s.aktiv?.start : nil
        let minuten = start.map { max(1, Int(Date().timeIntervalSince($0) / 60)) } ?? (u.minuten ?? 20)
        cardio = CardioEintrag(datum: Datum.text(Date()), geraet: geraet, minuten: minuten)
    }

    private func auschecken(_ s: GymSession) {
        if TrainingLogik.zuLang(start: s.start, ende: Date()) {
            langFrage = s
        } else {
            auscheckenJetzt(s)
        }
    }

    private func auscheckenJetzt(_ s: GymSession) {
        modell.auschecken(s.id)
        Haptik.erfolg()
        dismiss()
    }
}

/// Pure session body without its scroll view (render board; `GymSessionView` scrolls it).
struct GymSessionInhalt: View {
    let session: GymSession
    let tag: TrainingsTag?
    let jetzt: Date
    var aktionen = GymAktionen()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            kopf
            if let tag {
                ForEach(tag.uebungen) { u in
                    GymUebungKarte(uebung: u, stand: stand(u, tag), aktionen: aktionen)
                }
            } else {
                Text("Ohne Trainingstag eingecheckt. Leg im Plan Tage an, dann kannst du hier Übungen abhaken.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            schluss
        }
        .padding(16)
    }

    private var kopf: some View {
        let gesamt = tag?.uebungen.count ?? 0
        let fertig = tag?.uebungen.filter { session.erledigt($0.id) }.count ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            Text(tag?.name ?? "Training").font(.largeTitle.bold())
            Text(untertitel).font(.subheadline).foregroundStyle(.secondary)
            if gesamt > 0 {
                ProgressView(value: Double(fertig), total: Double(gesamt)).tint(HabitFarbe.mint.farbe)
                Text("\(fertig) von \(gesamt) fertig").font(.footnote.weight(.medium)).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var untertitel: String {
        if let ende = session.ende {
            return "\(Datum.uhrzeit(session.start))–\(Datum.uhrzeit(ende)) · \(TrainingLogik.dauerText(ende.timeIntervalSince(session.start)))"
        }
        return "Eingecheckt um \(Datum.uhrzeit(session.start)) · \(TrainingLogik.dauerText(jetzt.timeIntervalSince(session.start)))"
    }

    private func stand(_ u: PlanUebung, _ tag: TrainingsTag) -> UebungStand {
        if session.erledigt(u.id) { return .fertig }
        if let a = session.aktiv {
            if a.plan == u.id, let seit = a.start { return .aktiv(seit: seit) }
            return .offen
        }
        return TrainingLogik.naechste(tag, session)?.id == u.id ? .naechste : .offen
    }

    @ViewBuilder
    private var schluss: some View {
        if session.ende == nil {
            Button(action: aktionen.auschecken) {
                Label("Auschecken", systemImage: "door.left.hand.open").frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        } else {
            Label("Ausgecheckt", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(HabitFarbe.mint.farbe)
        }
    }
}

/// One exercise in the gym: thumbnail (tap plays the GIF), sets, and Start / timer + Fertig / tick.
struct GymUebungKarte: View {
    let uebung: PlanUebung
    let stand: UebungStand
    var aktionen = GymAktionen()

    private var istAktiv: Bool {
        if case .aktiv = stand { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                vorschau
                VStack(alignment: .leading, spacing: 2) {
                    Text(uebung.anzeigeName).font(.headline).lineLimit(2)
                    Text(TrainingLogik.saetzeText(uebung)).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                rechts
            }
            if istAktiv { aktivLeiste }
        }
        .padding(14)
        .background(hintergrund, in: .rect(cornerRadius: 18, style: .continuous))
        .overlay {
            if stand == .naechste {
                RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 2)
            }
        }
        .opacity(stand == .fertig ? 0.7 : 1)
        .contextMenu { menue }
        .animation(Feder.weich, value: stand)
    }

    private var hintergrund: Color {
        istAktiv ? HabitFarbe.mint.farbe.opacity(0.18) : Color(uiColor: .secondarySystemGroupedBackground)
    }

    @ViewBuilder
    private var vorschau: some View {
        if uebung.katalog != nil {
            Button { aktionen.video(uebung) } label: {
                UebungVorschau(id: uebung.uebung)
                    .frame(width: 64, height: 64)
                    .clipShape(.rect(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.federnd)
            .accessibilityLabel("Video: \(uebung.anzeigeName)")
        } else {
            Image(systemName: uebung.istCardio ? "figure.run" : "dumbbell.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
                .background(Color(uiColor: .tertiarySystemFill), in: .rect(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var rechts: some View {
        switch stand {
        case .fertig:
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(HabitFarbe.mint.farbe)
                .accessibilityLabel("erledigt")
        case .aktiv(let seit):
            Text(seit, style: .timer).font(.title3.monospacedDigit().weight(.semibold))
        case .naechste:
            Button("Start") { aktionen.starten(uebung) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .offen:
            Button("Start") { aktionen.starten(uebung) }
                .buttonStyle(.bordered)
        }
    }

    private var aktivLeiste: some View {
        HStack(spacing: 10) {
            if !uebung.istCardio {
                Button("Sätze anpassen") { aktionen.anpassen(uebung) }
                    .buttonStyle(.bordered)
            }
            Button { aktionen.fertig(uebung) } label: {
                Label("Fertig", systemImage: "checkmark").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(HabitFarbe.mint.farbe)
        }
    }

    @ViewBuilder
    private var menue: some View {
        if stand == .fertig {
            Button("Nicht erledigt", systemImage: "arrow.uturn.backward") { aktionen.zuruecksetzen(uebung) }
        } else {
            Button("Direkt abhaken", systemImage: "checkmark") { aktionen.fertig(uebung) }
        }
        if uebung.katalog != nil {
            Button("Video ansehen", systemImage: "play.rectangle") { aktionen.video(uebung) }
        }
    }
}

/// Adjust the sets before finishing; they become the plan values.
struct FertigBlatt: View {
    let uebung: PlanUebung
    let fertig: ([PlanSatz]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var saetze: [PlanSatz]

    init(uebung: PlanUebung, fertig: @escaping ([PlanSatz]) -> Void) {
        self.uebung = uebung
        self.fertig = fertig
        _saetze = State(initialValue: uebung.saetze)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SaetzeListe(saetze: $saetze)
                } footer: {
                    Text("Die Werte gelten auch fürs nächste Mal.")
                }
            }
            .navigationTitle(uebung.anzeigeName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        fertig(saetze)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
