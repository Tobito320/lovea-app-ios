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

    /// Schlaf / Ziel · 0,4, Wasser / Ziel · 0,2, Schritte / Ziel · 0,15, mittlere Erholung (0...1) · 0,25.
    /// `schlafZiel` ist Minuten, Standard 480 (8 h) — Teil 6 übergibt das flexible Tagesziel.
    static func tagesform(schlafMinuten: Int?, wasser: Int, wasserZiel: Int, schritte: Int?, schritteZiel: Int,
                          erholung: Double, schlafZiel: Int = schlafSollMinuten) -> Tagesform {
        guard schlafMinuten != nil || schritte != nil || wasser > 0 else {
            return Tagesform(akku: nil, urteil: "Noch leer",
                             satz: "Trag Wasser ein oder erlaube Apple Health, dann rechne ich deine Tagesform aus.")
        }
        func anteil(_ ist: Int, _ soll: Int) -> Double { soll > 0 ? min(1, max(0, Double(ist) / Double(soll))) : 1 }
        let schlaf = anteil(schlafMinuten ?? 0, schlafZiel)
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
    /// Energie-Rat (früher eigene Karte auf der Training-Seite): Urteil, Gym/Cardio, Gründe, Partner.
    var energie: EnergieRat? = nil
    var partner: (person: Person, rat: EnergieRat)? = nil
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
            if let energie { energieTeil(energie) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heuteKarte()
        .accessibilityElement(children: .combine)
    }
}

private extension TagesformKarte {
    func energieTeil(_ rat: EnergieRat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Label(rat.titel, systemImage: "bolt.heart.fill").font(.subheadline.weight(.semibold)).foregroundStyle(HabitFarbe.amber.farbe)
            HStack(spacing: 8) {
                energieChip(rat.gym, "dumbbell.fill")
                energieChip(rat.cardioText, "figure.run")
            }
            ForEach(rat.gruende, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
            if let partner {
                HStack(spacing: 4) {
                    Text("\(partner.person.name):").foregroundStyle(Color.person(partner.person))
                    Text("\(partner.rat.titel.lowercased()), \(partner.rat.gym.lowercased())").foregroundStyle(.secondary)
                }
                .font(.footnote)
            }
        }
    }

    func energieChip(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(HabitFarbe.amber.farbe)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(HabitFarbe.amber.farbe.opacity(0.15), in: .capsule)
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
    case schritte, schlaf, habits, habit(String), punkte, ernaehrung, training, koerper, verlauf
}

private struct KoerperAuswahl: Identifiable {
    let gruppe: MuskelGruppe
    let teil: MuskelTeil?
    var id: String { "\(gruppe.rawValue)/\(teil?.rawValue ?? "-")" }
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

/// Der Health-Tab (Ahmed, 27.09.: ein Health statt vier Tabs). Training, Körper, Verlauf, Schritte, Food und
/// Schlaf öffnen sich als Seiten im selben Stapel.
struct HeuteView: View {
    @State private var pfad = NavigationPath()
    /// Der gezeigte Tag (Ahmed, 27.09.): Wochenstreifen oben, Pfeile, Monat. Standard heute.
    @State private var gewaehlt = Datum.text(Date())
    @State private var monatOffen = false
    @State private var koerperAuswahl: KoerperAuswahl?
    @State private var befragung = false
    @State private var gewichtOffen = false
    @State private var freitextOffen = false
    @State private var offeneHinweise: Set<String> = []
    @Namespace private var zoom
    @Environment(\.dynamicTypeSize) private var schrift
    @Environment(\.accessibilityReduceMotion) private var ruhig

