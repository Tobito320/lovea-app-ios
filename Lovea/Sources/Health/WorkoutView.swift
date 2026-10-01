import SwiftUI

// Training loggen wie Hevy (Ahmed, 01.10.2026): erst alle Übungen mit ihrem Stand, ein Tipp öffnet
// eine einzelne mit Satzzeilen (Vorher, kg, Wdh, Haken). Unten ein Knopf für den nächsten Schritt.
// Akku: Uhren zeichnet SwiftUI selbst aus Zeitpunkten, gesendet wird nur bei Haken und Satzstart.

/// Rundes Bild der Übung wie in Hevy; ohne Katalog-Eintrag ein Symbol.
struct UebungBild: View {
    let uebung: PlanUebung
    var groesse: CGFloat = 48

    var body: some View {
        Group {
            if uebung.katalog != nil {
                UebungVorschau(id: uebung.uebung)
            } else {
                Image(systemName: uebung.istCardio ? "figure.run" : "dumbbell.fill")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .tertiarySystemFill))
            }
        }
        .frame(width: groesse, height: groesse)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}

/// Die Leiste unten: was dran ist, die laufende Satz- oder Pausenzeit, ein Knopf für den nächsten Schritt.
struct WorkoutLeiste: View {
    let titel: String
    let unter: String
    let uhr: WorkoutUhr.Stand?
    let knopf: String
    /// Nur die sichtbare Leiste vibriert am Pausenende (die Übersicht liegt unter der Einzelansicht).
    var vibriert = true
    let aktion: () -> Void

    @State private var abgelaufen = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(unter).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            zeit
            Button(action: aktion) {
                Text(knopf).font(.headline).frame(minWidth: 108, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .task(id: uhr) { await pauseAbwarten() }
    }

    /// Pause mit Ziel zählt rückwärts, danach rot weiter hoch. Ein Satz zählt hoch.
    @ViewBuilder
    private var zeit: some View {
        if let uhr {
            Group {
                if let ende = uhr.pauseEnde {
                    if abgelaufen {
                        Text(ende, style: .timer).foregroundStyle(Color.red)
                    } else {
                        Text(timerInterval: uhr.seit...ende, countsDown: true)
                    }
                } else {
                    Text(uhr.seit, style: .timer)
                }
            }
            .font(.title2.bold().monospacedDigit())
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 84, alignment: .trailing)
        }
    }

    private func pauseAbwarten() async {
        abgelaufen = false
        guard let ende = uhr?.pauseEnde else { return }
        let rest = ende.timeIntervalSinceNow
        if rest > 0 {
            try? await Task.sleep(for: .seconds(rest))
            if Task.isCancelled { return }
            if vibriert { Haptik.warnung() }
        }
        abgelaufen = true
    }
}

// MARK: - Übersicht

struct WorkoutAktionen {
    var oeffnen: (WorkoutUebung) -> Void = { _ in }
    var hinzufuegen: () -> Void = {}
    var verwerfen: () -> Void = {}
    var tagWaehlen: (TrainingsTag) -> Void = { _ in }
    var wiederEinchecken: () -> Void = {}
    var zeiten: () -> Void = {}
}

/// Das laufende Training: Starten hat eingecheckt, "Beenden" checkt aus.
struct GymSessionView: View {
    let sessionId: String

    @Environment(\.dismiss) private var dismiss
    @State private var offen: String?
    @State private var sucheOffen = false
    @State private var cardio: CardioEintrag?
    @State private var zeiten: GymSession?
    @State private var langFrage: GymSession?
    @State private var planFrage: TrainingsTag?
    @State private var verwerfenFrage = false

