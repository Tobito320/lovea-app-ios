import SwiftUI
import UIKit

/// Z-21.3: Schritte-Duell auf Home — nur die zwei Ringe, Antippen wechselt in den Health-Tab
/// (Spec 3.1: "Home: nur das Duell mit den zwei Ringen").
struct SchritteDuellCard: View {
    var body: some View {
        VStack(spacing: 12) {
            kopfzeile
            HStack(spacing: 28) {
                // Der Ring behält seinen eigenen "Erlauben"/"Einstellungen"-Knopf (Z-21.3, Review-
                // Fokus 4) — `children: .contain` unten lässt ihn einzeln erreichbar, die Karte wird
                // trotzdem über die Kopfzeile als Ganzes geöffnet (Tap überall, VoiceOver-Aktion dort).
                SchritteRing(person: .ahmed, groesse: 84)
                SchritteRing(person: .annika, groesse: 84)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { oeffneHealth() }
        .accessibilityElement(children: .contain)
    }

    private var kopfzeile: some View {
        HStack {
            Text("Schritte-Duell").font(.headline)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Öffnet Health")
        .accessibilityAction { oeffneHealth() }
    }

    private func oeffneHealth() {
        UISelectionFeedbackGenerator().selectionChanged()
        AppNavigation.shared.tabWunsch = "health"
    }
}
