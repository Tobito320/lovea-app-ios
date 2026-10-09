import AppIntents
import SwiftUI
import WidgetKit

/// "Partner jetzt": Figur, Status, letzter Moment des Tages und der Herz-Knopf "Denk an dich", der ohne
/// App-Start `geste herz` schickt. Daten nur aus dem App-Group-Stand, das Widget fragt nichts selbst ab.
struct PartnerJetztWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PartnerJetzt", provider: WidgetStandProvider()) { entry in
            PartnerJetztView(entry: entry)
        }
        .configurationDisplayName("Partner jetzt")
        .description("Was dein Partner gerade macht, der letzte Moment und ein Herz zum Zurückschicken.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct PartnerJetztView: View {
    let entry: WidgetStandEntry

    private var partner: String { entry.stand.eigenePerson == "ahmed" ? "annika" : "ahmed" }
    /// Meine Herzen heute; ein Zähler von gestern zählt nicht.
    private var herzen: Int {
        entry.stand.herzDatum == WidgetDatum.heute(entry.date) ? entry.stand.herzHeute ?? 0 : 0
    }

    var body: some View {
        HStack(spacing: 12) {
            PartnerBild(bild: entry.partnerFigur).frame(width: 52)
            VStack(alignment: .leading, spacing: 4) {
                WidgetKopf(titel: "\(WidgetStil.name(partner)) jetzt", symbol: "heart.fill", farbe: WidgetStil.farbe(partner))
                Text(entry.stand.partnerStatus ?? "noch nichts bekannt").font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(entry.stand.partnerLetzterMoment ?? "Noch kein Moment heute").widgetEtikett().lineLimit(2)
                Spacer(minLength: 0)
                Button(intent: DenkAnDichIntent()) {
                    Label(herzen > 0 ? "\(herzen)×" : "Denk an dich", systemImage: "heart.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(WidgetStil.rose))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "lovea://home"))
        .widgetHintergrund(WidgetStil.farbe(partner))
    }
}
