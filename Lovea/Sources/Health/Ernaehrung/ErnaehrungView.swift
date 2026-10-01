import SwiftUI

// Food-Tagebuch 1:1 nach YAZIO (Ahmed, 26./27.09.): großer Tagestitel mit Woche, Karte "Übersicht"
// (Gegessen, offener Ring mit Übrig, Verbrannt, drei Makros), "Ernährung" als kompakte Mahlzeit-Zeilen
// mit rundem Plus, Wasserzähler in Litern mit "Wasser aus Lebensmitteln", Körperwerte.
// Tage wechseln per Pfeilen oben oder Kalender, beliebig weit (Ahmed, 01.10.: kein Wischen mehr,
// das stand dem Zurück-Wischen vom Rand im Weg).

enum ErnaehrungStil {
    /// YAZIO-Mint, nur für Ringe und Balken, nie für Text.
    static let akzent = Color(red: 0.13, green: 0.86, blue: 0.66)
    static let wasser = Color(red: 0.35, green: 0.72, blue: 1)
    static let radius: CGFloat = 20
    /// Ein Glas im Wasserzähler.
    static let glasMl = 250
}

// MARK: - Wrapper

struct ErnaehrungView: View {
    @State private var tag = Datum.text(Date())
    @State private var vorwaerts = true
    @State private var partnerAnsicht = false
    @State private var neu: Mahlzeit?
    @State private var scannen: Mahlzeit?
    @State private var offeneMahlzeit: Mahlzeit?
    @State private var uebersichtOffen = false
    @State private var analyseOffen = false
    @State private var kalenderOffen = false
    @State private var zieleOffen = false
    @State private var koerperOffen = false
    @State private var fastenOffen = false
    @State private var einkaufOffen = false
    @State private var naehrwerteOffen = false
    @State private var anpassenOffen = false
    @Environment(\.accessibilityReduceMotion) private var ruhig

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }
    private var ich: Person { modell.ich }
    private var person: Person { partnerAnsicht ? ich.partner : ich }
    private var heute: String { Datum.text(Date()) }

    var body: some View {
        ScrollView {
            TagebuchAnsicht(stand: stand, aktionen: aktionen)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .id(tag)
                .transition(ruhig ? AnyTransition.opacity : AnyTransition.push(from: vorwaerts ? .trailing : .leading))
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Barcode scannen", systemImage: "barcode.viewfinder") {
                    scannen = Mahlzeit.zurZeit(stunde: Datum.kalender.component(.hour, from: Date()))
                }
                .disabled(partnerAnsicht)
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Ziele", systemImage: "target") { zieleOffen = true }
                    Button("Auswertung", systemImage: "chart.bar") { analyseOffen = true }
                    Button("Nährwerte des Tages", systemImage: "list.bullet.rectangle") { naehrwerteOffen = true }
                    Button("Intervallfasten", systemImage: "timer") { fastenOffen = true }
                    Button("Einkaufsliste", systemImage: "cart") { einkaufOffen = true }
                    Button("Tagebuch anpassen", systemImage: "slider.horizontal.3") { anpassenOffen = true }
                    Button(partnerAnsicht ? "Mein Tag" : "Tag von \(ich.partner.name)", systemImage: "person.2") {
                        partnerAnsicht.toggle()
                        Haptik.auswahl()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Mehr")
            }
        }
        .navigationDestination(item: $offeneMahlzeit) { m in
            MahlzeitView(mahlzeit: m, tag: tag, person: person)
        }
        .navigationDestination(isPresented: $uebersichtOffen) { MahlzeitenUebersicht(tag: tag, person: person) }
        .navigationDestination(isPresented: $analyseOffen) { ErnaehrungAnalyseView() }
        .navigationDestination(isPresented: $naehrwerteOffen) { TagesNaehrwerteView(tag: tag, person: person) }
        .navigationDestination(isPresented: $fastenOffen) { FastenView() }
        .navigationDestination(isPresented: $einkaufOffen) { EinkaufView() }
        .sheet(isPresented: $anpassenOffen) { TagebuchAnpassenBlatt() }
        .sheet(item: $neu) { m in HinzufuegenBlatt(mahlzeit: m, datum: tag) }
        .sheet(item: $scannen) { m in HinzufuegenBlatt(mahlzeit: m, datum: tag, scannen: true) }
        .sheet(isPresented: $zieleOffen) { ErnaehrungZieleView() }
        .sheet(isPresented: $koerperOffen) { KoerperwerteBlatt(tag: tag) }
        .sheet(isPresented: $kalenderOffen) { kalenderBlatt }
        .onAppear { LebensmittelIndex.shared.laden() }
        .onDisappear { LebensmittelIndex.shared.freigeben() }
    }

    private var stand: TagebuchStand {
        let alle = modell.eintraege(person, tag)
        let koerper: [KoerperwertD] = KoerperArt.allCases.compactMap { modell.koerperwert(person, $0, bis: tag) }
        let anpassung = modell.anpassung(person)
        var namen: [Mahlzeit: String] = [:]
        for m in Mahlzeit.allCases { namen[m] = anpassung.name(m) }
        return TagebuchStand(
            tag: tag, heute: heute, person: person, partnerAnsicht: partnerAnsicht,
            ziele: modell.ziele(person, tag: tag), zieleEingerichtet: modell.ziele(person).eingerichtet,
            eintraege: Dictionary(grouping: alle, by: \.mahlzeit),
            verbrannt: modell.verbrannt(person, tag),
            wasserGlaeser: HealthModell.shared.wasserAnzahl(person, tag),
            wasserZielGlaeser: HealthModell.shared.zielWasser(person),
            wasserAusEssenMl: Int(ErnaehrungLogik.wasserAusLebensmitteln(alle).rounded()),
            gewicht: modell.gewicht(person, bis: tag).map { GewichtStand(zehntel: $0.zehntel, datum: $0.datum) },
            koerperwerte: koerper,
            abschnitte: anpassung.sichtbar,
            mahlzeitNamen: namen
        )
    }

    private var aktionen: TagebuchAktionen {
        TagebuchAktionen(
            vorherigerTag: { wechseln(-1) },
            naechsterTag: { wechseln(1) },
            datumOeffnen: { kalenderOffen = true },
            zieleOeffnen: { zieleOffen = true },
            mahlzeitOeffnen: { offeneMahlzeit = $0 },
            hinzufuegen: { neu = $0 },
            mehr: { uebersichtOffen = true },
            wasserSetzen: { n in
                HealthModell.shared.setzeWasser(datum: tag, anzahl: n)
                Haptik.leicht()
            },
            gewichtAendern: { schritt in gewichtAendern(schritt) },
            koerperMehr: { koerperOffen = true },
            naehrwerteOeffnen: { naehrwerteOffen = true }
        )
    }

    private func wechseln(_ richtung: Int) {
        vorwaerts = richtung > 0
        withAnimation(ruhig ? nil : Feder.weich) {
            tag = Datum.addTage(tag, richtung)
        }
        Haptik.auswahl()
    }

    /// ±0,1 kg vom Gewicht dieses Tages oder vom letzten davor. Nie eingetragen: Blatt öffnen.
    private func gewichtAendern(_ schritt: Int) {
        guard let letztes = modell.gewicht(ich, bis: tag) else {
            koerperOffen = true
            return
        }
        modell.gewichtSetzen(zehntel: letztes.zehntel + schritt, datum: tag)
        Haptik.leicht()
    }

    private var tagBinding: Binding<Date> {
        Binding(get: { Datum.datum(tag) }, set: { tag = Datum.text($0) })
    }

    private var kalenderBlatt: some View {
        NavigationStack {
            DatePicker("Datum", selection: tagBinding, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "de_DE"))
                .padding()
                .navigationTitle("Tag wählen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Heute") {
                            tag = heute
                            kalenderOffen = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) { Button("Fertig") { kalenderOffen = false } }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Reine Ansicht (Render-Tafel)

struct GewichtStand: Equatable {
    var zehntel: Int
    /// Tag des Eintrags; ungleich dem angezeigten Tag = zuletzt früher eingetragen.
    var datum: String
}

/// Alles, was `TagebuchAnsicht` zum Zeichnen braucht, ohne Singletons.
struct TagebuchStand {
    var tag: String
    var heute: String
    var person: Person
    var partnerAnsicht = false
    var ziele = ErnaehrungsZiele()
    var zieleEingerichtet = true
    var eintraege: [Mahlzeit: [EssenEintrag]] = [:]
    var verbrannt: Int? = nil
    var wasserGlaeser = 0
    var wasserZielGlaeser = 8
    var wasserAusEssenMl = 0
    var gewicht: GewichtStand? = nil
    var koerperwerte: [KoerperwertD] = []
    /// Sichtbare Abschnitte in Reihenfolge (`TagebuchAnpassung.sichtbar`).
    var abschnitte: [String] = TagebuchAnpassung.alleAbschnitte
    var mahlzeitNamen: [Mahlzeit: String] = [:]

    var bearbeitbar: Bool { !partnerAnsicht }
    func name(_ m: Mahlzeit) -> String { mahlzeitNamen[m] ?? m.name }
}

struct TagebuchAktionen {
    var vorherigerTag: () -> Void = {}
    var naechsterTag: () -> Void = {}
    var datumOeffnen: () -> Void = {}
    var zieleOeffnen: () -> Void = {}
    var mahlzeitOeffnen: (Mahlzeit) -> Void = { _ in }
    var hinzufuegen: (Mahlzeit) -> Void = { _ in }
    var mehr: () -> Void = {}
    var wasserSetzen: (Int) -> Void = { _ in }
    /// Schritt in Zehntel-kg, +1 oder -1.
    var gewichtAendern: (Int) -> Void = { _ in }
    var koerperMehr: () -> Void = {}
    var naehrwerteOeffnen: () -> Void = {}
}

struct TagebuchAnsicht: View {
    let stand: TagebuchStand
    var aktionen = TagebuchAktionen()

    private var alle: [EssenEintrag] { Mahlzeit.allCases.flatMap { stand.eintraege[$0] ?? [] } }
    private var summe: Naehrwerte { ErnaehrungLogik.summe(alle) }
    private var gegessen: Int { Int(summe.kcal.rounded()) }
    private var karte: some Shape { RoundedRectangle(cornerRadius: ErnaehrungStil.radius, style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            kopf
            ForEach(stand.abschnitte, id: \.self) { abschnitt($0) }
        }
        .fontDesign(.rounded)
    }

    @ViewBuilder
    private func abschnitt(_ id: String) -> some View {
        switch id {
        case "uebersicht":
            VStack(alignment: .leading, spacing: 12) {
                ueberschrift("Übersicht")
                Button(action: aktionen.naehrwerteOeffnen) { uebersicht }
                    .buttonStyle(.plain)
                    .accessibilityHint("Zeigt alle Nährwerte des Tages")
                if stand.bearbeitbar && !stand.zieleEingerichtet { zielHinweis }
            }
        case "ernaehrung":
            VStack(alignment: .leading, spacing: 12) {
                abschnittKopf("Ernährung", aktion: aktionen.mehr)
                mahlzeiten
            }
        case "wasser":
            VStack(alignment: .leading, spacing: 12) {
                ueberschrift("Wasserzähler")
                wasserKarte
            }
        case "koerper":
            VStack(alignment: .leading, spacing: 12) {
                abschnittKopf("Körperwerte", aktion: stand.bearbeitbar ? aktionen.koerperMehr : nil)
                koerperKarte
            }
        default:
            EmptyView()
        }
    }

    private func ueberschrift(_ text: String) -> some View {
        Text(text).font(.title2.weight(.heavy)).accessibilityAddTraits(.isHeader)
    }

    private func abschnittKopf(_ text: String, aktion: (() -> Void)?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            ueberschrift(text)
            Spacer()
            if let aktion {
                Button("Mehr", action: aktion)
                    .font(.body.weight(.semibold))
                    .frame(minHeight: 44)
            }
        }
    }

    // MARK: Kopf

    private var untertitel: String {
        let woche = Datum.kalender.component(.weekOfYear, from: Datum.datum(stand.tag))
        return stand.partnerAnsicht ? "\(stand.person.name) · Woche \(woche)" : "Woche \(woche)"
    }

    private var titel: String {
        if stand.tag == stand.heute { return "Heute" }
        if stand.tag == Datum.addTage(stand.heute, -1) { return "Gestern" }
        if stand.tag == Datum.addTage(stand.heute, 1) { return "Morgen" }
        return Datum.anzeige(stand.tag)
    }

    private var kopf: some View {
        HStack(alignment: .center, spacing: 4) {
            Button(action: aktionen.datumOeffnen) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel)
                        .font(.largeTitle.weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(untertitel).font(.subheadline).foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Anderen Tag wählen")
            Spacer(minLength: 8)
            tagKnopf("chevron.left", "Vorheriger Tag", aktion: aktionen.vorherigerTag)
            tagKnopf("chevron.right", "Nächster Tag", aktion: aktionen.naechsterTag)
        }
        .padding(.top, 4)
    }

    private func tagKnopf(_ symbol: String, _ titel: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .frame(width: 44, height: 44)
                .background(Color(uiColor: .secondarySystemBackground), in: Circle())
        }
        .buttonStyle(.federnd)
        .foregroundStyle(Color.primary)
        .accessibilityLabel(titel)
    }

    // MARK: Übersicht

    private var uebersicht: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 0) {
                kennzahl(gegessen, "Gegessen")
                ring
                kennzahl(stand.verbrannt ?? 0, "Verbrannt")
            }
            HStack(alignment: .top, spacing: 16) {
                makro("Kohlenhydrate", ist: summe.kohlenhydrate, ziel: stand.ziele.kohlenhydrate)
                makro("Eiweiß", ist: summe.protein, ziel: stand.ziele.protein)
                makro("Fett", ist: summe.fett, ziel: stand.ziele.fett)
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemBackground), in: karte)
    }

    private func kennzahl(_ wert: Int, _ titel: String) -> some View {
        VStack(spacing: 2) {
            Text(ernaehrungZahl(wert)).font(.title3.weight(.bold)).monospacedDigit()
            Text(titel).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var ring: some View {
        let rest = stand.ziele.kcal - gegessen
        let anteil: Double = stand.ziele.kcal > 0 ? min(1, Double(gegessen) / Double(stand.ziele.kcal)) : 0
        return ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: CGFloat(0.75 * anteil))
                .stroke(rest >= 0 ? ErnaehrungStil.akzent : Color.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(135))
            VStack(spacing: 0) {
                Text(ernaehrungZahl(abs(rest))).font(.title.weight(.heavy)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                Text(rest >= 0 ? "Übrig" : "Drüber").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
        }
        .frame(width: 136, height: 136)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rest >= 0 ? "\(rest) Kilokalorien übrig" : "\(-rest) Kilokalorien drüber")
    }

    private func makro(_ titel: String, ist: Double, ziel: Int) -> some View {
        let anteil: Double = ziel > 0 ? min(1, ist / Double(ziel)) : 0
        return VStack(alignment: .leading, spacing: 6) {
            Text(titel).font(.footnote).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule().fill(ErnaehrungStil.akzent).frame(width: geo.size.width * CGFloat(anteil))
                }
            }
            .frame(height: 6)
            Text("\(Int(ist.rounded())) / \(ziel) g").font(.footnote.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var zielHinweis: some View {
        Button(action: aktionen.zieleOeffnen) {
            HStack(spacing: 6) {
                Text("Ziel \(ernaehrungZahl(stand.ziele.kcal)) kcal geschätzt.").foregroundStyle(.secondary)
                Text("Anpassen").fontWeight(.semibold)
            }
            .font(.footnote)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    // MARK: Ernährung

    private var mahlzeiten: some View {
        VStack(spacing: 0) {
            ForEach(Mahlzeit.allCases) { m in
                mahlzeitZeile(m)
                if m != Mahlzeit.allCases.last { Divider().padding(.leading, 76) }
            }
        }
        .background(Color(uiColor: .secondarySystemBackground), in: karte)
    }

    private func mahlzeitZeile(_ m: Mahlzeit) -> some View {
        let eintraege = stand.eintraege[m] ?? []
        let kcal = Int(ErnaehrungLogik.summe(eintraege).kcal.rounded())
        let richtwert = Int((m.anteil * Double(stand.ziele.kcal)).rounded())
        let namen = eintraege.map(\.lebensmittel.name).joined(separator: ", ")
        let anteil: Double = richtwert > 0 ? min(1, Double(kcal) / Double(richtwert)) : 0
        return HStack(spacing: 14) {
            Button { aktionen.mahlzeitOeffnen(m) } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().stroke(Color.primary.opacity(0.12), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: CGFloat(anteil))
                            .stroke(ErnaehrungStil.akzent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: m.symbol).font(.body).foregroundStyle(.secondary)
                    }
                    .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(stand.name(m)).font(.headline.weight(.bold))
                            Image(systemName: "arrow.right").font(.footnote.weight(.bold))
                        }
                        Text("\(ernaehrungZahl(kcal)) / \(ernaehrungZahl(richtwert)) kcal").font(.subheadline).monospacedDigit()
                        if !namen.isEmpty {
                            Text(namen).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Zeigt, was du gegessen hast")
            if stand.bearbeitbar {
                Button { aktionen.hinzufuegen(m) } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .frame(width: 38, height: 38)
                        .background(Color.primary, in: Circle())
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.federnd)
                .accessibilityLabel("Zu \(stand.name(m)) hinzufügen")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Wasserzähler

    private func liter(_ ml: Int) -> String {
        let l = Double(ml) / 1000
        let text = String(format: "%.2f", l).replacingOccurrences(of: ".", with: ",")
        return text.replacingOccurrences(of: ",?0+$", with: "", options: .regularExpression) + " l"
    }

    private var wasserKarte: some View {
        let anzahl = max(stand.wasserZielGlaeser, stand.wasserGlaeser + (stand.bearbeitbar ? 1 : 0))
        let spalten = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
        return VStack(spacing: 14) {
            VStack(spacing: 2) {
                Text("Wasser").font(.headline.weight(.bold))
                Text("Ziel: \(liter(stand.wasserZielGlaeser * ErnaehrungStil.glasMl))").font(.footnote).foregroundStyle(.secondary)
            }
            Text(liter(stand.wasserGlaeser * ErnaehrungStil.glasMl)).font(.title.weight(.heavy)).monospacedDigit()
            LazyVGrid(columns: spalten, spacing: 8) {
                ForEach(0..<anzahl, id: \.self) { i in glas(i) }
            }
            Text("+ Wasser aus Lebensmitteln: \(ernaehrungZahl(stand.wasserAusEssenMl)) ml")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground), in: karte)
    }

    /// Tipp auf ein volles Glas: bis dahin zurück. Tipp auf das nächste leere: eins mehr.
    private func glas(_ i: Int) -> some View {
        let voll = i < stand.wasserGlaeser
        let naechstes = i == stand.wasserGlaeser
        return Button {
            aktionen.wasserSetzen(voll ? i : i + 1)
        } label: {
            Group {
                if naechstes && stand.bearbeitbar {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ErnaehrungStil.wasser)
                } else {
                    Image(systemName: voll ? "waterbottle.fill" : "waterbottle")
                        .foregroundStyle(voll ? ErnaehrungStil.wasser : Color.primary.opacity(0.25))
                }
            }
            .font(.title)
            .imageScale(.large)
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!stand.bearbeitbar || i > stand.wasserGlaeser)
        .accessibilityLabel(voll ? "Glas \(i + 1), voll" : "Glas \(i + 1), leer")
    }

    // MARK: Körperwerte

    private var gewichtText: String {
        guard let g = stand.gewicht else { return "–" }
        return "\(ErnaehrungLogik.zahl(Double(g.zehntel) / 10)) kg"
    }

    private var gewichtUnterzeile: String {
        guard let g = stand.gewicht else { return "Noch nicht eingetragen" }
        if g.datum == stand.tag { return "An diesem Tag eingetragen" }
        let teile = g.datum.split(separator: "-")
        let kurz = teile.count == 3 ? "\(teile[2]).\(teile[1])." : g.datum
        return "Zuletzt am \(kurz)"
    }

    private var koerperKarte: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gewicht").font(.headline.weight(.bold))
                    Text(gewichtText).font(.title3.weight(.heavy)).monospacedDigit()
                    Text(gewichtUnterzeile).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if stand.bearbeitbar {
                    rundKnopf("minus", "0,1 kg weniger") { aktionen.gewichtAendern(-1) }
                    rundKnopf("plus", "0,1 kg mehr") { aktionen.gewichtAendern(1) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            ForEach(stand.koerperwerte, id: \.art) { w in
                Divider().padding(.leading, 16)
                HStack {
                    Text(w.art.name).font(.body)
                    Spacer()
                    Text("\(ErnaehrungLogik.zahl(w.wert)) \(w.art.einheit)").font(.body.weight(.semibold)).monospacedDigit()
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground), in: karte)
    }

    private func rundKnopf(_ symbol: String, _ titel: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(width: 38, height: 38)
                .background(Color.primary, in: Circle())
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(titel)
    }
}

/// YAZIO Pro "Tagebuch anpassen": Abschnitte sortieren und ausblenden, Mahlzeiten umbenennen.
struct TagebuchAnpassenBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var reihenfolge: [String]
    @State private var ausgeblendet: Set<String>
    @State private var namen: [String: String]

    init() {
        let a = ErnaehrungModell.shared.anpassung(ErnaehrungModell.shared.ich)
        let bekannt = a.reihenfolge.filter { TagebuchAnpassung.alleAbschnitte.contains($0) }
        _reihenfolge = State(initialValue: bekannt + TagebuchAnpassung.alleAbschnitte.filter { !bekannt.contains($0) })
        _ausgeblendet = State(initialValue: Set(a.ausgeblendet))
        _namen = State(initialValue: a.mahlzeitNamen)
    }

    private func titel(_ id: String) -> String {
        switch id {
        case "uebersicht": "Übersicht"
        case "ernaehrung": "Ernährung"
        case "wasser": "Wasserzähler"
        default: "Körperwerte"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(reihenfolge, id: \.self) { id in
                        Toggle(titel(id), isOn: Binding(
                            get: { !ausgeblendet.contains(id) },
                            set: { an in
                                if an { _ = ausgeblendet.remove(id) } else { _ = ausgeblendet.insert(id) }
                            }))
                    }
                    .onMove { reihenfolge.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("Abschnitte")
                } footer: {
                    Text("Ziehen zum Sortieren, Schalter zum Ausblenden.")
                }
                Section("Mahlzeiten") {
                    ForEach(Mahlzeit.allCases) { m in
                        HStack {
                            Image(systemName: m.symbol).foregroundStyle(.secondary).frame(width: 28)
                            TextField(m.name, text: Binding(
                                get: { namen[m.rawValue] ?? "" },
                                set: { namen[m.rawValue] = $0 }))
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .fontDesign(.rounded)
            .navigationTitle("Tagebuch anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let leer = namen.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
                        ErnaehrungModell.shared.anpassungSichern(TagebuchAnpassung(
                            reihenfolge: reihenfolge,
                            ausgeblendet: reihenfolge.filter { ausgeblendet.contains($0) },
                            mahlzeitNamen: leer))
                        Haptik.erfolg()
                        dismiss()
                    }
                }
            }
        }
    }
}
