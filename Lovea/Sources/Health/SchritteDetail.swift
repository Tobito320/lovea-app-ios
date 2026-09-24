import Charts
import SwiftUI

/// Steps detail (Ahmed's reference, 24.09.2026): T/W/M in the glass nav bar, a big ring for the
/// chosen day/week/month (chevrons and swipe step through periods, never into the future), stat
/// chips, a smooth 7-day line with the goal and the chosen day, the week challenge as a
/// leaderboard, and a switch between Ahmed's and Annika's data.
struct SchritteDetailView: View {
    @State private var person: Person
    @State private var zeitraum: SchritteZeitraum = .tag
    @State private var anker = Datum.text(Date())
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(person: Person) { _person = State(initialValue: person) }

    private var health: HealthModell { HealthModell.shared }
    private var heute: String { Datum.text(Date()) }
    private var bewegung: Animation { reduceMotion ? .easeInOut(duration: 0.2) : Feder.federnd }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ringZeile
                SchritteStatChips(werte: statWerte)
                verlauf
                SchritteChallengeKarte()
            }
            .padding(16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { zeitraumWahl }
            ToolbarItem(placement: .topBarTrailing) { personWahl }
        }
        .onChange(of: zeitraum) { _, _ in
            Haptik.auswahl()
            anker = min(anker, heute)
        }
    }

    // MARK: Oben: T / W / M und Person

    private var zeitraumWahl: some View {
        Picker("Zeitraum", selection: $zeitraum.animation(bewegung)) {
            Text("T").tag(SchritteZeitraum.tag).accessibilityLabel("Tag")
            Text("W").tag(SchritteZeitraum.woche).accessibilityLabel("Woche")
            Text("M").tag(SchritteZeitraum.monat).accessibilityLabel("Monat")
        }
        .pickerStyle(.segmented)
        .frame(width: 168)
    }

    /// Default is yourself; tapping switches to the partner's synced steps.
    private var personWahl: some View {
        Button {
            withAnimation(bewegung) { person = person.partner }
            Haptik.auswahl()
        } label: {
            FigurKopf(person: person, groesse: 32)
        }
        .accessibilityLabel("Schritte von \(person.name)")
        .accessibilityHint("Wechselt zu \(person.partner.name)")
    }

    // MARK: Ring

    private var tage: [String] { SchritteLogik.tage(zeitraum, anker: anker) }

    private var ringZeile: some View {
        let werte = health.schritteWerte(person)
        let ziel = tage.reduce(0) { $0 + HealthLogik.zielAmTag($1, health.zielSchritteAenderungen[person] ?? [], standard: 10_000) }
        return HStack(spacing: 0) {
            pfeil("chevron.left", um: -1, label: "Früher")
            SchritteGrossRing(person: person, titel: titel, anzahl: SchritteLogik.summe(werte, tage: tage, heute: heute), ziel: ziel)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .simultaneousGesture(wischen)
            pfeil("chevron.right", um: 1, label: "Später")
        }
    }

    private func pfeil(_ symbol: String, um schritte: Int, label: String) -> some View {
        Button { wechseln(um: schritte) } label: {
            Image(systemName: symbol).font(.title3.weight(.semibold)).frame(width: 44, height: 44)
        }
        .buttonStyle(.federnd)
        .foregroundStyle(.secondary)
        .disabled(SchritteLogik.verschoben(anker, zeitraum, um: schritte, heute: heute) == nil)
        .accessibilityLabel(label)
    }

    private var wischen: some Gesture {
        DragGesture(minimumDistance: 24).onEnded { wert in
            guard abs(wert.translation.width) > abs(wert.translation.height) * 1.5, abs(wert.translation.width) > 50 else { return }
            wechseln(um: wert.translation.width < 0 ? 1 : -1)
        }
    }

    private func wechseln(um schritte: Int) {
        guard let neu = SchritteLogik.verschoben(anker, zeitraum, um: schritte, heute: heute) else {
            Haptik.warnung()
            return
        }
        withAnimation(bewegung) { anker = neu }
        Haptik.auswahl()
    }

    private var titel: String {
        let stil = Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
        switch zeitraum {
        case .tag:
            return anker == heute ? "Heute" : Datum.datum(anker).formatted(stil.day().month(.abbreviated).year())
        case .woche:
            guard let erster = tage.first else { return "" }
            return "Woche ab " + Datum.datum(erster).formatted(stil.day().month(.abbreviated))
        case .monat:
            return HealthText.monat(HealthLogik.monatsGitter(heute: anker, monateZurueck: 0))
        }
    }

    // MARK: Chips

    private var statWerte: SchritteExtra {
        let extras = tage.filter { $0 <= heute }.compactMap { health.extrasAm(person, $0) }
        func summe<T: AdditiveArithmetic>(_ pfad: KeyPath<SchritteExtra, T?>) -> T? {
            let werte = extras.compactMap { $0[keyPath: pfad] }
            return werte.isEmpty ? nil : werte.reduce(.zero, +)
        }
        return SchritteExtra(km: summe(\.km), etagen: summe(\.etagen), kcal: summe(\.kcal), aktivMinuten: summe(\.aktivMinuten))
    }

    // MARK: Verlauf

    @ViewBuilder
    private var verlauf: some View {
        if zeitraum == .monat {
            SchritteMonatRinge(person: person, anker: anker, heute: heute) { waehlen($0) }
        } else {
            let fenster = zeitraum == .tag ? SchritteLogik.fensterTage(anker: anker, heute: heute) : tage
            SchritteLinie(
                punkte: SchritteLogik.linienPunkte(tage: fenster, werte: health.schritteWerte(person), heute: heute),
                ziel: health.zielSchritte(person),
                gewaehlt: zeitraum == .tag ? anker : nil,
                farbe: Color.person(person)
            ) { waehlen($0) }
        }
    }

    /// Tapping a day in the chart or the month shows that day in the ring.
    private func waehlen(_ tag: String) {
        guard tag <= heute, tag != anker || zeitraum != .tag else { return }
        Haptik.auswahl()
        withAnimation(bewegung) {
            zeitraum = .tag
            anker = tag
        }
    }
}

