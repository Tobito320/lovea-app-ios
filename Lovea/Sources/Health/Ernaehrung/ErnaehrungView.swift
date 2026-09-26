import SwiftUI

// Ernährungs-Tagebuch (Teil 5, wie YAZIO): Kopf mit Ring und Makros, Fasten, vier Mahlzeiten, Wasser,
// aufklappbare Nährwerte. Gepusht aus `HeuteView`, deshalb ohne eigenen `NavigationStack`.

// MARK: - Wrapper

struct ErnaehrungView: View {
    @State private var tag = Datum.text(Date())
    @State private var partnerAnsicht = false
    @State private var neu: Mahlzeit?
    @State private var bearbeiten: EssenEintrag?
    @State private var kalenderOffen = false
    @State private var zieleOffen = false

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }
    private var ich: Person { modell.ich }
    private var heute: String { Datum.text(Date()) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { kontext in
            ScrollView {
                TagebuchAnsicht(stand: stand(kontext.date), aktionen: aktionen)
                    .padding(16)
            }
        }
        .navigationTitle("Ernährung")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { NavigationLink("Analyse") { ErnaehrungAnalyseView() } }
            ToolbarItem(placement: .primaryAction) { Button("Ziele") { zieleOffen = true } }
        }
        .sheet(item: $neu) { m in HinzufuegenBlatt(mahlzeit: m, datum: tag) }
        .sheet(item: $bearbeiten) { EintragBearbeitenBlatt(eintrag: $0) }
        .sheet(isPresented: $zieleOffen) { ErnaehrungZieleView() }
        .sheet(isPresented: $kalenderOffen) { kalenderBlatt }
    }

    private var tagBinding: Binding<Date> {
        Binding(get: { Datum.datum(tag) }, set: { tag = Datum.text($0) })
    }

    private var kalenderBlatt: some View {
        NavigationStack {
            DatePicker("Datum", selection: tagBinding, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "de_DE"))
                .padding()
                .navigationTitle("Datum wählen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Fertig") { kalenderOffen = false } }
                }
        }
        .presentationDetents([.medium])
    }

    private func stand(_ jetzt: Date) -> TagebuchStand {
        let person = partnerAnsicht ? ich.partner : ich
        return TagebuchStand(
            ich: ich, partnerAnsicht: partnerAnsicht, tag: tag, heute: heute, jetzt: jetzt,
            ziele: modell.ziele(person), zieleEingerichtet: modell.ziele(ich).eingerichtet,
            eintraege: Dictionary(uniqueKeysWithValues: Mahlzeit.allCases.map { ($0, modell.eintraege(person, tag, $0)) }),
            verbrannt: modell.verbrannt(person, tag), wasser: HealthModell.shared.wasserAnzahl(person, tag),
            wasserZiel: HealthModell.shared.zielWasser(person), fasten: modell.fasten(person)
        )
    }

    private var aktionen: TagebuchAktionen {
        TagebuchAktionen(
            vorherigerTag: { tag = Datum.addTage(tag, -1) },
            naechsterTag: { if tag < heute { tag = Datum.addTage(tag, 1) } },
            datumOeffnen: { kalenderOffen = true },
            personWechseln: {
                partnerAnsicht.toggle()
                Haptik.auswahl()
            },
            zieleEinrichten: { zieleOffen = true },
            hinzufuegen: { neu = $0 },
            eintragOeffnen: { bearbeiten = $0 },
            eintragLoeschen: {
                modell.loeschen($0)
                Haptik.leicht()
            },
            vonGesternUebernehmen: { m in modell.kopieren(von: Datum.addTage(tag, -1), nach: tag, mahlzeit: m) },
            wasserPlus: {
                HealthModell.shared.setzeWasser(datum: tag, anzahl: HealthModell.shared.wasserAnzahl(ich, tag) + 1)
                Haptik.leicht()
            },
            wasserMinus: {
                let n = HealthModell.shared.wasserAnzahl(ich, tag)
                HealthModell.shared.setzeWasser(datum: tag, anzahl: max(0, n - 1))
                Haptik.leicht()
            },
            fastenStarten: {
                modell.fastenStarten()
                Haptik.erfolg()
            },
            fastenBeenden: {
                modell.fastenBeenden()
                Haptik.erfolg()
            }
        )
    }
}

