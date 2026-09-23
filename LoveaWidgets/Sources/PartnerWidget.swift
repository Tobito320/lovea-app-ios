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

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text(entry.stand.partnerOrtName ?? "Partner")
            case .accessoryRectangular:
                PartnerRechteck(stand: entry.stand)
            case .systemMedium:
                PartnerBreit(entry: entry)
            default:
                PartnerSchmal(entry: entry)
            }
        }
        .widgetURL(URL(string: "lovea://home"))
        .containerBackground(.background, for: .widget)
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

/// Spec 9 "kleines Wetter-Symbol an der Partner-Figur … und im Widget" (Brief I.3).
private struct PartnerWetterLabel: View {
    let stand: WidgetStand
    var body: some View {
        if let wetter = stand.partnerWetter {
            Label(wetter, systemImage: stand.partnerWetterSymbol ?? "cloud.fill")
        }
    }
}

private struct PartnerSchmal: View {
    let entry: WidgetStandEntry
    var body: some View {
        VStack(spacing: 4) {
            PartnerBild(bild: entry.partnerFigur).frame(height: 64)
            Text(entry.stand.partnerOrtName ?? "Kein Ort bekannt").font(.caption2).lineLimit(1)
            HStack(spacing: 6) {
                if let akku = entry.stand.partnerAkku {
                    Label("\(Int(akku * 100)) %", systemImage: "battery.50").font(.caption2).foregroundStyle(.secondary)
                }
                PartnerWetterLabel(stand: entry.stand).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(4)
    }
}

private struct PartnerBreit: View {
    let entry: WidgetStandEntry
    var body: some View {
        HStack(spacing: 12) {
            PartnerBild(bild: entry.partnerFigur).frame(width: 76)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.stand.partnerOrtName ?? "Kein Ort bekannt").font(.headline)
                if let akku = entry.stand.partnerAkku {
                    Label("\(Int(akku * 100)) %", systemImage: "battery.50").font(.caption)
                }
                PartnerWetterLabel(stand: entry.stand).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(4)
    }
}
