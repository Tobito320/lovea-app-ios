import SwiftUI

/// Game sheet (Z-14.1, Block 18): a 3-column grid of covers. Tapping a cover invites the partner
/// right away with the defaults; the Kritzel-Duell's corner badge opens its settings.
/// `SpieleStarter(vorauswahl: .duell)` starts in the settings (Zeichnen-Tab).
struct SpieleStarter: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pfad: [SpielArt]
    @State private var eingeladen: SpielArt?

    init(vorauswahl: SpielArt? = nil) {
        _pfad = State(initialValue: vorauswahl == .duell ? [.duell] : [])
    }

    private var partner: String { Raum.shared.ich?.partner.name ?? "Dein Schatz" }

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: 3), spacing: 18) {
                    ForEach(SpielArt.allCases) { art in
                        kachel(art)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                Text(Raum.shared.partnerDa
                    ? "\(partner) hat 2 Minuten zum Annehmen."
                    : "\(partner) ist gerade nicht online. Die Einladung gilt 2 Minuten.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(16)
            }
            .navigationTitle("Spielen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Schließen")
                }
            }
            .navigationDestination(for: SpielArt.self) { _ in
                DuellEinstellungen(partner: partner) { einstellungen in
                    einladen(.duell, einstellungen)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.success, trigger: eingeladen) { _, neu in neu != nil }
        .sensoryFeedback(.impact(weight: .light), trigger: pfad) { alt, neu in neu.count > alt.count }
    }

    private func kachel(_ art: SpielArt) -> some View {
        Button {
            einladen(art, art == .duell ? .duell() : SpieleModell.Einstellungen())
        } label: {
            VStack(spacing: 8) {
                SpielCover(art: art)
                    .overlay {
                        if eingeladen == art {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(.white)
                                .background(Circle().fill(Color.loveaRose).padding(4))
                                .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                Text(art.titel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(eingeladen != nil)
        .accessibilityLabel(art.titel)
        .accessibilityHint("Lädt \(partner) sofort ein")
        .overlay(alignment: .topTrailing) {
            if art == .duell {
                Button { pfad.append(.duell) } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.loveaRose)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.background))
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                        .padding(7)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: 14, y: -14)
                .accessibilityLabel("Kritzel-Duell einstellen")
            }
        }
    }

    /// One tap, one invitation: the model replaces an older open one of mine, the tile shows a
    /// check, then the sheet closes. Taps during that moment are ignored.
    private func einladen(_ art: SpielArt, _ einstellungen: SpieleModell.Einstellungen) {
        guard eingeladen == nil else { return }
        SpieleModell.shared.einladen(art, einstellungen: einstellungen)
        withAnimation(.snappy) {
            pfad.removeAll()
            eingeladen = art
        }
        Task {
            try? await Task.sleep(for: .seconds(0.7))
            dismiss()
        }
    }
}

/// Minimal Duell settings: 1 or 3 rounds, time per round, and the vibe for a single round.
/// Three rounds always run leicht → mittel → schwer.
private struct DuellEinstellungen: View {
    let partner: String
    let einladen: (SpieleModell.Einstellungen) -> Void

    @State private var runden = 1
    @State private var dauer = 60
    @State private var vibe = Wortliste.gemischt

    private var optionen: [String] {
        [Wortliste.gemischt] + Wortliste.vibes + (SpieleModell.shared.alleEigenenWoerter.isEmpty ? [] : [Wortliste.eigene])
    }

    var body: some View {
        Form {
            Section {
                Picker("Runden", selection: $runden) {
                    Text("1 Runde").tag(1)
                    Text("3 Runden").tag(3)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                if runden == 3 { Text("Leicht, dann mittel, dann schwer.") }
            }
            Section("Zeit pro Runde") {
                Picker("Zeit pro Runde", selection: $dauer) {
                    Text("1 min").tag(60)
                    Text("5 min").tag(300)
                    Text("10 min").tag(600)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if runden == 1 {
                Section {
                    Picker("Vibe", selection: $vibe) {
                        ForEach(optionen, id: \.self) { Text(Wortliste.titel($0)).tag($0) }
                    }
                    NavigationLink("Eure Insider") { InsiderEditor() }
                }
            }
        }
        .navigationTitle(SpielArt.duell.titel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Herausfordern") {
                    einladen(.duell(runden: runden, dauer: dauer, vibe: vibe))
                }
                .accessibilityHint("Fordert \(partner) heraus")
            }
        }
        .sensoryFeedback(.selection, trigger: runden)
        .sensoryFeedback(.selection, trigger: dauer)
    }
}

/// Own Duell words ("Insider"), shared with the partner through `einstellung.setzen`.
private struct InsiderEditor: View {
    @State private var text = ""

    private var woerter: [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var body: some View {
        Form {
            Section {
                TextField("Pupsbär, unser Sofa, Döner um drei …", text: $text, axis: .vertical)
                    .lineLimit(3...8)
            } footer: {
                Text("Mit Komma trennen. Ihr beide findet sie im Vibe „Eure Insider“.")
            }
        }
        .navigationTitle("Eure Insider")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let ich = Raum.shared.ich else { return }
            text = (SpieleModell.shared.eigeneWoerter[ich] ?? []).joined(separator: ", ")
        }
        .onDisappear {
            let meine = Raum.shared.ich.flatMap { SpieleModell.shared.eigeneWoerter[$0] } ?? []
            if woerter != meine { SpieleModell.shared.eigeneWoerterSetzen(woerter) }
        }
    }
}