// MARK: - Ring

/// Big ring of the steps detail: period above the number, the number, "von 10.000 Schritten",
/// a badge once the goal is reached. Pure, so the render board can draw it.
struct SchritteGrossRing: View {
    let person: Person
    let titel: String
    let anzahl: Int?
    let ziel: Int

    @ScaledMetric(relativeTo: .largeTitle) private var skala: CGFloat = 1

    var body: some View {
        let seite = 250 * min(max(skala, 1), 1.25)
        let anteil = Double(anzahl ?? 0) / Double(max(1, ziel))
        let farbe = Color.person(person)
        ZStack {
            Circle().stroke(farbe.opacity(0.15), lineWidth: 22)
            Circle()
                .trim(from: 0, to: min(anteil, 1))
                .stroke(
                    AngularGradient(colors: [farbe.opacity(0.65), farbe], center: .center, startAngle: .zero, endAngle: .degrees(360 * max(min(anteil, 1), 0.01))),
                    style: StrokeStyle(lineWidth: 22, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            mitte(seite: seite, farbe: farbe, erreicht: anteil >= 1)
        }
        .padding(11)
        .frame(width: seite, height: seite)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.name), \(titel): \(anzahl.map(HealthText.zahl) ?? "keine") von \(HealthText.zahl(ziel)) Schritten\(anteil >= 1 ? ", Ziel erreicht" : "")")
    }

    private func mitte(seite: CGFloat, farbe: Color, erreicht: Bool) -> some View {
        VStack(spacing: 4) {
            Text(titel)
                .font(.system(size: seite * 0.075, weight: .semibold, design: .rounded))
                .foregroundStyle(farbe)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(anzahl.map(HealthText.zahl) ?? "–")
                .font(.system(size: seite * 0.2, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: Double(anzahl ?? 0)))
            Text("von \(HealthText.zahl(ziel)) Schritten")
                .font(.system(size: seite * 0.056, design: .rounded))
                .foregroundStyle(.secondary)
            if erreicht {
                Label("Ziel", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.personText(person))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(farbe))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, seite * 0.14)
    }
}

// MARK: - Chips

/// kcal, km, active time and floors of the period, side by side and scrollable.
struct SchritteStatChips: View {
    let werte: SchritteExtra
    /// `false` only for the render board (`ImageRenderer` does not draw scroll views).
    var scrollbar = true

