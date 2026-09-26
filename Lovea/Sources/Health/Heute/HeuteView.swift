import Charts
import SwiftUI

// Tab "Heute" (Plan Task 8): Tagesform-Karte, "Dein Tag" mit neun Formen, "Das fällt mir auf", Punkte-Zeile.

// MARK: - Tagesform (reine Logik)

struct Tagesform: Equatable, Sendable {
    /// nil = noch gar keine Daten, dann zeigt die Karte "–".
    var akku: Int?
    var urteil: String
    var satz: String
}

enum TagesformLogik {
    static let schlafSollMinuten = 480

    /// Schlaf / 8 h · 0,4, Wasser / Ziel · 0,2, Schritte / Ziel · 0,15, mittlere Erholung (0...1) · 0,25.
    static func tagesform(schlafMinuten: Int?, wasser: Int, wasserZiel: Int, schritte: Int?, schritteZiel: Int,
                          erholung: Double) -> Tagesform {
        guard schlafMinuten != nil || schritte != nil || wasser > 0 else {
            return Tagesform(akku: nil, urteil: "Noch leer",
                             satz: "Trag Wasser ein oder erlaube Apple Health, dann rechne ich deine Tagesform aus.")
        }
        func anteil(_ ist: Int, _ soll: Int) -> Double { soll > 0 ? min(1, max(0, Double(ist) / Double(soll))) : 1 }
        let schlaf = anteil(schlafMinuten ?? 0, schlafSollMinuten)
        let trinken = anteil(wasser, wasserZiel)
        let gehen = anteil(schritte ?? 0, schritteZiel)
        let akku = Int((100 * (schlaf * 0.4 + trinken * 0.2 + gehen * 0.15 + min(1, max(0, erholung)) * 0.25)).rounded())
        let urteil = akku >= 85 ? "Voll geladen" : akku >= 70 ? "Gut geladen" : akku >= 50 ? "Halb leer" : "Sparmodus"
        let satz: String
        if min(schlaf, trinken, gehen) >= 1 {
            satz = "Alles im grünen Bereich. So bleibt es."
        } else if schlaf <= trinken && schlaf <= gehen {
            satz = "Schlaf bremst dich. Heute früher ins Bett bringt morgen am meisten."
        } else if trinken <= gehen {
            let fehlt = wasserZiel - wasser
            satz = "Wasser bremst dich: noch \(fehlt) \(fehlt == 1 ? "Glas" : "Gläser") bis zum Ziel."
        } else {
            satz = "Schritte bremsen dich: noch \(deZahl(schritteZiel - (schritte ?? 0))) bis zum Ziel."
        }
        return Tagesform(akku: akku, urteil: urteil, satz: satz)
    }

    /// Mittlere Erholung 0...1. Teile ohne Training fehlen in `MuskelLogik.erholung` und zählen als 100.
    static func erholungMittel(_ werte: [MuskelTeil: Int]) -> Double {
        let alle = MuskelTeil.allCases
        return Double(alle.map { werte[$0] ?? 100 }.reduce(0, +)) / Double(alle.count * 100)
    }
}

private func deZahl(_ n: Int) -> String { n.formatted(.number.locale(Locale(identifier: "de_DE"))) }

private func komma(_ x: Double) -> String { String(format: "%.1f", x).replacingOccurrences(of: ".", with: ",") }

// MARK: - Schlaf gegen Leistung (Diagramm-Daten)

struct SchlafPunkt: Identifiable, Equatable, Sendable {
    var id: String
    var stunden: Double
    /// Prozent des eigenen Bestwerts, Mittel über die Übungen der Einheit.
    var leistung: Double
}

enum SchlafLeistung {
    /// Ein Punkt je Einheit mit Schlafdaten: Schlaf der Nacht davor gegen Leistung (wie `HinweisLogik.schlaf`).
    static func punkte(_ sessions: [GymSession], schlafMinuten: [String: Int]) -> [SchlafPunkt] {
        let werte = sessions.map { e1rm($0) }
        var bestwert: [String: Double] = [:]
        for w in werte { bestwert.merge(w, uniquingKeysWith: max) }
        var punkte: [SchlafPunkt] = []
        for (s, w) in zip(sessions, werte) where !w.isEmpty {
            guard let minuten = schlafMinuten[Datum.text(s.start)] else { continue }
            let mittel = w.map { $0.value / (bestwert[$0.key] ?? $0.value) }.reduce(0, +) / Double(w.count)
            punkte.append(SchlafPunkt(id: s.id, stunden: Double(minuten) / 60, leistung: mittel * 100))
        }
        return punkte
    }

