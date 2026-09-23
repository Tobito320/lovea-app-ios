import SwiftUI

/// Z-36.3, Spec 3.4: last night of both (duration, asleep, awake) plus week bars, in the Health card
/// look (indigo tint, SF Rounded numbers). Read-only — `HealthModell` gets sleep only from HealthKit.
struct SchlafCard: View {
    private var health: HealthModell { HealthModell.shared }

    var body: some View {
        let heute = Datum.text(Date())
        VStack(alignment: .leading, spacing: 14) {
            Label("Schlaf", systemImage: "moon.zzz.fill")
                .font(.headline)
                .foregroundStyle(HabitFarbe.indigo.farbe)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .top, spacing: 16) {
                schlafPerson(.ahmed, heute: heute)
                schlafPerson(.annika, heute: heute)
            }
            wocheBalken(heute: heute)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(HabitFarbe.indigo.farbe)
    }

    private func schlafPerson(_ person: Person, heute: String) -> some View {
        let nacht = health.schlafNacht(person, heute)
        return VStack(alignment: .leading, spacing: 2) {
            Text(person.name).font(.caption.weight(.semibold)).foregroundStyle(Color.person(person))
            Text(nacht.map { dauerText($0.minuten) } ?? "–")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
            if let nacht {
                Text("\(uhrzeit(nacht.von))–\(uhrzeit(nacht.bis))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nacht.map { "\(person.name): \(dauerText($0.minuten)), \(uhrzeit($0.von)) bis \(uhrzeit($0.bis))" } ?? "\(person.name): keine Schlafdaten")
    }

    private func dauerText(_ minuten: Int) -> String { "\(minuten / 60) h \(minuten % 60) min" }

    private func uhrzeit(_ datum: Date) -> String {
        datum.formatted(.dateTime.hour().minute().locale(Locale(identifier: "de_DE")))
    }

    private func wocheBalken(heute: String) -> some View {
        let tage = HabitLogik.wochenTage(heute: heute)
        let alleMinuten = tage.flatMap { tag in Person.allCases.compactMap { health.schlafNacht($0, tag)?.minuten } }
        let maxMinuten = max(alleMinuten.max() ?? 480, 60)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(tage, id: \.self) { tag in
                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: 3) {
                        balken(health.schlafNacht(.ahmed, tag)?.minuten, hoechstwert: maxMinuten, farbe: Color.person(.ahmed))
                        balken(health.schlafNacht(.annika, tag)?.minuten, hoechstwert: maxMinuten, farbe: Color.person(.annika))
                    }
                    .frame(height: 56)
                    Text(HabitLogik.wochentagKuerzel[Datum.wochentag(tag) - 1])
                        .font(.caption2)
                        .foregroundStyle(tag == heute ? Color.primary : Color.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func balken(_ minuten: Int?, hoechstwert: Int, farbe: Color) -> some View {
        let hoehe = minuten.map { CGFloat($0) / CGFloat(hoechstwert) * 56 } ?? 3
        return Capsule()
            .fill(minuten != nil ? farbe : farbe.opacity(0.15))
            .frame(width: 7, height: max(3, hoehe))
    }
}
