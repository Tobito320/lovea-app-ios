import SwiftUI

/// Z-22.2: Punktestand-Kapsel (Health-Tab und eigenes Profil), laufende Challenges mit Fortschritt
/// (auch Z-21.1) und die "Wofür?"-Historie. Reine Anzeige — die Zahlen kommen aus `PunkteModell`
/// (`PunkteLogik`/`ChallengeLogik`, Z-22.1).
struct PunkteChip: View {
    let person: Person

    var body: some View {
        let verfuegbar = PunkteModell.shared.verfuegbar(person)
        HStack(spacing: 4) {
            Text("⭐️")
            Text(verfuegbar.formatted(.number.locale(Locale(identifier: "de_DE"))))
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(verfuegbar) Punkte")
    }
}

// MARK: - Laufende Challenges

private struct ChallengeKarte: Identifiable {
    var id: String
    var titel: String
    var untertitel: String
    var anteil: Double
    var farbe: Color
}

struct LaufendeChallengesCard: View {
    private var punkte: PunkteModell { PunkteModell.shared }

    var body: some View {
        let karten = challengeKarten
        if !karten.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Challenges").font(.headline)
                ForEach(karten) { karte in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(karte.titel).font(.subheadline.weight(.semibold))
                        Text(karte.untertitel).font(.caption).foregroundStyle(.secondary)
                        fortschrittsbalken(karte.anteil, farbe: karte.farbe)
                    }
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func fortschrittsbalken(_ anteil: Double, farbe: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color(uiColor: .tertiarySystemFill))
                RoundedRectangle(cornerRadius: 4).fill(farbe).frame(width: geo.size.width * max(0, min(1, anteil)))
            }
        }
        .frame(height: 8)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: anteil)
    }

    private func formatiert(_ n: Int) -> String { n.formatted(.number.locale(Locale(identifier: "de_DE"))) }

    private var challengeKarten: [ChallengeKarte] {
        var karten: [ChallengeKarte] = []
        if let woche = punkte.aktuelleWoche {
            let ahmed = woche.schritteDuell[.ahmed] ?? 0
            let annika = woche.schritteDuell[.annika] ?? 0
            if ahmed + annika > 0 {
                karten.append(ChallengeKarte(
                    id: "duell", titel: "Duell der Woche",
                    untertitel: "Ahmed \(formatiert(ahmed)) · Annika \(formatiert(annika))",
                    anteil: Double(ahmed) / Double(ahmed + annika), farbe: .loveaRose
                ))
            }
            karten.append(ChallengeKarte(
                id: "gemeinsamWoche", titel: "Gemeinsam Woche",
                untertitel: "\(formatiert(woche.schritteGesamt)) von \(formatiert(woche.gemeinsamZiel))",
                anteil: Double(woche.schritteGesamt) / Double(max(1, woche.gemeinsamZiel)), farbe: .mint
            ))
        }
        if let monat = punkte.aktuellerMonat {
            karten.append(ChallengeKarte(
                id: "gemeinsamMonat", titel: "Gemeinsam Monat",
                untertitel: "\(formatiert(monat.schritteGesamt)) von \(formatiert(ChallengeLogik.zielGemeinsamMonat))",
                anteil: Double(monat.schritteGesamt) / Double(ChallengeLogik.zielGemeinsamMonat), farbe: .purple
            ))
        }
        for person in Person.allCases {
            let laenge = punkte.laufendeSerien[person] ?? 0
            guard laenge > 0 else { continue }
            let naechstesZiel = [3, 7, 14, 30].first { $0 > laenge } ?? 30
            karten.append(ChallengeKarte(
                id: "serie-\(person.rawValue)", titel: "Serie \(person.name)",
                untertitel: "\(laenge) Tage am Stück", anteil: Double(laenge) / Double(naechstesZiel), farbe: .orange
            ))
        }
        return karten
    }
}

// MARK: - "Wofür?"

struct PunkteVerlaufView: View {
    var body: some View {
        // Einmal gelesen (Z-29.2): `verlauf` faltet Punkte/Challenges/Käufe komplett neu, zweimal
        // pro Render (ForEach + leer-Check) wäre die doppelte Arbeit für dieselbe Liste.
        let verlauf = PunkteModell.shared.verlauf
        List {
            ForEach(Array(verlauf.reversed().enumerated()), id: \.offset) { _, eintrag in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(grundText(eintrag)).font(.subheadline.weight(.medium))
                        Text("\(eintrag.von.name) · \(Datum.anzeige(eintrag.datum))").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(eintrag.punkte >= 0 ? "+\(eintrag.punkte)" : "\(eintrag.punkte)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(eintrag.punkte >= 0 ? Color.green : Color.red)
                }
            }
        }
        .overlay {
            if verlauf.isEmpty {
                ContentUnavailableView("Noch keine Punkte", systemImage: "star")
            }
        }
        .navigationTitle("Wofür?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func grundText(_ eintrag: PunkteLogik.Eintrag) -> String {
        switch eintrag.grund {
        case "Tag": return "Punkte des Tages"
        case "Gym-Wochenziel": return "Gym-Wochenziel geschafft"
        default: return eintrag.grund
        }
    }
}

// MARK: - Konfetti bei Abschluss

/// Merkt sich pro Gerät, welche Challenge-Abschlüsse schon gefeiert wurden (Z-22.2 "Konfetti bei
/// Abschluss"), damit derselbe Abschluss nicht bei jedem Tab-Wechsel erneut Konfetti auslöst.
/// // ponytail: `UserDefaults`, kein Server-Zustand — Konfetti ist rein kosmetisch, beide Geräte
/// dürfen unabhängig (und beim ersten je Gerät nicht rückwirkend) feiern.
@MainActor
enum ChallengeKonfetti {
    private static let schluessel = "lovea.health.gefeierteChallenges"

    static func neuAbgeschlossen() -> Bool {
        let punkte = PunkteModell.shared
        var aktuell: [String] = []
        if let sieger = punkte.letzteAbgeschlosseneWoche, let s = sieger.duellSieger {
            aktuell.append("duell-\(sieger.montag)-\(s.rawValue)")
        }
        if let woche = punkte.aktuelleWoche, woche.gemeinsamErreichtAm != nil {
            aktuell.append("gemeinsamWoche-\(woche.montag)")
        }
        if let monat = punkte.aktuellerMonat, monat.gemeinsamErreichtAm != nil {
            aktuell.append("gemeinsamMonat-\(monat.monat)")
        }
        for person in Person.allCases {
            let laenge = punkte.laufendeSerien[person] ?? 0
            if [3, 7, 14, 30].contains(laenge) { aktuell.append("serie-\(person.rawValue)-\(laenge)") }
        }

        let istErsterStart = UserDefaults.standard.object(forKey: schluessel) == nil
        let bisher = Set(UserDefaults.standard.stringArray(forKey: schluessel) ?? [])
        UserDefaults.standard.set(Array(bisher.union(aktuell)), forKey: schluessel)
        guard !istErsterStart else { return false }
        return aktuell.contains { !bisher.contains($0) }
    }
}
