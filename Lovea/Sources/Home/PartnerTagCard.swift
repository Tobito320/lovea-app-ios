import SwiftUI

/// Home-Karte "Ahmeds Tag": Figur, Status und letzter Moment.
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
        }
        .padding(16)
        .healthKarte()
    }
}
