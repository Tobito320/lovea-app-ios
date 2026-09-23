import SwiftUI
import UIKit

/// Z-21.1/Z-21.2, Spec 3.1/3.2: "Heute"-Karte für Gym und Wasser, plus die Woche/Monat/Jahr-Historie
/// — für Schritte fest auf dem Health-Tab (Spec 3.1 "Darunter Verlauf"), für Gym/Wasser beim
/// Antippen der jeweiligen Zeile (Spec 3.2 "Antippen einer Habit-Zeile öffnet die Historie").
enum HabitArt: String {
    case schritte, gym, wasser
    var titel: String {
        switch self {
        case .schritte: return "Schritte"
        case .gym: return "Gym"
        case .wasser: return "Wasser"
        }
    }
}

struct HabitsHeuteCard: View {
    private var health: HealthModell { HealthModell.shared }
    private var heute: String { Datum.text(Date()) }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Heute").font(.headline)
            gymZeile
            Divider()
            wasserZeile
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var gymZeile: some View {
        HStack(spacing: 14) {
            NavigationLink { HabitHistoryView(art: .gym) } label: {
                HStack { Text("Gym").font(.body.weight(.semibold)); Spacer() }.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            gymKreis(.ahmed)
            gymKreis(.annika)
        }
        .frame(minHeight: 44)
    }

    private func gymKreis(_ person: Person) -> some View {
        let an = health.gymAbgehakt(person, heute)
        return Group {
            if person == ich {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    health.setzeGym(datum: heute, an: !an)
                } label: {
                    kreisInhalt(an: an, farbe: Color.person(person))
                }
                .buttonStyle(.plain)
            } else {
                kreisInhalt(an: an, farbe: Color.person(person))
            }
        }
        .accessibilityLabel("Gym \(person.name)")
        .accessibilityValue(an ? "erledigt" : "offen")
        .accessibilityAddTraits(person == ich ? .isButton : [])
    }

