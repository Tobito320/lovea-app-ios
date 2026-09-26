import SwiftUI

// Ernährungs-Tagebuch 1:1 nach YAZIO (Ahmed, 26.09.): großer Tagestitel mit Woche, Karte "Übersicht"
// (Gegessen, offener Ring mit Übrig, Verbrannt, drei Makros), "Ernährung" als kompakte Mahlzeit-Zeilen
// mit rundem Plus, Wasserzähler mit Gläsern. Einträge stehen eine Ebene tiefer (`MahlzeitView`).

enum ErnaehrungStil {
    /// YAZIO-Mint, nur für Ringe und Balken, nie für Text.
    static let akzent = Color(red: 0.13, green: 0.86, blue: 0.66)
    static let wasser = Color(red: 0.35, green: 0.72, blue: 1)
    static let radius: CGFloat = 20
}

// MARK: - Wrapper

struct ErnaehrungView: View {
    @State private var tag = Datum.text(Date())
    @State private var partnerAnsicht = false
    @State private var neu: Mahlzeit?
    @State private var scannen: Mahlzeit?
    @State private var offeneMahlzeit: Mahlzeit?
    @State private var analyseOffen = false
    @State private var kalenderOffen = false
    @State private var zieleOffen = false

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }
    private var ich: Person { modell.ich }
    private var person: Person { partnerAnsicht ? ich.partner : ich }
    private var heute: String { Datum.text(Date()) }

    var body: some View {
        ScrollView {
            TagebuchAnsicht(stand: stand, aktionen: aktionen)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemBackground))
        .simultaneousGesture(tagWischen)
        .navigationTitle("")
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
        .navigationDestination(isPresented: $analyseOffen) { ErnaehrungAnalyseView() }
        .sheet(item: $neu) { m in HinzufuegenBlatt(mahlzeit: m, datum: tag) }
        .sheet(item: $scannen) { m in HinzufuegenBlatt(mahlzeit: m, datum: tag, scannen: true) }
        .sheet(isPresented: $zieleOffen) { ErnaehrungZieleView() }
        .sheet(isPresented: $kalenderOffen) { kalenderBlatt }
    }

    private var stand: TagebuchStand {
        TagebuchStand(
            tag: tag, heute: heute, person: person, partnerAnsicht: partnerAnsicht,
            ziele: modell.ziele(person), zieleEingerichtet: modell.ziele(person).eingerichtet,
            eintraege: Dictionary(uniqueKeysWithValues: Mahlzeit.allCases.map { ($0, modell.eintraege(person, tag, $0)) }),
            verbrannt: modell.verbrannt(person, tag), wasser: HealthModell.shared.wasserAnzahl(person, tag),
            wasserZiel: HealthModell.shared.zielWasser(person)
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
            mehr: { analyseOffen = true },
            wasserSetzen: { n in
                HealthModell.shared.setzeWasser(datum: tag, anzahl: n)
                Haptik.leicht()
            }
        )
    }

    private func wechseln(_ richtung: Int) {
        let ziel = Datum.addTage(tag, richtung)
        guard ziel <= heute else { return }
        tag = ziel
        Haptik.auswahl()
    }

    /// Waagerecht wischen wechselt den Tag, wie in YAZIO.
    private var tagWischen: some Gesture {
        DragGesture(minimumDistance: 40).onEnded { wert in
            let x = wert.translation.width
            guard abs(x) > 90, abs(x) > abs(wert.translation.height) * 2 else { return }
            wechseln(x < 0 ? 1 : -1)
        }
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
                .navigationTitle("Tag wählen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Fertig") { kalenderOffen = false } }
                }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Reine Ansicht (Render-Tafel)

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
    var wasser = 0
    var wasserZiel = 8

    var bearbeitbar: Bool { !partnerAnsicht }
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
}

struct TagebuchAnsicht: View {
    let stand: TagebuchStand
    var aktionen = TagebuchAktionen()

