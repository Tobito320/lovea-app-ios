import FoundationModels
import SwiftUI

/// Freitext wie im Tagebuch: "23 Uhr geschlafen, 5 Uhr auf, 78,4 kg, 2 Liter, Creatin". Erst feste Muster
/// (`FreitextLogik`), findet das nichts, das Sprachmodell auf dem Gerät. Gespeichert wird erst nach "Sichern".
struct FreitextBlatt: View {
    let tag: String
    @State private var text = ""
    @State private var eintraege: [FreitextEintrag] = []
    @State private var aus: Set<Int> = []
    @State private var laeuft = false
    @State private var nichtsGefunden = false
    @FocusState private var fokus: Bool
    @Environment(\.dismiss) private var dismiss

    private var health: HealthModell { HealthModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("z. B. 23 Uhr geschlafen, um 5 aufgestanden, 1,5 l Wasser, Creatin", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($fokus)
                        .onSubmit(erkennen)
                    Button(laeuft ? "Lese …" : "Erkennen", action: erkennen)
                        .disabled(laeuft || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: {
                    Text("Schlaf, Gewicht, Wasser und Creatin. Du siehst alles, bevor es gespeichert wird.")
                }
                if !eintraege.isEmpty {
                    Section("Stimmt das?") {
                        ForEach(eintraege.indices, id: \.self) { i in
                            Toggle(isOn: Binding(get: { !aus.contains(i) }, set: { _ in aus.formSymmetricDifference([i]) })) {
                                Label(beschreibung(eintraege[i]), systemImage: symbol(eintraege[i]))
                            }
                        }
                    }
                } else if nichtsGefunden {
                    Section { Text("Nichts erkannt. Schreib Uhrzeiten mit \"Uhr\", Gewicht mit \"kg\", Wasser mit \"l\" oder \"Glas\".").foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: sichern).disabled(eintraege.indices.allSatisfy { aus.contains($0) })
                }
            }
            .onAppear { fokus = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func erkennen() {
        let eingabe = text
        aus = []
        eintraege = FreitextLogik.lesen(eingabe, tag: tag)
        nichtsGefunden = false
        guard eintraege.isEmpty else { return }
        laeuft = true
        Task {
            eintraege = await FreitextKI.lesen(eingabe, tag: tag)
            nichtsGefunden = eintraege.isEmpty
            laeuft = false
        }
    }

    private func sichern() {
        for (i, e) in eintraege.enumerated() where !aus.contains(i) {
            switch e {
            case .schlaf(let bett, let auf): health.schlafEintragen(SchlafZeitenD(datum: tag, bett: bett, auf: auf))
            case .gewicht(let zehntel): health.setzeHabit(Habit.gewicht.id, datum: tag, wert: zehntel)
            case .wasser(let n): health.setzeWasser(datum: tag, anzahl: health.wasserAnzahl(ich, tag) + n)
            case .creatin(let n): health.setzeHabit(Habit.creatin.id, datum: tag, wert: health.habitWert(Habit.creatin.id, ich, tag) + n)
            }
        }
        Haptik.erfolg()
        dismiss()
    }

    private func beschreibung(_ e: FreitextEintrag) -> String {
        switch e {
        case .schlaf(let bett, let auf):
            let f = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: Datum.kalender.timeZone)
            let min = Int(auf.timeIntervalSince(bett) / 60)
            return "Schlaf \(bett.formatted(f)) bis \(auf.formatted(f)), \(min / 60) h \(min % 60) min"
        case .gewicht(let zehntel): return "Gewicht \(GewichtText.anzeige(zehntel))"
        case .wasser(let n): return "Wasser +\(n) \(n == 1 ? "Glas" : "Gläser") (\(n * Int(FreitextLogik.glasMl)) ml)"
        case .creatin(let n): return "Creatin +\(n) \(n == 1 ? "Klick" : "Klicks") (\(String(format: "%.1f", Double(n) * Habit.creatinGramm).replacingOccurrences(of: ".", with: ",")) g)"
        }
    }

    private func symbol(_ e: FreitextEintrag) -> String {
        switch e {
        case .schlaf: "bed.double.fill"
        case .gewicht: "scalemass.fill"
        case .wasser: "drop.fill"
        case .creatin: "pills.fill"
        }
    }
}

@Generable
struct FreitextKIAntwort {
    @Guide(description: "Uhrzeit, zu der die Person schlafen gegangen ist, als HH:mm im 24-Stunden-Format. Leer, wenn nicht erwähnt.")
    var bett: String?
    @Guide(description: "Uhrzeit, zu der die Person aufgewacht oder aufgestanden ist, als HH:mm im 24-Stunden-Format. Leer, wenn nicht erwähnt.")
    var auf: String?
    @Guide(description: "Körpergewicht in Kilogramm. Leer, wenn nicht erwähnt.")
    var gewichtKg: Double?
    @Guide(description: "Getrunkenes Wasser in Millilitern, ein Glas sind 250. Kein Kaffee. Leer, wenn nicht erwähnt.")
    var wasserMl: Int?
    @Guide(description: "Eingenommenes Creatin in Gramm. Nur 'Creatin genommen' ohne Menge bedeutet 3.5. Leer, wenn nicht erwähnt.")
    var creatinGramm: Double?
}

/// Apples Sprachmodell auf dem Gerät (ab iPhone 15 Pro mit Apple Intelligence). Sonst leer.
enum FreitextKI {
    static func lesen(_ text: String, tag: String) async -> [FreitextEintrag] {
        guard SystemLanguageModel.default.isAvailable else { return [] }
        let session = LanguageModelSession(instructions: "Du liest kurze deutsche Tagebuch-Notizen, oft mit Tippfehlern, und trägst nur ein, was wirklich drinsteht. Nichts erfinden.")
        guard let a = try? await session.respond(to: text, generating: FreitextKIAntwort.self).content else { return [] }
        var ergebnis: [FreitextEintrag] = []
        if let b = a.bett.flatMap({ FreitextLogik.uhrzeiten(" \($0) ").first }), let u = a.auf.flatMap({ FreitextLogik.uhrzeiten(" \($0) ").first }),
           let s = FreitextLogik.schlafDaten(bett: b, auf: u, tag: tag) { ergebnis.append(s) }
        if let kg = a.gewichtKg, kg >= 20, kg < 400 { ergebnis.append(.gewicht(zehntel: Int((kg * 10).rounded()))) }
        if let ml = a.wasserMl, ml > 0, ml <= 8000 { ergebnis.append(.wasser(glaeser: max(1, Int((Double(ml) / FreitextLogik.glasMl).rounded())))) }
        if let g = a.creatinGramm, g > 0, g <= 30 { ergebnis.append(.creatin(klicks: max(1, Int((g / Habit.creatinGramm).rounded())))) }
        return ergebnis
    }
}
