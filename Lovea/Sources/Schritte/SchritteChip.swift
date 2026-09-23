import SwiftUI

/// Kleine Kapsel „👟 8.432 Schritte" für Profil und Karte (Z-18.8). Platzhalter, solange die Zahl
/// unbekannt ist (keine Berechtigung, Simulator, oder der Partner hat heute noch nichts gesendet).
struct SchritteChip: View {
    let person: Person

    private var anzahl: Int? { SchritteModell.shared.heute[person] }

    var body: some View {
        HStack(spacing: 4) {
            Text("👟")
            if let anzahl {
                Text("\(anzahl.formatted(.number.locale(Locale(identifier: "de_DE")))) Schritte")
            } else {
                Text("– Schritte")
            }
        }
        .font(.caption)
        .foregroundStyle(Color.personText(person))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.person(person), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