// MARK: - Reine Ansicht (Render-Tafel)

/// Alles, was `TagebuchAnsicht` zum Zeichnen braucht — ohne Singletons, damit die Render-Tafel sie
/// mit festen Daten zeichnen kann. `jetzt` kommt aus dem `TimelineView` des Wrappers, nie aus `Date()`.
struct TagebuchStand {
    var ich: Person
    var partnerAnsicht = false
    var tag: String
    var heute: String
    var jetzt = Date()
    var ziele = ErnaehrungsZiele()
    var zieleEingerichtet = true
    var eintraege: [Mahlzeit: [EssenEintrag]] = [:]
    var verbrannt: Int? = nil
    var wasser = 0
    var wasserZiel = 8
    var fasten: FastenD? = nil

    var person: Person { partnerAnsicht ? ich.partner : ich }
    var bearbeitbar: Bool { !partnerAnsicht }
}

struct TagebuchAktionen {
    var vorherigerTag: () -> Void = {}
    var naechsterTag: () -> Void = {}
    var datumOeffnen: () -> Void = {}
    var personWechseln: () -> Void = {}
    var zieleEinrichten: () -> Void = {}
    var hinzufuegen: (Mahlzeit) -> Void = { _ in }
    var eintragOeffnen: (EssenEintrag) -> Void = { _ in }
    var eintragLoeschen: (EssenEintrag) -> Void = { _ in }
    var vonGesternUebernehmen: (Mahlzeit) -> Void = { _ in }
    var wasserPlus: () -> Void = {}
    var wasserMinus: () -> Void = {}
    var fastenStarten: () -> Void = {}
    var fastenBeenden: () -> Void = {}
}

/// Pure Tagebuch-Ansicht ohne `ScrollView` und ohne `TimelineView` (das übernimmt der Wrapper),
/// damit `ImageRenderer` sie ohne UIKit-Steuerelemente zeichnen kann.
struct TagebuchAnsicht: View {
    let stand: TagebuchStand
    var aktionen = TagebuchAktionen()

    @State private var naehrwerteOffen = false

    private var farbe: Color { TagesForm.protein.farbe }
    private var summe: Naehrwerte { ErnaehrungLogik.summe(Mahlzeit.allCases.flatMap { stand.eintraege[$0] ?? [] }) }
    private var kcalIst: Int { Int(summe.kcal.rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            personSchalter
            tagNavigation
            if stand.bearbeitbar && !stand.zieleEingerichtet { zieleKarte }
            kopfKarte
            if zeigeFasten { fastenKarte }
            ForEach(Mahlzeit.allCases) { m in mahlzeitAbschnitt(m) }
            wasserZeile
            naehrwerteAbschnitt
        }
    }

    // MARK: Kopf: Person, Tag

    private var personSchalter: some View {
        HStack(spacing: 8) {
            schalterKnopf("Ich", ausgewaehlt: !stand.partnerAnsicht)
            schalterKnopf(stand.ich.partner.name, ausgewaehlt: stand.partnerAnsicht)
        }
    }