    private var alle: [EssenEintrag] { Mahlzeit.allCases.flatMap { stand.eintraege[$0] ?? [] } }
    private var summe: Naehrwerte { ErnaehrungLogik.summe(alle) }
    private var gegessen: Int { Int(summe.kcal.rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            kopf
            VStack(alignment: .leading, spacing: 12) {
                ueberschrift("Übersicht")
                uebersicht
                if stand.bearbeitbar && !stand.zieleEingerichtet { zielHinweis }
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    ueberschrift("Ernährung")
                    Spacer()
                    Button("Mehr", action: aktionen.mehr)
                        .font(.body.weight(.semibold))
                        .fontDesign(.rounded)
                }
                mahlzeiten
            }
            VStack(alignment: .leading, spacing: 12) {
                ueberschrift("Wasser")
                wasserKarte
            }
        }
        .fontDesign(.rounded)
    }

    private func ueberschrift(_ text: String) -> some View {
        Text(text).font(.title2.weight(.heavy)).accessibilityAddTraits(.isHeader)
    }

    // MARK: Kopf

    private var tagTitel: String {
        if stand.tag == stand.heute { return "Heute" }
        if stand.tag == Datum.addTage(stand.heute, -1) { return "Gestern" }
        return Datum.anzeige(stand.tag)
    }

    private var untertitel: String {
        let woche = Datum.kalender.component(.weekOfYear, from: Datum.datum(stand.tag))
        return stand.partnerAnsicht ? "\(stand.person.name) · Woche \(woche)" : "Woche \(woche)"
    }

    private var kopf: some View {
        HStack(alignment: .center, spacing: 4) {
            Button(action: aktionen.datumOeffnen) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tagTitel)
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
            tagKnopf("chevron.left", "Vorheriger Tag", aktion: aktionen.vorherigerTag, aus: false)
            tagKnopf("chevron.right", "Nächster Tag", aktion: aktionen.naechsterTag, aus: stand.tag >= stand.heute)
        }
        .padding(.top, 4)
    }

    private func tagKnopf(_ symbol: String, _ titel: String, aktion: @escaping () -> Void, aus: Bool) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .frame(width: 44, height: 44)
                .background(Color(uiColor: .secondarySystemBackground), in: Circle())
        }
        .buttonStyle(.federnd)
        .foregroundStyle(Color.primary)
        .disabled(aus)
        .opacity(aus ? 0.3 : 1)
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
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: ErnaehrungStil.radius, style: .continuous))
    }

    private func kennzahl(_ wert: Int, _ titel: String) -> some View {
        VStack(spacing: 2) {
            Text(zahl(wert)).font(.title3.weight(.bold)).monospacedDigit()
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
                Text(zahl(abs(rest))).font(.title.weight(.heavy)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
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
                Text("Ziel \(zahl(stand.ziele.kcal)) kcal geschätzt.").foregroundStyle(.secondary)
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
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: ErnaehrungStil.radius, style: .continuous))
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
                            Text(m.name).font(.headline.weight(.bold))
                            Image(systemName: "arrow.right").font(.footnote.weight(.bold))
                        }
                        Text("\(zahl(kcal)) / \(zahl(richtwert)) kcal").font(.subheadline).monospacedDigit()
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
                .accessibilityLabel("Zu \(m.name) hinzufügen")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Wasser

    private var wasserKarte: some View {
        let anzahl = max(stand.wasserZiel, stand.wasser + (stand.bearbeitbar ? 1 : 0))
        let spalten = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
        return VStack(spacing: 14) {
            VStack(spacing: 2) {
                Text("\(stand.wasser) \(stand.wasser == 1 ? "Glas" : "Gläser")").font(.title2.weight(.heavy)).monospacedDigit()
                Text("Ziel: \(stand.wasserZiel) Gläser").font(.footnote).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: spalten, spacing: 8) {
                ForEach(0..<anzahl, id: \.self) { i in glas(i) }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: ErnaehrungStil.radius, style: .continuous))
    }

    /// Tipp auf ein volles Glas: bis dahin zurück. Tipp auf das nächste leere: eins mehr.
    private func glas(_ i: Int) -> some View {
        let voll = i < stand.wasser
        let naechstes = i == stand.wasser
        return Button {
            aktionen.wasserSetzen(voll ? i : i + 1)
        } label: {
            ZStack {
                Image(systemName: voll ? "waterbottle.fill" : "waterbottle")
                    .font(.title2)
                    .foregroundStyle(voll ? ErnaehrungStil.wasser : Color.primary.opacity(0.25))
                if naechstes && stand.bearbeitbar {
                    Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(Color.primary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!stand.bearbeitbar || i > stand.wasser)
        .accessibilityLabel(voll ? "Glas \(i + 1), voll" : "Glas \(i + 1), leer")
    }

    private func zahl(_ n: Int) -> String { n.formatted(.number.locale(Locale(identifier: "de_DE"))) }
}
