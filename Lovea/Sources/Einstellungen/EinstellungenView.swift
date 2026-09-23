import SwiftUI

/// Z-15.2: Einstellungen im iOS-Listen-Stil, geöffnet über das Zahnrad im eigenen Profil.
struct EinstellungenView: View {
    let person: Person
    @ObservedObject var session: PersonSession
    @AppStorage("profile.performanceHUD") private var showsHUD = false
    @State private var zeigtOrte = false
    @State private var zeigtEntwickler = false

    var body: some View {
        List {
            Section("Mitteilungen") {
                NavigationLink("Mitteilungen") { MitteilungenListe() }
            }
            Section("Figur") {
                NavigationLink("Figuren-Editor") { FigurEditorSeite(person: person) }
                NavigationLink("Flammen-Emoji") { FlammeEditor() }
            }
            Section("Chat") {
                NavigationLink("Chat-Hintergrund") { ChatHintergrundPicker() }
                NavigationLink("Duell-Wörter") { DuellWoerterEditor() }
            }
            Section("Wir") {
                Button("Orte") { zeigtOrte = true }
                    .foregroundStyle(.primary)
                NavigationLink("Jahrestag") { JahrestagEditor() }
                NavigationLink("Wochenplan") { WochenplanEditor() }
            }
            Section {
                Toggle("Leistungsanzeige", isOn: $showsHUD)
            }
            Section {
                Text("Version \(Bundle.main.appVersion)")
                    .foregroundStyle(.secondary)
                    .onTapGesture(count: 7) { zeigtEntwickler = true }
                if zeigtEntwickler {
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
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $zeigtOrte) { OrteListeView() }
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
        Kategorie(id: "spiele", titel: "Spiele"),
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

private struct FigurEditorSeite: View {
    let person: Person
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FigurEditor(start: FigurenModell.shared.aussehen(person)) { neu in
            FigurenModell.shared.aussehenSichern(neu)
            dismiss()
        }
        .navigationTitle("Figuren-Editor")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Flammen-Emoji

private struct FlammeEditor: View {
    let modell = EinstellungenModell.shared
    @State private var text = ""

    var body: some View {
        Form {
            Section {
                TextField("Emoji", text: $text)
                    .font(.system(size: 40))
                    .multilineTextAlignment(.center)
                    .onSubmit(sichern)
            } footer: {
                Text("Erscheint als Flamme im Chat-Kopf, z. B. bei einer Streak.")
            }
        }
        .navigationTitle("Flammen-Emoji")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Sichern", action: sichern) }
        }
        .onAppear { text = modell.string("flamme", default: "🔥") }
    }

    private func sichern() {
        // ponytail: erstes Grapheme-Cluster statt Emoji-Validierung — reicht für "ein Emoji tippen".
        guard let erstes = text.first else { return }
        modell.setzen("flamme", .string(String(erstes)))
    }
}

// MARK: - Chat-Hintergrund
//
// `Chat/Medien/ChatEinstellungen.swift` (Block 5, noch nicht auf app-komplett gemergt) faltet
// `einstellung.setzen{schluessel:"hintergrund"}` bereits selbst, mit `wert` als Objekt
// `{art:"farbe"|"foto"|"zeichnung", farbe:{red,green,blue,alpha}?, medienId, abgedunkelt}`
// (`RGBAColor` aus Drawing/Library/ArtworkModels.swift, gehört keinem Block allein). Block 15
// schreibt hier absichtlich dasselbe Objekt-Format (nur Farb-Presets, kein Foto/Zeichnung-Picker
// — das bleibt Chat/**), statt einen eigenen, kollidierenden String-Wert unter demselben
// Schlüssel zu senden. `HintergrundWert` unten ist eine lokale Kopie der Form, kein Import von
// Chat/**, damit dieser Block ohne die noch ungemergte Datei baut.

private struct HintergrundWert: Codable, Equatable {
    enum Art: String, Codable { case farbe, foto, zeichnung }
    var art: Art
    var farbe: RGBAColor?
    var medienId: String?
    var abgedunkelt = false

    static let standard = HintergrundWert(art: .farbe, farbe: nil)
}

private struct EinstellungWertPayload<Wert: Codable>: Codable {
    var schluessel: String
    var wert: Wert
}

private struct ChatHintergrundPicker: View {
    let modell = EinstellungenModell.shared
    private static let optionen: [(titel: String, wert: HintergrundWert)] = [
        ("Standard", .standard),
        ("Rose", HintergrundWert(art: .farbe, farbe: RGBAColor(red: 1, green: 59 / 255, blue: 92 / 255))),
        ("Mitternacht", HintergrundWert(art: .farbe, farbe: RGBAColor(red: 0.06, green: 0.07, blue: 0.14))),
        ("Pfirsich", HintergrundWert(art: .farbe, farbe: RGBAColor(red: 0.94, green: 0.75, blue: 0.61))),
    ]

    private var aktuell: HintergrundWert { modell.dekodiert("hintergrund", als: HintergrundWert.self) ?? .standard }

    var body: some View {
        List(Self.optionen.indices, id: \.self) { i in
            let option = Self.optionen[i]
            Button {
                Raum.shared.senden("einstellung.setzen", EinstellungWertPayload(schluessel: "hintergrund", wert: option.wert))
            } label: {
                HStack {
                    Text(option.titel).foregroundStyle(.primary)
                    Spacer()
                    if aktuell == option.wert {
                        Image(systemName: "checkmark").foregroundStyle(Color.loveaRose)
                    }
                }
            }
        }
        .navigationTitle("Chat-Hintergrund")
        .navigationBarTitleDisplayMode(.inline)
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
