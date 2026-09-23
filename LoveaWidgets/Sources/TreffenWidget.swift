import Foundation
import SwiftUI
import WidgetKit

/// Spec 10 "Treffen" (klein) + Sperrbildschirm-Ring (accessoryCircular): Tage bis zum nächsten
/// Treffen, aus `WidgetDatum.heute()` selbst berechnet (Review-Fokus 1), nicht aus einem
/// möglicherweise vor Mitternacht geschriebenen Feld im Stand.
struct TreffenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Treffen", provider: WidgetStandProvider()) { entry in
            TreffenView(entry: entry)
        }
        .configurationDisplayName("Treffen")
        .description("Tage bis zum nächsten Treffen.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

private enum TreffenTage {
    static func tage(_ stand: WidgetStand) -> Int? {
        guard let datum = stand.naechstesTreffenDatum else { return nil }
        return max(0, WidgetDatum.tageZwischen(WidgetDatum.heute(), datum))
    }
}

private struct TreffenView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetStandEntry

    var body: some View {
        Group {
            if family == .accessoryCircular {
                TreffenLockscreen(stand: entry.stand)
            } else {
                TreffenKarte(stand: entry.stand)
            }
        }
        .widgetURL(URL(string: "lovea://home"))
        .containerBackground(.background, for: .widget)
    }
}

private struct TreffenKarte: View {
    let stand: WidgetStand
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Treffen", systemImage: "calendar.badge.clock").font(.caption2).foregroundStyle(.secondary)
            if let tage = TreffenTage.tage(stand) {
                Text(tage == 0 ? "Heute!" : "\(tage)").font(.system(size: 30, weight: .bold))
                if tage != 0 { Text(tage == 1 ? "Tag" : "Tage").font(.caption) }
            } else {
                Text("Kein Treffen geplant").font(.caption)
            }
            if let text = stand.naechstesTreffenText { Text(text).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
        }
        .padding(4)
    }
}

private struct TreffenLockscreen: View {
    let stand: WidgetStand
    var body: some View {
        VStack(spacing: 0) {
            if let tage = TreffenTage.tage(stand) {
                Text("\(tage)").font(.title2).bold()
                Text("Tage").font(.system(size: 9))
            } else {
                Image(systemName: "calendar")
            }
        }
    }
}
