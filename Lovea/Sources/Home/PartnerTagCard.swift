import SwiftUI

/// Home-Karte "Ahmeds Tag": Figur, Status, letzter Moment und der "Denk an dich"-Knopf.
/// Tippen auf die Kopfzeile öffnet die Zeitleiste (`navigationDestination(for: Person.self)` in `HomeView`).
struct PartnerTagCard: View {
    let person: Person
    private var partner: Person { person.partner }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: partner) {
                HStack(spacing: 12) {
                    FigurKopf(person: partner, groesse: 44, zustand: FigurenModell.shared.anzeige(partner).haupt)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(partner.name)s Tag").font(.headline)
                        Text(FigurenModell.shared.anzeige(partner).haupt.titel).font(.subheadline).foregroundStyle(.secondary)
                        if let letzter = TagModell.shared.letzterMoment(person: partner) {
                            Text(letzter).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            DenkAnDichKnopf(partner: partner)
        }
        .padding(16)
        .healthKarte()
    }
}

/// "Denk an dich": schickt `geste herz` an den Partner (Push serverseitig höchstens alle 10 Minuten,
/// jeder Tipp zählt). Rechts: wie oft du heute getippt hast.
struct DenkAnDichKnopf: View {
    let partner: Person
    @State private var getippt = 0

    var body: some View {
        let heute = FigurenModell.shared.herzHeute[partner.partner] ?? 0
        Button {
            Haptik.leicht()
            FigurenModell.shared.gesteSenden("herz")
            getippt += 1
        } label: {
            HStack {
                Label("Denk an dich", systemImage: "heart.fill").symbolEffect(.bounce, value: getippt)
                if heute > 0 { Text("heute \(heute)×").font(.footnote).opacity(0.85) }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.loveaRose)
    }
}
