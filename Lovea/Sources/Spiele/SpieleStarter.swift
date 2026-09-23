import SwiftUI

/// Game list sheet (Z-14.1). Tapping a game invites the partner right away; the Kritzel-Duell
/// opens its settings first. `SpieleStarter(vorauswahl: .duell)` starts there (Zeichnen-Tab).
struct SpieleStarter: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pfad: [SpielArt]

    init(vorauswahl: SpielArt? = nil) {
        _pfad = State(initialValue: vorauswahl == .duell ? [.duell] : [])
    }

    private var partner: String { Raum.shared.ich?.partner.name ?? "Dein Schatz" }

    var body: some View {
        NavigationStack(path: $pfad) {
            List {
                Section {
                    ForEach(SpielArt.allCases) { art in
                        Button {
                            if art == .duell {
                                pfad.append(.duell)
                            } else {
                                SpieleModell.shared.einladen(art)
                                dismiss()
                            }
                        } label: {
                            zeile(art)
                        }
                        .foregroundStyle(.primary)
                    }
                } footer: {
                    Text(Raum.shared.partnerDa
                        ? "\(partner) hat 2 Minuten zum Annehmen."
                        : "\(partner) ist gerade nicht online. Die Einladung gilt 2 Minuten.")
                }
            }
            .navigationTitle("Spielen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .navigationDestination(for: SpielArt.self) { _ in
                DuellEinstellungen(partner: partner) { einstellungen in
                    SpieleModell.shared.einladen(.duell, einstellungen: einstellungen)
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func zeile(_ art: SpielArt) -> some View {
        HStack(spacing: 14) {
            Image(systemName: art.symbol)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.loveaRose.gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(art.titel).font(.headline)
                Text(art.beschreibung).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if art == .duell {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            } else {
                Text("Einladen").font(.subheadline.weight(.semibold)).foregroundStyle(Color.loveaRose)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Rounds, time per round, vibe per round and the own words ("Insider").
private struct DuellEinstellungen: View {
    let partner: String
    let einladen: (SpieleModell.Einstellungen) -> Void

    @State private var runden = 3
    @State private var dauer = 60
    @State private var vibes = Array(repeating: "leicht", count: 5)
    @State private var eigeneText = ""

    private var eigene: [String] {
        eigeneText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private var optionen: [String] {
        Wortliste.vibes + [Wortliste.gemischt] + (SpieleModell.shared.alleEigenenWoerter.isEmpty && eigene.isEmpty ? [] : [Wortliste.eigene])
    }

    var body: some View {
        Form {
            Section("Runden") {
                Stepper("\(runden) \(runden == 1 ? "Runde" : "Runden")", value: $runden, in: 1...5)
            }
            Section("Zeit pro Runde") {
                Picker("Zeit pro Runde", selection: $dauer) {
                    Text("60 s").tag(60)
                    Text("5 min").tag(300)
                    Text("10 min").tag(600)
                }
                .pickerStyle(.segmented)
            }
            Section("Vibe pro Runde") {
                ForEach(0..<runden, id: \.self) { r in
                    Picker("Runde \(r + 1)", selection: $vibes[r]) {
                        ForEach(optionen, id: \.self) { Text(Wortliste.titel($0)).tag($0) }
                    }
                }
            }
            Section {
                TextField("Pupsbär, unser Sofa, Döner um drei …", text: $eigeneText, axis: .vertical)
                    .lineLimit(2...5)
            } header: {
                Text("Eure Insider")
            } footer: {
                Text("Mit Komma trennen. Ihr beide findet sie im Vibe „Eure Insider“.")
            }
            Section {
                Button {
                    let meine = Raum.shared.ich.flatMap { SpieleModell.shared.eigeneWoerter[$0] } ?? []
                    if eigene != meine { SpieleModell.shared.eigeneWoerterSetzen(eigene) }
                    einladen(SpieleModell.Einstellungen(runden: runden, dauer: dauer, vibes: Array(vibes.prefix(runden))))
                } label: {
                    Text("\(partner) herausfordern").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.loveaRose)
                .controlSize(.large)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(SpielArt.duell.titel)
        .onAppear {
            guard eigeneText.isEmpty, let ich = Raum.shared.ich else { return }
            eigeneText = (SpieleModell.shared.eigeneWoerter[ich] ?? []).joined(separator: ", ")
        }
    }
}
