import SwiftUI

/// Z-15.2: Einstellungen im iOS-Listen-Stil, geöffnet über das Zahnrad im eigenen Profil.
struct EinstellungenView: View {
    let person: Person
    @ObservedObject var session: PersonSession
    @AppStorage("profile.performanceHUD.v2") private var showsHUD = false
    @AppStorage("lovea.haptik") private var haptik = true // Z-31.1: same key `Haptik.an` reads
    @AppStorage(SnapBildAusrichtung.schluessel) private var selfieSpiegeln = false
    @AppStorage(SnapFilterAnzeige.schluessel) private var kameraFilter = true // same key `SnapFilterAnzeige.an` reads
    @AppStorage(ChatTempo.schluessel) private var chatTempo = true // same key `ChatTempo.an` reads
    @AppStorage(TabWischLogik.schluessel) private var tabWischen = true
    @AppStorage(KalenderNeu.schluessel) private var kalenderNeu = true // same key `KalenderNeu.an` reads
    @AppStorage(GymNeu.schluessel) private var gymNeu = true // same key `GymNeu.an` reads
    @AppStorage(StartPlan.schluessel) private var schnellerStart = true // same key `StartPlan.an` reads
    @AppStorage(AirPodsPro3.schluessel) private var airpodsPro3 = AirPodsPro3.startwert // same key `AirPodsPro3.an` reads
    @AppStorage(BettErinnerung.schluessel) private var bettErinnerung = false
    @State private var zeigtEntwickler = false
    @AppStorage(MedienKodierung.videoSchnellSchluessel) private var videoSchnell = true // same key `MedienKodierung.videoSchnell` reads
    @AppStorage(VideoVorab.schluessel) private var videoVorab = true // same key `VideoVorab.an` reads

