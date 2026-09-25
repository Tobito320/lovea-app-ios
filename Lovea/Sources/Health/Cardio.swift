import SwiftUI

/// Laufband/Stairmaster: am Ende abtippen, was das Gerät anzeigt. Op `cardio.setzen` (ersetzt per id),
/// `cardio.loeschen {id}`. Beide sehen die Einträge des anderen.
struct CardioEintrag: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var datum: String
    var geraet: String // "laufband" | "stairmaster"
    var minuten: Int
    var kcal: Int?
    var km: Double?
    var hoehe: Int?
    var steigung: Double?
    var kmh: Double?
    var etagen: Int?
    var stufen: Int?
    var stufe: Int?

    var titel: String { geraet == "stairmaster" ? "Stairmaster" : "Laufband" }
    var symbol: String { geraet == "stairmaster" ? "figure.stair.stepper" : "figure.walk.treadmill" }

    /// ponytail: estimate, ~1.300 steps per walked km, one step per stair. Real counts would need
    /// HealthKit steps inside the session window.
    var schritteCa: Int? {
        if geraet == "stairmaster" { return stufen }
        return km.map { Int(($0 * 1300).rounded()) }
    }
}

@MainActor
@Observable
final class CardioModell {
    static let shared = CardioModell()
    private(set) var eintraege: [Person: [String: CardioEintrag]] = [:]

    private init() {
        Raum.shared.beobachten(["cardio.setzen", "cardio.loeschen"]) { [weak self] op in self?.anwenden(op) }
    }

    func anwenden(_ op: Op) {
        if op.art == "cardio.setzen", let e = op.daten(CardioEintrag.self) {
            eintraege[op.von, default: [:]][e.id] = e
        } else if op.art == "cardio.loeschen", let d = op.daten([String: String].self), let id = d["id"] {
            eintraege[op.von]?[id] = nil
        }
    }

    func am(_ tag: String, von person: Person) -> [CardioEintrag] {
        (eintraege[person] ?? [:]).values.filter { $0.datum == tag }.sorted { $0.id < $1.id }
    }

    func sichern(_ e: CardioEintrag) { Raum.shared.senden("cardio.setzen", e) }
    func loeschen(_ e: CardioEintrag) { Raum.shared.senden("cardio.loeschen", ["id": e.id]) }
}

/// Section in the steps detail for one day.
struct CardioSektion: View {
    let person: Person
    let tag: String
    @State private var blatt: CardioEintrag?

    private var eigene: Bool { person == Raum.shared.ich }

    var body: some View {
        let liste = CardioModell.shared.am(tag, von: person)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Cardio").font(.headline)
                Spacer()
                if eigene {
                    Menu {
                        Button("Laufband", systemImage: "figure.walk.treadmill") { blatt = CardioEintrag(datum: tag, geraet: "laufband", minuten: 30) }
                        Button("Stairmaster", systemImage: "figure.stair.stepper") { blatt = CardioEintrag(datum: tag, geraet: "stairmaster", minuten: 20) }
                    } label: { Label("Eintragen", systemImage: "plus") }
                }
            }
            if liste.isEmpty {
                Text(eigene ? "Laufband oder Stairmaster? Werte vom Gerät am Ende eintragen." : "Nichts eingetragen")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(liste) { e in
                Button { blatt = e } label: { zeile(e) }.buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        .sheet(item: $blatt) { CardioFormular(eintrag: $0, bearbeitbar: eigene) }
    }

    private func zeile(_ e: CardioEintrag) -> some View {
        HStack(spacing: 12) {
            Image(systemName: e.symbol).font(.title3).foregroundStyle(Color.person(person)).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.titel).font(.subheadline.weight(.semibold))
                Text([ "\(e.minuten) min", e.kcal.map { "\($0) kcal" }, e.km.map { String(format: "%.2f km", $0) }, e.stufen.map { "\($0) Stufen" } ]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let s = e.schritteCa {
                Text("ca. \(s.formatted()) Schritte").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
    }
}

/// Enter or view one session. The partner sees it read-only.
struct CardioFormular: View {
    @State var eintrag: CardioEintrag
    let bearbeitbar: Bool
    @Environment(\.dismiss) private var dismiss

    private var laufband: Bool { eintrag.geraet != "stairmaster" }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                Section("Vom Gerät") {
                    feld("Dauer", "min", Binding<Int?> { eintrag.minuten } set: { eintrag.minuten = $0 ?? 0 })
                    feld("Kalorien", "kcal", $eintrag.kcal)
                    if laufband {
                        feld("Entfernung", "km", $eintrag.km)
                        feld("Höhe", "m", $eintrag.hoehe)
                    } else {
                        feld("Stufen", "Stufen", $eintrag.stufen)
                        feld("Etagen", "Etagen", $eintrag.etagen)
                    }
                }
                Section("Eingestellt") {
                    if laufband {
                        feld("Steigung", "%", $eintrag.steigung)
                        feld("Geschwindigkeit", "km/h", $eintrag.kmh)
                    } else {
                        feld("Stufe", "Stufe", $eintrag.stufe)
                    }
                }
                }
                .disabled(!bearbeitbar)
                if let s = eintrag.schritteCa {
                    Section { LabeledContent("Schritte", value: "ca. \(s.formatted())") } footer: {
                        Text(laufband ? "Geschätzt aus der Entfernung." : "Eine Stufe = ein Schritt.")
                    }
                }
                if bearbeitbar, CardioModell.shared.am(eintrag.datum, von: Raum.shared.ich ?? .ahmed).contains(where: { $0.id == eintrag.id }) {
                    Button("Löschen", role: .destructive) { CardioModell.shared.loeschen(eintrag); dismiss() }
                }
            }
            .navigationTitle(eintrag.titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(bearbeitbar ? "Abbrechen" : "Fertig") { dismiss() } }
                if bearbeitbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Sichern") { CardioModell.shared.sichern(eintrag); Haptik.erfolg(); dismiss() }
                    }
                }
            }
        }
    }

    private func feld(_ titel: String, _ einheit: String, _ wert: Binding<Int?>) -> some View {
        LabeledContent(titel) {
            TextField(einheit, value: wert, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing)
        }
    }

    private func feld(_ titel: String, _ einheit: String, _ wert: Binding<Double?>) -> some View {
        LabeledContent(titel) {
            TextField(einheit, value: wert, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
        }
    }
}
