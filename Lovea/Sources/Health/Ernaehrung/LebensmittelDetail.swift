import SwiftUI

/// Produktseite 1:1 nach YAZIO (Ahmed, 27.09.): Name, Nutri-Score, vier Werte, Nährwerte-Liste,
/// Portionsbeispiele, unten die Mengen-Zeile mit Rad-Blatt und der Speichern-Knopf. Wird in einen
/// bestehenden `NavigationStack` gepusht (siehe `HinzufuegenBlatt`), für ein eigenes Blatt siehe
/// `EintragBearbeitenBlatt`. Kein eigener Zurück-Knopf, damit von links nach rechts zurückgewischt werden kann.
struct LebensmittelDetailView: View {
    let lebensmittel: Lebensmittel
    let bearbeiten: EssenEintrag?
    let datum: String
    let fertig: () -> Void

    @State private var mahlzeit: Mahlzeit
    @State private var auswahl: MengenOption
    @State private var zahl: Double
    @State private var mengenRadOffen = false
    @State private var portionsbeispieleOffen = false
    @State private var loeschenFragen = false

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }

    init(lebensmittel: Lebensmittel, mahlzeit: Mahlzeit, datum: String, bearbeiten: EssenEintrag? = nil, fertig: @escaping () -> Void = {}) {
        self.lebensmittel = lebensmittel
        self.bearbeiten = bearbeiten
        self.datum = bearbeiten?.datum ?? datum
        self.fertig = fertig
        _mahlzeit = State(initialValue: bearbeiten?.mahlzeit ?? mahlzeit)
        let start = Self.start(lebensmittel, bearbeiten: bearbeiten)
        _auswahl = State(initialValue: start.auswahl)
        _zahl = State(initialValue: start.zahl)
    }

    /// Menge des Eintrags, sonst die letzte Menge, sonst 1 × erste Portion, sonst 100 in der Basis-Einheit.
    private static func start(_ l: Lebensmittel, bearbeiten: EssenEintrag?) -> (auswahl: MengenOption, zahl: Double) {
        if let e = bearbeiten {
            return (MengenOption.auswahl(einheit: e.einheit, portionName: e.lebensmittel.portionName, l: l), e.menge)
        }
        if let letzte = ErnaehrungModell.shared.letzteMenge(ErnaehrungModell.shared.ich, l) {
            return (MengenOption.auswahl(einheit: letzte.einheit, portionName: l.portionName, l: l), letzte.menge)
        }
        let portionen = ErnaehrungLogik.portionsAuswahl(l)
        if let erste = portionen.first(where: { $0.name.contains("mittel") }) ?? portionen.first { return (.portion(erste), 1) }
        return (l.fluessig ? .milliliter : .gramm, 100)
    }

    /// Das Lebensmittel mit der gewählten Portion, wie es gespeichert wird.
    private var lebensmittelFuerMenge: Lebensmittel {
        if case .portion(let p) = auswahl { return ErnaehrungLogik.mitPortion(lebensmittel, p) }
        return lebensmittel
    }

    private var naehrwerte: Naehrwerte { ErnaehrungLogik.naehrwerte(lebensmittelFuerMenge, menge: zahl, einheit: auswahl.einheit) }
    private var kannSpeichern: Bool { zahl > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                kopf
                werteReihe
                naehrwerteAbschnitt
                portionsbeispieleZeile
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemBackground))
        .fontDesign(.rounded)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { mahlzeitMenu }
            ToolbarItem(placement: .primaryAction) { favoritKnopf }
            if bearbeiten != nil {
                ToolbarItem(placement: .primaryAction) { loeschenKnopf }
            }
        }
        .safeAreaInset(edge: .bottom) { unten }
        .sheet(isPresented: $mengenRadOffen) {
            MengenRadBlatt(lebensmittel: lebensmittel, auswahl: $auswahl, zahl: $zahl)
        }
        .sheet(isPresented: $portionsbeispieleOffen) { PortionsbeispieleBlatt() }
        .confirmationDialog("Eintrag löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { loeschen() }
        }
    }

    // MARK: Toolbar

    private var mahlzeitMenu: some View {
        Menu {
            ForEach(Mahlzeit.allCases) { m in
                Button { mahlzeit = m } label: { Label(m.name, systemImage: m.symbol) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(mahlzeit.name).font(.headline)
                Image(systemName: "chevron.down").font(.caption.weight(.bold))
            }
            .foregroundStyle(Color.primary)
        }
    }

    private var favoritKnopf: some View {
        Button {
            modell.favoritSetzen(lebensmittel, an: !modell.istFavorit(lebensmittel))
            Haptik.leicht()
        } label: {
            Image(systemName: modell.istFavorit(lebensmittel) ? "star.fill" : "star")
        }
        .accessibilityLabel(modell.istFavorit(lebensmittel) ? "Favorit entfernen" : "Als Favorit merken")
    }

    private var loeschenKnopf: some View {
        Button(role: .destructive) { loeschenFragen = true } label: {
            Image(systemName: "trash")
        }
        .accessibilityLabel("Eintrag löschen")
    }

    // MARK: Inhalt

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let gross = lebensmittel.bildGross {
                LebensmittelBild(url: gross, groesse: 220)
                    .frame(maxWidth: .infinity)
            }
            kopfText
        }
    }

    private var kopfText: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lebensmittel.name).font(.title.weight(.bold))
                if let marke = lebensmittel.marke { Text(marke).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            if let note = lebensmittel.nutriscore { NutriScoreAbzeichen(note: note) }
        }
    }

    private var werteReihe: some View {
        HStack {
            wertSpalte(ErnaehrungLogik.zahl(naehrwerte.kcal), "kcal")
            wertSpalte("\(ErnaehrungLogik.zahl(naehrwerte.kohlenhydrate)) g", "Kohlenhydrate")
            wertSpalte("\(ErnaehrungLogik.zahl(naehrwerte.protein)) g", "Eiweiß")
            wertSpalte("\(ErnaehrungLogik.zahl(naehrwerte.fett)) g", "Fett")
        }
    }

    private func wertSpalte(_ wert: String, _ titel: String) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.headline).monospacedDigit()
            Text(titel).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var naehrwerteAbschnitt: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Nährwerte").font(.title3.weight(.bold))
                naehrwerteListe
            }
            ForEach(Mikro.Gruppe.allCases, id: \.self) { gruppe in mikroAbschnitt(gruppe) }
            if naehrwerte.mikro?.isEmpty ?? true {
                Text("Für dieses Lebensmittel gibt es keine Angaben zu Vitaminen und Mineralstoffen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Nur Werte, die es für dieses Lebensmittel wirklich gibt. Rechts der Anteil an der EU-Tagesreferenzmenge.
    @ViewBuilder
    private func mikroAbschnitt(_ gruppe: Mikro.Gruppe) -> some View {
        let werte: [MikroWert] = Mikro.allCases.filter { $0.gruppe == gruppe }.compactMap { m in
            naehrwerte.wert(m).map { MikroWert(mikro: m, wert: $0) }
        }
        if !werte.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(gruppe.rawValue).font(.title3.weight(.bold))
                VStack(spacing: 0) {
                    ForEach(werte) { w in
                        mikroZeile(w.mikro, w.wert)
                        if w.id != werte.last?.id { Divider() }
                    }
                }
                if gruppe != .weitere {
                    Text("% = Anteil am Tagesbedarf (EU-Referenzmenge)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func mikroZeile(_ m: Mikro, _ wert: Double) -> some View {
        HStack {
            Text(m.name)
            Spacer()
            Text("\(mikroZahl(wert)) \(m.einheit)").foregroundStyle(.secondary).monospacedDigit()
            if let referenz = m.referenz, referenz > 0 {
                Text("\(Int((wert / referenz * 100).rounded())) %")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .frame(minWidth: 48, alignment: .trailing)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    /// Kleine Mengen mit mehr Nachkommastellen (0,04 mg Vitamin B2), große ohne.
    private func mikroZahl(_ x: Double) -> String {
        let stellen = x >= 10 ? 0 : (x >= 1 ? 1 : 2)
        return x.formatted(.number.precision(.fractionLength(0...stellen)).locale(Locale(identifier: "de_DE")))
    }

    private var naehrwerteListe: some View {
        VStack(spacing: 0) {
            naehrwertZeile("Kalorien", "\(ErnaehrungLogik.zahl(naehrwerte.kcal)) kcal")
            Divider()
            naehrwertZeile("Eiweiß", grammText(naehrwerte.protein))
            Divider()
            naehrwertZeile("Kohlenhydrate", grammText(naehrwerte.kohlenhydrate))
            Divider()
            naehrwertZeile("davon Zucker", optionalerGrammText(naehrwerte.zucker), einzug: true)
            Divider()
            naehrwertZeile("Ballaststoffe", optionalerGrammText(naehrwerte.ballaststoffe))
            Divider()
            naehrwertZeile("Fett", grammText(naehrwerte.fett))
            Divider()
            naehrwertZeile("davon gesättigte Fettsäuren", optionalerGrammText(naehrwerte.gesFett), einzug: true)
            Divider()
            naehrwertZeile("Salz", optionalerGrammText(naehrwerte.salz))
        }
    }

    private func grammText(_ x: Double) -> String { "\(ErnaehrungLogik.zahl(x)) g" }
    private func optionalerGrammText(_ x: Double?) -> String { x.map(grammText) ?? "–" }

    private func naehrwertZeile(_ titel: String, _ wert: String, einzug: Bool = false) -> some View {
        HStack {
            Text(titel).padding(.leading, einzug ? 16 : 0)
            Spacer()
            Text(wert).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(.vertical, 10)
    }

    private var portionsbeispieleZeile: some View {
        Button { portionsbeispieleOffen = true } label: {
            HStack {
                Text("Portionsbeispiele").foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: Unten

    private var unten: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Button { mengenRadOffen = true } label: {
                    Text(MengenOption.bruchText(zahl)).font(.title3.weight(.bold)).monospacedDigit()
                }
                Button { mengenRadOffen = true } label: {
                    Text(auswahl.anzeige(lebensmittel)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)

            Button { speichern() } label: {
                Text(bearbeiten != nil ? "Speichern" : "Hinzufügen")
                    .font(.headline)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
                .tint(ErnaehrungStil.akzent)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(!kannSpeichern)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: ErnaehrungStil.radius, style: .continuous))
    }

    // MARK: Aktionen

    private func speichern() {
        if bearbeiten != nil { sichern() } else { eintragen() }
    }

    private func eintragen() {
        modell.eintragen(lebensmittelFuerMenge, menge: zahl, einheit: auswahl.einheit, mahlzeit: mahlzeit, datum: datum)
        Haptik.erfolg()
        fertig()
    }

    private func sichern() {
        guard var eintrag = bearbeiten else { return }
        eintrag.mahlzeit = mahlzeit
        eintrag.menge = zahl
        eintrag.einheit = auswahl.einheit
        eintrag.lebensmittel = lebensmittelFuerMenge
        modell.aendern(eintrag)
        Haptik.erfolg()
        fertig()
    }

    private func loeschen() {
        guard let eintrag = bearbeiten else { return }
        modell.loeschen(eintrag)
        fertig()
    }
}

/// A bis E in den Farben des Nutri-Score-Logos.
struct NutriScoreAbzeichen: View {
    let note: String

    private var farbe: Color {
        switch note {
        case "a": .green
        case "b": Color(red: 0.6, green: 0.8, blue: 0.1)
        case "c": .yellow
        case "d": .orange
        default: .red
        }
    }

    var body: some View {
        Text(note.uppercased())
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(Circle().fill(farbe))
            .accessibilityLabel("Nutri-Score \(note.uppercased())")
    }
}

/// Blatt zum Ändern eines bestehenden Eintrags, eigener `NavigationStack`, schließt sich selbst.
struct EintragBearbeitenBlatt: View {
    let eintrag: EssenEintrag
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LebensmittelDetailView(lebensmittel: eintrag.lebensmittel, mahlzeit: eintrag.mahlzeit, datum: eintrag.datum,
                                   bearbeiten: eintrag, fertig: { dismiss() })
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                }
        }
    }
}

private struct MikroWert: Identifiable {
    let mikro: Mikro
    let wert: Double
    var id: Mikro { mikro }
}