    var body: some View {
        if scrollbar {
            ScrollView(.horizontal) { reihe }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
        } else {
            reihe
        }
    }

    private var reihe: some View {
        HStack(spacing: 10) {
            chip(werte.kcal.map(HealthText.zahl), "kcal")
            chip(werte.km.map { $0.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "de_DE"))) }, "km")
            chip(werte.aktivMinuten.map { "\($0 / 60):" + String(format: "%02d", $0 % 60) }, "h aktiv")
            chip(werte.etagen.map(HealthText.zahl), "Etagen")
        }
        .padding(.horizontal, 2)
    }

    private func chip(_ wert: String?, _ einheit: String) -> some View {
        VStack(spacing: 0) {
            Text(wert ?? "–")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(einheit).font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 76, minHeight: 56)
        .padding(.horizontal, 12)
        .healthKarte()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Linie

/// Smooth area line (Catmull-Rom) of up to 7 days, the daily goal dotted, the chosen day with a
/// rule and a pill. Dragging or tapping picks a day.
struct SchritteLinie: View {
    let punkte: [SchrittPunkt]
    let ziel: Int
    let gewaehlt: String?
    let farbe: Color
    var waehlen: (String) -> Void = { _ in }

    @State private var roh: String?

    var body: some View {
        let hoechster = max(punkte.map { $0.schritte }.max() ?? 0, ziel, 1000)
        Chart {
            ForEach(punkte) { p in punkt(p) }
            RuleMark(y: .value("Ziel", ziel))
                .foregroundStyle(Color.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 4]))
            if let gewaehlt, let wert = punkte.first(where: { $0.tag == gewaehlt })?.schritte {
                RuleMark(x: .value("Tag", gewaehlt))
                    .foregroundStyle(farbe.opacity(0.5))
                    .annotation(position: .top, spacing: 2) { pille(wert) }
            }
        }
        .chartYScale(domain: 0...Int(Double(hoechster) * 1.3))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { wert in
                AxisValueLabel {
                    if let tag = wert.as(String.self) {
                        Text(HabitLogik.wochentagKuerzel[Datum.wochentag(tag) - 1].uppercased())
                            .fontWeight(tag == gewaehlt ? .bold : .regular)
                    }
                }
            }
        }
        .chartXSelection(value: $roh)
        .onChange(of: roh) { _, neu in if let neu { waehlen(neu) } }
        .frame(height: 190)
        .padding(16)
        .healthKarte()
    }

    @ChartContentBuilder
    private func punkt(_ p: SchrittPunkt) -> some ChartContent {
        AreaMark(x: .value("Tag", p.tag), y: .value("Schritte", p.schritte))
            .interpolationMethod(.catmullRom)
            .foregroundStyle(LinearGradient(colors: [farbe.opacity(0.35), farbe.opacity(0.02)], startPoint: .top, endPoint: .bottom))
        LineMark(x: .value("Tag", p.tag), y: .value("Schritte", p.schritte))
            .interpolationMethod(.catmullRom)
            .foregroundStyle(farbe)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
        PointMark(x: .value("Tag", p.tag), y: .value("Schritte", p.schritte))
            .foregroundStyle(p.tag == gewaehlt ? farbe : Color.white)
            .symbolSize(p.tag == gewaehlt ? 110 : 45)
            .accessibilityLabel(Text(Datum.anzeige(p.tag)))
            .accessibilityValue(Text("\(HealthText.zahl(p.schritte)) Schritte"))
    }

    private func pille(_ wert: Int) -> some View {
        Text(HealthText.zahl(wert))
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(farbe))
    }
}

// MARK: - Monat

