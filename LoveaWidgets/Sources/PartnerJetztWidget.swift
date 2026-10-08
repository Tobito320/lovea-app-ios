import AppIntents
import SwiftUI
import UIKit
import WidgetKit

/// "Partner jetzt": Figur, Status in Worten, letzter Moment des Tages und Herzen heute. Tippen öffnet
/// "<Name>s Tag" (`lovea://tag`), der Herz-Knopf schickt "Denk an dich" ohne die App zu öffnen.
/// Daten kommen nur aus dem App-Group-Stand; das Widget fragt nichts selbst ab.
struct PartnerJetztWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PartnerJetzt", provider: WidgetStandProvider()) { entry in
            PartnerJetztView(entry: entry)
        }
        .configurationDisplayName("Partner jetzt")
        .description("Was dein Partner gerade macht, der letzte Moment und ein Herz zum Zurückschicken.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

private struct PartnerJetztView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetStandEntry

    private var ich: String { entry.stand.eigenePerson }
    private var partner: String { ich == "ahmed" ? "annika" : "ahmed" }
    private var status: String { entry.stand.partnerStatus ?? "noch nichts bekannt" }
    private var moment: String { entry.stand.partnerLetzterMoment ?? "Noch kein Moment heute" }
    /// Meine Herzen heute (nur wenn der Stand von heute ist, sonst beginnt der Zähler bei 0).
    private var meineHerzen: Int {
        entry.stand.herzDatum == WidgetDatum.heute(entry.date) ? (entry.stand.herzHeute?[ich] ?? 0) : 0
    }

    /// Herzen, die der Partner heute geschickt hat: dieselbe Zahl wie "heute n×" in seinem Tag.
    private var vomPartner: Int {
        entry.stand.herzDatum == WidgetDatum.heute(entry.date) ? (entry.stand.herzHeute?[partner] ?? 0) : 0
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Button(intent: DenkAnDichIntent()) {
                    VStack(spacing: 0) {
                        Image(systemName: "heart.fill").font(.title3)
                        Text("\(meineHerzen)×").font(.caption2.weight(.semibold)).monospacedDigit()
                    }
                }
                .buttonStyle(.plain)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(WidgetStil.name(partner)): \(status)").font(.caption).bold().lineLimit(1)
                    Text(moment).font(.caption2).lineLimit(2)
                    Label("heute \(vomPartner)×", systemImage: "heart.fill").font(.caption2)
                }
            case .systemMedium:
                breit
            default:
                schmal
            }
        }
        .widgetURL(URL(string: "lovea://tag"))
        .widgetHintergrund(WidgetStil.farbe(partner))
    }

    private var figur: some View {
        Group {
            if let bild = entry.partnerFigur {
                Image(uiImage: bild).resizable().scaledToFit()
            } else {
                Image(systemName: "person.crop.circle").resizable().scaledToFit().foregroundStyle(.secondary)
            }
        }
    }

    private var herzKnopf: some View {
        Button(intent: DenkAnDichIntent()) {
            Label(meineHerzen > 0 ? "\(meineHerzen)×" : "Denk an dich", systemImage: "heart.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(WidgetStil.rose))
        }
        .buttonStyle(.plain)
    }

    private var schmal: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                figur.frame(width: 38, height: 38)
                Text(status).font(.subheadline.weight(.semibold)).fontDesign(.rounded).lineLimit(2)
            }
            Text(moment).widgetEtikett().lineLimit(2)
            Spacer(minLength: 0)
            HStack {
                herzKnopf
                Spacer(minLength: 0)
                Text("heute \(vomPartner)×").widgetEtikett().monospacedDigit()
            }
        }
    }

    private var breit: some View {
        HStack(spacing: 14) {
            figur.frame(width: 84)
            VStack(alignment: .leading, spacing: 6) {
                WidgetKopf(titel: "\(WidgetStil.name(partner)) jetzt", symbol: "heart.fill", farbe: WidgetStil.farbe(partner))
                Text(status).font(.title3.weight(.bold)).fontDesign(.rounded).lineLimit(2)
                Text(moment).widgetEtikett().lineLimit(2)
                Spacer(minLength: 0)
                HStack {
                    herzKnopf
                    Spacer(minLength: 0)
                    Text("heute \(vomPartner)×").widgetEtikett().monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
    }
}
