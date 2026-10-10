import SwiftUI
import UserNotifications

/// Chat mit dem Coach. Die Antwort kommt als Strom vom Server und baut sich Wort für Wort auf.
/// Der Coach kennt dein Ziel, was du heute gegessen hast, Schritte und Schlaf.
struct CoachView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var nachrichten: [EssenCoachNachricht] = []
    @State private var eingabe = ""
    @State private var antwortet = false
    @State private var fehlerText: String?
    @State private var aufgabe: Task<Void, Never>?
    /// Vom Coach eingetragene Mahlzeiten je Coach-Nachricht (für "Rückgängig").
    @State private var eingetragen: [UUID: [EssenMahlzeit]] = [:]

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private let vorschlaege = ["Was esse ich heute noch?", "Wie läuft mein Tag?", "Was kann ich statt Süßem essen?"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if nachrichten.isEmpty { vorschlagsZeile }
                            ForEach(nachrichten) { n in
                                blase(n).id(n.id)
                            }
                            if let fehlerText {
                                Text(fehlerText).font(.footnote).foregroundStyle(.red)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: nachrichten.last?.text) { _, _ in
                        if let id = nachrichten.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
                Divider()
                eingabeleiste
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .onDisappear { aufgabe?.cancel() }
    }

    private var vorschlagsZeile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frag mich etwas zu Essen, Training oder deinem Tag.").foregroundStyle(.secondary)
            ForEach(vorschlaege, id: \.self) { text in
                Button(text) { senden(text) }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func blase(_ n: EssenCoachNachricht) -> some View {
        let vonMir = n.rolle == "nutzer"
        let text = vonMir ? n.text : CoachMarker.zerlegen(n.text).text
        return VStack(alignment: vonMir ? .trailing : .leading, spacing: 4) {
            HStack {
                if vonMir { Spacer(minLength: 40) }
                Text(text.isEmpty ? "…" : text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(vonMir ? Color.personText(ich) : Color.primary)
                    .background(vonMir ? Color.person(ich) : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    .textSelection(.enabled)
                if !vonMir { Spacer(minLength: 40) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(vonMir ? "Du" : "Coach"): \(text)")
            ForEach(eingetragen[n.id] ?? []) { m in
                HStack(spacing: 8) {
                    Label("Eingetragen: \(m.titel), \(m.kcal) kcal", systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                    Button("Rückgängig") { rueckgaengig(m, in: n.id) }
                        .font(.footnote)
                }
            }
        }
    }

    /// Trägt die Mahlzeiten aus den Markern der fertigen Antwort ein und ersetzt den Text durch die bereinigte Fassung.
    private func eintragen(inLetzterNachricht person: Person) {
        guard let i = nachrichten.indices.last, nachrichten[i].rolle == "coach" else { return }
        let zerlegt = CoachMarker.zerlegen(nachrichten[i].text)
        nachrichten[i].text = zerlegt.text
        guard !zerlegt.essen.isEmpty else { return }
        let jetzt = Date()
        let neu = zerlegt.essen.map { EssenMahlzeit.vomCoach($0, tag: Datum.text(jetzt), zeit: jetzt) }
        neu.forEach { EssenStore.shared.speichern($0, fuer: person) }
        eingetragen[nachrichten[i].id] = neu
    }

    private func rueckgaengig(_ m: EssenMahlzeit, in nachricht: UUID) {
        EssenStore.shared.loeschen(m.id, fuer: ich)
        eingetragen[nachricht]?.removeAll { $0.id == m.id }
    }

    private var eingabeleiste: some View {
        HStack(spacing: 8) {
            TextField("Nachricht", text: $eingabe, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit { senden(eingabe) }
            Button {
                senden(eingabe)
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
            }
            .disabled(antwortet || eingabe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Senden")
        }
        .padding(12)
    }

    private func senden(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !antwortet else { return }
        eingabe = ""
        fehlerText = nil
        nachrichten.append(EssenCoachNachricht(rolle: "nutzer", text: t))
        let verlauf = nachrichten.filter { !$0.text.isEmpty }
        nachrichten.append(EssenCoachNachricht(rolle: "coach", text: ""))
        antwortet = true
        let person = ich
        let profil = EssenKontext.profil(person)
        let tag = EssenKontext.tag(person, tag: Datum.text(Date()))
        let kontext = EssenKontext.gesundheitsZeilen(person, heute: Datum.text(Date()))
        aufgabe = Task {
            do {
                for try await stueck in KiClient.coach(nachrichten: verlauf, profil: profil, tag: tag, kontext: kontext) {
                    if let i = nachrichten.indices.last { nachrichten[i].text += stueck }
                }
            } catch {
                fehlerText = (error as? LocalizedError)?.errorDescription ?? "Das hat nicht geklappt."
            }
            eintragen(inLetzterNachricht: person)
            if nachrichten.last?.rolle == "coach", nachrichten.last?.text.isEmpty == true { nachrichten.removeLast() }
            antwortet = false
        }
    }
}

/// Tagesbericht: kurze Auswertung des heutigen Tages mit Blick auf die letzten Tage.
/// Der Bericht von heute wird auf dem Gerät gemerkt, damit er nicht bei jedem Öffnen neu Geld kostet.
struct BerichtView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bericht: KiBericht?
    @State private var laedt = false
    @State private var fehlerText: String?

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var heute: String { Datum.text(Date()) }
    private var merkSchluessel: String { "lovea.essen.bericht.\(ich.rawValue).\(heute)" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let bericht {
                        inhalt(bericht)
                    } else if laedt {
                        ProgressView("Ich schreibe deinen Bericht …").frame(maxWidth: .infinity)
                    } else {
                        Text("Der Bericht fasst deinen Tag zusammen: was gut lief, was besser geht und was morgen dran ist.")
                            .foregroundStyle(.secondary)
                        Button("Bericht erstellen") { erstellen() }
                            .buttonStyle(.borderedProminent)
                    }
                    if let fehlerText { Text(fehlerText).font(.footnote).foregroundStyle(.red) }
                }
                .padding(16)
            }
            .navigationTitle("Tagesbericht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                if bericht != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Neu", systemImage: "arrow.clockwise") { erstellen() }.disabled(laedt)
                    }
                }
            }
        }
        .onAppear { gemerktLaden() }
    }

    private func inhalt(_ b: KiBericht) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(b.titel).font(.title2.bold())
            Text(b.kurzfassung)
            liste("Das lief gut", b.wasGut, symbol: "checkmark.circle.fill", farbe: .green)
            liste("Das geht besser", b.wasBesser, symbol: "arrow.up.circle.fill", farbe: .orange)
            liste("Morgen", b.morgen, symbol: "sun.max.fill", farbe: .yellow)
        }
    }

    @ViewBuilder
    private func liste(_ titel: String, _ punkte: [String], symbol: String, farbe: Color) -> some View {
        if !punkte.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(titel).font(.headline)
                ForEach(punkte, id: \.self) { punkt in
                    Label {
                        Text(punkt)
                    } icon: {
                        Image(systemName: symbol).foregroundStyle(farbe)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func gemerktLaden() {
        guard bericht == nil, let daten = UserDefaults.standard.data(forKey: merkSchluessel),
              let gemerkt = try? JSONDecoder().decode(KiBericht.self, from: daten)
        else { return }
        bericht = gemerkt
    }

    private func erstellen() {
        guard !laedt else { return }
        let tag = EssenKontext.tag(ich, tag: heute)
        guard tag.kcalGegessen != nil else {
            fehlerText = "Trag zuerst mindestens eine Mahlzeit ein."
            return
        }
        laedt = true
        fehlerText = nil
        let profil = EssenKontext.profil(ich)
        let vortage = EssenKontext.vortage(ich, vor: heute)
        let schluessel = merkSchluessel
        Task {
            do {
                let neu = try await KiClient.bericht(profil: profil, tag: tag, vortage: vortage)
                bericht = neu
                if let daten = try? JSONEncoder().encode(neu) { UserDefaults.standard.set(daten, forKey: schluessel) }
            } catch {
                fehlerText = (error as? LocalizedError)?.errorDescription ?? "Das hat nicht geklappt."
            }
            laedt = false
        }
    }
}

/// Ziele und die abendliche Erinnerung an den Tagesbericht.
struct EssenZieleView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lovea.essen.erinnerung") private var erinnerung = false
    @State private var ziele = EssenZiele()

    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ziel") {
                    Picker("Ziel", selection: $ziele.ziel) {
                        ForEach(["cut", "halten", "aufbauen"], id: \.self) { Text(EssenZiele.titel($0)).tag($0) }
                    }
                    Stepper(value: $ziele.kcal, in: EssenZiele.mindestKcal...6000, step: 50) {
                        Text("\(ziele.kcal) kcal pro Tag").monospacedDigit()
                    }
                    Stepper(value: $ziele.protein, in: 0...400, step: 5) {
                        Text("\(ziele.protein) g Eiweiß pro Tag").monospacedDigit()
                    }
                }
                Section {
                    Text("Weniger als \(EssenZiele.mindestKcal) kcal pro Tag empfiehlt Lovea nie. Das ist die Untergrenze für Coach und Bericht.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Toggle("Erinnerung um 21 Uhr", isOn: $erinnerung)
                } footer: {
                    Text("Eine Mitteilung auf diesem Gerät: \"Dein Tagesbericht wartet.\" Ohne Inhalte.")
                }
            }
            .navigationTitle("Ziele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        EssenStore.shared.setzeZiele(ziele, fuer: ich)
                        dismiss()
                    }
                }
            }
        }
        .onAppear { ziele = EssenStore.shared.ziele(ich) }
        .onChange(of: erinnerung) { _, neu in
            Task { await EssenErinnerung.setzen(neu) }
        }
    }
}

enum EssenErinnerung {
    static let kennung = "lovea.essen.bericht"

    /// Plant (oder löscht) die tägliche Erinnerung um 21 Uhr. Fragt bei Bedarf nach der Erlaubnis.
    static func setzen(_ an: Bool) async {
        let zentrum = UNUserNotificationCenter.current()
        zentrum.removePendingNotificationRequests(withIdentifiers: [kennung])
        guard an else { return }
        let erlaubt = (try? await zentrum.requestAuthorization(options: [.alert, .sound])) ?? false
        guard erlaubt else { return }
        let inhalt = UNMutableNotificationContent()
        inhalt.title = "Lovea"
        inhalt.body = "Dein Tagesbericht wartet."
        var zeit = DateComponents()
        zeit.hour = 21
        zeit.minute = 0
        let ausloeser = UNCalendarNotificationTrigger(dateMatching: zeit, repeats: true)
        try? await zentrum.add(UNNotificationRequest(identifier: kennung, content: inhalt, trigger: ausloeser))
    }
}
