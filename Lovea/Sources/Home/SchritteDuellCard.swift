import SwiftUI

/// Z-36.2: the step duel on Home in the new Health look — the two rings with km and floors,
/// tapping switches to the Health tab (Spec 3.1 Runde 2: "Home: nur das Duell").
struct SchritteDuellCard: View {
    private var health: HealthModell { HealthModell.shared }

    var body: some View {
        let heute = Datum.text(Date())
        VStack(alignment: .leading, spacing: 12) {
            kopfzeile
            HStack(alignment: .top, spacing: 8) {
                ForEach(Person.allCases, id: \.self) { person in
                    SchritteSpalte(
                        person: person, anzahl: health.heuteSchritte(person), ziel: health.zielSchritte(person),
                        km: health.kmAm(person, heute), etagen: health.etagenAm(person, heute), groesse: 104
                    )
                }
            }
        }
        .padding(16)
        .healthKarte()
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture { oeffneHealth() }
        .accessibilityElement(children: .contain)
    }

    private var kopfzeile: some View {
        HStack {
            Text("Schritte").font(.headline)
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Öffnet Health")
        .accessibilityAction { oeffneHealth() }
    }

    private func oeffneHealth() {
        Haptik.auswahl()
        AppNavigation.shared.tabWunsch = "health"
    }
}