    private var modell: TrainingModell { TrainingModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        let liste = modell.workout(sessionId)
        inhalt(liste)
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $offen) { id in
                WorkoutUebungView(sessionId: sessionId, planId: id, wechseln: { offen = $0 }).id(id)
            }
            .sheet(isPresented: $sucheOffen) { UebungsSuche { hinzufuegen($0) } }
            .sheet(item: $cardio) { CardioFormular(eintrag: $0, bearbeitbar: true) }
            .sheet(item: $zeiten) { ZeitenBlatt(session: $0) }
            .alert("Warst du wirklich so lange im Gym?", isPresented: langFrageOffen, presenting: langFrage) { s in
                Button("Ja, stimmt") { abschliessen(s) }
                Button("Endzeit ändern") { zeiten = s }
                Button("Abbrechen", role: .cancel) {}
            } message: { s in
                Text("Gestartet um \(Datum.uhrzeit(s.start)), das sind \(TrainingLogik.dauerText(Date().timeIntervalSince(s.start))).")
            }
            .alert("Plan aktualisieren?", isPresented: planFrageOffen, presenting: planFrage) { neu in
                Button("Plan aktualisieren") {
                    modell.planSichern(TrainingLogik.tagSetzen(modell.plan(ich), neu))
                    dismiss()
                }
                Button("So lassen", role: .cancel) { dismiss() }
            } message: { neu in
                Text("Du hast Sätze oder Übungen geändert. Soll \(neu.name.isEmpty ? "der Tag" : neu.name) beim nächsten Mal so aussehen?")
            }
            .confirmationDialog("Training verwerfen?", isPresented: $verwerfenFrage, titleVisibility: .visible) {
                Button("Verwerfen", role: .destructive) { verwerfen() }
            } message: {
                Text("Die Einheit und alle Sätze darin werden gelöscht.")
            }
    }

    @ViewBuilder
    private func inhalt(_ liste: [WorkoutUebung]) -> some View {
        if let session = modell.sessions(ich).first(where: { $0.id == sessionId }) {
            ScrollView {
                WorkoutInhalt(session: session, tag: modell.tag(ich, id: session.tag), tage: modell.plan(ich).tage, liste: liste, aktionen: aktionen(session))
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if session.ende == nil, !liste.isEmpty { leiste(session, liste) }
            }
            .toolbar {
                if session.ende == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Beenden") { beenden(session) }.fontWeight(.semibold)
                    }
                }
            }
        } else {
            ContentUnavailableView("Einheit nicht gefunden", systemImage: "dumbbell")
        }
    }

    private func leiste(_ s: GymSession, _ liste: [WorkoutUebung]) -> WorkoutLeiste {
        let uhr = WorkoutUhr.shared.stand.flatMap { $0.session == s.id ? $0 : nil }
        guard let d = WorkoutLogik.dran(liste) else {
            return WorkoutLeiste(titel: "Alle Sätze fertig", unter: "Beenden checkt dich aus", uhr: uhr, knopf: "Beenden", vibriert: offen == nil) { beenden(s) }
        }
        let u = liste[d.uebung]
        if u.planUebung.istCardio {
            return WorkoutLeiste(titel: u.planUebung.anzeigeName, unter: "\(u.planUebung.minuten ?? 20) min", uhr: uhr, knopf: "Fertig", vibriert: offen == nil) { cardioTipp(u, s) }
        }
        let unter = "Satz \(d.satz + 1) von \(u.saetze.count) · \(WorkoutLogik.satzText(u.saetze[d.satz]))"
        return WorkoutLeiste(titel: u.planUebung.anzeigeName, unter: unter, uhr: uhr, knopf: "Öffnen", vibriert: offen == nil) { offen = u.id }
    }

    private var langFrageOffen: Binding<Bool> {
        Binding { langFrage != nil } set: { if !$0 { langFrage = nil } }
    }

    private var planFrageOffen: Binding<Bool> {
        Binding { planFrage != nil } set: { if !$0 { planFrage = nil } }
    }

    private func aktionen(_ s: GymSession) -> WorkoutAktionen {
        WorkoutAktionen(
            oeffnen: { u in
                if u.planUebung.istCardio { cardioTipp(u, s) } else { offen = u.id }
            },
            hinzufuegen: { sucheOffen = true },
            verwerfen: { verwerfenFrage = true },
            tagWaehlen: { t in
                modell.tagSetzen(s, t.id)
                Haptik.leicht()
            },
            wiederEinchecken: {
                modell.auscheckenRueckgaengig(s.id)
                Haptik.erfolg()
            },
            zeiten: { zeiten = s }
        )
    }

    /// Cardio hat keine Sätze: ein Tipp hakt ab (Laufband und Treppe öffnen das Cardio-Formular), noch einer nimmt den Haken weg.
    private func cardioTipp(_ u: WorkoutUebung, _ s: GymSession) {
        guard s.ende == nil else { return }
        if u.cardioFertig {
            modell.zuruecksetzen(s.id, u.planUebung)
            Haptik.leicht()
            return
        }
        modell.fertig(s.id, u.planUebung, saetze: [])
        Haptik.erfolg()
        if let geraet = TrainingLogik.cardioGeraet(u.planUebung.katalog) {
            cardio = CardioEintrag(datum: Datum.text(Date()), geraet: geraet, minuten: u.planUebung.minuten ?? 20)
        }
    }

    /// Eine Übung nur für dieses Training; beim Beenden fragt "Plan aktualisieren?".
    private func hinzufuegen(_ p: PlanUebung) {
        if p.istCardio { modell.starten(sessionId, p) } else { modell.saetzeSenden(sessionId, p, p.saetze) }
    }

    private func beenden(_ s: GymSession) {
        if TrainingLogik.zuLang(start: s.start, ende: Date()) { langFrage = s } else { abschliessen(s) }
    }

    private func abschliessen(_ s: GymSession) {
        WorkoutAktion.pauseAbschliessen(s.id, nil, [])
        WorkoutUhr.shared.aus()
        let liste = modell.workout(s.id)
        modell.auschecken(s.id)
        Haptik.erfolg()
        if let tag = modell.tag(ich, id: s.tag), let neu = WorkoutLogik.neuerTag(tag, liste) {
            planFrage = neu
        } else {
            dismiss()
        }
    }

    private func verwerfen() {
        WorkoutUhr.shared.aus()
        if let s = modell.sessions(ich).first(where: { $0.id == sessionId }) { modell.loeschen(s) }
        Haptik.warnung()
        dismiss()
    }
}