    // ponytail: wiederholt das private `HinweisLogik.bestwerte`, dort internal machen und hier löschen.
    private static func e1rm(_ s: GymSession) -> [String: Double] {
        var werte: [String: Double] = [:]
        for lauf in s.laeufe where lauf.fertig && lauf.uebung != PlanUebung.eigen {
            for satz in lauf.saetze ?? [] {
                guard let kg = satz.kg, kg > 0 else { continue }
                werte[lauf.uebung] = max(werte[lauf.uebung] ?? 0, kg * (1 + Double(satz.wdh) / 30))
            }
        }
        return werte
    }
}

// MARK: - Bausteine

private extension View {
    func heuteKarte() -> some View {
        background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Links der Kopf, rechts Akku, Urteil und Bremssatz.
struct TagesformKarte: View {
    let person: Person
    let form: Tagesform
    var animiert = true
    @ScaledMetric(relativeTo: .largeTitle) private var akkuGroesse = 46.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tagesform").font(.headline)
            HStack(spacing: 16) {
                KopfFigur(person: person, groesse: 84, animiert: animiert)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(form.akku.map { String($0) } ?? "–")
                            .font(.system(size: akkuGroesse, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("%").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    Text(form.urteil).font(.headline)
                    Text(form.satz).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heuteKarte()
        .accessibilityElement(children: .combine)
    }
}

private extension Hinweis.Art {
    var farbe: Color {
        switch self {
        case .stillstand: Color(red: 1, green: 0.478, blue: 0.349)
        case .schlaf: TagesForm.schlaf.farbe
        case .wasser: TagesForm.wasser.farbe
        case .vergessen: TagesForm.stimmung.farbe
        case .gesperrt: .gray
        }
    }

    var symbol: String {
        switch self {
        case .stillstand: "arrow.left.and.right"
        case .schlaf: "moon.fill"
        case .wasser: "drop.fill"
        case .vergessen: "clock"
        case .gesperrt: "lock.fill"
        }
    }
}

/// Ein Hinweis. Gesperrte zeigen den Fortschrittsbalken, die anderen klappen Tipp, Basis und Diagramm auf.
struct HinweisKarte: View {
    let hinweis: Hinweis
    var punkte: [SchlafPunkt] = []
    let offen: Bool
    let umschalten: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hinweis.art == .gesperrt { gesperrt } else { aufklappbar }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heuteKarte()
    }

    private var symbol: some View {
        Image(systemName: hinweis.art.symbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(hinweis.art.farbe)
            .frame(width: 36, height: 36)
            .background(hinweis.art.farbe.opacity(0.18), in: Circle())
            .accessibilityHidden(true)
    }

    private var gesperrt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                symbol
                Text(hinweis.titel).font(.headline)
                Spacer(minLength: 8)
                Text(hinweis.zahl).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
            }
            Text(hinweis.text).font(.subheadline).foregroundStyle(.secondary)
            ProgressView(value: min(1, max(0, hinweis.fortschritt ?? 0))).tint(.gray)
        }
        .accessibilityElement(children: .combine)
    }

    private var aufklappbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: umschalten) {
                HStack(spacing: 12) {
                    symbol
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hinweis.titel).font(.headline).multilineTextAlignment(.leading)
                        Text(hinweis.zahl).font(.subheadline.weight(.semibold)).foregroundStyle(hinweis.art.farbe).monospacedDigit()
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(offen ? 90 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(offen ? "aufgeklappt" : "zugeklappt")
            Text(hinweis.text).font(.subheadline).foregroundStyle(.secondary)
            if offen { details }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hinweis.art == .schlaf && !punkte.isEmpty { SchlafDiagramm(punkte: punkte) }
            VStack(alignment: .leading, spacing: 2) {
                Text("Tipp").font(.caption.weight(.semibold)).foregroundStyle(hinweis.art.farbe)
                Text(hinweis.tipp).font(.subheadline)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hinweis.art.farbe.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(hinweis.basis).font(.caption).foregroundStyle(.tertiary)
        }
        .transition(.opacity)
    }
}

/// Punkte = Einheiten. Unter 6 h liegt eine schraffierte Fläche, bei 6 h eine gestrichelte Linie.
struct SchlafDiagramm: View {
    let punkte: [SchlafPunkt]
    private let farbe = TagesForm.schlaf.farbe
    private let stunden = 4.0...9.0

    private var leistung: ClosedRange<Double> {
        let tief = punkte.map(\.leistung).min() ?? 90
        return max(0, (tief / 5).rounded(.down) * 5 - 5)...105
    }