    private var health: HealthModell { HealthModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }
    /// Alle Kacheln und die Tagesform zeigen den gewählten Tag (Name bleibt, damit der Rest gleich liest).
    private var heute: String { gewaehlt }
    private var echtHeute: String { Datum.text(Date()) }

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    kopf
                    freitextZeile
                    VStack(spacing: 0) {
                        tagesWahl
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        TagesformKarte(person: ich, form: tagesform,
                                       energie: heute == echtHeute ? EnergieLogik.rat(EnergieQuelle.eingabe(ich)) : nil,
                                       partner: heute == echtHeute ? (ich.partner, EnergieLogik.rat(EnergieQuelle.eingabe(ich.partner))) : nil)
                    }
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    abschnitt(heute == echtHeute ? "Dein Tag" : Datum.anzeige(heute)) { raster }
                    abschnitt("Das fällt mir auf") { hinweisListe }
                    punkteZeile
                    abschnitt("Körper") { koerper }
                    verlaufKasten
                }
                .padding(16)
            }
            .toolbar(.hidden, for: .navigationBar)
            // R6: nur die Heute-Wurzel, nicht Training/Körper/Verlauf dahinter. Konkurriert mit dem
            // Wochenstreifen (`tagesWahl`) nicht normalerweise — der braucht nur 30 pt und reagiert
            // schon vor den hier nötigen 60 pt; nur bei einem sehr schnellen, weiten Wisch genau dort
            // können beide einmal zugleich feuern (bekannter, seltener Randfall wie bei MonatsAnsicht).
            .tabWischen(vorheriger: "drawing", naechster: "profile")
            .navigationDestination(for: HeuteZiel.self) { ansicht($0) }
            .navigationDestination(for: HealthZiel.self) { HealthZielAnsicht(ziel: $0) }
            .navigationDestination(for: VerlaufZiel.self) { ziel in VerlaufZielSeite(ziel: ziel) { pfad.append($0) } }
            .sheet(isPresented: $monatOffen) { monatBlatt }
            .sheet(item: $koerperAuswahl) { a in
                ScrollView { KoerperBlatt(daten: KoerperDaten.laden(ich), gruppe: a.gruppe, teil: a.teil).padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 30) }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $befragung) { ZieleBefragung() }
            .sheet(isPresented: $freitextOffen) { FreitextBlatt(tag: heute) }
            .sheet(isPresented: $gewichtOffen) {
                GewichtBlatt(start: gewichte.last.map { komma(Double($0.zehntel) / 10) } ?? "") {
                    health.setzeHabit(Habit.gewicht.id, datum: heute, wert: $0)
                }
            }
        }
        .onAppear {
            health.sicherstellen()
            seiteAusWunsch()
        }
        .onChange(of: AppNavigation.shared.healthSeite) { _, _ in seiteAusWunsch() }
    }

    /// Sprung von außen ("training", "koerper", "verlauf"), z. B. aus der Körper-Seite oder Home.
    private func seiteAusWunsch() {
        guard let wunsch = AppNavigation.shared.healthSeite else { return }
        AppNavigation.shared.healthSeite = nil
        switch wunsch {
        case "training": pfad.append(HeuteZiel.training)
        case "koerper": pfad.append(HeuteZiel.koerper)
        case "verlauf": pfad.append(HeuteZiel.verlauf)
        case "gym":
            pfad = NavigationPath()
            pfad.append(HeuteZiel.training)
            if let s = TrainingModell.shared.laufende(ich) { pfad.append(HealthZiel.gymSession(s.id)) }
        default: break
        }
    }

    /// Tipp auf den Kopf springt zurück zu heute.
    private var kopf: some View {
        Button { zuHeute() } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(heute == echtHeute ? Datum.anzeige(heute).uppercased() : "ZURÜCK ZU HEUTE")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(heute == echtHeute ? Color.secondary : Color.accentColor)
                Text("Health").font(.largeTitle.bold()).foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
    }

    private func zuHeute() {
        guard gewaehlt != echtHeute else { return }
        Haptik.auswahl()
        withAnimation(Feder.weich) { gewaehlt = echtHeute }
    }

    // MARK: Tag wählen

    /// Monat mit Pfeilen (eine Woche vor/zurück), darunter Mo bis So. Monat antippen öffnet den Kalender,
    /// den Kreis von heute antippen oder den Kopf springt zurück zu heute.
    private var tagesWahl: some View {
        let woche = KoerperWoche.bauen(ich: ich, sessions: [ich: TrainingModell.shared.sessions(ich), ich.partner: TrainingModell.shared.sessions(ich.partner)],
                                       plan: TrainingModell.shared.plan(ich), heute: echtHeute, katalog: { UebungsKatalog.nachId[$0] },
                                       montagVon: gewaehlt)
        return VStack(spacing: 0) {
            HStack {
                pfeil("chevron.left", -7, "Woche davor")
                Spacer()
                Button { monatOffen = true } label: {
                    HStack(spacing: 4) {
                        Text(Datum.datum(gewaehlt).formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "de_DE"))))
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "calendar").font(.footnote)
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Öffnet den Monat")
                Spacer()
                pfeil("chevron.right", 7, "Woche danach")
            }
            Streifen(woche: woche, gewaehlt: gewaehlt) { tag in
                Haptik.auswahl()
                withAnimation(Feder.weich) { gewaehlt = tag }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                // R6-Fix (Review 01.10.): beansprucht die Berührung, sobald klar horizontal, damit
                // der Tab-Wisch (60 pt) hier nicht zugleich feuert — die 30-pt-Schwelle hier wird bei
                // jedem Tab-Wisch zuerst erreicht.
                .onChanged { g in
                    if abs(g.translation.width) > abs(g.translation.height) { TabWischSperre.shared.beanspruchen() }
                }
                .onEnded { g in
                    guard abs(g.translation.width) > abs(g.translation.height) else { return }
                    blaettern(g.translation.width < 0 ? 7 : -7)
                }
        )
    }

    private func pfeil(_ symbol: String, _ tage: Int, _ label: String) -> some View {
        Button { blaettern(tage) } label: {
            Image(systemName: symbol).font(.body.weight(.semibold)).frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func blaettern(_ tage: Int) {
        Haptik.auswahl()
        withAnimation(Feder.weich) { gewaehlt = Datum.addTage(gewaehlt, tage) }
    }

    private var monatBlatt: some View {
        NavigationStack {
            DatePicker("Tag", selection: Binding(get: { Datum.datum(gewaehlt) }, set: { gewaehlt = Datum.text($0); monatOffen = false }),
                       displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "de_DE"))
                .padding()
                .navigationTitle("Tag wählen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Heute") { gewaehlt = echtHeute; monatOffen = false } }
                    ToolbarItem(placement: .confirmationAction) { Button("Fertig") { monatOffen = false } }
                }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Körper und Verlauf (ganz unten)

    private var koerper: some View {
        KoerperInhalt(
            daten: KoerperDaten.laden(ich),
            onGruppe: { koerperAuswahl = KoerperAuswahl(gruppe: $0, teil: $1) },
            onZiele: { befragung = true },
            onTraining: { gymOeffnen() },
            mitStreifen: false,
            mitFigur: false,
            mitNaechstes: false
        )
    }

    private var verlaufKasten: some View {
        kasten("Verlauf", symbol: "chart.xyaxis.line", farbe: TagesForm.schlaf.farbe, text: "Übungen und Muskelgruppen") { pfad.append(HeuteZiel.verlauf) }
    }

    /// Gym: läuft eine Einheit, direkt hinein, sonst der Plan mit Einchecken.
    private func gymOeffnen() {
        pfad.append(HeuteZiel.training)
        if let s = TrainingModell.shared.laufende(ich) { pfad.append(HealthZiel.gymSession(s.id)) }
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
                HabitsSektion(zoom: zoom) { if case .habit(let id) = $0 { pfad.append(HeuteZiel.habit(id)) } }.padding(16)
            }
            .navigationTitle("Habits")
        case .habit(let id): HabitDetailView(habitId: id)
        case .punkte: PunkteVerlaufView()
        case .ernaehrung: ErnaehrungView()
        case .training: TrainingsPlanView(person: ich, oeffnen: { pfad.append($0) })
        case .koerper: KoerperView()
        case .verlauf: VerlaufView { pfad.append($0) }
        }
    }

    // MARK: Kasten

    private func kasten(_ titel: String, symbol: String, farbe: Color, text: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(farbe)
                    .frame(width: 44, height: 44)
                    .background(farbe.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(.headline)
                    Text(text).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .heuteKarte()
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.federnd)
    }

    // MARK: Tagesform

    private var tagesform: Tagesform {
        let erholung = MuskelLogik.erholung(TrainingModell.shared.sessions(ich), jetzt: Date())
        return TagesformLogik.tagesform(
            schlafMinuten: health.schlafMinuten(ich, heute), wasser: health.wasserAnzahl(ich, heute),
            wasserZiel: health.zielWasser(ich), schritte: health.schritteAm(ich, heute), schritteZiel: health.zielSchritte(ich),
            erholung: TagesformLogik.erholungMittel(erholung), schlafZiel: health.schlafZiel(ich, tag: heute))
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
            creatinKachel
        }
    }

    private var schritteKachel: some View {
        let ziel = health.zielSchritte(ich)
        let n = health.schritteAm(ich, heute) ?? 0
        return FormKachel(form: .schritte, titel: "Schritte", wert: deZahl(n), einheit: "",
                          fuellung: ziel > 0 ? Double(n) / Double(ziel) : 0, zusatz: "Ziel \(deZahl(ziel))") { pfad.append(HeuteZiel.schritte) }
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
        let ziel = health.schlafZiel(ich, tag: heute)
        let zielText = ziel % 60 == 0 ? "\(ziel / 60)" : komma(Double(ziel) / 60)
        return FormKachel(form: .schlaf, titel: "Schlaf", wert: minuten.map { komma(Double($0) / 60) } ?? "–", einheit: "/\(zielText) h",
                          fuellung: ziel > 0 ? Double(minuten ?? 0) / Double(ziel) : 0) { pfad.append(HeuteZiel.schlaf) }
    }

    private var habitsKachel: some View {
        let sichtbar = health.sichtbareHabits(fuer: ich)
        let erledigt = sichtbar.filter {
            HabitLogik.erledigt($0, wert: health.habitWert($0.id, ich, heute), ziel: health.habitZiel($0.id, ich))
        }.count
        return FormKachel(form: .habits, titel: "Habits", wert: "\(erledigt)", einheit: "/\(sichtbar.count)",
                          fuellung: sichtbar.isEmpty ? 0 : Double(erledigt) / Double(sichtbar.count)) { pfad.append(HeuteZiel.habits) }
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

    /// Ein Tipp = ein Klick = 3,5 g, Ziel 2 Klicks (Ahmed, 27.09.).
    private var creatinKachel: some View {
        let n = health.habitWert(Habit.creatin.id, ich, heute)
        let ziel = Habit.creatin.tagesziel ?? 2
        return FormKachel(form: .creatin, titel: "Creatin", wert: komma(Double(n) * Habit.creatinGramm), einheit: "g",
                          fuellung: Double(n) / Double(ziel), zusatz: "\(n)/\(ziel) Klicks") {
            health.setzeHabit(Habit.creatin.id, datum: heute, wert: n + 1)
        }
    }

    /// Schmale Zeile statt Karte (Ahmed, 01.10.: Training starten muss ohne Scrollen sichtbar bleiben,
    /// auch bei großer Schrift).
    private var freitextZeile: some View {
        Button { freitextOffen = true } label: {
            Label("Schreib, was war", systemImage: "square.and.pencil")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Schlaf, Gewicht, Wasser, Creatin per Freitext eintragen")
    }

    private var proteinKachel: some View {
        let ernaehrung = ErnaehrungModell.shared
        let ziel = ernaehrung.ziele(ich, tag: heute).kcal
        let summe = ernaehrung.summe(ich, heute)
        let kcal = Int(summe.kcal.rounded())
        let protein = Int(summe.protein.rounded())
        return FormKachel(form: .protein, titel: "Food", wert: "\(kcal)", einheit: "/\(ziel) kcal",
                          fuellung: ziel > 0 ? Double(kcal) / Double(ziel) : 0, zusatz: "\(protein) g Protein") {
            pfad.append(HeuteZiel.ernaehrung)
        }
    }

    /// Alle Einträge mit Wert, älteste zuerst. Wert = Zehntel-kg.
    private var gewichte: [(tag: String, zehntel: Int)] {
        health.habitWerte(Habit.gewicht.id, ich).filter { $0.value > 0 }.sorted { $0.key < $1.key }
            .map { (tag: $0.key, zehntel: $0.value) }
    }

    /// Groß der berechnete Wert (`GewichtLogik`, Schnitt der letzten 7 Tage), klein der letzte Eintrag.
    private var gewichtKachel: some View {
        let berechnet = GewichtLogik.berechnet(health.habitWerte(Habit.gewicht.id, ich))
        let zuletzt = gewichte.last.map { "zuletzt \(komma(Double($0.zehntel) / 10))" }
        return FormKachel(form: .gewicht, titel: "Gewicht", wert: berechnet.map { komma(Double($0) / 10) } ?? "–", einheit: "kg",
                          fuellung: 0, zusatz: zuletzt) { gewichtOffen = true }
    }

    private var trainingKachel: some View {
        let dran = health.gymAbgehakt(ich, heute) || TrainingModell.shared.sessions(ich).contains { Datum.text($0.start) == heute }
        return FormKachel(form: .training, titel: "Gym", wert: dran ? "Gym" : "Pause", einheit: "", fuellung: dran ? 1 : 0) {
            gymOeffnen()
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
        Button { pfad.append(HeuteZiel.punkte) } label: {
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
