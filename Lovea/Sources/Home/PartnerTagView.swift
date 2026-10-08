import SwiftUI

/// "<Name>s Tag": senkrechte Zeitleiste von heute, nur aus schon gesyncten Daten (`TagModell`).
struct PartnerTagView: View {
    let person: Person

    var body: some View {
        let momente = TagModell.shared.ansicht(person: person, tag: Date())
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if momente.isEmpty {
                    Text("Noch nichts los. Sobald \(person.name) etwas macht, steht es hier.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(momente) { moment in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(Datum.uhrzeit(moment.zeit)).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                        Image(systemName: moment.sorte.symbol).foregroundStyle(Color.loveaRose).frame(width: 24)
                        Text(moment.anzeige)
                    }
                    .accessibilityElement(children: .combine)
                }
                if person != Raum.shared.ich { DenkAnDichKnopf(partner: person) }
            }
            .padding(16)
        }
        .navigationTitle("\(person.name)s Tag")
        .navigationBarTitleDisplayMode(.inline)
    }
}