    var body: some View {
        Chart {
            RectangleMark(xStart: .value("von", stunden.lowerBound), xEnd: .value("bis", 6.0),
                          yStart: .value("unten", leistung.lowerBound), yEnd: .value("oben", leistung.upperBound))
                .foregroundStyle(farbe.opacity(0.08))
            RuleMark(x: .value("Grenze", 6.0))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(.secondary)
                .annotation(position: .overlay, alignment: .topTrailing) {
                    Text("unter 6 h").font(.caption2).foregroundStyle(.secondary).padding(4)
                }
            ForEach(punkte) { p in
                PointMark(x: .value("Schlaf", min(max(p.stunden, stunden.lowerBound), stunden.upperBound)),
                          y: .value("Leistung", min(max(p.leistung, leistung.lowerBound), leistung.upperBound)))
                    .foregroundStyle(farbe)
                    .symbolSize(70)
            }
        }
        .chartXScale(domain: stunden)
        .chartYScale(domain: leistung)
        .chartXAxis {
            AxisMarks(values: [5.0, 6.0, 7.0, 8.0, 9.0]) { wert in
                AxisGridLine()
                AxisValueLabel { if let h = wert.as(Double.self) { Text("\(Int(h)) h") } }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { wert in
                AxisGridLine()
                AxisValueLabel { if let p = wert.as(Double.self) { Text("\(Int(p)) %") } }
            }
        }
        .chartOverlay { schraffur($0) }
        .frame(height: 170)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Schlaf gegen Leistung")
        .accessibilityValue("\(punkte.count) Einheiten")
    }

    private func schraffur(_ proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            if let rahmen = proxy.plotFrame, let links = proxy.position(forX: stunden.lowerBound),
               let rechts = proxy.position(forX: 6.0) {
                let plot = geo[rahmen]
                Schraffur()
                    .stroke(farbe.opacity(0.25), lineWidth: 1)
                    .frame(width: max(0, rechts - links), height: plot.height)
                    .clipped()
                    .offset(x: plot.minX + links, y: plot.minY)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct Schraffur: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x = rect.minX - rect.height
        while x < rect.maxX {
            p.move(to: CGPoint(x: x, y: rect.maxY))
            p.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += 7
        }
        return p
    }
}

// MARK: - Ziele und Gewichtsblatt

private enum HeuteZiel: Hashable {
    case schritte, schlaf, habits, habit(String), punkte
}

private struct StimmungSetzen: Codable { var datum: String; var stimmung: String }

/// Zahlenfeld für das Gewicht. "78,4" wird als 784 Zehntel-kg gespeichert (`GewichtText`).
private struct GewichtBlatt: View {
    let speichern: (Int) -> Void
    @State private var text: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var fokus: Bool

    init(start: String, speichern: @escaping (Int) -> Void) {
        self.speichern = speichern
        _text = State(initialValue: start)
    }

    private var zehntel: Int? { GewichtText.zehntel(text) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Gewicht in kg", text: $text)
                    .keyboardType(.decimalPad)
                    .focused($fokus)
                    .accessibilityLabel("Gewicht in Kilogramm")
            }
            .navigationTitle("Gewicht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        if let zehntel { speichern(zehntel) }
                        dismiss()
                    }
                    .disabled(zehntel == nil)
                }
            }
            .onAppear { fokus = true }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Tab

struct HeuteView: View {
    @State private var pfad: [HeuteZiel] = []
    @State private var gewichtOffen = false
    @State private var offeneHinweise: Set<String> = []
    @Namespace private var zoom
    @Environment(\.dynamicTypeSize) private var schrift
    @Environment(\.accessibilityReduceMotion) private var ruhig

