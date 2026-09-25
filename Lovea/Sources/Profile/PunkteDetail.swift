import Charts
import SwiftUI

// MARK: - Logik (rein, getestet in PunkteAufschluesselungTests)

/// Ordnet `PunkteModell.verlauf` nach Herkunft. Kennt auch feinere `grund`-Namen ("Schritte",
/// "Gym", "Wasserziel" …), falls `PunkteLogik` den Tageseintrag später aufteilt; bis dahin landet
/// der Sammeleintrag "Tag" unter "Tagespunkte".
enum PunkteAufschluesselung {
    enum Kategorie: String, CaseIterable, Identifiable, Sendable {
        case tag, schritte, gym, wasser, spiele, serie, duell, gemeinsam, streak, shop, sonstiges
        var id: String { rawValue }

        var titel: String {
            switch self {
            case .tag: "Tagespunkte"
            case .schritte: "Schritte"
            case .gym: "Gym"
            case .wasser: "Wasser"
            case .spiele: "Spiele"
            case .serie: "Schritte-Serien"
            case .duell: "Duell der Woche"
            case .gemeinsam: "Gemeinsame Ziele"
            case .streak: "Chat-Streak"
            case .shop: "Shop"
            case .sonstiges: "Sonstiges"
            }
        }

        var symbol: String {
            switch self {
            case .tag: "sun.max.fill"
            case .schritte: "figure.walk"
            case .gym: "dumbbell.fill"
            case .wasser: "drop.fill"
            case .spiele: "gamecontroller.fill"
            case .serie: "flame.fill"
            case .duell: "trophy.fill"
            case .gemeinsam: "heart.circle.fill"
            case .streak: "bubble.left.and.bubble.right.fill"
            case .shop: "bag.fill"
            case .sonstiges: "star.fill"
            }
        }

        var farbe: Color {
            switch self {
            case .tag: .yellow
            case .schritte: .green
            case .gym: .orange
            case .wasser: .cyan
            case .spiele: .purple
            case .serie: .red
            case .duell: .indigo
            case .gemeinsam: .pink
            case .streak: .teal
            case .shop: .gray
            case .sonstiges: .secondary
            }
        }
    }

    struct Gruppe: Identifiable, Sendable {
        let kategorie: Kategorie
        let summe: Int
        let eintraege: [PunkteLogik.Eintrag]
        var id: String { kategorie.id }
    }

    static func kategorie(_ grund: String) -> Kategorie {
        if grund.hasPrefix("Kauf:") || grund.hasPrefix("Geschenk:") { return .shop }
        if grund.hasPrefix("Serie") { return .serie }
        if grund.hasPrefix("Gemeinsam") { return .gemeinsam }
        if grund.hasPrefix("Gym") { return .gym }
        if grund.hasPrefix("Spiel") { return .spiele }
        switch grund {
        case "Tag": return .tag
        case "Schritte", "Schrittziel", "15.000 Schritte": return .schritte
        case "Wasserziel": return .wasser
        case "Duell der Woche": return .duell
        case "Chat-Streak": return .streak
        default: return .sonstiges
        }
    }

    /// Eine Gruppe je Kategorie mit Einträgen, größte Beträge zuerst (Shop als Abzug ans Ende).
    static func gruppen(_ eintraege: [PunkteLogik.Eintrag]) -> [Gruppe] {
        Dictionary(grouping: eintraege) { kategorie($0.grund) }
            .map { Gruppe(kategorie: $0.key, summe: $0.value.reduce(0) { $0 + $1.punkte }, eintraege: $0.value.sorted { $0.datum > $1.datum }) }
            .sorted { ($0.summe, $0.kategorie.rawValue) > ($1.summe, $1.kategorie.rawValue) }
    }

    /// Verdiente Punkte (ohne Abzüge) je Tag Mo…So der Woche von `montag`.
    static func woche(_ eintraege: [PunkteLogik.Eintrag], montag: String) -> [(tag: String, punkte: Int)] {
        (0..<7).map { offset in
            let tag = Datum.addTage(montag, offset)
            return (tag, eintraege.filter { $0.datum == tag && $0.punkte > 0 }.reduce(0) { $0 + $1.punkte })
        }
    }
}

/// "So gibt es Punkte" — spiegelt `PunkteLogik.tagesPunkte`, `wochenGymBonus` und
/// `ChallengeLogik` (Spec 4.1). `PunkteRegelnTests` prüft die Tageswerte gegen `tagesPunkte`.
enum PunkteRegeln {
    struct Regel: Identifiable, Sendable {
        let kategorie: PunkteAufschluesselung.Kategorie
        let text: String
        let punkte: String
        var id: String { text }
    }