    private func schalterKnopf(_ titel: String, ausgewaehlt: Bool) -> some View {
        Button(action: aktionen.personWechseln) {
            Text(titel)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(ausgewaehlt ? Color.aufHabitFarbe : Color.primary)
                .background(ausgewaehlt ? farbe : Color(uiColor: .secondarySystemBackground), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private var tagTitel: String {
        if stand.tag == stand.heute { return "Heute" }
        if stand.tag == Datum.addTage(stand.heute, -1) { return "Gestern" }
        return Datum.anzeige(stand.tag)
    }

    private var tagNavigation: some View {
        HStack {
            Button(action: aktionen.vorherigerTag) {
                Image(systemName: "chevron.left").frame(width: 36, height: 36)
            }
            .buttonStyle(.federnd)
            .accessibilityLabel("Vorheriger Tag")
            Spacer()
            Button(action: aktionen.datumOeffnen) {
                Text(tagTitel).font(.title3.bold())
            }
            .buttonStyle(.plain)
            Spacer()
            Button(action: aktionen.naechsterTag) {
                Image(systemName: "chevron.right").frame(width: 36, height: 36)
            }
            .buttonStyle(.federnd)
            .disabled(stand.tag >= stand.heute)
            .opacity(stand.tag >= stand.heute ? 0.3 : 1)
            .accessibilityLabel("Nächster Tag")
        }
    }

    private var zieleKarte: some View {
        Button(action: aktionen.zieleEinrichten) {
            HStack {
                Label("Ziele einrichten", systemImage: "target").font(.headline)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.federnd)
        .foregroundStyle(Color.primary)
        .healthKarte(farbe)
    }

    // MARK: Kopf-Karte: Ring, Makros

    private var kopfKarte: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                ring
                VStack(alignment: .leading, spacing: 8) {
                    Text(restText).font(.headline).foregroundStyle(restFarbe)
                    HStack(spacing: 16) {
                        kennzahl("\(kcalIst)", "gegessen")
                        if let verbrannt = stand.verbrannt {
                            VStack(alignment: .leading, spacing: 0) {
                                kennzahl("\(verbrannt)", "verbrannt")
                                Text("zählt nicht zum Ziel").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .accessibilityElement(children: .combine)
            VStack(spacing: 10) {
                makroZeile("Kohlenhydrate", ist: summe.kohlenhydrate, ziel: stand.ziele.kohlenhydrate)
                makroZeile("Protein", ist: summe.protein, ziel: stand.ziele.protein)
                makroZeile("Fett", ist: summe.fett, ziel: stand.ziele.fett)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }

    private var ring: some View {
        let anteil: Double = stand.ziele.kcal > 0 ? Double(kcalIst) / Double(stand.ziele.kcal) : 0
        return ZStack {
            Circle().stroke(farbe.opacity(0.15), lineWidth: 10)
            Circle()
                .trim(from: 0, to: CGFloat(min(1, max(0, anteil))))
                .stroke(farbe, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(kcalIst)").font(.title2.bold()).monospacedDigit()
                Text("von \(stand.ziele.kcal)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(width: 110, height: 110)
        .accessibilityHidden(true)
    }

    private func kennzahl(_ wert: String, _ titel: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(wert).font(.headline).monospacedDigit()
            Text(titel).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var restText: String {
        let rest = stand.ziele.kcal - kcalIst
        return rest >= 0 ? "noch \(rest) kcal" : "\(-rest) kcal drüber"
    }

    private var restFarbe: Color { stand.ziele.kcal - kcalIst >= 0 ? Color.secondary : Color.orange }

    private func makroZeile(_ titel: String, ist: Double, ziel: Int) -> some View {
        let anteil: Double = ziel > 0 ? min(1, ist / Double(ziel)) : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(titel).font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(ist.rounded())) / \(ziel) g").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(farbe.opacity(0.15))
                    Capsule().fill(farbe).frame(width: geo.size.width * CGFloat(anteil))
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Fasten

    /// Nur am aktuellen Tag: der Fasten-Status ist live, nicht rückwirkend pro Tag.
    private var zeigeFasten: Bool { stand.tag == stand.heute && stand.ziele.fastenStunden > 0 }

    private var fastenPlanText: String { "\(stand.ziele.fastenStunden):\(24 - stand.ziele.fastenStunden)" }

    private var fastenKarte: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Fasten", systemImage: "timer").font(.headline).foregroundStyle(farbe)
            if let start = stand.fasten?.start {
                fastenLaufend(start)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Plan \(fastenPlanText). Noch nicht gestartet.").font(.subheadline).foregroundStyle(.secondary)
                    if stand.bearbeitbar {
                        Button("Fasten starten", action: aktionen.fastenStarten)
                            .buttonStyle(.borderedProminent)
                            .tint(farbe)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }

    private func fastenLaufend(_ start: Date) -> some View {
        let rest = ErnaehrungLogik.fastenRest(start: start, stunden: stand.ziele.fastenStunden, jetzt: stand.jetzt)
        let vergangen = stand.jetzt.timeIntervalSince(start)
        let gesamt = Double(stand.ziele.fastenStunden) * 3600
        let anteil: Double = gesamt > 0 ? min(1, max(0, vergangen / gesamt)) : 0
        return VStack(alignment: .leading, spacing: 10) {
            Text("Fastest seit \(Datum.uhrzeit(start))").font(.subheadline)
            Text(rest >= 0 ? "noch \(TrainingLogik.dauerText(rest))" : "\(TrainingLogik.dauerText(-rest)) über dem Ziel")
                .font(.title3.bold())
                .foregroundStyle(rest >= 0 ? Color.primary : Color.green)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(farbe.opacity(0.15))
                    Capsule().fill(farbe).frame(width: geo.size.width * CGFloat(anteil))
                }
            }
            .frame(height: 8)
            if stand.bearbeitbar {
                Button("Fasten beenden", action: aktionen.fastenBeenden).buttonStyle(.bordered).tint(farbe)
            }
        }
    }

    // MARK: Mahlzeiten

    private func mahlzeitAbschnitt(_ m: Mahlzeit) -> some View {
        let eintraege = stand.eintraege[m] ?? []
        let kcal = Int(ErnaehrungLogik.summe(eintraege).kcal.rounded())
        let richtwert = Int((m.anteil * Double(stand.ziele.kcal)).rounded())
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(m.name, systemImage: m.symbol).font(.headline)
                Spacer()
                Text("\(kcal) / \(richtwert) kcal").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            .contextMenu {
                if stand.bearbeitbar {
                    Button("Von gestern übernehmen", systemImage: "arrow.uturn.backward") { aktionen.vonGesternUebernehmen(m) }
                }
            }
            if eintraege.isEmpty {
                Text("Noch nichts eingetragen").font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(eintraege) { e in
                        eintragZeile(e)
                        if e.id != eintraege.last?.id { Divider() }
                    }
                }
            }
            if stand.bearbeitbar {
                Button { aktionen.hinzufuegen(m) } label: {
                    Label("Hinzufügen", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
                .tint(farbe)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }

    @ViewBuilder
    private func eintragZeile(_ e: EssenEintrag) -> some View {
        let inhalt = HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(e.lebensmittel.anzeigeName).font(.subheadline)
                Text(ErnaehrungLogik.mengeText(e.menge, e.einheit, e.lebensmittel)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text("\(Int(e.naehrwerte.kcal.rounded())) kcal").font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .padding(.vertical, 8)
        .contentShape(.rect)

        if stand.bearbeitbar {
            Button { aktionen.eintragOeffnen(e) } label: { inhalt }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Löschen", systemImage: "trash", role: .destructive) { aktionen.eintragLoeschen(e) }
                }
        } else {
            inhalt
        }
    }

    // MARK: Wasser

    private var wasserZeile: some View {
        HStack(spacing: 12) {
            Label("\(stand.wasser) von \(stand.wasserZiel) Gläsern", systemImage: "drop.fill").font(.subheadline)
            Spacer()
            if stand.bearbeitbar {
                Button(action: aktionen.wasserMinus) { Image(systemName: "minus").frame(width: 32, height: 32) }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Ein Glas weniger")
                Button(action: aktionen.wasserPlus) { Image(systemName: "plus").frame(width: 32, height: 32) }
                    .buttonStyle(.borderedProminent)
                    .tint(HabitFarbe.himmel.farbe)
                    .accessibilityLabel("Ein Glas mehr")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(HabitFarbe.himmel.farbe)
    }

    // MARK: Nährwerte

    private var naehrwerteAbschnitt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(Feder.weich) { naehrwerteOffen.toggle() }
            } label: {
                HStack {
                    Text("Nährwerte").font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(naehrwerteOffen ? 90 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if naehrwerteOffen {
                VStack(spacing: 0) {
                    naehrwertZeile("Zucker", summe.zucker)
                    Divider()
                    naehrwertZeile("Ballaststoffe", summe.ballaststoffe)
                    Divider()
                    naehrwertZeile("Salz", summe.salz)
                    Divider()
                    naehrwertZeile("Gesättigte Fettsäuren", summe.gesFett)
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }

    private func naehrwertZeile(_ titel: String, _ wert: Double?) -> some View {
        HStack {
            Text(titel).font(.subheadline)
            Spacer()
            Text(wert.map { "\(ErnaehrungLogik.zahl($0)) g" } ?? "–").font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