    private var health: HealthModell { HealthModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var heute: String { Datum.text(Date()) }

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    kopf
                    TagesformKarte(person: ich, form: tagesform)
                    abschnitt("Dein Tag") { raster }
                    abschnitt("Das fällt mir auf") { hinweisListe }
                    punkteZeile
                }
                .padding(16)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HeuteZiel.self) { ansicht($0) }
            .sheet(isPresented: $gewichtOffen) {
                GewichtBlatt(start: gewichte.last.map { komma(Double($0.zehntel) / 10) } ?? "") {
                    health.setzeHabit(Habit.gewicht.id, datum: heute, wert: $0)
                }
            }
        }
        .onAppear { health.sicherstellen() }
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Datum.anzeige(heute).uppercased()).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            Text("Heute").font(.largeTitle.bold())
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func abschnitt<Inhalt: View>(_ titel: String, @ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titel).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            inhalt()
        }
    }

    @ViewBuilder
    private func ansicht(_ ziel: HeuteZiel) -> some View {
        switch ziel {
        case .schritte: SchritteDetailView(person: ich)
        case .schlaf: SchlafDetailView()
        case .habits:
            ScrollView {
                HabitsSektion(zoom: zoom) { if case .habit(let id) = $0 { pfad.append(.habit(id)) } }.padding(16)
            }
            .navigationTitle("Habits")
        case .habit(let id): HabitDetailView(habitId: id)
        case .punkte: PunkteVerlaufView()
        }
    }

    // MARK: Tagesform

    private var tagesform: Tagesform {
        let erholung = MuskelLogik.erholung(TrainingModell.shared.sessions(ich), jetzt: Date())
        return TagesformLogik.tagesform(
            schlafMinuten: health.schlafMinuten(ich, heute), wasser: health.wasserAnzahl(ich, heute),
            wasserZiel: health.zielWasser(ich), schritte: health.heuteSchritte(ich), schritteZiel: health.zielSchritte(ich),
            erholung: TagesformLogik.erholungMittel(erholung))
    }

    // MARK: Dein Tag

    private var raster: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: schrift.isAccessibilitySize ? 1 : 3), spacing: 10) {
            schritteKachel
            wasserKachel
            schlafKachel
            habitsKachel
            stimmungKachel
            koffeinKachel
            proteinKachel
            gewichtKachel
            trainingKachel
        }
    }

    private var schritteKachel: some View {
        let ziel = health.zielSchritte(ich)
        let n = health.heuteSchritte(ich) ?? 0
        return FormKachel(form: .schritte, titel: "Schritte", wert: deZahl(n), einheit: "",
                          fuellung: ziel > 0 ? Double(n) / Double(ziel) : 0, zusatz: "Ziel \(deZahl(ziel))") { pfad.append(.schritte) }
    }

    private var wasserKachel: some View {
        let ziel = health.zielWasser(ich)
        let n = health.wasserAnzahl(ich, heute)
        return FormKachel(form: .wasser, titel: "Wasser", wert: "\(n)", einheit: "/\(ziel) Gl.",
                          fuellung: ziel > 0 ? Double(n) / Double(ziel) : 0) {
            health.setzeWasser(datum: heute, anzahl: n + 1)
        }
    }

    private var schlafKachel: some View {
        let minuten = health.schlafMinuten(ich, heute)
        return FormKachel(form: .schlaf, titel: "Schlaf", wert: minuten.map { komma(Double($0) / 60) } ?? "–", einheit: "/8 h",
                          fuellung: Double(minuten ?? 0) / Double(TagesformLogik.schlafSollMinuten)) { pfad.append(.schlaf) }
    }

    private var habitsKachel: some View {
        let sichtbar = health.sichtbareHabits(fuer: ich)
        let erledigt = sichtbar.filter {
            HabitLogik.erledigt($0, wert: health.habitWert($0.id, ich, heute), ziel: health.habitZiel($0.id, ich))
        }.count
        return FormKachel(form: .habits, titel: "Habits", wert: "\(erledigt)", einheit: "/\(sichtbar.count)",
                          fuellung: sichtbar.isEmpty ? 0 : Double(erledigt) / Double(sichtbar.count)) { pfad.append(.habits) }
    }

    /// 1 = schlecht, 3 = gut, nil = noch nicht eingetragen.
    private var stimmungStufe: Int? {
        switch health.stimmung(ich, heute) ?? "" {
        case "gut": 3
        case "mittel": 2
        case "schlecht": 1
        default: nil
        }
    }

    private var stimmungKachel: some View {
        let stufe = stimmungStufe
        return FormKachel(form: .stimmung, titel: "Stimmung", wert: stufe.map { ["Schlecht", "Mittel", "Gut"][$0 - 1] } ?? "–",
                          einheit: "", fuellung: Double(stufe ?? 0) / 3, stimmung: stufe) {
            // gut, mittel, schlecht, wieder gut
            let naechste = stufe == 3 ? "mittel" : stufe == 2 ? "schlecht" : "gut"
            Raum.shared.senden("stimmung.setzen", StimmungSetzen(datum: heute, stimmung: naechste))
            FigurenModell.shared.zustandSenden(.init(haupt: FigurZustand(rawValue: naechste) ?? .ruhig))
        }
    }

    private var koffeinKachel: some View {
        let n = health.habitWert(Habit.koffein.id, ich, heute)
        return FormKachel(form: .koffein, titel: "Koffein", wert: "\(n)", einheit: n == 1 ? "Tasse" : "Tassen",
                          fuellung: Double(n) / 4) { health.setzeHabit(Habit.koffein.id, datum: heute, wert: n + 1) }
    }

    private var proteinKachel: some View {
        let ok = health.habitWert(Habit.protein.id, ich, heute) > 0
        return FormKachel(form: .protein, titel: "Protein", wert: ok ? "geschafft" : "offen", einheit: "",
                          fuellung: ok ? 1 : 0) { health.setzeHabit(Habit.protein.id, datum: heute, wert: ok ? 0 : 1) }
    }

    /// Alle Einträge mit Wert, älteste zuerst. Wert = Zehntel-kg.
    private var gewichte: [(tag: String, zehntel: Int)] {
        health.habitWerte(Habit.gewicht.id, ich).filter { $0.value > 0 }.sorted { $0.key < $1.key }
            .map { (tag: $0.key, zehntel: $0.value) }
    }

    private var gewichtKachel: some View {
        let alle = gewichte
        let letztes = alle.last?.zehntel
        var trend: String?
        if alle.count > 1, let letztes {
            let diff = letztes - alle[alle.count - 2].zehntel
            trend = diff == 0 ? "±0" : "\(diff > 0 ? "+" : "−")\(komma(Double(abs(diff)) / 10)) kg"
        }
        return FormKachel(form: .gewicht, titel: "Gewicht", wert: letztes.map { komma(Double($0) / 10) } ?? "–", einheit: "kg",
                          fuellung: 0, zusatz: trend) { gewichtOffen = true }
    }

    private var trainingKachel: some View {
        let dran = health.gymAbgehakt(ich, heute) || TrainingModell.shared.sessions(ich).contains { Datum.text($0.start) == heute }
        return FormKachel(form: .training, titel: "Training", wert: dran ? "Gym" : "Pause", einheit: "", fuellung: dran ? 1 : 0) {
            AppNavigation.shared.tabWunsch = "training"
        }
    }

    // MARK: Das fällt mir auf

    private var hinweisListe: some View {
        let sessions = TrainingModell.shared.sessions(ich)
        let schlaf = schlafTage
        let hinweise = HinweisLogik.alle(hinweisEingabe(sessions, schlaf))
        let punkte = SchlafLeistung.punkte(sessions, schlafMinuten: schlaf)
        return VStack(spacing: 12) {
            ForEach(hinweise) { h in
                HinweisKarte(hinweis: h, punkte: punkte, offen: offeneHinweise.contains(h.id)) {
                    withAnimation(ruhig ? nil : Feder.weich) {
                        if offeneHinweise.remove(h.id) == nil { offeneHinweise.insert(h.id) }
                    }
                }
            }
        }
    }

    /// Schlafminuten der letzten 90 Tage, Schlüssel = Tag des Aufwachens.
    // ponytail: bei jedem Zeichnen neu gelesen, bei Bedarf in einen @State-Cache legen.
    private var schlafTage: [String: Int] {
        var tage: [String: Int] = [:]
        for i in 0..<90 {
            let tag = Datum.addTage(heute, -i)
            if let minuten = health.schlafMinuten(ich, tag) { tage[tag] = minuten }
        }
        return tage
    }

    private func hinweisEingabe(_ sessions: [GymSession], _ schlaf: [String: Int]) -> HinweisEingabe {
        let gymAbgehakt = health.habitWerte(Habit.gym.id, ich).filter { $0.value > 0 }.keys
        let koffein = health.habitWerte(Habit.koffein.id, ich)
        var prio: [(gruppe: MuskelGruppe, rang: Int)] = []
        for gruppe in MuskelGruppe.allCases {
            if let rang = health.ziel("ziel.prio.\(gruppe.rawValue)", ich), rang > 0 { prio.append((gruppe, rang)) }
        }
        return HinweisEingabe(
            sessions: sessions, schlafMinuten: schlaf, wasser: health.habitWerte(Habit.wasser.id, ich),
            gymTage: Set(sessions.map { Datum.text($0.start) }).union(gymAbgehakt),
            stimmungTage: schlaf.keys.filter { health.stimmung(ich, $0) != nil }.count,
            koffeinTage: schlaf.keys.filter { (koffein[$0] ?? 0) > 0 }.count,
            prio: prio.sorted { $0.rang < $1.rang }.map { $0.gruppe }, heute: heute)
    }

    // MARK: Punkte

    private var punkteZeile: some View {
        Button { pfad.append(.punkte) } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.circle.fill").font(.title2).foregroundStyle(Color.loveaRose)
                Text("Punkte und Challenges").font(.headline)
                Spacer(minLength: 8)
                Text("\(PunkteModell.shared.stand[ich] ?? 0)").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .heuteKarte()
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.federnd)
        .accessibilityHint("Zeigt, wofür es Punkte gab")
    }
}
