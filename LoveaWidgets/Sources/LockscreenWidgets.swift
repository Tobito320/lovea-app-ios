import SwiftUI
import WidgetKit

/// Sperrbildschirm "Wiedersehen": Rund zeigt die Tage bis zum nächsten gemeinsamen Treffen,
/// rechteckig Tage, Datum und Uhrzeit, Zeile den Satz.
struct WiedersehenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Wiedersehen", provider: WidgetStandProvider()) { entry in
            WiedersehenView(stand: entry.stand)
        }
        .configurationDisplayName("Wiedersehen")
        .description("Tage bis zu eurem nächsten Treffen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct WiedersehenView: View {
    @Environment(\.widgetFamily) private var family
    let stand: WidgetStand

    private var tage: Int? { LockscreenLogik.tageBis(treffen: stand.naechstesTreffen, heute: WidgetDatum.heute()) }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                if let tage {
                    Label("Wiedersehen \(LockscreenLogik.countdownText(tage: tage))", systemImage: "heart.fill")
                } else {
                    Label("Kein Treffen geplant", systemImage: "heart")
                }
            case .accessoryRectangular:
                rechteck
            default:
                rund
            }
        }
        .widgetURL(URL(string: "lovea://home"))
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var rund: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let tage, tage > 0 {
                VStack(spacing: 0) {
                    Text("\(tage)").font(.system(size: 24, weight: .bold, design: .rounded)).monospacedDigit().widgetAccentable()
                    Text(tage == 1 ? "Tag" : "Tage").font(.system(size: 10, weight: .medium))
                }
            } else {
                Image(systemName: tage == 0 ? "heart.fill" : "heart").font(.title2).widgetAccentable()
            }
        }
    }

    private var rechteck: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("Wiedersehen", systemImage: "heart.fill").font(.caption2.weight(.semibold)).widgetAccentable()
            if let tage, let datum = stand.naechstesTreffen {
                Text(LockscreenLogik.countdownText(tage: tage)).font(.headline).lineLimit(1)
                Text([LockscreenLogik.datumKurz(datum), stand.treffenUhrzeit].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Kein Treffen geplant").font(.headline).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Sperrbildschirm "Schlaf": letzte Nacht gegen das Ziel, dazu die Schritte von heute. Die Werte
/// kommen aus Apple Health, also auch von einem Tracker, der dorthin schreibt.
struct SchlafWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SchlafHeute", provider: WidgetStandProvider()) { entry in
            SchlafView(stand: entry.stand)
        }
        .configurationDisplayName("Schlaf")
        .description("Schlaf der letzten Nacht und Schritte von heute.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct SchlafView: View {
    @Environment(\.widgetFamily) private var family
    let stand: WidgetStand

    private var minuten: Int? { stand.schlafMinutenHeute?[stand.eigenePerson] }
    private var ziel: Int { max(stand.zielSchlafMinuten?[stand.eigenePerson] ?? 480, 1) }
    private var schritte: Int? { stand.schritteHeute[stand.eigenePerson] }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label(inlineText, systemImage: "moon.zzz.fill")
            case .accessoryRectangular:
                rechteck
            default:
                Gauge(value: Double(min(minuten ?? 0, ziel)), in: 0...Double(ziel)) {
                    Image(systemName: "moon.zzz.fill")
                } currentValueLabel: {
                    Text(minuten.map { "\($0 / 60)h" } ?? "–")
                }
                .gaugeStyle(.accessoryCircularCapacity)
            }
        }
        .widgetURL(URL(string: "lovea://health"))
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var inlineText: String {
        let schlaf = minuten.map { LockscreenLogik.schlafText(minuten: $0) + " h" } ?? "–"
        return schritte.map { "Schlaf \(schlaf) · \(LockscreenLogik.kurzZahl($0))" } ?? "Schlaf \(schlaf)"
    }

    private var rechteck: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Label("Schlaf", systemImage: "moon.zzz.fill").font(.caption2.weight(.semibold)).widgetAccentable()
                Spacer(minLength: 0)
                if let schritte {
                    Label(LockscreenLogik.kurzZahl(schritte), systemImage: "figure.walk").font(.caption2)
                }
            }
            Text(minuten.map { LockscreenLogik.schlafText(minuten: $0) + " h" } ?? "Keine Daten").font(.headline)
            Gauge(value: Double(min(minuten ?? 0, ziel)), in: 0...Double(ziel)) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
        }
    }
}
