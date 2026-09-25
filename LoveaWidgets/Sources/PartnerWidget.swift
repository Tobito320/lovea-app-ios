import Foundation
import SwiftUI
import UIKit
import WidgetKit

/// Spec 10 "Partner-Figur" (klein, mittel, Wetter) + Sperrbildschirm-Zeile/-Rechteck (Ort, Akku)
/// in einem Widget.
struct PartnerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Partner", provider: WidgetStandProvider()) { entry in
            PartnerView(entry: entry)
        }
        .configurationDisplayName("Partner")
        .description("Figur, Ort und Akku deines Partners.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

private struct PartnerView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetStandEntry

    private var partner: String { entry.stand.eigenePerson == "ahmed" ? "annika" : "ahmed" }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text(entry.stand.partnerOrtName ?? "Partner")
            case .accessoryRectangular:
                PartnerRechteck(stand: entry.stand)
            case .systemMedium:
                PartnerBreit(entry: entry, partner: partner)
            default:
                PartnerSchmal(entry: entry, partner: partner)
            }
        }
        .widgetURL(URL(string: "lovea://home"))
        .widgetHintergrund(WidgetStil.farbe(partner))
    }
}

private struct PartnerRechteck: View {
    let stand: WidgetStand
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stand.partnerOrtName ?? "Kein Ort bekannt").font(.caption).bold().lineLimit(1)
            if let akku = stand.partnerAkku {
                Label("\(Int(akku * 100)) %", systemImage: "battery.50").font(.caption2)
            }
        }
    }
}

private struct PartnerBild: View {
    let bild: UIImage?
    var body: some View {
        if let bild {
            Image(uiImage: bild).resizable().scaledToFit()
        } else {
            Image(systemName: "person.crop.circle").resizable().scaledToFit().foregroundStyle(.secondary)
        }
    }
}

/// Akku und Wetter (Spec 9 "kleines Wetter-Symbol an der Partner-Figur … und im Widget", Brief I.3).
private struct PartnerDetails: View {
    let stand: WidgetStand
    var body: some View {
        HStack(spacing: 8) {
            if let akku = stand.partnerAkku {
                Label("\(Int(akku * 100)) %", systemImage: "battery.50")
            }
            if let wetter = stand.partnerWetter {
                Label(wetter, systemImage: stand.partnerWetterSymbol ?? "cloud.fill")
            }
        }
        .widgetEtikett()
    }
}

private struct PartnerSchmal: View {
    let entry: WidgetStandEntry
    let partner: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            WidgetKopf(titel: WidgetStil.name(partner), symbol: "heart.fill", farbe: WidgetStil.farbe(partner))
            PartnerBild(bild: entry.partnerFigur).frame(maxWidth: .infinity).frame(height: 56)
            Text(entry.stand.partnerOrtName ?? "Kein Ort bekannt").font(.subheadline.weight(.semibold)).fontDesign(.rounded).lineLimit(1)
            PartnerDetails(stand: entry.stand)
        }
    }
}

private struct PartnerBreit: View {
    let entry: WidgetStandEntry
    let partner: String
    var body: some View {
        HStack(spacing: 14) {
            PartnerBild(bild: entry.partnerFigur).frame(width: 84)
            VStack(alignment: .leading, spacing: 6) {
                WidgetKopf(titel: WidgetStil.name(partner), symbol: "heart.fill", farbe: WidgetStil.farbe(partner))
                Text(entry.stand.partnerOrtName ?? "Kein Ort bekannt").font(.title3.weight(.bold)).fontDesign(.rounded).lineLimit(2)
                PartnerDetails(stand: entry.stand)
            }
            Spacer(minLength: 0)
        }
    }
}
