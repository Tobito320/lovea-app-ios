import SwiftUI
import UIKit

/// Z-21.3: Schritte-Duell auf Home — nur die zwei Ringe, Antippen wechselt in den Health-Tab
/// (Spec 3.1: "Home: nur das Duell mit den zwei Ringen").
struct SchritteDuellCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Schritte-Duell").font(.headline)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            HStack(spacing: 28) {
                // Kein Knopf im Ring hier — die ganze Karte ist selbst die Tippfläche zu Health, ein
                // verschachtelter "Erlauben"-Knopf würde Tap/VoiceOver-Aktivierung uneindeutig machen.
                SchritteRing(person: .ahmed, groesse: 84, zeigtKnopf: false)
                SchritteRing(person: .annika, groesse: 84, zeigtKnopf: false)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { oeffneHealth() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Schritte-Duell")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { oeffneHealth() }
    }

    private func oeffneHealth() {
        UISelectionFeedbackGenerator().selectionChanged()
        AppNavigation.shared.tabWunsch = "health"
    }
}
