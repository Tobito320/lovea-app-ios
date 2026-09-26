import SwiftUI

/// Z-9.6 / Z-42.2 Treffen-Tag: Herz, Uhrzeit, „Was machen wir", Notizen beider mit Namen,
/// Checkliste, „Zum iPhone-Kalender". Text, Uhrzeit und die eigene Notiz speichern sich nach 1 s
/// Tipp-Pause, beim Verlassen und beim Wechsel in den Hintergrund, nicht nur mit Enter. „Sichern"
/// (und Enter) gibt Haptik, „Gespeichert" steht sichtbar daneben.
struct TreffenTagView: View {
    let datum: String
    let kalender = KalenderModell.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var wasMachenWir = ""
    @State private var uhrzeit: String?
    @State private var notiz = ""
    /// Stand beim Laden oder letzten Senden, siehe `TreffenEntwurf`.
    @State private var basis = TreffenEntwurf()
    @State private var gesichert: Set<Feld> = []
    @State private var neueAufgabe = ""
    @State private var zeigtExport = false
    @State private var fragtAbsage = false

    private enum Feld { case treffen, notiz }

    private var eintrag: KalenderModell.TreffenEintrag? { kalender.zustand.treffenText[datum] }
    private var checkliste: [KalenderModell.ChecklistEintrag] { kalender.zustand.checklisten[datum] ?? [] }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    /// Was die Felder gerade zeigen.
    private var entwurf: TreffenEntwurf {
        TreffenEntwurf(text: wasMachenWir.trimmingCharacters(in: .whitespaces), uhrzeit: uhrzeit, notiz: notiz)
    }

