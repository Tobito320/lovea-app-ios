import Charts
import SwiftUI

/// One bar of the week chart.
struct SchrittBalken: Identifiable, Sendable {
    let tag: String
    let person: Person
    let anzahl: Int?
    var id: String { tag + person.rawValue }
    var kuerzel: String { HabitLogik.wochentagKuerzel[Datum.wochentag(tag) - 1] }
}

/// Z-36.2, Spec 3.2 "Verlauf: nur die Woche": bars for both, the number above each bar, dragging a
/// finger over the chart shows the exact values with selection haptics.
struct SchritteWocheKarte: View {
    @State private var auswahl: String?
    private var health: HealthModell { HealthModell.shared }

    var body: some View {
        let tage = HabitLogik.wochenTage(heute: Datum.text(Date()))
        let balken = tage.flatMap { tag in Person.allCases.map { SchrittBalken(tag: tag, person: $0, anzahl: health.schritteAm($0, tag)) } }
        VStack(alignment: .leading, spacing: 12) {
            Text("Woche").font(.headline).accessibilityAddTraits(.isHeader)
            Text(zusammenfassung(balken)).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            SchritteWocheChart(balken: balken, auswahl: $auswahl)
        }
        .padding(16)
        .healthKarte()
    }

    private func zusammenfassung(_ balken: [SchrittBalken]) -> String {
        let gewaehlt = balken.filter { auswahl == nil || $0.kuerzel == auswahl }
        let teile = Person.allCases.map { person in
            "\(person.name) \(HealthText.zahl(gewaehlt.filter { $0.person == person }.compactMap(\.anzahl).reduce(0, +)))"
        }
        let titel = gewaehlt.first.map { auswahl == nil ? "Diese Woche" : Datum.anzeige($0.tag) } ?? "Diese Woche"
        return "\(titel): " + teile.joined(separator: " · ")
    }
}

struct SchritteWocheChart: View {
    let balken: [SchrittBalken]
    @Binding var auswahl: String?

    var body: some View {
        let hoechster = max(balken.compactMap(\.anzahl).max() ?? 0, 1000)
        // Only one value label (the tallest bar of the week or of the selected day): two labels
        // over the paired bars overlapped. The summary line above names both values.
        let sichtbar = balken.filter { auswahl == nil || $0.kuerzel == auswahl }
        let beschriftet = sichtbar.max { ($0.anzahl ?? 0) < ($1.anzahl ?? 0) }
        Chart(balken) { b in marke(b, beschriftet: beschriftet?.id == b.id) }
            .chartXSelection(value: $auswahl)
            .chartYScale(domain: 0...Int(Double(hoechster) * 1.2))
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 180)
            .onChange(of: auswahl) { _, neu in if neu != nil { Haptik.auswahl() } }
    }

    private func marke(_ b: SchrittBalken, beschriftet: Bool) -> some ChartContent {
        BarMark(x: .value("Tag", b.kuerzel), y: .value("Schritte", b.anzahl ?? 0), width: .ratio(0.9))
            .position(by: .value("Person", b.person.name))
            .foregroundStyle(Color.person(b.person))
            .cornerRadius(5)
            .opacity(auswahl == nil || auswahl == b.kuerzel ? 1 : 0.35)
            .annotation(position: .top, spacing: 3) {
                if beschriftet, let anzahl = b.anzahl {
                    Text(HealthText.kurz(anzahl)).font(.caption2.weight(.semibold)).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel(Text("\(b.person.name), \(Datum.anzeige(b.tag))"))
            .accessibilityValue(Text(b.anzahl.map { "\(HealthText.zahl($0)) Schritte" } ?? "keine Daten"))
    }
}

/// Z-36.2, Spec 3.2 "Eigenen Ring antippen": each day a mini ring (goal reached: full, else its
/// share), months swipeable, never the future.
struct SchritteMonatView: View {
    private var health: HealthModell { HealthModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                MonatsPager { zurueck in monat(zurueck).padding(.horizontal, 16) }
                Text("Voller Ring: Tagesziel geschafft.").font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Deine Schritte")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func monat(_ zurueck: Int) -> some View {
        let heute = Datum.text(Date())
        let gitter = HealthLogik.monatsGitter(heute: heute, monateZurueck: zurueck)
        let zellen = gitter + [String?](repeating: nil, count: max(0, 42 - gitter.count)) // immer 6 Zeilen, gleiche Höhe
        return VStack(alignment: .leading, spacing: 12) {
            Text(HealthText.monat(gitter)).font(.title3.weight(.semibold))
            Text(summe(gitter, heute: heute)).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            WochentagsKopf()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(Array(zellen.enumerated()), id: \.offset) { _, tag in zelle(tag, heute: heute) }
            }
        }
    }

    @ViewBuilder
    private func zelle(_ tag: String?, heute: String) -> some View {
        if let tag, tag <= heute {
            let anzahl = health.schritteAm(ich, tag)
            let ziel = HealthLogik.zielAmTag(tag, health.zielSchritteAenderungen[ich] ?? [], standard: 10_000)
            MiniRing(anteil: anzahl.map { Double($0) / Double(max(1, ziel)) }, farbe: Color.person(ich), tag: tag)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Datum.anzeige(tag)): \(anzahl.map { "\(HealthText.zahl($0)) Schritte" } ?? "keine Daten")")
        } else if let tag {
            Text(HealthText.tagesnummer(tag)).font(.caption2).foregroundStyle(.quaternary).frame(maxWidth: .infinity, minHeight: 36)
                .accessibilityHidden(true)
        } else {
            Color.clear.frame(height: 36)
        }
    }

    private func summe(_ gitter: [String?], heute: String) -> String {
        let werte = gitter.compactMap { $0 }.filter { $0 <= heute }.compactMap { health.schritteAm(ich, $0) }
        guard !werte.isEmpty else { return "Noch keine Schritte" }
        let gesamt = werte.reduce(0, +)
        return "\(HealthText.zahl(gesamt)) Schritte · Ø \(HealthText.zahl(gesamt / werte.count)) am Tag"
    }
}

