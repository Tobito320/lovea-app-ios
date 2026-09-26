import SwiftUI

/// Eine Mahlzeit eines Tages, wie in YAZIO eine Ebene unter dem Tagebuch. Tipp auf einen Eintrag
/// klappt die einfachen Werte auf, "Mehr sehen" öffnet `NaehrwerteBlatt` mit allen Nährwerten.
struct MahlzeitView: View {
    let mahlzeit: Mahlzeit
    let tag: String
    let person: Person

    @State private var offen: Set<String> = []
    @State private var mehr: EssenEintrag?
    @State private var bearbeiten: EssenEintrag?
    /// "Menge ändern" im Blatt: das Bearbeiten-Blatt geht erst auf, wenn das Nährwerte-Blatt zu ist.
    @State private var folge: EssenEintrag?
    @State private var neuOffen = false
    @Environment(\.accessibilityReduceMotion) private var ruhig

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }
    private var bearbeitbar: Bool { person == modell.ich }

    var body: some View {
        let liste = modell.eintraege(person, tag, mahlzeit)
        let summe = ErnaehrungLogik.summe(liste)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                kopf(summe)
                if liste.isEmpty { leer } else { eintragListe(liste) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemBackground))
        .fontDesign(.rounded)
        .navigationTitle(mahlzeit.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if bearbeitbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Von gestern übernehmen", systemImage: "arrow.uturn.backward") {
                            modell.kopieren(von: Datum.addTage(tag, -1), nach: tag, mahlzeit: mahlzeit)
                            Haptik.erfolg()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Mehr")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if bearbeitbar { hinzufuegenKnopf }
        }
        .sheet(item: $mehr, onDismiss: folgeOeffnen) { e in
            NaehrwerteBlatt(titel: e.lebensmittel.anzeigeName,
                            untertitel: ErnaehrungLogik.mengeText(e.menge, e.einheit, e.lebensmittel),
                            werte: e.naehrwerte, lebensmittel: e.lebensmittel, bearbeitbar: bearbeitbar,
                            aendern: {
                                folge = e
                                mehr = nil
                            },
                            loeschen: {
                                modell.loeschen(e)
                                Haptik.leicht()
                                mehr = nil
                            })
        }
        .sheet(item: $bearbeiten) { EintragBearbeitenBlatt(eintrag: $0) }
        .sheet(isPresented: $neuOffen) { HinzufuegenBlatt(mahlzeit: mahlzeit, datum: tag) }
    }

    private func folgeOeffnen() {
        guard let e = folge else { return }
        folge = nil
        bearbeiten = e
    }

    private func kopf(_ summe: Naehrwerte) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tagText).font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(zahl(Int(summe.kcal.rounded()))).font(.system(.largeTitle, design: .rounded).weight(.heavy)).monospacedDigit()
                Text("kcal").font(.headline).foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                wert("\(ErnaehrungLogik.zahl(summe.kohlenhydrate)) g", "Kohlenhydrate")
                wert("\(ErnaehrungLogik.zahl(summe.protein)) g", "Eiweiß")
                wert("\(ErnaehrungLogik.zahl(summe.fett)) g", "Fett")
            }
        }
    }

    private var tagText: String {
        let heute = Datum.text(Date())
        if tag == heute { return "Heute" }
        if tag == Datum.addTage(heute, -1) { return "Gestern" }
        return Datum.anzeige(tag)
    }

    private var leer: some View {
        VStack(spacing: 8) {
            Image(systemName: "barcode.viewfinder").font(.largeTitle).foregroundStyle(.secondary)
            Text(bearbeitbar ? "Noch nichts eingetragen. Scann einfach die Packung." : "Noch nichts eingetragen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func eintragListe(_ liste: [EssenEintrag]) -> some View {
        VStack(spacing: 0) {
            ForEach(liste) { e in
                eintragZeile(e)
                if e.id != liste.last?.id { Divider().padding(.leading, 16) }
            }
        }
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: ErnaehrungStil.radius, style: .continuous))
    }

    private func eintragZeile(_ e: EssenEintrag) -> some View {
        let istOffen = offen.contains(e.id)
        let n = e.naehrwerte
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(ruhig ? nil : Feder.weich) {
                    if offen.remove(e.id) == nil { offen.insert(e.id) }
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.lebensmittel.anzeigeName).font(.body.weight(.semibold)).multilineTextAlignment(.leading)
                        Text(ErnaehrungLogik.mengeText(e.menge, e.einheit, e.lebensmittel)).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text("\(zahl(Int(n.kcal.rounded()))) kcal").font(.body.weight(.semibold)).monospacedDigit()
                }
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityValue(istOffen ? "aufgeklappt" : "zugeklappt")
            if istOffen {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 0) {
                        wert("\(ErnaehrungLogik.zahl(n.kohlenhydrate)) g", "Kohlenhydrate")
                        wert("\(ErnaehrungLogik.zahl(n.protein)) g", "Eiweiß")
                        wert("\(ErnaehrungLogik.zahl(n.fett)) g", "Fett")
                    }
                    Button { mehr = e } label: {
                        HStack(spacing: 4) {
                            Text("Mehr sehen")
                            Image(systemName: "chevron.right").font(.footnote.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contextMenu {
            if bearbeitbar {
                Button("Menge ändern", systemImage: "pencil") { bearbeiten = e }
                Button("Löschen", systemImage: "trash", role: .destructive) { modell.loeschen(e) }
            }
        }
    }

    private func wert(_ zahlText: String, _ titel: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(zahlText).font(.headline.weight(.bold)).monospacedDigit()
            Text(titel).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var hinzufuegenKnopf: some View {
        Button { neuOffen = true } label: {
            Label("Hinzufügen", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func zahl(_ n: Int) -> String { n.formatted(.number.locale(Locale(identifier: "de_DE"))) }
}

/// Alle Nährwerte eines Eintrags oder einer Menge. Schließen mit X oder nach unten wischen.
struct NaehrwerteBlatt: View {
    let titel: String
    let untertitel: String
    let werte: Naehrwerte
    let lebensmittel: Lebensmittel
    /// Nur dann gibt es "Menge ändern" und "Löschen".
    var bearbeitbar = false
    var aendern: () -> Void = {}
    var loeschen: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var loeschenFragen = false

    private var basis: String { lebensmittel.basisEinheit.rawValue }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(untertitel).font(.subheadline).foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(Int(werte.kcal.rounded()))").font(.system(.largeTitle, design: .rounded).weight(.heavy)).monospacedDigit()
                            Text("kcal").font(.headline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Nährwerte") {
                    zeile("Kohlenhydrate", werte.kohlenhydrate)
                    zeile("davon Zucker", werte.zucker, eingerueckt: true)
                    zeile("Eiweiß", werte.protein)
                    zeile("Fett", werte.fett)
                    zeile("davon gesättigt", werte.gesFett, eingerueckt: true)
                    zeile("Ballaststoffe", werte.ballaststoffe)
                    zeile("Salz", werte.salz)
                }
                Section("Pro 100 \(basis)") {
                    LabeledContent("Kalorien", value: "\(Int(lebensmittel.pro100.kcal.rounded())) kcal")
                    zeile("Kohlenhydrate", lebensmittel.pro100.kohlenhydrate)
                    zeile("Eiweiß", lebensmittel.pro100.protein)
                    zeile("Fett", lebensmittel.pro100.fett)
                }
                if lebensmittel.marke != nil || lebensmittel.barcode != nil || lebensmittel.nutriscore != nil {
                    Section("Produkt") {
                        if let marke = lebensmittel.marke { LabeledContent("Marke", value: marke) }
                        if let code = lebensmittel.barcode { LabeledContent("Barcode", value: code) }
                        if let note = lebensmittel.nutriscore {
                            LabeledContent("Nutri-Score") { NutriScoreAbzeichen(note: note) }
                        }
                    }
                }
                if bearbeitbar {
                    Section {
                        Button("Menge ändern", systemImage: "pencil", action: aendern)
                        Button("Löschen", systemImage: "trash", role: .destructive) { loeschenFragen = true }
                    }
                }
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Schließen")
                }
            }
            .confirmationDialog("Eintrag löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { loeschen() }
            }
        }
        .fontDesign(.rounded)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func zeile(_ titel: String, _ wert: Double?, eingerueckt: Bool = false) -> some View {
        LabeledContent {
            Text(wert.map { "\(ErnaehrungLogik.zahl($0)) g" } ?? "–").monospacedDigit()
        } label: {
            Text(titel)
                .foregroundStyle(eingerueckt ? Color.secondary : Color.primary)
                .padding(.leading, eingerueckt ? 12 : 0)
        }
    }
}
