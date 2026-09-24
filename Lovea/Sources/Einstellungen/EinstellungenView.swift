import SwiftUI

/// Z-15.2: Einstellungen im iOS-Listen-Stil, geöffnet über das Zahnrad im eigenen Profil.
struct EinstellungenView: View {
    let person: Person
    @ObservedObject var session: PersonSession
    @AppStorage("profile.performanceHUD") private var showsHUD = false
    @AppStorage("lovea.haptik") private var haptik = true // Z-31.1: same key `Haptik.an` reads
    @State private var zeigtOrte = false
    @State private var zeigtEntwickler = false

    var body: some View {
        List {
            Section("Mitteilungen") {
                NavigationLink("Mitteilungen") { MitteilungenListe() }
            }
            Section("FaceTime") {
                FaceTimeKontaktZeile()
            }
            Section("Figur") {
                NavigationLink("Figuren-Editor") { FigurEditorSeite(person: person) }
            }
            Section("Szenen") {
                ForEach(RaumOrt.allCases, id: \.self) { ort in
                    NavigationLink {
                        ZimmerEditor(person: person, ort: ort)
                    } label: {
                        HStack(spacing: 12) {
                            Label(ort.titel, systemImage: ort.symbol)
                            Spacer()
                            ZimmerKachel(zimmer: Zimmer.von(person, ort: ort), ort: ort, art: .raum, aussehen: FigurenModell.shared.aussehen(person))
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
            }
            Section("Chat") {
                NavigationLink("Duell-Wörter") { DuellWoerterEditor() }
            }
            Section("Wir") {
                Button("Orte") { zeigtOrte = true }
                    .foregroundStyle(.primary)
                NavigationLink("Jahrestag") { JahrestagEditor() }
                NavigationLink("Wochenplan") { WochenplanEditor() }
            }
            Section("Spotify") {
                SpotifyVerbindenRow()
            }
            Section {
                Toggle("Haptik", isOn: $haptik)
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

/// Internal (not `private`): Profile/ProfileView.swift's "Figur bearbeiten" reuses this exact
/// wrapper (Shop button included) instead of duplicating the `FigurEditor` navigation chrome.
struct FigurEditorSeite: View {
    let person: Person
    @Environment(\.dismiss) private var dismiss
    @State private var shopOffen = false

    var body: some View {
        FigurEditor(start: FigurenModell.shared.aussehen(person)) { neu in
            FigurenModell.shared.aussehenSichern(neu)
            dismiss()
        }
        .navigationTitle("Figuren-Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Z-23.2: Shop reachable from the figure editor too (Spec §4.3).
            ToolbarItem(placement: .primaryAction) { Button("Shop") { shopOffen = true } }
        }
        .sheet(isPresented: $shopOffen) { ShopView() }
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
