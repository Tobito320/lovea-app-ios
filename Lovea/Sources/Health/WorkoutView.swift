import SwiftUI
import TipKit

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
            .layoutPriority(1)
            Spacer(minLength: 4)
            zeit
            Button(action: aktion) {
                Text(knopf).font(.subheadline.weight(.semibold)).lineLimit(1).fixedSize().frame(minHeight: 36)
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
            .fixedSize()
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
    var startzeit: () -> Void = {}
    var auslassen: (WorkoutUebung) -> Void = { _ in }
    var aufnehmen: (WorkoutUebung) -> Void = { _ in }
    var beenden: () -> Void = {}
    /// Cardio außerhalb des Plans: Katalog-id (Laufband, Stairmaster).
    var cardio: (String) -> Void = { _ in }
}

/// Das laufende Training: Starten hat eingecheckt, "Beenden" checkt aus.
struct GymSessionView: View {
    let sessionId: String

    @Environment(\.dismiss) private var dismiss
    @State private var offen: String?
    @State private var sucheOffen = false
    @State private var cardio: CardioEintrag?
    @State private var zeiten: GymSession?
    @State private var startBlatt: GymSession?
    @State private var langFrage: GymSession?
    @State private var planFrage: TrainingsTag?
    /// Training ohne Trainingstag fertig: "Als Trainingstag speichern?" mit den Übungen von eben.
    @State private var freiListe: [WorkoutUebung]?
    @State private var freiName = ""
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
                WorkoutInhalt(session: session, tag: modell.tag(ich, id: session.tag), tage: modell.plan(ich).tage, liste: liste,
                              puls: session.ende == nil ? WorkoutPuls.shared.puls : session.puls,
                              kcal: session.ende == nil ? WorkoutPuls.shared.kcal : session.kcal,
                              aktionen: aktionen(session))
            }
            .onAppear { if session.ende == nil { WorkoutPuls.shared.starten() } }
            // Health versteckt die Leiste auf seiner Startseite, das erbte das Training: "Beenden" fehlte (Ahmed, 04.10.).
            .toolbar(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if session.ende == nil, !liste.isEmpty { leiste(session, liste) }
            }
            .toolbar {
                if session.ende == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Startzeit ändern", systemImage: "clock") { startBlatt = session }
                            Button("Training verwerfen", systemImage: "trash", role: .destructive) { verwerfenFrage = true }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Mehr")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        // Auch mit offenen Übungen: was fertig ist, zählt, der Rest bleibt im Plan.
                        Button("Beenden") { beenden(session) }.fontWeight(.semibold)
                            .popoverTip(TrainingBeendenTip())
                    }
                }
            }
            .sheet(item: $startBlatt) { StartzeitBlatt(session: $0) }
            .alert("Als Trainingstag speichern?", isPresented: freiFrageOffen, presenting: freiListe) { liste in
                TextField("Name", text: $freiName)
                Button("Speichern") { alsTagSpeichern(liste) }
                Button("Nein", role: .cancel) { dismiss() }
            } message: { _ in
                Text("Du hast ohne Trainingstag trainiert. Beim nächsten Mal steht es als Vorlage bereit.")
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

    private var freiFrageOffen: Binding<Bool> {
        Binding { freiListe != nil } set: { if !$0 { freiListe = nil } }
    }

    private func aktionen(_ s: GymSession) -> WorkoutAktionen {
        WorkoutAktionen(
            oeffnen: { u in
                if u.planUebung.istCardio { cardioTipp(u, s) } else { offen = u.id }
            },
            hinzufuegen: { sucheOffen = true },
            verwerfen: { verwerfenFrage = true },
            tagWaehlen: { t in
                guard t.id != s.tag else { return }
                modell.tagWechseln(s, zu: t.id)
                Haptik.leicht()
            },
            wiederEinchecken: {
                modell.auscheckenRueckgaengig(s.id)
                Haptik.erfolg()
            },
            zeiten: { zeiten = s },
            startzeit: { startBlatt = s },
            auslassen: { u in
                modell.auslassen(s.id, u.planUebung)
                Haptik.leicht()
            },
            aufnehmen: { u in
                modell.entfernen(s.id, u.planUebung)
                Haptik.leicht()
            },
            beenden: { beenden(s) },
            cardio: { id in
                guard let u = UebungsKatalog.nachId[id] else { return }
                hinzufuegen(PlanUebung.neu(u))
                Haptik.leicht()
            }
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
        let tag = modell.tag(ich, id: s.tag)
        if let tag, let neu = WorkoutLogik.neuerTag(tag, liste) {
            planFrage = neu
        } else if tag == nil, WorkoutLogik.alsTag(liste, name: "") != nil {
            freiListe = liste
        } else {
            dismiss()
        }
    }

    /// Der neue Tag kommt in den Plan, die Einheit gehört danach zu ihm (gleiche Übungs-ids).
    private func alsTagSpeichern(_ liste: [WorkoutUebung]) {
        if let neu = WorkoutLogik.alsTag(liste, name: freiName) {
            modell.planSichern(TrainingLogik.tagSetzen(modell.plan(ich), neu))
            if let s = modell.sessions(ich).first(where: { $0.id == sessionId }) { modell.tagSetzen(s, neu.id) }
        }
        dismiss()
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
    /// Nur mit Messung (AirPods Pro 3, Pulsgurt); ohne Wert bleibt die Spalte weg.
    var puls: Int? = nil
    var kcal: Int? = nil
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
                if session.ende == nil {
                    Text("Halte eine Übung gedrückt, um sie auszulassen.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            schluss
        }
        .padding(16)
    }

    private var werte: some View {
        VStack(alignment: .leading, spacing: 12) {
            titel
            HStack(alignment: .top, spacing: 22) {
                wert("Dauer") { dauer.foregroundStyle(Color.blue) }
                wert("Volumen") { Text("\(TrainingLogik.kgText(WorkoutLogik.volumen(liste).rounded())) kg") }.popoverTip(VolumenTip())
                wert("Sätze") { Text("\(WorkoutLogik.saetzeZahl(liste))") }
                if let puls { wert(session.ende == nil ? "Puls" : "Puls im Schnitt") { Text("\(puls)").foregroundStyle(Color.red) } }
                if let kcal { wert("kcal") { Text("\(kcal)") } }
            }
            Divider()
        }
    }

    /// Der Name des Tages. Solange nichts abgehakt ist, öffnet ein Tipp die anderen Tage.
    @ViewBuilder
    private var titel: some View {
        let name = tag?.name ?? "Training"
        if session.ende == nil, tag != nil, tage.count > 1, WorkoutLogik.tagWechselbar(liste) {
            Menu {
                ForEach(tage) { t in
                    Button { aktionen.tagWaehlen(t) } label: {
                        if t.id == tag?.id {
                            Label(t.name.isEmpty ? "Ohne Namen" : t.name, systemImage: "checkmark")
                        } else {
                            Text(t.name.isEmpty ? "Ohne Namen" : t.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(name).font(.largeTitle.bold())
                    Image(systemName: "chevron.down.circle.fill").font(.title3).foregroundStyle(.secondary)
                }
                .foregroundStyle(Color.primary)
            }
            .accessibilityHint("Anderen Trainingstag wählen")
            .popoverTip(TrainingstagWechselnTip())
        } else {
            Text(name).font(.largeTitle.bold())
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
                    Text(untertitel(u, dran: dran)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    if u.fertig { Image(systemName: "checkmark") }
                    Text(zaehler(u))
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
        .accessibilityValue(zustand(u, dran: dran))
        .contextMenu { kontext(u) }
    }

    private func untertitel(_ u: WorkoutUebung, dran: Bool) -> String {
        if u.ausgelassen { return "Ausgelassen" }
        return dran ? "Jetzt dran" : unter(u)
    }

    private func zaehler(_ u: WorkoutUebung) -> String {
        u.ausgelassen ? "–" : "\(u.fertigZahl)/\(u.gesamt)"
    }

    private func zustand(_ u: WorkoutUebung, dran: Bool) -> String {
        if u.fertig { return "fertig" }
        if u.ausgelassen { return "ausgelassen" }
        return dran ? "jetzt dran" : ""
    }

    /// Lang drücken: Übung auslassen (Gerät besetzt) oder wieder aufnehmen. Nur Plan-Übungen ohne
    /// abgehakten Satz; im Training dazugekommene entfernt das Menü der Übung.
    @ViewBuilder
    private func kontext(_ u: WorkoutUebung) -> some View {
        if session.ende == nil, !u.extra {
            if u.ausgelassen {
                Button("Wieder aufnehmen", systemImage: "arrow.uturn.backward") { aktionen.aufnehmen(u) }
            } else if u.fertigZahl == 0 {
                Button("Auslassen", systemImage: "forward.end") { aktionen.auslassen(u) }
            }
        }
    }

    private func unter(_ u: WorkoutUebung) -> String {
        if let minuten = u.planUebung.minuten { return "\(minuten) min" }
        return u.planUebung.katalog.map { "\($0.muskel) · \($0.geraet)" } ?? "Eigene Übung"
    }

    @ViewBuilder
    private var leer: some View {
        if session.ende == nil, tag == nil, !tage.isEmpty {
            Text("Welcher Trainingstag?").font(.headline)
            gruppe(tage.map { (t: TrainingsTag) -> ListenZeile in
                (id: t.id, titel: t.name.isEmpty ? "Ohne Namen" : t.name, bild: "dumbbell", aktion: { aktionen.tagWaehlen(t) })
            })
        } else {
            Text("Noch keine Übung. Füg unten eine hinzu.").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    typealias ListenZeile = (id: String, titel: String, bild: String, aktion: () -> Void)

    /// Ruhige Inset-Gruppe: Zeilen mit Symbol und Chevron, getrennt durch Linien.
    private func gruppe(_ zeilen: [ListenZeile]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(zeilen.enumerated()), id: \.element.id) { i, z in
                if i > 0 { Divider().padding(.leading, 52) }
                Button(action: z.aktion) {
                    HStack(spacing: 12) {
                        Image(systemName: z.bild).frame(width: 28).foregroundStyle(Color.accentColor)
                        Text(z.titel).font(.body).foregroundStyle(Color.primary)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(uiColor: .tertiarySystemFill), in: .rect(cornerRadius: 14, style: .continuous))
    }

    /// Cardio-Kurzknöpfe unter "Übung hinzufügen" (Katalog-ids wie im Split 01).
    static let cardioSchnell: [(id: String, name: String, bild: String)] = [
        ("rjiM4L3", "Laufband", "figure.run"), ("j9Q5crt", "Stairmaster", "figure.stair.stepper"),
    ]

    @ViewBuilder
    private var schluss: some View {
        if session.ende == nil {
            let leerStart = tag == nil && liste.isEmpty
            Text(leerStart ? "Oder frei trainieren" : "Hinzufügen").font(.footnote).foregroundStyle(.secondary)
            let neu: ListenZeile = (id: "neu", titel: leerStart ? "Leeres Training" : "Übung hinzufügen", bild: "plus", aktion: aktionen.hinzufuegen)
            gruppe([neu] + Self.cardioSchnell.map { (c: (id: String, name: String, bild: String)) -> ListenZeile in
                (id: c.id, titel: c.name, bild: c.bild, aktion: { aktionen.cardio(c.id) }) })
                .popoverTip(CardioSchnellTip())
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
    /// Eine beendete Einheit korrigieren oder nachtragen (Rückblick): ohne Uhr und ohne untere Leiste,
    /// jede Änderung wird gleich gesendet.
    var nachtrag = false

    @State private var saetze: [PlanSatz] = []
    @State private var notiz = ""
    @State private var geladen = false
    @State private var animation: Uebung?
    @State private var scheibenOffen = false
    @AppStorage("gym.rpe") private var rpeAn = true
    @AppStorage(WorkoutLogik.satzzeitSchluessel) private var satzzeitAn = false
    @FocusState private var fokus: Bool
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var dismiss

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
        let frueher = fruehereTage(u)
        return List {
            Section {
                kopf(u)
                if !u.extra {
                    TextField("Notizen hier hinzufügen", text: $notiz, axis: .vertical).font(.subheadline)
                    pausenMenue(u)
                    Toggle("Satz-Zeit", isOn: $satzzeitAn).font(.subheadline.weight(.medium))
                }
            }
            .listRowSeparator(.hidden)
            DefektAbschnitt(sessionId: sessionId, uebung: u, saetze: $saetze, nachtrag: nachtrag)
            EinstellAbschnitt(person: ich, uebung: u.planUebung)
            AusweichAbschnitt(sessionId: sessionId, uebung: u, saetze: $saetze, nachtrag: nachtrag)
            Section {
                if !saetze.isEmpty { TipView(SatzWischenTip()).listRowSeparator(.hidden) }
                tabellenKopf.listRowSeparator(.hidden)
                ForEach(saetze.indices, id: \.self) { i in zeile(u, i, frueher) }
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !nachtrag { leiste(u, liste) }
        }
        .sheet(item: $animation) { a in
            NavigationStack { UebungDetail(uebung: a) }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $scheibenOffen) { ScheibenBlatt(kg: arbeitsgewicht ?? 60) }
        .onAppear { laden(u) }
        .onDisappear { sichern() }
        .onChange(of: phase) { _, neu in
            if neu == .active { neuLaden() } else if neu == .background { sichern() }
        }
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

    /// Diese Übung in allen Einheiten vor dieser (für die Rekord-Marke).
    private func fruehereTage(_ u: WorkoutUebung) -> [UebungTag] {
        let alle = modell.sessions(ich)
        guard let jetzt = alle.first(where: { $0.id == sessionId }) else { return [] }
        return RekordLogik.tage(katalogId: u.planUebung.uebung, planId: planId, in: alle.filter { $0.start < jetzt.start })
    }

    /// Bricht dieser eine Satz einen Rekord (Gewicht, One-Rep-Max oder Satzvolumen)?
    private func rekord(_ i: Int, _ frueher: [UebungTag]) -> String? {
        guard saetze.indices.contains(i), saetze[i].zaehlt else { return nil }
        return RekordLogik.neue([saetze[i]], gegen: frueher, arten: [.gewicht, .e1rm, .satzVolumen]).first?.titel
    }

    private func zeile(_ u: WorkoutUebung, _ i: Int, _ frueher: [UebungTag]) -> some View {
        let fertig = saetze.indices.contains(i) && saetze[i].ok == true
        return WorkoutSatzZeile(
            nummer: WorkoutLogik.nummer(saetze, i),
            satz: bindung(i),
            vorher: u.vorher.indices.contains(i) ? u.vorher[i] : nil,
            rpe: rpeAn,
            satzzeit: satzzeitAn,
            laeuft: laufenderSatz == i,
            rekord: rekord(i, frueher),
            typ: { t in
                if saetze.indices.contains(i) { saetze[i].setzeTyp(t) }
                Haptik.auswahl()
            },
            haken: { haken(u, i) }
        )
        .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
        .listRowSeparator(.hidden)
        .listRowBackground(fertig ? Color.green.opacity(0.2) : Color.clear)
        .swipeActions(allowsFullSwipe: false) {
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
            } else if saetze.isEmpty {
                Button("Übung wieder aufnehmen", systemImage: "arrow.uturn.backward") { aufnehmen(u) }
            } else {
                Button("Übung auslassen", systemImage: "forward.end") { auslassen() }
                    .disabled(saetze.contains { $0.ok == true })
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Mehr")
        .popoverTip(UebungMehrTip())
    }

    private func leiste(_ u: WorkoutUebung, _ liste: [WorkoutUebung]) -> WorkoutLeiste {
        let stand = WorkoutUhr.shared.stand.flatMap { $0.session == sessionId ? $0 : nil }
        guard let offener = saetze.firstIndex(where: { $0.ok != true }) else {
            let kraft = liste.filter { $0.id != u.id && !$0.fertig && !$0.planUebung.istCardio }
            let danach = liste.drop { $0.id != u.id }.dropFirst().first { !$0.fertig && !$0.planUebung.istCardio }
            let naechste = danach ?? kraft.first
            return WorkoutLeiste(
                titel: saetze.isEmpty ? "Übung ausgelassen" : "Übung fertig",
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

    /// Zurück aus dem Hintergrund: der Knopf am Sperrbildschirm kann Sätze abgehakt haben.
    private func neuLaden() {
        guard geladen, let u = modell.workout(sessionId).first(where: { $0.id == planId }) else { return }
        saetze = u.saetze
    }

    /// Beim Verlassen: getippte Werte senden und die Notiz in den Plan schreiben, falls geändert.
    private func sichern() {
        guard geladen, let u = modell.workout(sessionId).first(where: { $0.id == planId }) else { return }
        let laeuft = modell.sessions(ich).first { $0.id == sessionId }?.ende == nil
        let darf = nachtrag || laeuft
        if darf, saetze != u.saetze { modell.saetzeSenden(sessionId, u.planUebung, saetze) }
        let neu = notiz.trimmingCharacters(in: .whitespacesAndNewlines)
        if !u.extra, neu != (u.planUebung.notiz ?? "") {
            modell.planSichern(TrainingLogik.aendern(modell.plan(ich), planUebung: planId) { $0.notiz = neu.isEmpty ? nil : neu })
        }
    }

    private func haken(_ u: WorkoutUebung, _ i: Int) {
        let vorher = saetze.indices.contains(i) && saetze[i].ok == true
        if nachtrag {
            saetze = WorkoutLogik.hakenNachtrag(saetze, i)
            modell.saetzeSenden(sessionId, u.planUebung, saetze)
        } else {
            saetze = WorkoutAktion.haken(sessionId, u.planUebung, saetze, i)
        }
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
        // Beendete Einheit: die Uhr gehört zum laufenden Training, nicht anfassen.
        guard !nachtrag, WorkoutUhr.shared.stand?.plan == planId else { return }
        WorkoutUhr.shared.aus()
    }

    /// Zurück zur Übersicht, oder aus dem Rückblick heraus.
    private func zurueck() {
        if nachtrag { dismiss() } else { wechseln(nil) }
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
        zurueck()
    }

    /// Ein leerer Stand wird gesendet (`sichern`); die Plan-Sätze bleiben im Plan.
    private func auslassen() {
        uhrAus()
        saetze = []
        sichern()
        Haptik.leicht()
        zurueck()
    }

    /// "weg" nimmt den leeren Stand zurück: die Zeilen kommen wieder aus dem Plan.
    private func aufnehmen(_ u: WorkoutUebung) {
        modell.entfernen(sessionId, u.planUebung)
        saetze = WorkoutLogik.zeilen(u.planUebung, lauf: nil, vorher: u.vorher)
        Haptik.leicht()
    }
}

/// Eine Satzzeile wie in Hevy: Nummer (Tipp wählt den Typ), Vorher, kg, Wdh, RPE, Haken. Darunter
/// Satz- und Pausenzeit, wenn gemessen.
struct WorkoutSatzZeile: View {
    let nummer: String
    @Binding var satz: PlanSatz
    let vorher: PlanSatz?
    var rpe = true
    var satzzeit = false
    var laeuft = false
    /// "Schwerstes Gewicht": dieser Satz bricht einen persönlichen Rekord.
    var rekord: String? = nil
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
            if fertig, let rekord {
                Label("Rekord: \(rekord)", systemImage: "medal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.orange)
                    .padding(.leading, 50)
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
        return WorkoutLogik.zeitenText(sek: satz.sek, pause: satz.pause, satzzeit: satzzeit)
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
