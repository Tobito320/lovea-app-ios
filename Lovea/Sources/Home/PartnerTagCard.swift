import SwiftUI

/// Ziel für `NavigationStack` auf Home ("<Name>s Tag"); der Partner ergibt sich aus der Person auf Home.
struct PartnerTagZiel: Hashable {}

/// Home-Karte "Ahmeds Tag · 7 Momente": Figur, Status in Worten, letzter Moment, darunter der
/// "Denk an dich"-Knopf. Tippen auf die Kopfzeile öffnet die Zeitleiste.
struct PartnerTagCard: View {
    let person: Person
    private var partner: Person { person.partner }

    var body: some View {
        let ansicht = TagModell.shared.ansicht(person: partner, tag: Date())
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: PartnerTagZiel()) {
                HStack(spacing: 12) {
                    FigurKopf(person: partner, groesse: 44, zustand: FigurenModell.shared.anzeige(partner).haupt)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TagLogik.titel(person: partner, momente: ansicht.momente.count)).font(.headline)
                        Text(TagModell.shared.statusText(person: partner)).font(.subheadline).foregroundStyle(.secondary)
                        if let letzter = ansicht.momente.last {
                            Text("\(TagModell.uhrzeit(letzter.zeit)) \(letzter.text)")
                                .font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Öffnet den Tag von \(partner.name)")
            DenkAnDichKnopf(partner: partner)
        }
        .padding(16)
        .healthKarte()
    }
}

/// "Denk an dich": schickt `geste herz` an den Partner (Push höchstens alle 10 Minuten, serverseitig;
/// jeder Tipp zählt trotzdem). Zeigt rechts, wie oft du heute schon getippt hast.
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
                Label("Denk an dich", systemImage: "heart.fill")
                    .symbolEffect(.bounce, value: getippt)
                if heute > 0 { Text("heute \(heute)×").font(.footnote).opacity(0.85) }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.loveaRose)
        .accessibilityHint("Schickt \(partner.name) einen Gedanken an dich")
    }
}

/// Zeile im Partner-Profil: öffnet "<Name>s Tag" als Blatt. Eigener State und eigenes Sheet, damit die
/// lange Modifier-Kette von `ProfileView.body` nicht noch länger wird.
struct PartnerTagProfilZeile: View {
    let person: Person
    @State private var offen = false

    var body: some View {
        Button { offen = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "clock.fill").foregroundStyle(Color.loveaRose).frame(width: 28).accessibilityHidden(true)
                Text("\(person.name)s Tag").font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .healthKarte()
        .sheet(isPresented: $offen) { NavigationStack { PartnerTagView(person: person) } }
    }
}
