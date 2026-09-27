import SwiftUI

/// Where Health navigates. Everything is pushed onto the one stack of `HeuteView` (the Health tab).
enum HealthZiel: Hashable {
    case habit(String), schritte(Person), schritteVergleich, punkte
    case trainingsPlan(Person), gymSession(String), gymVerlauf
}

/// Die Seite zu einem `HealthZiel`, registriert im Stapel von Health.
struct HealthZielAnsicht: View {
    let ziel: HealthZiel

    var body: some View {
        switch ziel {
        case .habit(let id): HabitDetailView(habitId: id)
        case .schritte(let person): SchritteDetailView(person: person)
        case .schritteVergleich: SchritteVergleichView()
        case .punkte: PunkteVerlaufView()
        case .trainingsPlan(let person): TrainingsPlanView(person: person)
        case .gymSession(let id): GymSessionView(sessionId: id)
        case .gymVerlauf: GymVerlaufView()
        }
    }
}

/// Schritte für einen Tag von Hand, wenn kein Tracker zählt.
struct SchritteEintragenBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var datum = Date()
    @State private var text = ""

    private var anzahl: Int? { Int(text.filter(\.isNumber)) }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Tag", selection: $datum, in: ...Date(), displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "de_DE"))
                TextField("Schritte", text: $text)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("Schritte eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        if let anzahl { HealthModell.shared.schritteEintragen(anzahl, datum: Datum.text(datum)) }
                        Haptik.erfolg()
                        dismiss()
                    }
                    .disabled(anzahl == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
