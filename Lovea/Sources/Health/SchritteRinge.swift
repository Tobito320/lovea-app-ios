import SwiftUI
import UIKit

/// Ein Schritte-Ring (Z-21.1/Z-21.3, Spec 3.1): füllt sich bis zum eigenen Ziel, über 100 % läuft
/// eine zweite Runde (wie Apple Fitness). Wiederverwendet von `HealthTab` und Homes Duell-Karte.
/// // ponytail: zweite Runde ist die Obergrenze (200 %), keine dritte Runde für Extremtage.
struct SchritteRing: View {
    let person: Person
    var groesse: CGFloat = 108

    private var anzahl: Int? { HealthModell.shared.heuteSchritte(person) }
    private var ziel: Int { max(1, HealthModell.shared.zielSchritte(person)) }

    var body: some View {
        if let anzahl {
            ringGefuellt(anzahl)
        } else {
            HealthNichtErlaubtHinweis(person: person, groesse: groesse)
        }
    }

    private func ringGefuellt(_ anzahl: Int) -> some View {
        let anteil = Double(anzahl) / Double(ziel)
        let ersteRunde = min(anteil, 1)
        let zweiteRunde = min(max(anteil - 1, 0), 1)
        let farbe = Color.person(person)
        let breite = groesse * 0.11
        return ZStack {
            Circle().stroke(farbe.opacity(0.16), lineWidth: breite)
            Circle()
                .trim(from: 0, to: ersteRunde)
                .stroke(farbe, style: StrokeStyle(lineWidth: breite, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if zweiteRunde > 0 {
                Circle()
                    .trim(from: 0, to: zweiteRunde)
                    .stroke(farbe, style: StrokeStyle(lineWidth: breite * 0.55, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: farbe.opacity(0.5), radius: 3)
            }
            VStack(spacing: 0) {
                Text(anzahl.formatted(.number.locale(Locale(identifier: "de_DE"))))
                    .font(.system(size: groesse * 0.17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                Text(person.name)
                    .font(.system(size: groesse * 0.1))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: groesse, height: groesse)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: anzahl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.name): \(anzahl) von \(ziel) Schritten\(anteil >= 1 ? ", Ziel erreicht" : "")")
    }
}

/// "Health nicht erlaubt" statt einer irreführenden 0 (Spec 3.1, Review-Fokus 4) — auch der Zustand
/// "noch keine Daten heute" (z. B. direkt nach dem Start) sieht hier bewusst gleich aus, denn beides
/// bedeutet für die Anzeige dasselbe: kein Wert, den man ins Duell zählen dürfte.
struct HealthNichtErlaubtHinweis: View {
    let person: Person
    var groesse: CGFloat = 108

    private var eigenes: Bool { person == (Raum.shared.ich ?? .ahmed) }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.slash")
                .font(.system(size: groesse * 0.22))
                .foregroundStyle(.secondary)
            Text(eigenes ? "Health nicht erlaubt" : "Keine Daten")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if eigenes {
                Button(HealthModell.shared.berechtigungAngefragt ? "Einstellungen" : "Erlauben") { einstellungenOeffnen() }
                    .font(.caption2.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(Color.person(person))
            }
        }
        .frame(width: groesse)
        .frame(minHeight: groesse)
        .accessibilityElement(children: .combine)
    }

    /// UNSICHER (Bericht): `openSettingsURLString` öffnet Loveas allgemeine Einstellungsseite — ob
    /// diese auf iOS 26 direkt zum Health-Freigabe-Screen springt oder nur zur App-Seite (von der aus
    /// man selbst zu Health → Freigaben weiter muss), lässt sich ohne Gerät nicht sicher sagen.
    private func einstellungenOeffnen() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if HealthModell.shared.berechtigungAngefragt {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } else {
            HealthModell.shared.sicherstellen()
        }
    }
}