/// Month mode: each day a mini ring (full at the goal); tapping a day shows it in the ring.
struct SchritteMonatRinge: View {
    let person: Person
    let anker: String
    let heute: String
    var waehlen: (String) -> Void = { _ in }

    private var health: HealthModell { HealthModell.shared }

    var body: some View {
        let gitter = HealthLogik.monatsGitter(heute: anker, monateZurueck: 0)
        VStack(spacing: 10) {
            WochentagsKopf()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(Array(gitter.enumerated()), id: \.offset) { _, tag in zelle(tag) }
            }
        }
        .padding(16)
        .healthKarte()
    }

    @ViewBuilder
    private func zelle(_ tag: String?) -> some View {
        if let tag, tag <= heute {
            let anzahl = health.schritteAm(person, tag)
            let ziel = HealthLogik.zielAmTag(tag, health.zielSchritteAenderungen[person] ?? [], standard: 10_000)
            Button { waehlen(tag) } label: {
                MiniRing(anteil: anzahl.map { Double($0) / Double(max(1, ziel)) }, farbe: Color.person(person), tag: tag)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.federnd)
            .accessibilityLabel("\(Datum.anzeige(tag)): \(anzahl.map { "\(HealthText.zahl($0)) Schritte" } ?? "keine Daten")")
        } else if let tag {
            Text(HealthText.tagesnummer(tag)).font(.caption2).foregroundStyle(.quaternary).frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityHidden(true)
        } else {
            Color.clear.frame(height: 44)
        }
    }
}

// MARK: - Challenge

/// The running "Gemeinsam Woche" challenge (`PunkteModell.aktuelleWoche`) as a leaderboard: rank,
/// figure, name, week total, last update, bar towards the shared goal. Header → week comparison.
struct SchritteChallengeKarte: View {
    private var health: HealthModell { HealthModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        let heute = Datum.text(Date())
        let woche = PunkteModell.shared.aktuelleWoche
        let ziel = max(1, woche?.gemeinsamZiel ?? health.zielGemeinsamWoche)
        let tage = HabitLogik.wochenTage(heute: heute)
        let summen = Dictionary(uniqueKeysWithValues: Person.allCases.map { p in
            (p, SchritteLogik.summe(health.schritteWerte(p), tage: tage, heute: heute) ?? 0)
        })
        VStack(alignment: .leading, spacing: 14) {
            kopf(ziel: ziel, heute: heute)
            ForEach(SchritteLogik.rangliste(summen), id: \.person) { platz in zeile(platz, ziel: ziel) }
        }
        .padding(16)
        .healthKarte()
    }

    private func kopf(ziel: Int, heute: String) -> some View {
        NavigationLink(value: HealthZiel.schritteVergleich) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Challenge", systemImage: "trophy.fill").font(.headline).foregroundStyle(Color.person(ich))
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                    Spacer()
                    Text("Tag \(Datum.wochentag(heute)) von 7").font(.subheadline).foregroundStyle(.secondary)
                }
                Text("\(HealthText.zahl(ziel)) Schritte zusammen").font(.title3.weight(.bold)).foregroundStyle(.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.federnd)
        .accessibilityHint("Vergleicht eure Woche Tag für Tag")
    }

    private func zeile(_ platz: SchritteLogik.Platz, ziel: Int) -> some View {
        let farbe = Color.person(platz.person)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(platz.rang)").font(.headline.monospacedDigit()).frame(width: 18)
                FigurKopf(person: platz.person, groesse: 40)
                Text(platz.person.name).font(.body.weight(.semibold))
                if platz.person == ich {
                    Text("Ich").font(.caption.weight(.bold)).foregroundStyle(farbe)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(farbe.opacity(0.15)))
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(HealthText.zahl(platz.schritte)).font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
                    if let zuletzt = health.schritteZuletzt[platz.person] {
                        Text(ZeitText.relativ(zuletzt)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            ProgressView(value: min(1, Double(platz.schritte) / Double(ziel))).tint(farbe)
        }
        .accessibilityElement(children: .combine)
    }
}
