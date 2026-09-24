import SwiftUI
import UIKit

/// Z-36.2, Spec 3.2: step ring in the person's color, big SF Rounded number. Over 100 % a second,
/// thinner lap runs (like Apple Fitness). Pure — values come in, so the render board can draw it.
// ponytail: the second lap is the cap (200 %), no third lap for extreme days.
struct SchritteRing: View {
    let person: Person
    let anzahl: Int?
    let ziel: Int
    var groesse: CGFloat = 132

    @ScaledMetric(relativeTo: .title) private var skala: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let seite = groesse * min(max(skala, 1), 1.35)
        let anteil = Double(anzahl ?? 0) / Double(max(1, ziel))
        ZStack {
            ring(seite: seite, anteil: anteil)
            VStack(spacing: 0) {
                Text(anzahl.map(HealthText.zahl) ?? "–")
                    .font(.system(size: seite * 0.2, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: Double(anzahl ?? 0)))
                Text("Schritte")
                    .font(.system(size: seite * 0.09, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, seite * 0.16)
        }
        .frame(width: seite, height: seite)
        .animation(reduceMotion ? nil : Feder.weich, value: anzahl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(beschreibung(anteil))
    }

    private func ring(seite: CGFloat, anteil: Double) -> some View {
        let farbe = Color.person(person)
        let breite = seite * 0.11
        let ersteRunde = min(anteil, 1)
        let zweiteRunde = min(max(anteil - 1, 0), 1)
        return ZStack {
            Circle().stroke(farbe.opacity(0.16), lineWidth: breite)
            Circle()
                .trim(from: 0, to: ersteRunde)
                .stroke(
                    AngularGradient(colors: [farbe.opacity(0.7), farbe], center: .center, startAngle: .zero, endAngle: .degrees(360 * max(ersteRunde, 0.01))),
                    style: StrokeStyle(lineWidth: breite, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            if zweiteRunde > 0 {
                Circle()
                    .trim(from: 0, to: zweiteRunde)
                    .stroke(farbe, style: StrokeStyle(lineWidth: breite * 0.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: farbe.opacity(0.5), radius: 3)
            }
        }
        .padding(breite / 2)
    }

    private func beschreibung(_ anteil: Double) -> String {
        guard let anzahl else { return "\(person.name): keine Schritte heute" }
        return "\(person.name): \(HealthText.zahl(anzahl)) von \(HealthText.zahl(ziel)) Schritten\(anteil >= 1 ? ", Ziel erreicht" : "")"
    }
}

/// Ring plus name and "5,1 km · 7 Etagen" below (Spec 3.2). Health tab and Home share it.
struct SchritteSpalte: View {
    let person: Person
    let anzahl: Int?
    let ziel: Int
    let km: Double?
    let etagen: Int?
    var groesse: CGFloat = 132

    var body: some View {
        VStack(spacing: 8) {
            SchritteRing(person: person, anzahl: anzahl, ziel: ziel, groesse: groesse)
            VStack(spacing: 2) {
                Text(person.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(HealthText.strecke(km: km, etagen: etagen) ?? " ")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Z-36.2: the step duel on the Health tab. Each ring zooms into the steps detail of that person.
struct SchritteKarte: View {
    let zoom: Namespace.ID
    let oeffnen: (HealthZiel) -> Void

    private var health: HealthModell { HealthModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(Person.allCases, id: \.self) { person in spalte(person) }
            }
            if health.heuteSchritte(ich) == nil { HealthNichtErlaubtHinweis() }
        }
        .padding(16)
        .healthKarte()
    }

    private func spalte(_ person: Person) -> some View {
        let heute = Datum.text(Date())
        let ziel = HealthZiel.schritte(person)
        return Button { oeffnen(ziel) } label: {
            SchritteSpalte(
                person: person, anzahl: health.heuteSchritte(person), ziel: health.zielSchritte(person),
                km: health.kmAm(person, heute), etagen: health.etagenAm(person, heute)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.federnd)
        .matchedTransitionSource(id: ziel, in: zoom)
        .accessibilityHint("Öffnet die Schritte von \(person == ich ? "dir" : person.name)")
    }
}

/// "Health nicht erlaubt" instead of a misleading 0 (Review-Fokus 4 aus Runde 2). Before the first
/// prompt the button asks, afterwards it leads to Settings (HealthKit never says what was granted).
struct HealthNichtErlaubtHinweis: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.slash").foregroundStyle(.secondary)
            Text("Health nicht erlaubt").font(.footnote).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button(HealthModell.shared.berechtigungAngefragt ? "Einstellungen" : "Erlauben") { erlauben() }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
        }
    }

    /// UNSICHER (Bericht): `openSettingsURLString` öffnet Loveas Einstellungsseite; ob iOS 26 von dort
    /// direkt zu den Health-Freigaben springt, lässt sich ohne Gerät nicht sagen.
    private func erlauben() {
        Haptik.leicht()
        if HealthModell.shared.berechtigungAngefragt {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } else {
            HealthModell.shared.sicherstellen()
        }
    }
}

/// One day of the month calendar: a small ring (full at the goal, else its share) around the day number.
struct MiniRing: View {
    /// `nil` = no steps that day.
    let anteil: Double?
    let farbe: Color
    let tag: String

    var body: some View {
        ZStack {
            Circle().stroke(farbe.opacity(0.15), lineWidth: 3.5)
            if let anteil, anteil > 0 {
                Circle()
                    .trim(from: 0, to: min(anteil, 1))
                    .stroke(farbe, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Text(HealthText.tagesnummer(tag))
                .font(.system(.caption2, design: .rounded).weight((anteil ?? 0) >= 1 ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle((anteil ?? 0) >= 1 ? Color.primary : Color.secondary)
        }
        .frame(width: 36, height: 36)
    }
}
