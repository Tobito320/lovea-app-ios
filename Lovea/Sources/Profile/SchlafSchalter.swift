import SwiftUI

/// Eigenes Profil: "Wach" / "Schläft" mit einem Tipp. Schickt denselben `gruss` wie der Home-Knopf
/// (`GrussKnopfCard`): "nacht" lässt die eigene Figur 12 h schlafen (bis "morgen"), der Partner
/// bekommt "sagt Gute Nacht". Automatisch schläft die Figur außerdem bei Schlafen-Fokus 22–7 Uhr.
struct SchlafSchalter: View {
    // Manueller Override ODER Schlafen-Fokus (eigener `zustand`), nicht `anzeige(ich)`: das wäre
    // auch bei einer frischen Geste kurz etwas anderes.
    private var manuell: Bool {
        guard let ich = Raum.shared.ich, let bis = FigurenModell.shared.grussSchlaeft[ich] else { return false }
        return bis > Date()
    }

    private var schlaeft: Bool {
        guard let ich = Raum.shared.ich else { return false }
        return manuell || FigurenModell.shared.zustand[ich]?.haupt == .schlaeft
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                seite("Wach", symbol: "sun.max.fill", farbe: .orange, aktiv: !schlaeft) { setzen(schlafen: false) }
                seite("Schläft", symbol: "moon.zzz.fill", farbe: .indigo, aktiv: schlaeft) { setzen(schlafen: true) }
            }
            .padding(4)
            .glassEffect(.regular, in: .capsule)
            .sensoryFeedback(.selection, trigger: schlaeft)

            Text(manuell ? "Deine Figur schläft, bis du „Wach“ tippst, höchstens 12 Stunden."
                 : schlaeft ? "Schlafen-Fokus ist an. „Wach“ weckt deine Figur bis 7 Uhr."
                 : "Mit Schlafen-Fokus schläft deine Figur zwischen 22 und 7 Uhr automatisch.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
    }

    private func seite(_ titel: String, symbol: String, farbe: Color, aktiv: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Label(titel, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(aktiv ? Color.white : Color.primary)
                .background(aktiv ? farbe : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.28), value: aktiv)
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }

    private func setzen(schlafen: Bool) {
        guard schlafen != schlaeft else { return }
        Anwesenheit.shared.wach(!schlafen) // Fokus-Schlaf bis 7 Uhr überstimmen bzw. freigeben
        if schlafen { FigurenModell.shared.grussSenden("nacht") } else if manuell { FigurenModell.shared.grussSenden("morgen") }
    }
}