/// Z-36.2, Spec 3.2 "Partner-Ring antippen": the partner's week against yours, bars side by side,
/// difference per day and in total (from your side: + means you are ahead).
struct SchritteVergleichView: View {
    private var health: HealthModell { HealthModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        let heute = Datum.text(Date())
        let tage = HabitLogik.wochenTage(heute: heute)
        let hoechster = max(tage.flatMap { tag in Person.allCases.compactMap { health.schritteAm($0, tag) } }.max() ?? 0, 1)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                gesamt(tage)
                VStack(spacing: 14) {
                    ForEach(tage, id: \.self) { tag in zeile(tag, zukunft: tag > heute, hoechster: hoechster) }
                }
                .padding(16)
                .healthKarte()
            }
            .padding(16)
        }
        .navigationTitle("\(ich.partner.name) gegen dich")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func gesamt(_ tage: [String]) -> some View {
        let mein = tage.compactMap { health.schritteAm(ich, $0) }.reduce(0, +)
        let sein = tage.compactMap { health.schritteAm(ich.partner, $0) }.reduce(0, +)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Diese Woche").font(.headline)
            HStack(alignment: .firstTextBaseline) {
                Text(differenz(mein - sein))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Du \(HealthText.zahl(mein))").foregroundStyle(Color.person(ich))
                    Text("\(ich.partner.name) \(HealthText.zahl(sein))").foregroundStyle(Color.person(ich.partner))
                }
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            }
        }
        .padding(16)
        .healthKarte()
        .accessibilityElement(children: .combine)
    }

    private func zeile(_ tag: String, zukunft: Bool, hoechster: Int) -> some View {
        let mein = health.schritteAm(ich, tag)
        let sein = health.schritteAm(ich.partner, tag)
        return HStack(spacing: 12) {
            Text(HabitLogik.wochentagKuerzel[Datum.wochentag(tag) - 1])
                .font(.subheadline.weight(.semibold))
                .frame(width: 30, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                balken(sein, hoechster: hoechster, farbe: Color.person(ich.partner))
                balken(mein, hoechster: hoechster, farbe: Color.person(ich))
            }
            Text(mein.flatMap { m in sein.map { differenz(m - $0) } } ?? "–")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 64, alignment: .trailing)
        }
        .opacity(zukunft ? 0.35 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Datum.anzeige(tag)): du \(mein.map(HealthText.zahl) ?? "keine Daten"), \(ich.partner.name) \(sein.map(HealthText.zahl) ?? "keine Daten")")
    }

    private func balken(_ wert: Int?, hoechster: Int, farbe: Color) -> some View {
        GeometryReader { geo in
            Capsule().fill(farbe.opacity(0.15))
                .overlay(alignment: .leading) {
                    Capsule().fill(farbe).frame(width: geo.size.width * CGFloat(wert ?? 0) / CGFloat(hoechster))
                }
        }
        .frame(height: 10)
    }

    private func differenz(_ d: Int) -> String { d > 0 ? "+\(HealthText.zahl(d))" : d < 0 ? "−\(HealthText.zahl(-d))" : "±0" }
}