    /// Was gerade im Log steht (Faltung).
    private var gespeichert: TreffenEntwurf {
        TreffenEntwurf(text: eintrag?.text ?? "", uhrzeit: eintrag?.uhrzeit, notiz: kalender.zustand.notizen[datum]?[ich] ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label(Datum.anzeige(datum), systemImage: "heart.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.loveaRose)
                    .accessibilityAddTraits(.isHeader)
                vorherigeFassung
                treffenAbschnitt
                notizenAbschnitt
                checklisteAbschnitt
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Treffen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { mehr }
        }
        .onAppear(perform: uebernehmen)
        .onChange(of: gespeichert) { _, _ in uebernehmen() }
        .task(id: entwurf) {
            // Autosave nach 1 s Tipp-Pause; jede neue Eingabe bricht die Wartezeit ab.
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled { speichern() }
        }
        .onDisappear { speichern() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { speichern() } }
        .sheet(isPresented: $zeigtExport) { exportBlatt }
        .confirmationDialog("Treffen absagen?", isPresented: $fragtAbsage, titleVisibility: .visible) {
            Button("Treffen absagen", role: .destructive, action: absagen)
        } message: {
            Text("Das Herz verschwindet für euch beide aus dem Kalender.")
        }
    }

    // MARK: - Abschnitte

    @ViewBuilder
    private var vorherigeFassung: some View {
        if let vorherige = eintrag?.vorherige {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vorherige Fassung von \(vorherige.von.name)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(vorherige.text)
                    .font(.callout)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var treffenAbschnitt: some View {
        VStack(alignment: .leading, spacing: 10) {
            ueberschrift("Was machen wir", gespeichert: gesichert.contains(.treffen) && entwurf.text == basis.text && uhrzeit == basis.uhrzeit)
            TextField("z. B. Kino", text: $wasMachenWir)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit { sichern(.treffen) }
            ZeitWahl(datum: datum, start: $uhrzeit, ohneZeit: "Offen")
            Button("Sichern") { sichern(.treffen) }
                .buttonStyle(.borderedProminent)
                .tint(Color.loveaRose)
                .disabled(entwurf.text.isEmpty)
        }
    }

    private var notizenAbschnitt: some View {
        VStack(alignment: .leading, spacing: 8) {
            ueberschrift("Notizen", gespeichert: gesichert.contains(.notiz) && notiz == basis.notiz)
            ForEach(Person.allCases, id: \.self) { person in
                notizZeile(person)
            }
        }
    }

    private var checklisteAbschnitt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Checkliste")
                .font(.subheadline.weight(.semibold))
            ForEach(checkliste) { aufgabe in
                checklistZeile(aufgabe)
            }
            HStack {
                TextField("Neuer Punkt", text: $neueAufgabe)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { aufgabeHinzufuegen() }
                Button("Hinzufügen", action: aufgabeHinzufuegen)
                    .disabled(neueAufgabe.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var mehr: some View {
        Menu {
            Button("Zum iPhone-Kalender", systemImage: "calendar.badge.plus") { zeigtExport = true }
            if eintrag != nil {
                Button("Treffen absagen", systemImage: "heart.slash", role: .destructive) { fragtAbsage = true }
            }
        } label: {
            Label("Mehr", systemImage: "ellipsis")
        }
    }

    private var exportBlatt: some View {
        let start = IPhoneKalenderDatum.kombiniert(datum, uhrzeit)
        return IPhoneKalenderExportBlatt(titel: entwurf.text.isEmpty ? "Treffen" : entwurf.text, start: start, ende: start.addingTimeInterval(2 * 60 * 60))
    }

    private func ueberschrift(_ titel: String, gespeichert: Bool) -> some View {
        HStack {
            Text(titel)
                .font(.subheadline.weight(.semibold))
            Spacer()
            if gespeichert {
                Label("Gespeichert", systemImage: "checkmark")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(Feder.weich, value: gespeichert)
    }

    private func notizZeile(_ person: Person) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(person.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.person(person))
            if person == ich {
                TextField("Deine Notiz", text: $notiz)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit { sichern(.notiz) }
            } else {
                let text = kalender.zustand.notizen[datum]?[person] ?? ""
                Text(text.isEmpty ? "Noch keine Notiz" : text)
                    .font(.callout)
                    .foregroundStyle(text.isEmpty ? .secondary : .primary)
            }
        }
    }

    private func checklistZeile(_ aufgabe: KalenderModell.ChecklistEintrag) -> some View {
        HStack {
            Button {
                if !aufgabe.erledigt { Haptik.erfolg() }
                Raum.shared.senden("checkliste.setzen", CheckOp(datum: datum, id: aufgabe.id, text: aufgabe.text, erledigt: !aufgabe.erledigt))
            } label: {
                Image(systemName: aufgabe.erledigt ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(aufgabe.erledigt ? Color.loveaRose : .secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(aufgabe.text)
            .accessibilityValue(aufgabe.erledigt ? "erledigt" : "offen")
            Text(aufgabe.text)
                .strikethrough(aufgabe.erledigt)
                .foregroundStyle(aufgabe.erledigt ? .secondary : .primary)
                .accessibilityHidden(true)
            Spacer()
            Button {
                Raum.shared.senden("checkliste.loeschen", ["datum": datum, "id": aufgabe.id])
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("„\(aufgabe.text)“ löschen")
        }
        .buttonStyle(.plain)
    }

    // MARK: - Speichern

    /// Übernimmt den Stand aus dem Log in alle Felder, die gerade nicht bearbeitet werden. Nach dem
    /// eigenen Senden ändert sich nichts Sichtbares (kein Zurücksetzen mitten im Tippen).
    private func uebernehmen() {
        let neu = gespeichert
        let jetzt = entwurf
        if jetzt.text == basis.text, jetzt.uhrzeit == basis.uhrzeit {
            if neu.text != jetzt.text { wasMachenWir = neu.text }
            if neu.uhrzeit != jetzt.uhrzeit { uhrzeit = neu.uhrzeit }
            basis.text = neu.text
            basis.uhrzeit = neu.uhrzeit
        }
        if jetzt.notiz == basis.notiz {
            if neu.notiz != jetzt.notiz { notiz = neu.notiz }
            basis.notiz = neu.notiz
        }
    }

    /// Sendet nur, was sich seit `basis` geändert hat (Autosave, Verlassen, Hintergrund).
    private func speichern() {
        let jetzt = entwurf
        if let treffen = jetzt.treffen(datum, seit: basis) {
            Raum.shared.senden("treffen.setzen", treffen)
            basis.text = jetzt.text
            basis.uhrzeit = jetzt.uhrzeit
            gesichert.insert(.treffen)
        }
        if let neueNotiz = jetzt.neueNotiz(seit: basis) {
            Raum.shared.senden("notiz.setzen", ["datum": datum, "text": neueNotiz])
            basis.notiz = neueNotiz
            gesichert.insert(.notiz)
        }
    }

    /// „Sichern" und Enter: speichern, sichtbar bestätigen, Haptik.
    private func sichern(_ feld: Feld) {
        if feld == .treffen, entwurf.text.isEmpty { return }
        speichern()
        gesichert.insert(feld)
        Haptik.erfolg()
    }

    private func absagen() {
        Raum.shared.senden("treffen.loeschen", ["datum": datum])
        basis.text = entwurf.text // nichts mehr nachsenden, auch nicht beim Verlassen
        basis.uhrzeit = entwurf.uhrzeit
        Haptik.leicht()
        dismiss()
    }

    private func aufgabeHinzufuegen() {
        let text = neueAufgabe.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        Raum.shared.senden("checkliste.setzen", CheckOp(datum: datum, id: UUID().uuidString, text: text, erledigt: false))
        Haptik.leicht()
        neueAufgabe = ""
    }
}

private struct CheckOp: Codable { var datum: String; var id: String; var text: String; var erledigt: Bool }
