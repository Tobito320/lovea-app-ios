import SwiftUI

/// Produktseite 1:1 nach YAZIO (Ahmed, 27.09./01.10.): dunkler Kopf mit Name, vier Werte, Nährwerte-Liste,
/// Portionsbeispiele, unten fest die `MengenLeiste` mit Zahlenfeld, Dreier-Rad und Speichern-Knopf.
/// Wird in einen bestehenden `NavigationStack` gepusht (siehe `HinzufuegenBlatt`), für ein eigenes Blatt
/// siehe `EintragBearbeitenBlatt`. Kein eigener Zurück-Knopf, damit von links nach rechts zurückgewischt werden kann.
struct LebensmittelDetailView: View {
    let lebensmittel: Lebensmittel
    let bearbeiten: EssenEintrag?
    let datum: String
    let fertig: () -> Void

    @State private var mahlzeit: Mahlzeit
    @State private var auswahl: MengenOption
    @State private var zahl: Double
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

    /// Menge des Eintrags, sonst die letzte Menge, sonst 1 Teelöffel bei löffelbaren Lebensmitteln,
    /// sonst 1 × erste Portion, sonst 100 in der Basis-Einheit.
    private static func start(_ l: Lebensmittel, bearbeiten: EssenEintrag?) -> (auswahl: MengenOption, zahl: Double) {
        if let e = bearbeiten {
            return (MengenOption.auswahl(einheit: e.einheit, portionName: e.lebensmittel.portionName, l: l), e.menge)
        }
        if let letzte = ErnaehrungModell.shared.letzteMenge(ErnaehrungModell.shared.ich, l) {
            return (MengenOption.auswahl(einheit: letzte.einheit, portionName: l.portionName, l: l), letzte.menge)
        }
        let portionen = ErnaehrungLogik.portionsAuswahl(l)
        if let teelöffel = portionen.first(where: { $0.name == "Teelöffel, gestrichen" }) { return (.portion(teelöffel), 1) }
        if let erste = portionen.first(where: { $0.name.contains("mittel") }) ?? portionen.first { return (.portion(erste), 1) }
        return (l.fluessig ? .milliliter : .gramm, 100)
    }

    /// Das Lebensmittel mit der gewählten Portion, wie es gespeichert wird.
    private var lebensmittelFuerMenge: Lebensmittel {
        if case .portion(let p) = auswahl { return ErnaehrungLogik.mitPortion(lebensmittel, p) }
        return lebensmittel
    }

    private var naehrwerte: Naehrwerte { ErnaehrungLogik.naehrwerte(lebensmittelFuerMenge, menge: zahl, einheit: auswahl.einheit) }

    /// BLS-Grundlebensmittel erkennt man an der ID (T2 bringt `Lebensmittel.quelle` nach, dann übernimmt das).
    private var istBLS: Bool { lebensmittel.id.hasPrefix("bls-") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                kopf
                VStack(alignment: .leading, spacing: 24) {
                    werteReihe
                    quelleZeile
                    let schilder = FoodRating.schilder(lebensmittel)
                    if !schilder.isEmpty { FoodSchilder(schilder: schilder) }
                    naehrwerteAbschnitt
                    portionsbeispieleZeile
                    if istBLS {
                        Text("Nährwerte: Max Rubner-Institut, BLS 4.0 (CC BY 4.0)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
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
        .safeAreaInset(edge: .bottom) {
            MengenLeiste(lebensmittel: lebensmittel, auswahl: $auswahl, zahl: $zahl,
                         knopf: bearbeiten == nil ? "Hinzufügen" : "Speichern", aktion: speichern)
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
                Button { mahlzeit = m } label: { Label(modell.mahlzeitName(m), systemImage: m.symbol) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(modell.mahlzeitName(mahlzeit)).font(.headline)
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
        ZStack {
            LinearGradient(colors: [Color(white: 0.28), Color(white: 0.14)], startPoint: .top, endPoint: .bottom)
            Text(lebensmittel.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(height: 220)
    }

    /// "Geprüfte Nährwertangaben" (BLS) und/oder "Zuletzt hinzugefügt" (schon einmal gegessen), wie YAZIO.
    @ViewBuilder
    private var quelleZeile: some View {
        if istBLS || modell.letzteMenge(modell.ich, lebensmittel) != nil {
            VStack(spacing: 4) {
                if istBLS {
                    Label("Geprüfte Nährwertangaben", systemImage: "checkmark.seal.fill")
                }
                if modell.letzteMenge(modell.ich, lebensmittel) != nil {
                    Label("Zuletzt hinzugefügt", systemImage: "clock.arrow.circlepath")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
    }

    private var werteReihe: some View {
        HStack {
            wertSpalte("\(kcalText) kcal", "Kalorien")
            wertSpalte("\(ErnaehrungLogik.zahl(naehrwerte.kohlenhydrate)) g", "Kohlenhydrate")
            wertSpalte("\(ErnaehrungLogik.zahl(naehrwerte.protein)) g", "Eiweiß")
            wertSpalte("\(ErnaehrungLogik.zahl(naehrwerte.fett)) g", "Fett")
        }
    }

    /// Ganzzahlig mit deutschem Tausenderpunkt, für 721 × einer Portion auch fünfstellig lesbar.
    private var kcalText: String {
        Int(naehrwerte.kcal.rounded()).formatted(.number.locale(Locale(identifier: "de_DE")))
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