    static let schrittProHundert = 1
    static let schritteMaxProTag = 300
    static let schrittziel = 20
    static let fuenfzehnTausend = 30
    static let gymTag = 40
    static let gymWoche = 80
    static let wasserziel = 10
    static let spielSieg = 10

    static let alle: [Regel] = [
        Regel(kategorie: .schritte, text: "Je 100 Schritte, höchstens 300 am Tag", punkte: "+\(schrittProHundert)"),
        Regel(kategorie: .schritte, text: "Schrittziel des Tages erreicht", punkte: "+\(schrittziel)"),
        Regel(kategorie: .schritte, text: "15.000 Schritte an einem Tag", punkte: "+\(fuenfzehnTausend)"),
        Regel(kategorie: .gym, text: "Gym abgehakt (bis 7 Tage nachträglich)", punkte: "+\(gymTag)"),
        Regel(kategorie: .gym, text: "Gym-Wochenziel geschafft", punkte: "+\(gymWoche)"),
        Regel(kategorie: .wasser, text: "Wasserziel des Tages erreicht", punkte: "+\(wasserziel)"),
        Regel(kategorie: .spiele, text: "Ein Spiel gewonnen", punkte: "+\(spielSieg)"),
        Regel(kategorie: .duell, text: "Schritte-Duell der Woche gewonnen", punkte: "+150"),
        Regel(kategorie: .gemeinsam, text: "Gemeinsames Wochenziel, für beide", punkte: "+150"),
        Regel(kategorie: .gemeinsam, text: "Gemeinsames Monatsziel, für beide", punkte: "+500"),
        Regel(kategorie: .serie, text: "Schrittziel 3 / 7 / 14 / 30 Tage in Folge", punkte: "+30 bis +600"),
    ]
}

// MARK: - Punkte-Knopf (ersetzt `PunkteChip` dort, wo man tippen soll)

struct PunkteKnopf: View {
    let person: Person
    @State private var offen = false

    var body: some View {
        Button { offen = true } label: { PunkteChip(person: person) }
            .buttonStyle(.plain)
            .accessibilityHint("Zeigt, woraus die Punkte bestehen")
            .sheet(isPresented: $offen) { PunkteDetailBlatt(person: person) }
    }
}

// MARK: - Profil-Karte "Punkte diese Woche"

struct ProfilPunkteKarte: View {
    let person: Person
    @State private var offen = false

