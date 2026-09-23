import SwiftUI

/// Z-21.1, Spec 3.3: letzte Nacht beider Personen (Dauer, Einschlafen, Aufwachen) plus Wochen-Balken.
/// Nur Lesen, keine Eingabe — `HealthModell` speist sich hier ausschließlich aus HealthKit.
struct SchlafCard: View {
    private var health: HealthModell { HealthModell.shared }
    private var heute: String { Datum.text(Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Schlaf").font(.headline)
            HStack(alignment: .top, spacing: 20) {
                schlafPerson(.ahmed)
                schlafPerson(.annika)
            }
            wocheBalken
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func schlafPerson(_ person: Person) -> some View {
        let nacht = health.schlafNacht(person, heute)
        return VStack(alignment: .leading, spacing: 2) {
            Text(person.name).font(.caption).foregroundStyle(.secondary)
            if let nacht {
                Text(dauerText(nacht.minuten)).font(.title3.bold()).monospacedDigit()
                Text("\(uhrzeit(nacht.von))–\(uhrzeit(nacht.bis))").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("–").font(.title3.bold()).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(nacht.map { "\(person.name): \(dauerText($0.minuten)), \(uhrzeit($0.von)) bis \(uhrzeit($0.bis))" } ?? "\(person.name): keine Schlafdaten")
    }

    private func dauerText(_ minuten: Int) -> String { "\(minuten / 60) h \(minuten % 60) min" }

    private func uhrzeit(_ datum: Date) -> String {
        datum.formatted(.dateTime.hour().minute().locale(Locale(identifier: "de_DE")))
    }

    private var wocheBalken: some View {
        let tage = HealthLogik.wocheTage(heute)
        let alleMinuten = tage.flatMap { tag in Person.allCases.compactMap { health.schlafNacht($0, tag)?.minuten } }
        let maxMinuten = max(alleMinuten.max() ?? 480, 60)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(tage, id: \.self) { tag in
                VStack(spacing: 3) {
                    HStack(alignment: .bottom, spacing: 2) {
                        balken(health.schlafNacht(.ahmed, tag)?.minuten, hoechstwert: maxMinuten, farbe: Color.person(.ahmed))
                        balken(health.schlafNacht(.annika, tag)?.minuten, hoechstwert: maxMinuten, farbe: Color.person(.annika))
                    }
                    .frame(height: 56)
                    Text(kuerzel(tag)).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func balken(_ minuten: Int?, hoechstwert: Int, farbe: Color) -> some View {
        let hoehe = minuten.map { CGFloat($0) / CGFloat(hoechstwert) * 56 } ?? 2
        return RoundedRectangle(cornerRadius: 2)
            .fill(minuten != nil ? farbe : Color(uiColor: .tertiarySystemFill))
            .frame(width: 8, height: Swift.max(2, hoehe))
    }

    private func kuerzel(_ tag: String) -> String { ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"][Datum.wochentag(tag) - 1] }
}