    private func kreisInhalt(an: Bool, farbe: Color) -> some View {
        Circle()
            .fill(an ? farbe : Color(uiColor: .tertiarySystemFill))
            .frame(width: 36, height: 36)
            .overlay {
                if an { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) }
            }
            .scaleEffect(an ? 1 : 0.9)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: an)
    }

    private var wasserZeile: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink { HabitHistoryView(art: .wasser) } label: {
                HStack {
                    Text("Wasser").font(.body.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(minHeight: 30)
            wasserGlaeserZeile(ich, interaktiv: true)
            wasserGlaeserZeile(ich.partner, interaktiv: false)
        }
    }

    private func wasserGlaeserZeile(_ person: Person, interaktiv: Bool) -> some View {
        let anzahl = health.wasserAnzahl(person, heute)
        let ziel = max(1, HealthLogik.zielAmTag(heute, health.zielWasserAenderungen[person] ?? [], standard: 8))
        return HStack(spacing: 4) {
            Text(person.name).font(.caption).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(0..<ziel, id: \.self) { index in
                        Image(systemName: index < anzahl ? "drop.fill" : "drop")
                            .foregroundStyle(index < anzahl ? Color.person(person) : Color(uiColor: .tertiarySystemFill))
                            .frame(width: 26, height: 30)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard interaktiv else { return }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                health.setzeWasser(datum: heute, anzahl: anzahl == index + 1 ? index : index + 1)
                            }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wasser \(person.name): \(anzahl) von \(ziel) Gläsern")
    }
}

// MARK: - Historie (Z-21.1 "Verlauf" / Z-21.2 "Ansichten")

/// Push-Ziel beim Antippen der Gym-/Wasser-Zeile (Spec 3.2). Für Schritte sitzt dieselbe Ansicht
/// fest eingebettet auf dem Tab, siehe `VerlaufCard`.
struct HabitHistoryView: View {
    let art: HabitArt

    var body: some View {
        ScrollView { HabitVerlaufInhalt(art: art).padding(16) }
            .navigationTitle(art.titel)
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Z-21.1, Spec 3.1: Schritte-Verlauf fest unter den Ringen — dieselbe Woche/Monat/Jahr-Ansicht wie
/// `HabitHistoryView`, nur ohne eigene Navigation, weil sie direkt auf dem Tab sitzt.
struct VerlaufCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Verlauf").font(.headline)
            HabitVerlaufInhalt(art: .schritte)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct HabitVerlaufInhalt: View {
    let art: HabitArt

    @State private var ansicht = 0
    @State private var monateZurueck = 0

    private var health: HealthModell { HealthModell.shared }
    private var heute: String { Datum.text(Date()) }

    var body: some View {
        VStack(spacing: 18) {
            Picker("Ansicht", selection: $ansicht) {
                Text("Woche").tag(0)
                Text("Monat").tag(1)
                Text("Jahr").tag(2)
            }
            .pickerStyle(.segmented)

            switch ansicht {
            case 0:
                // Spec 3.1 ist hier explizit: Schritte-Woche sind Balken, nicht die Stufen-Kästchen.
                if art == .schritte { schritteWoche } else { wocheAnsicht }
            case 1: monatAnsicht
            default: jahrAnsicht
            }
            if !(art == .schritte && ansicht == 0) { legende }
        }
    }

    // MARK: Woche

    /// Spec 3.1 "Woche (Balken pro Tag, beide)" — nur für Schritte, Gym/Wasser bleiben bei den
    /// Stufen-Kästchen (`wocheAnsicht`), weil sie 0…3-Level sind, keine stetige Menge wie Schritte.
    private var schritteWoche: some View {
        let tage = HealthLogik.wocheTage(heute)
        let werte = Person.allCases.map { p in tage.map { health.schritteAm(p, $0) } }
        let ziele = Person.allCases.map { HealthLogik.zielAmTag(heute, health.zielSchritteAenderungen[$0] ?? [], standard: 10_000) }
        let hoechstwert = max(werte.flatMap { $0.compactMap { $0 } }.max() ?? 0, ziele.max() ?? 10_000, 1)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(tage, id: \.self) { tag in
                VStack(spacing: 3) {
                    HStack(alignment: .bottom, spacing: 2) {
                        schrittBalken(health.schritteAm(.ahmed, tag), hoechstwert: hoechstwert, farbe: Color.person(.ahmed))
                        schrittBalken(health.schritteAm(.annika, tag), hoechstwert: hoechstwert, farbe: Color.person(.annika))
                    }
                    .frame(height: 56)
                    Text(wochentagsKuerzel(tag)).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(schrittTagBeschriftung(tag))
            }
        }
    }

    private func schrittBalken(_ anzahl: Int?, hoechstwert: Int, farbe: Color) -> some View {
        let hoehe = anzahl.map { CGFloat($0) / CGFloat(hoechstwert) * 56 } ?? 2
        return RoundedRectangle(cornerRadius: 2)
            .fill(anzahl != nil ? farbe : Color(uiColor: .tertiarySystemFill))
            .frame(width: 8, height: Swift.max(2, hoehe))
    }

    private func schrittTagBeschriftung(_ tag: String) -> String {
        let ahmed = health.schritteAm(.ahmed, tag).map { "\($0)" } ?? "keine Daten"
        let annika = health.schritteAm(.annika, tag).map { "\($0)" } ?? "keine Daten"
        return "\(Datum.anzeige(tag)): Ahmed \(ahmed), Annika \(annika)"
    }

    private func wochentagsKuerzel(_ tag: String) -> String { ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"][Datum.wochentag(tag) - 1] }

    private var wocheAnsicht: some View {
        let tage = HealthLogik.wocheTage(heute)
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(Person.allCases, id: \.self) { person in
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name).font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(tage, id: \.self) { tag in zelle(stufe(person, tag), tag: tag, groesse: 32) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Monat

    private var monatAnsicht: some View {
        VStack(spacing: 10) {
            HStack {
                Button { wechsleMonat(1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel("Vorheriger Monat")
                Spacer()
                Text(monatsTitel).font(.subheadline.weight(.semibold))
                Spacer()
                Button { wechsleMonat(-1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .disabled(monateZurueck == 0)
                    .accessibilityLabel("Nächster Monat")
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 6) {
                ForEach(Array(monatsGitter.enumerated()), id: \.offset) { _, tag in
                    if let tag { monatsZelle(tag) } else { Color.clear.frame(height: 28) }
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .contentShape(Rectangle())
        .gesture(
            // Wie `MonatsAnsicht`: links wischen = später (Richtung heute), rechts wischen = früher.
            DragGesture(minimumDistance: 24).onEnded { wert in
                if wert.translation.width < -30 { wechsleMonat(-1) }
                else if wert.translation.width > 30 { wechsleMonat(1) }
            }
        )
    }

    private var monatsGitter: [String?] { HealthLogik.monatsGitter(heute: heute, monateZurueck: monateZurueck) }

    private func wechsleMonat(_ delta: Int) {
        UISelectionFeedbackGenerator().selectionChanged()
        monateZurueck = max(0, monateZurueck + delta)
    }

    private var monatsTitel: String {
        let aktuellerErster = String(heute.prefix(7)) + "-01"
        guard let ziel = Datum.kalender.date(byAdding: .month, value: -monateZurueck, to: Datum.datum(aktuellerErster)) else { return "" }
        let f = DateFormatter()
        f.calendar = Datum.kalender
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: ziel)
    }

    private func monatsZelle(_ tag: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 2).fill(farbe(stufe(.ahmed, tag))).frame(width: 9, height: 14)
                RoundedRectangle(cornerRadius: 2).fill(farbe(stufe(.annika, tag))).frame(width: 9, height: 14)
            }
            Text(tagesnummer(tag)).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(height: 28)
        .accessibilityLabel("\(Datum.anzeige(tag))")
    }

    private func tagesnummer(_ tag: String) -> String { String(Int(tag.suffix(2)) ?? 0) }

    // MARK: Jahr

    private var jahrAnsicht: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Person.allCases, id: \.self) { person in
                VStack(alignment: .leading, spacing: 6) {
                    Text(person.name).font(.caption).foregroundStyle(.secondary)
                    jahrGitter(person)
                }
            }
        }
    }

    private func jahrGitter(_ person: Person) -> some View {
        let tage = HealthLogik.jahresGitter(heute: heute)
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(11), spacing: 2), count: 7), spacing: 2) {
                ForEach(tage, id: \.self) { tag in
                    RoundedRectangle(cornerRadius: 2).fill(farbe(stufe(person, tag))).frame(width: 11, height: 11)
                }
            }
            .padding(.vertical, 2)
        }
        .defaultScrollAnchor(.trailing)
        .frame(height: 90)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.name)s Jahresübersicht \(art.titel)")
    }

    // MARK: Gemeinsame Stufen-/Farblogik

    /// UI-seitige Anwendung von `HealthLogik.gymStufe`/`wasserStufe` je Tag — die Logik selbst bleibt
    /// in `HealthLogik` (Z-22.1), hier wird sie nur pro Kalendertag aufgerufen statt nur für "heute".
    /// Für Monat/Jahr (Spec 3.1: "GitHub-Raster, drei Grüntöne", Zielplan Z-21.1) auch für Schritte —
    /// nur die Woche ist dort explizit Balken (`schritteWoche`), diese Funktion wird für `ansicht == 0`
    /// bei `.schritte` also nie aufgerufen.
    /// // ponytail: Schritte-Monat/-Jahr nutzen `wasserStufe`s Prozent-vom-Ziel-Schwellen (<50 %/≥50 %/
    /// 100 %, Spec 4.2s Wasser-Stufen) statt einer eigenen `schritteStufe` — dieselbe Skala passt, spart
    /// eine vierte Funktion in `HealthLogik` für exakt dieselbe Formel.
    private func stufe(_ person: Person, _ tag: String) -> Int {
        switch art {
        case .schritte:
            let ziel = HealthLogik.zielAmTag(tag, health.zielSchritteAenderungen[person] ?? [], standard: 10_000)
            return HealthLogik.wasserStufe(glaeser: health.schritteAm(person, tag) ?? 0, ziel: ziel)
        case .gym:
            let montag = Datum.montagDerWoche(tag)
            let erledigtInWoche = (0..<Datum.wochentag(tag)).reduce(0) { summe, offset in
                summe + (health.gymAbgehakt(person, Datum.addTage(montag, offset)) ? 1 : 0)
            }
            let ziel = HealthLogik.zielAmTag(tag, health.zielGymAenderungen[person] ?? [], standard: 3)
            return HealthLogik.gymStufe(heuteAbgehakt: health.gymAbgehakt(person, tag), erledigtInWoche: erledigtInWoche, ziel: ziel, wochentag: Datum.wochentag(tag))
        case .wasser:
            let ziel = HealthLogik.zielAmTag(tag, health.zielWasserAenderungen[person] ?? [], standard: 8)
            return HealthLogik.wasserStufe(glaeser: health.wasserAnzahl(person, tag), ziel: ziel)
        }
    }

    private func farbe(_ stufe: Int) -> Color {
        switch stufe {
        case 1: return Color.green.opacity(0.35)
        case 2: return Color.green.opacity(0.65)
        case 3: return Color.green
        default: return Color(uiColor: .tertiarySystemFill)
        }
    }

    private func zelle(_ stufe: Int, tag: String, groesse: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6).fill(farbe(stufe)).frame(width: groesse, height: groesse)
            .accessibilityLabel(Datum.anzeige(tag))
    }

    private var legende: some View {
        HStack(spacing: 6) {
            Text("Weniger").font(.caption2).foregroundStyle(.secondary)
            ForEach([0, 1, 2, 3], id: \.self) { s in
                RoundedRectangle(cornerRadius: 2).fill(farbe(s)).frame(width: 11, height: 11)
            }
            Text("Mehr").font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }
}