    var body: some View {
        List {
            Section("Mitteilungen") {
                NavigationLink("Mitteilungen") { MitteilungenListe() }
            }
            Section("Figur") {
                NavigationLink("Meine Figur") { FigurEditorSeite(person: person) }
                NavigationLink("Szenen gestalten") { SzenenUebersicht(person: person) }
            }
            Section {
                Toggle("Selfie-Foto und -Video gespiegelt", isOn: $selfieSpiegeln)
                Toggle("Kamera-Filter anzeigen", isOn: $kameraFilter)
            } header: {
                Text("Kamera")
            } footer: {
                Text("Gespiegelt: Selfie-Foto und -Video sehen aus wie die Vorschau, wie in der iPhone-Kamera. Die Rückkamera bleibt immer ungespiegelt. Filter aus: keine Filterleiste und kein Wischen zwischen Filtern, das Bild bleibt original.")
            }
            Section {
                NavigationLink("Duell-Wörter") { DuellWoerterEditor() }
                Toggle("Chat-Tempo (Test)", isOn: $chatTempo)
                Toggle("Videos schneller senden (Test)", isOn: $videoSchnell)
                Toggle("Videos vorab hochladen (Test)", isOn: $videoVorab)
            } header: {
                Text("Chat")
            } footer: {
                Text("Schont das Scrollen im Chat. Gilt ab dem nächsten Öffnen des Chats. Aus: wie vorher.")
            }
            if person == .ahmed { AhmedHilfeEinstellungen() }
            Section("Wir") {
                NavigationLink("Orte") { OrteListeView() }
                NavigationLink("Jahrestag") { JahrestagEditor() }
                NavigationLink("Wochenplan") { WochenplanEditor() }
                Toggle("Neuer Kalender", isOn: $kalenderNeu)
                FaceTimeKontaktZeile()
                SpotifyVerbindenRow()
            }
            Section("Gym") {
                Toggle("Neues Gym", isOn: $gymNeu)
            }
            Section {
                Toggle("Ich habe AirPods Pro 3", isOn: $airpodsPro3)
                    .onChange(of: airpodsPro3) { _, neu in if !neu { WorkoutPuls.shared.beenden(speichern: false) } }
            } header: {
                Text("Geräte")
            } footer: {
                Text("Gilt für alles: Puls im Training, Kopfhörer-Ton beim Schlaf. Puls kostet nur während eines Trainings Akku.")
            }
            Section {
                Toggle("Bettzeit-Erinnerung", isOn: $bettErinnerung)
                    .onChange(of: bettErinnerung) { _, _ in HealthModell.shared.bettErinnerungAktualisieren() }
            } header: {
                Text("Schlaf")
            } footer: {
                Text("Eine stille Mitteilung 30 Minuten vor deiner üblichen Bettzeit. Die Zeit lernt die App aus deinen sicheren Nächten.")
            }
            Section {
                Toggle("Haptik", isOn: $haptik)
                NavigationLink("Erweitert") { SonstigesErweitert(session: session, zeigtEntwickler: $zeigtEntwickler, showsHUD: $showsHUD, tabWischen: $tabWischen, schnellerStart: $schnellerStart) }
            } header: {
                Text("Sonstiges")
            }
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Szenen (Räume gestalten)

private struct SzenenUebersicht: View {
    let person: Person
    @State private var szenenOrt: RaumOrt?

    var body: some View {
        List {
            ForEach(RaumOrt.allCases) { ort in
                Button { szenenOrt = ort } label: {
                    HStack(spacing: 12) {
                        Label(ort.titel, systemImage: ort.symbol)
                        Spacer()
                        ZimmerKachel(zimmer: Zimmer.von(person, ort: ort), ort: ort, art: .raum, aussehen: FigurenModell.shared.aussehen(person))
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Szenen gestalten")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $szenenOrt) { ort in NavigationStack { ZimmerEditor(person: person, ort: ort) } }
    }
}

// MARK: - Sonstiges, seltene und technische Schalter

private struct SonstigesErweitert: View {
    @ObservedObject var session: PersonSession
    @Binding var zeigtEntwickler: Bool
    @Binding var showsHUD: Bool
    @Binding var tabWischen: Bool
    @Binding var schnellerStart: Bool

    var body: some View {
        List {
            Section {
                Toggle("Zwischen Tabs wischen", isOn: $tabWischen)
            } footer: {
                Text("Nach links oder rechts wischen wechselt zwischen Home, Chat, Zeichnen, Health und Profil.")
            }
            Section {
                Toggle("Schneller Start (Test)", isOn: $schnellerStart)
            } footer: {
                Text("Galerie-Sync und Widget starten erst nach dem ersten Bild. Gilt ab dem nächsten App-Start. Aus: wie vorher.")
            }
            Section {
                Text("Version \(Bundle.main.appVersion)")
                    .foregroundStyle(.secondary)
                    .onTapGesture(count: 7) { zeigtEntwickler = true }
                // audit-app #8: a debug tool, gated behind the same 7-tap reveal as the rest of this
                // section instead of sitting permanently in the production settings list.
                if zeigtEntwickler {
                    Toggle("Leistungsanzeige", isOn: $showsHUD)
                    NavigationLink("Chat-Leistung") { ChatPerfView() }
                    Menu {
                        ForEach(Person.allCases, id: \.self) { kandidat in
                            Button(kandidat.name) { session.waehlen(kandidat) }
                        }
                    } label: {
                        Text("Person wechseln").frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } header: {
                Text("Entwickler")
            }
        }
        .navigationTitle("Erweitert")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Bundle {
    var appVersion: String {
        let kurz = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(kurz) (\(build))"
    }
}

// MARK: - Mitteilungen (Spec 12)

private struct Kategorie: Identifiable {
    let id: String
    let titel: String
}

private struct MitteilungenListe: View {
    let modell = EinstellungenModell.shared
    private static let kategorien: [Kategorie] = [
        Kategorie(id: "chat", titel: "Chat"), Kategorie(id: "snap", titel: "Snaps"),
        Kategorie(id: "geste", titel: "Gesten"), Kategorie(id: "kalender", titel: "Kalender"),
        Kategorie(id: "orte", titel: "Orte"), Kategorie(id: "zeichnen", titel: "Zeichnen"),
        Kategorie(id: "spiele", titel: "Spiele"), Kategorie(id: "gym", titel: "Gym"),
    ]

    var body: some View {
        List(Self.kategorien) { kategorie in
            Toggle(kategorie.titel, isOn: Binding(
                get: { modell.bool("mitteilungen.\(kategorie.id)", default: true) },
                set: { modell.setzen("mitteilungen.\(kategorie.id)", .bool($0)) }
            ))
        }
        .navigationTitle("Mitteilungen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Figuren-Editor-Seite

/// Internal (not `private`): Profile/ProfileView.swift reuses this exact wrapper instead of duplicating the
/// `FigurEditor` navigation chrome. p65 C: `.figur` is "Meine Figur" (Einstellungen and the profile's "Profil"
/// button), `.kleidung` is the wardrobe behind the profile's "Kleidung" button, with the Shop button.
struct FigurEditorSeite: View {
    let person: Person
    var bereich: FigurEditor.Bereich = .figur
    @Environment(\.dismiss) private var dismiss
    @State private var shopOffen = false

    var body: some View {
        FigurEditor(start: FigurenModell.shared.aussehen(person), modell: FigurenModell.shared.aussehen(person), bereich: bereich, person: person) { neu in
            FigurenModell.shared.aussehenSichern(neu.mitShopTeilen(von: FigurenModell.shared.aussehen(person)), fuer: person)
            dismiss()
        }
        .navigationTitle(titel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Z-23.2: Shop reachable from the wardrobe too (Spec §4.3).
            if bereich == .kleidung {
                ToolbarItem(placement: .primaryAction) { Button("Shop") { shopOffen = true } }
            }
        }
        .sheet(isPresented: $shopOffen) { ShopView(ziel: person) }
    }

    /// p68: Ahmed edits Annika's figure from her profile; the title says whose it is.
    private var titel: String {
        let fremd = person != (Raum.shared.ich ?? .ahmed)
        if bereich == .figur { return fremd ? "\(person.name)s Figur" : "Meine Figur" }
        return fremd ? "\(person.name)s Kleidung" : "Kleidung"
    }
}

// MARK: - Jahrestag

private struct JahrestagEditor: View {
    @State private var datum = Datum.datum("2026-08-26")

    var body: some View {
        Form {
            DatePicker("Jahrestag", selection: $datum, displayedComponents: .date)
                .datePickerStyle(.graphical)
        }
        .navigationTitle("Jahrestag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") { Raum.shared.senden("jahrestag.setzen", ["datum": Datum.text(datum)]) }
            }
        }
        .onAppear {
            if let bestehend = KalenderModell.shared.zustand.jahrestag { datum = Datum.datum(bestehend) }
        }
    }
}

// MARK: - Duell-Wörter (Spec 11, Kritzel-Duell)

private struct DuellWoerterEditor: View {
    let modell = EinstellungenModell.shared
    @State private var neuesWort = ""

    private var woerter: [String] { modell.stringListe("duellWoerter") }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Neues Wort", text: $neuesWort)
                        .onSubmit(hinzufuegen)
                    Button("Hinzufügen", action: hinzufuegen)
                        .disabled(neuesWort.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section {
                ForEach(woerter, id: \.self) { wort in Text(wort) }
                    .onDelete { indexSet in
                        var liste = woerter
                        liste.remove(atOffsets: indexSet)
                        modell.setzen("duellWoerter", .array(liste.map { .string($0) }))
                    }
            }
        }
        .navigationTitle("Duell-Wörter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hinzufuegen() {
        let wort = neuesWort.trimmingCharacters(in: .whitespaces)
        guard !wort.isEmpty else { return }
        modell.setzen("duellWoerter", .array((woerter + [wort]).map { .string($0) }))
        neuesWort = ""
    }
}