    var body: some View {
        let eintraege = PunkteModell.shared.verlauf.filter { $0.von == person }
        let woche = PunkteAufschluesselung.woche(eintraege, montag: Datum.montagDerWoche(Datum.text(Date())))
        let summe = woche.reduce(0) { $0 + $1.punkte }
        Button { offen = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Punkte diese Woche", systemImage: "star.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("+\(summe)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .fontDesign(.rounded)
                        .contentTransition(.numericText(value: Double(summe)))
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                WochenBalken(woche: woche, farbe: .yellow, hoehe: 64)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Punkte diese Woche: \(summe)")
        .accessibilityHint("Zeigt, woraus die Punkte bestehen")
        .sheet(isPresented: $offen) { PunkteDetailBlatt(person: person) }
    }
}

private struct WochenBalken: View {
    let woche: [(tag: String, punkte: Int)]
    let farbe: Color
    let hoehe: CGFloat
    private static let kuerzel = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    var body: some View {
        let heute = Datum.text(Date())
        Chart(Array(woche.enumerated()), id: \.offset) { eintrag in
            BarMark(x: .value("Tag", Self.kuerzel[eintrag.offset]), y: .value("Punkte", eintrag.element.punkte))
                .foregroundStyle(eintrag.element.tag == heute ? farbe : farbe.opacity(0.45))
                .cornerRadius(4)
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { _ in AxisValueLabel().font(.caption2) }
        }
        .frame(height: hoehe)
        .accessibilityHidden(true)
    }
}

// MARK: - Detail-Blatt

struct PunkteDetailBlatt: View {
    let person: Person
    @Environment(\.dismiss) private var schliessen
    @State private var aufgeklappt: Set<String> = []

    var body: some View {
        // Einmal falten (wie `PunkteVerlaufView`), nicht je Abschnitt.
        let eintraege = PunkteModell.shared.verlauf.filter { $0.von == person }
        let gruppen = PunkteAufschluesselung.gruppen(eintraege)
        NavigationStack {
            List {
                kopf(eintraege)
                wocheAbschnitt(eintraege)
                herkunft(gruppen)
                regeln
                Section {
                    NavigationLink("Alle Einträge") { PunkteVerlaufView() }
                }
            }
            .navigationTitle(person == Raum.shared.ich ? "Deine Punkte" : "Punkte von \(person.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func kopf(_ eintraege: [PunkteLogik.Eintrag]) -> some View {
        let verdient = eintraege.filter { $0.punkte > 0 }.reduce(0) { $0 + $1.punkte }
        let ausgegeben = -eintraege.filter { $0.punkte < 0 }.reduce(0) { $0 + $1.punkte }
        let verfuegbar = PunkteModell.shared.verfuegbar(person)
        return Section {
            VStack(spacing: 4) {
                Text(verfuegbar.formatted(.number.locale(Locale(identifier: "de_DE"))))
                    .font(.largeTitle.weight(.bold).monospacedDigit())
                    .fontDesign(.rounded)
                    .contentTransition(.numericText(value: Double(verfuegbar)))
                Text("verfügbar").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Label("\(verdient) verdient", systemImage: "arrow.up.circle.fill").foregroundStyle(.green)
                    Label("\(ausgegeben) ausgegeben", systemImage: "arrow.down.circle.fill").foregroundStyle(.secondary)
                }
                .font(.footnote.weight(.medium))
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
        }
    }

    private func wocheAbschnitt(_ eintraege: [PunkteLogik.Eintrag]) -> some View {
        let woche = PunkteAufschluesselung.woche(eintraege, montag: Datum.montagDerWoche(Datum.text(Date())))
        return Section("Diese Woche: +\(woche.reduce(0) { $0 + $1.punkte })") {
            WochenBalken(woche: woche, farbe: .yellow, hoehe: 110)
                .padding(.vertical, 6)
        }
    }

    private func herkunft(_ gruppen: [PunkteAufschluesselung.Gruppe]) -> some View {
        let groesste = max(1, gruppen.map { abs($0.summe) }.max() ?? 1)
        return Section("Woraus sie bestehen") {
            if gruppen.isEmpty {
                Text("Noch keine Punkte. Schritte, Gym und Spiele bringen die ersten.").foregroundStyle(.secondary)
            }
            ForEach(gruppen) { gruppe in
                DisclosureGroup(isExpanded: Binding(
                    get: { aufgeklappt.contains(gruppe.id) },
                    set: { offen in if offen { aufgeklappt.insert(gruppe.id) } else { aufgeklappt.remove(gruppe.id) } }
                )) {
                    ForEach(Array(gruppe.eintraege.prefix(30).enumerated()), id: \.offset) { _, eintrag in
                        HStack {
                            Text(eintrag.grund == "Tag" ? "Tagespunkte" : eintrag.grund).font(.subheadline)
                            Spacer()
                            Text(Datum.anzeige(eintrag.datum)).font(.caption).foregroundStyle(.secondary)
                            Text(eintrag.punkte >= 0 ? "+\(eintrag.punkte)" : "\(eintrag.punkte)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .frame(minWidth: 48, alignment: .trailing)
                        }
                    }
                } label: {
                    gruppenZeile(gruppe, anteil: Double(abs(gruppe.summe)) / Double(groesste))
                }
            }
        }
    }

    private func gruppenZeile(_ gruppe: PunkteAufschluesselung.Gruppe, anteil: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: gruppe.kategorie.symbol)
                .foregroundStyle(gruppe.kategorie.farbe)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(gruppe.kategorie.titel).font(.subheadline.weight(.medium))
                    Spacer()
                    Text(gruppe.summe >= 0 ? "+\(gruppe.summe)" : "\(gruppe.summe)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                GeometryReader { geo in
                    Capsule().fill(gruppe.kategorie.farbe.opacity(0.8))
                        .frame(width: max(4, geo.size.width * anteil))
                }
                .frame(height: 5)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var regeln: some View {
        Section("So gibt es Punkte") {
            ForEach(PunkteRegeln.alle) { regel in
                HStack(spacing: 12) {
                    Image(systemName: regel.kategorie.symbol)
                        .foregroundStyle(regel.kategorie.farbe)
                        .frame(width: 28)
                    Text(regel.text).font(.subheadline)
                    Spacer()
                    Text(regel.punkte).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(.green)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