/// Reine Übersicht ohne Scroll-Ansicht (Render-Tafel): Dauer, Volumen, Sätze, dann jede Übung mit
/// "2/3". Fertige sind grün, die Übung, die dran ist, ist hervorgehoben.
struct WorkoutInhalt: View {
    let session: GymSession
    let tag: TrainingsTag?
    var tage: [TrainingsTag] = []
    let liste: [WorkoutUebung]
    var aktionen = WorkoutAktionen()

    var body: some View {
        let dran = session.ende == nil ? WorkoutLogik.dran(liste)?.uebung : nil
        VStack(alignment: .leading, spacing: 16) {
            werte
            if liste.isEmpty {
                leer
            } else {
                VStack(spacing: 2) {
                    ForEach(Array(liste.enumerated()), id: \.element.id) { i, u in
                        zeile(u, dran: i == dran)
                    }
                }
            }
            schluss
        }
        .padding(16)
    }

    private var werte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tag?.name ?? "Training").font(.largeTitle.bold())
            HStack(alignment: .top, spacing: 28) {
                wert("Dauer") { dauer.foregroundStyle(Color.blue) }
                wert("Volumen") { Text("\(TrainingLogik.kgText(WorkoutLogik.volumen(liste).rounded())) kg") }
                wert("Sätze") { Text("\(WorkoutLogik.saetzeZahl(liste))") }
            }
            Divider()
        }
    }

    private var dauer: Text {
        if let ende = session.ende { return Text(TrainingLogik.dauerText(ende.timeIntervalSince(session.start))) }
        return Text(session.start, style: .timer)
    }

    private func wert(_ titel: String, @ViewBuilder _ inhalt: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.caption).foregroundStyle(.secondary)
            inhalt().font(.title3.weight(.semibold).monospacedDigit())
        }
    }

    private func zeile(_ u: WorkoutUebung, dran: Bool) -> some View {
        Button { aktionen.oeffnen(u) } label: {
            HStack(spacing: 12) {
                UebungBild(uebung: u.planUebung)
                VStack(alignment: .leading, spacing: 2) {
                    Text(u.planUebung.anzeigeName)
                        .font(.headline)
                        .foregroundStyle(dran ? Color.blue : Color.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(dran ? "Jetzt dran" : unter(u)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    if u.fertig { Image(systemName: "checkmark") }
                    Text("\(u.fertigZahl)/\(u.gesamt)")
                }
                .font(.headline.monospacedDigit())
                .foregroundStyle(u.fertig ? Color.green : Color.secondary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 68)
            .background(dran ? Color(uiColor: .tertiarySystemFill) : Color.clear, in: .rect(cornerRadius: 14, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(u.fertig ? "fertig" : dran ? "jetzt dran" : "")
    }

    private func unter(_ u: WorkoutUebung) -> String {
        if let minuten = u.planUebung.minuten { return "\(minuten) min" }
        return u.planUebung.katalog.map { "\($0.muskel) · \($0.geraet)" } ?? "Eigene Übung"
    }

    @ViewBuilder
    private var leer: some View {
        if session.ende == nil, tag == nil, !tage.isEmpty {
            Text("Welcher Trainingstag?").font(.headline)
            ForEach(tage) { t in
                Button { aktionen.tagWaehlen(t) } label: {
                    Text(t.name.isEmpty ? "Ohne Namen" : t.name).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
            Text("Oder leer starten und Übungen einzeln hinzufügen.").font(.footnote).foregroundStyle(.secondary)
        } else {
            Text("Noch keine Übung. Füg unten eine hinzu.").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var schluss: some View {
        if session.ende == nil {
            Button(action: aktionen.hinzufuegen) {
                Label("Übung hinzufügen", systemImage: "plus").font(.headline).frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            Button(role: .destructive, action: aktionen.verwerfen) {
                Text("Training verwerfen").frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.bordered)
        } else {
            HStack(spacing: 10) {
                Label("Beendet", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(Color.green)
                Spacer()
                Button("Zeiten", action: aktionen.zeiten).buttonStyle(.bordered)
                Button("Weiter", systemImage: "arrow.uturn.backward", action: aktionen.wiederEinchecken).buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Eine Übung

/// Nur diese eine Übung: Notiz, Pausenzeit, Satzzeilen. Zurückwischen zeigt wieder alle. Die Zeilen
/// leben hier lokal; gesendet wird bei Haken, Satzstart, Löschen und beim Verlassen.
struct WorkoutUebungView: View {
    let sessionId: String
    let planId: String
    /// Zur nächsten Übung wechseln, nil = zurück zur Übersicht.
    var wechseln: (String?) -> Void = { _ in }

    @State private var saetze: [PlanSatz] = []
    @State private var notiz = ""
    @State private var geladen = false
    @State private var animation: Uebung?
    @State private var scheibenOffen = false
    @AppStorage("gym.rpe") private var rpeAn = true
    @FocusState private var fokus: Bool

    private var modell: TrainingModell { TrainingModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        let liste = modell.workout(sessionId)
        if let u = liste.first(where: { $0.id == planId }) {
            seite(u, liste)
        } else {
            ContentUnavailableView("Übung nicht gefunden", systemImage: "dumbbell")
        }
    }

    private func seite(_ u: WorkoutUebung, _ liste: [WorkoutUebung]) -> some View {
        List {
            Section {
                kopf(u)
                if !u.extra {
                    TextField("Notizen hier hinzufügen", text: $notiz, axis: .vertical).font(.subheadline)
                    pausenMenue(u)
                }
            }
            .listRowSeparator(.hidden)
            Section {
                tabellenKopf.listRowSeparator(.hidden)
                ForEach(saetze.indices, id: \.self) { i in zeile(u, i) }
                Button { satzDazu() } label: {
                    Label("Satz hinzufügen", systemImage: "plus").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.bordered)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
        .focused($fokus)
        .navigationTitle(u.planUebung.anzeigeName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { menue(u) }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { fokus = false }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { leiste(u, liste) }
        .sheet(item: $animation) { a in
            NavigationStack { UebungDetail(uebung: a) }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $scheibenOffen) { ScheibenBlatt(kg: arbeitsgewicht ?? 60) }
        .onAppear { laden(u) }
        .onDisappear { sichern() }
    }

    private func kopf(_ u: WorkoutUebung) -> some View {
        Button { animation = u.planUebung.katalog } label: {
            HStack(spacing: 12) {
                UebungBild(uebung: u.planUebung, groesse: 56)
                Text(u.planUebung.anzeigeName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.blue)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Zeigt die Animation")
    }

    private func pausenMenue(_ u: WorkoutUebung) -> some View {
        Menu {
            Picker("Pause", selection: pauseBindung(u)) {
                ForEach(WorkoutLogik.pausen, id: \.self) { sek in
                    Text(WorkoutLogik.pauseText(sek)).tag(sek)
                }
            }
        } label: {
            Label("Pausentimer: \(WorkoutLogik.pauseText(u.planUebung.pause ?? WorkoutLogik.standardPause))", systemImage: "timer")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.blue)
        }
    }

    private func pauseBindung(_ u: WorkoutUebung) -> Binding<Int> {
        Binding {
            u.planUebung.pause ?? WorkoutLogik.standardPause
        } set: { neu in
            modell.planSichern(TrainingLogik.aendern(modell.plan(ich), planUebung: planId) { $0.pause = neu })
        }
    }

    private var tabellenKopf: some View {
        HStack(spacing: 6) {
            Text("SATZ").frame(width: 44)
            Text("VORHER").frame(maxWidth: .infinity, alignment: .leading)
            Text("KG").frame(width: 62)
            Text("WDH").frame(width: 50)
            if rpeAn { Text("RPE").frame(width: 44) }
            Image(systemName: "checkmark").frame(width: 44)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 0, trailing: 12))
        .accessibilityHidden(true)
    }

    private func zeile(_ u: WorkoutUebung, _ i: Int) -> some View {
        let fertig = saetze.indices.contains(i) && saetze[i].ok == true
        return WorkoutSatzZeile(
            nummer: WorkoutLogik.nummer(saetze, i),
            satz: bindung(i),
            vorher: u.vorher.indices.contains(i) ? u.vorher[i] : nil,
            rpe: rpeAn,
            laeuft: laufenderSatz == i,
            typ: { t in
                if saetze.indices.contains(i) { saetze[i].setzeTyp(t) }
                Haptik.auswahl()
            },
            haken: { haken(u, i) }
        )
        .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
        .listRowSeparator(.hidden)
        .listRowBackground(fertig ? Color.green.opacity(0.2) : Color.clear)
        .swipeActions {
            Button("Löschen", role: .destructive) { loeschen(u, i) }
        }
    }

    /// Index-sicher: eine Zeile, die gerade gelöscht wird, fragt ihren Index noch einmal ab.
    private func bindung(_ i: Int) -> Binding<PlanSatz> {
        Binding {
            saetze.indices.contains(i) ? saetze[i] : PlanSatz(wdh: 0, kg: nil, failure: false)
        } set: {
            if saetze.indices.contains(i) { saetze[i] = $0 }
        }
    }

    private func menue(_ u: WorkoutUebung) -> some View {
        Menu {
            if u.planUebung.katalog != nil {
                Button("Animation ansehen", systemImage: "play.rectangle") { animation = u.planUebung.katalog }
            }
            Button("Aufwärmsätze einfügen", systemImage: "flame") { aufwaermen() }
                .disabled(arbeitsgewicht == nil)
            Button("Scheibenrechner", systemImage: "circle.circle") { scheibenOffen = true }
            Toggle("RPE-Spalte", isOn: $rpeAn)
            if u.extra {
                Button("Übung entfernen", systemImage: "trash", role: .destructive) { entfernen(u) }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Mehr")
    }

    private func leiste(_ u: WorkoutUebung, _ liste: [WorkoutUebung]) -> WorkoutLeiste {
        let stand = WorkoutUhr.shared.stand.flatMap { $0.session == sessionId ? $0 : nil }
        guard let offener = saetze.firstIndex(where: { $0.ok != true }) else {
            let kraft = liste.filter { $0.id != u.id && !$0.fertig && !$0.planUebung.istCardio }
            let danach = liste.drop { $0.id != u.id }.dropFirst().first { !$0.fertig && !$0.planUebung.istCardio }
            let naechste = danach ?? kraft.first
            return WorkoutLeiste(
                titel: "Übung fertig",
                unter: naechste.map { "Weiter mit \($0.planUebung.anzeigeName)" } ?? "Zurück zur Übersicht",
                uhr: stand,
                knopf: naechste == nil ? "Übersicht" : "Nächste Übung"
            ) {
                wechseln(naechste?.id)
            }
        }
        let laufend = laufenderSatz.flatMap { saetze.indices.contains($0) ? $0 : nil }
        let ziel = laufend ?? offener
        let knopf = laufend != nil ? "Satz fertig" : offener == 0 ? "Übung starten" : "Nächster Satz"
        return WorkoutLeiste(titel: "Satz \(ziel + 1) von \(saetze.count)", unter: WorkoutLogik.satzText(saetze[ziel]), uhr: stand, knopf: knopf) {
            if laufend != nil {
                haken(u, ziel)
            } else {
                saetze = WorkoutAktion.satzStarten(sessionId, u.planUebung, saetze, offener)
                Haptik.mittel()
            }
        }
    }

    /// Der Satz dieser Übung, dessen Uhr gerade läuft.
    private var laufenderSatz: Int? {
        guard let s = WorkoutUhr.shared.stand, s.session == sessionId, !s.pause, s.plan == planId else { return nil }
        return s.satz
    }

    /// Das erste Gewicht, das kein Aufwärmsatz ist.
    private var arbeitsgewicht: Double? {
        saetze.first { $0.typ != "w" && $0.kg != nil }?.kg
    }

    private func laden(_ u: WorkoutUebung) {
        guard !geladen else { return }
        saetze = u.saetze
        notiz = u.planUebung.notiz ?? ""
        geladen = true
    }

    /// Beim Verlassen: getippte Werte senden und die Notiz in den Plan schreiben, falls geändert.
    private func sichern() {
        guard geladen, let u = modell.workout(sessionId).first(where: { $0.id == planId }) else { return }
        let laeuft = modell.sessions(ich).first { $0.id == sessionId }?.ende == nil
        if laeuft, saetze != u.saetze { modell.saetzeSenden(sessionId, u.planUebung, saetze) }
        let neu = notiz.trimmingCharacters(in: .whitespacesAndNewlines)
        if !u.extra, neu != (u.planUebung.notiz ?? "") {
            modell.planSichern(TrainingLogik.aendern(modell.plan(ich), planUebung: planId) { $0.notiz = neu.isEmpty ? nil : neu })
        }
    }

    private func haken(_ u: WorkoutUebung, _ i: Int) {
        let vorher = saetze.indices.contains(i) && saetze[i].ok == true
        saetze = WorkoutAktion.haken(sessionId, u.planUebung, saetze, i)
        if vorher { Haptik.leicht() } else { Haptik.erfolg() }
    }

    private func satzDazu() {
        var neu = (saetze.last ?? PlanSatz(wdh: 10, kg: nil, failure: false)).alsPlan
        if neu.typ == "w" { neu.typ = nil }
        saetze.append(neu)
        Haptik.leicht()
    }

    /// Die Uhr merkt sich Satznummern: verschieben sich die Zeilen, hört sie auf.
    private func uhrAus() {
        if WorkoutUhr.shared.stand?.plan == planId { WorkoutUhr.shared.aus() }
    }

    private func loeschen(_ u: WorkoutUebung, _ i: Int) {
        guard saetze.indices.contains(i) else { return }
        uhrAus()
        saetze.remove(at: i)
        modell.saetzeSenden(sessionId, u.planUebung, saetze)
        Haptik.leicht()
    }

    private func aufwaermen() {
        guard let kg = arbeitsgewicht else { return }
        uhrAus()
        saetze.insert(contentsOf: WorkoutLogik.aufwaermen(arbeit: kg), at: 0)
        Haptik.leicht()
    }

    private func entfernen(_ u: WorkoutUebung) {
        uhrAus()
        geladen = false // nichts mehr nachsenden
        modell.entfernen(sessionId, u.planUebung)
        wechseln(nil)
    }
}

/// Eine Satzzeile wie in Hevy: Nummer (Tipp wählt den Typ), Vorher, kg, Wdh, RPE, Haken. Darunter
/// Satz- und Pausenzeit, wenn gemessen.
struct WorkoutSatzZeile: View {
    let nummer: String
    @Binding var satz: PlanSatz
    let vorher: PlanSatz?
    var rpe = true
    var laeuft = false
    var typ: (String) -> Void = { _ in }
    var haken: () -> Void = {}

    private var fertig: Bool { satz.ok == true }
    private static let kachel = RoundedRectangle(cornerRadius: 9, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                typMenue
                Text(vorher.map(WorkoutLogik.satzText) ?? "–")
                    .font(.subheadline)
                    .foregroundStyle(fertig ? Color.primary.opacity(0.75) : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                feld(TextField("0", value: $satz.kg, format: .number).keyboardType(.decimalPad), 62)
                    .accessibilityLabel("Kilo")
                feld(TextField("0", value: $satz.wdh, format: .number).keyboardType(.numberPad), 50)
                    .accessibilityLabel("Wiederholungen")
                if rpe {
                    feld(TextField("–", value: $satz.rpe, format: .number).keyboardType(.decimalPad), 44)
                        .accessibilityLabel("RPE")
                }
                Button(action: haken) {
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .foregroundStyle(fertig ? Color.white : Color.secondary)
                        .frame(width: 44, height: 44)
                        .background(fertig ? Color.green : Color(uiColor: .tertiarySystemFill), in: Self.kachel)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(fertig ? "Haken entfernen" : "Satz abhaken")
            }
            if let zeiten {
                Text(zeiten).font(.caption).foregroundStyle(Color.primary.opacity(0.75)).padding(.leading, 50)
            }
        }
    }

    private var typMenue: some View {
        Menu {
            Button("Normal") { typ("") }
            Button("Aufwärmen (W)") { typ("w") }
            Button("Dropsatz (D)") { typ("d") }
            Button("Bis zum Versagen (F)") { typ("f") }
        } label: {
            Text(nummer)
                .font(.headline)
                .foregroundStyle(satz.kuerzel == nil ? Color.primary : Color.orange)
                .frame(width: 44, height: 44)
                .background(Color(uiColor: .tertiarySystemFill), in: Self.kachel)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Satztyp, jetzt \(nummer)")
    }

    private func feld(_ eingabe: some View, _ breite: CGFloat) -> some View {
        eingabe
            .multilineTextAlignment(.center)
            .font(.headline.monospacedDigit())
            .frame(width: breite, height: 44)
            .overlay {
                Self.kachel.strokeBorder(fertig ? Color.clear : laeuft ? Color.blue : Color(uiColor: .separator), lineWidth: 1)
            }
    }

    /// "Satz 0:42 · Pause 1:58".
    private var zeiten: String? {
        guard fertig else { return nil }
        let teile = [satz.sek.map { "Satz \(WorkoutLogik.zeitText($0))" }, satz.pause.map { "Pause \(WorkoutLogik.zeitText($0))" }].compactMap { $0 }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }
}

/// Welche Scheiben pro Seite auf die Stange kommen.
struct ScheibenBlatt: View {
    @State var kg: Double
    @State private var stange = 20.0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Gewicht in kg") {
                        TextField("kg", value: $kg, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    Picker("Stange", selection: $stange) {
                        ForEach([20.0, 15.0, 10.0], id: \.self) { s in
                            Text("\(TrainingLogik.kgText(s)) kg").tag(s)
                        }
                    }
                }
                Section("Pro Seite") {
                    Text(scheibenText).font(.title3.weight(.semibold).monospacedDigit())
                }
            }
            .navigationTitle("Scheibenrechner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }

    private var scheibenText: String {
        let liste = WorkoutLogik.scheiben(kg: kg, stange: stange)
        return liste.isEmpty ? "Nur die Stange" : liste.map(TrainingLogik.kgText).joined(separator: " + ")
    }
}
