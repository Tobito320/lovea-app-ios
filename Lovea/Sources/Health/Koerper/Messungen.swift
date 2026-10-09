import Charts
import SwiftUI

// Messungen wie in Hevy: letzter Wert, Diagramm, Historie, Plus zum Erfassen. Gewicht ist dasselbe
// Gewicht wie überall in Health (Habit "gewicht"), keine zweite Datenquelle. Umfänge und Körperfett
// liegen als Tageswerte unter "mass.<art>" in denselben Habit-Ops. Alle Werte in Zehnteln.

enum MessArt: String, CaseIterable, Identifiable, Sendable {
    case gewicht, taille, brust, schulter, bizeps, oberschenkel, koerperfett

    var id: String { rawValue }
    var habitId: String { self == .gewicht ? Habit.gewicht.id : "mass.\(rawValue)" }

    var titel: String {
        switch self {
        case .gewicht: "Gewicht"
        case .taille: "Taille"
        case .brust: "Brust"
        case .schulter: "Schulter"
        case .bizeps: "Bizeps"
        case .oberschenkel: "Oberschenkel"
        case .koerperfett: "Körperfett"
        }
    }

    var einheit: String {
        switch self {
        case .gewicht: "kg"
        case .koerperfett: "%"
        default: "cm"
        }
    }

    /// 784 -> "78,4 kg".
    func text(_ zehntel: Int) -> String { "\(zehntel / 10),\(zehntel % 10) \(einheit)" }
}

struct MessPunkt: Identifiable, Equatable {
    var tag: String
    var zehntel: Int
    var id: String { tag }
}

enum MessLogik {
    /// Tage mit Wert, älteste zuerst. 0 heißt "kein Wert" (so löscht man einen Eintrag).
    static func punkte(_ werte: [String: Int]) -> [MessPunkt] {
        werte.filter { $0.value > 0 }.map { MessPunkt(tag: $0.key, zehntel: $0.value) }.sorted { $0.tag < $1.tag }
    }
}

struct MessungenView: View {
    @State private var art = MessArt.gewicht
    @State private var person: Person?
    @State private var erfassen = false

    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        let wer = person ?? ich
        let punkte = MessLogik.punkte(HealthModell.shared.habitWerte(art.habitId, wer))
        List {
            Section {
                Picker("Wessen Messungen", selection: Binding { wer } set: { person = $0 }) {
                    Text("Ich").tag(ich)
                    Text(ich.partner.name).tag(ich.partner)
                }
                .pickerStyle(.segmented)
                Picker("Messung", selection: $art) {
                    ForEach(MessArt.allCases) { a in Text(a.titel).tag(a) }
                }
            }
            .listRowSeparator(.hidden)
            Section {
                if let letzter = punkte.last {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(art.text(letzter.zehntel)).font(.title.bold().monospacedDigit())
                        Text(Datum.anzeige(letzter.tag)).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if punkte.count > 1 {
                        Chart(punkte) { p in
                            LineMark(x: .value("Datum", Datum.datum(p.tag)), y: .value(art.einheit, Double(p.zehntel) / 10))
                            PointMark(x: .value("Datum", Datum.datum(p.tag)), y: .value(art.einheit, Double(p.zehntel) / 10))
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 180)
                        .accessibilityLabel("\(art.titel) über die Zeit")
                    }
                } else {
                    Text(wer == ich ? "Noch kein Wert. Tipp oben auf das Plus." : "\(wer.name) hat hier noch nichts eingetragen.")
                        .foregroundStyle(.secondary)
                }
            }
            .listRowSeparator(.hidden)
            if !punkte.isEmpty {
                Section("\(art.titel) Historie") {
                    ForEach(punkte.reversed()) { p in
                        LabeledContent(Datum.anzeige(p.tag), value: art.text(p.zehntel))
                    }
                }
            }
        }
        .navigationTitle("Messungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Messung erfassen", systemImage: "plus") { erfassen = true }
            }
        }
        .sheet(isPresented: $erfassen) { MessungBlatt() }
    }
}

/// Mehrere Werte für einen Tag erfassen; leere Felder bleiben unberührt.
struct MessungBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var datum = Date()
    @State private var texte: [MessArt: String] = [:]

    private var werte: [(MessArt, Int)] {
        MessArt.allCases.compactMap { a in GewichtText.zehntel(texte[a] ?? "").map { (a, $0) } }
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Datum", selection: $datum, in: ...Date(), displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "de_DE"))
                Section("Messungen") {
                    ForEach(MessArt.allCases) { a in
                        LabeledContent("\(a.titel) (\(a.einheit))") {
                            TextField("–", text: feld(a))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .navigationTitle("Messung erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let tag = Datum.text(datum)
                        for (a, zehntel) in werte { HealthModell.shared.setzeHabit(a.habitId, datum: tag, wert: zehntel) }
                        Haptik.erfolg()
                        dismiss()
                    }
                    .disabled(werte.isEmpty)
                }
            }
        }
    }

    private func feld(_ a: MessArt) -> Binding<String> {
        Binding { texte[a] ?? "" } set: { texte[a] = $0 }
    }
}
