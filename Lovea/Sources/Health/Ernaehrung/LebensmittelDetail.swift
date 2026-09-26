import SwiftUI

/// Ein Lebensmittel eintragen, ändern oder löschen: Menge, Einheit, Mahlzeit, Live-Nährwerte.
/// Wird meist in einen bestehenden `NavigationStack` gepusht (siehe `HinzufuegenBlatt`), für ein
/// eigenes Blatt siehe `EintragBearbeitenBlatt`.
struct LebensmittelDetailView: View {
    let lebensmittel: Lebensmittel
    let bearbeiten: EssenEintrag?
    let datum: String
    let fertig: () -> Void

    @State private var mahlzeit: Mahlzeit
    @State private var text: String
    @State private var einheit: Einheit
    @State private var loeschenFragen = false

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }

    init(lebensmittel: Lebensmittel, mahlzeit: Mahlzeit, datum: String, bearbeiten: EssenEintrag? = nil, fertig: @escaping () -> Void = {}) {
        self.lebensmittel = lebensmittel
        self.bearbeiten = bearbeiten
        self.datum = bearbeiten?.datum ?? datum
        self.fertig = fertig
        _mahlzeit = State(initialValue: bearbeiten?.mahlzeit ?? mahlzeit)
        let start = Self.start(lebensmittel, bearbeiten: bearbeiten)
        _text = State(initialValue: ErnaehrungLogik.zahl(start.menge))
        _einheit = State(initialValue: start.einheit)
    }

    /// Menge des Eintrags, sonst die letzte Menge dieses Lebensmittels, sonst die Startmenge.
    private static func start(_ l: Lebensmittel, bearbeiten: EssenEintrag?) -> (menge: Double, einheit: Einheit) {
        if let bearbeiten { return (bearbeiten.menge, bearbeiten.einheit) }
        if let letzte = ErnaehrungModell.shared.letzteMenge(ErnaehrungModell.shared.ich, l) { return letzte }
        return ErnaehrungLogik.startMenge(l)
    }

    private var menge: Double? { ErnaehrungLogik.eingabe(text) }
    private var kannSichern: Bool { (menge ?? 0) > 0 }

    private var naehrwerte: Naehrwerte {
        guard let menge else { return .null }
        return ErnaehrungLogik.naehrwerte(lebensmittel, menge: menge, einheit: einheit)
    }

    var body: some View {
        Form {
            Section { kopf }
            Section {
                HStack {
                    TextField("Menge", text: $text)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Menge")
                    Picker("Einheit", selection: $einheit) {
                        ForEach(ErnaehrungLogik.einheiten(lebensmittel), id: \.self) { e in
                            Text(ErnaehrungLogik.einheitName(e, lebensmittel)).tag(e)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }
                schnellwahl
                Picker("Mahlzeit", selection: $mahlzeit) {
                    ForEach(Mahlzeit.allCases) { m in Label(m.name, systemImage: m.symbol).tag(m) }
                }
            }
            Section("Nährwerte") { naehrwerteBlock }
        }
        .navigationTitle(lebensmittel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { favoritKnopf }
        }
        .safeAreaInset(edge: .bottom) { aktionen }
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

    private var kopf: some View {
        HStack(spacing: 12) {
            if let bild = lebensmittel.bild, let url = URL(string: bild) {
                AsyncImage(url: url) { bild in
                    bild.resizable().scaledToFill()
                } placeholder: {
                    Color(uiColor: .tertiarySystemFill)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(lebensmittel.name).font(.headline)
                if let marke = lebensmittel.marke { Text(marke).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer()
            if let note = lebensmittel.nutriscore { NutriScoreAbzeichen(note: note) }
        }
    }

    private var schnellwahl: some View {
        let werte: [Double] = einheit == .g || einheit == .ml ? [50, 100, 150, 200, 250] : [0.5, 1, 1.5, 2]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(werte, id: \.self) { w in
                    Button(ErnaehrungLogik.zahl(w)) {
                        text = ErnaehrungLogik.zahl(w)
                        Haptik.auswahl()
                    }
                    .buttonStyle(.bordered)
                    .tint(menge == w ? Color.accentColor : Color.secondary)
                }
            }
        }
    }

    private var naehrwerteBlock: some View {
        let n = naehrwerte
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(n.kcal.rounded()))").font(.system(size: 34, weight: .bold)).monospacedDigit()
                Text("kcal").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack {
                makro("Protein", n.protein)
                makro("Kohlenhydrate", n.kohlenhydrate)
                makro("Fett", n.fett)
            }
            VStack(spacing: 0) {
                if let zucker = n.zucker { detailZeile("Zucker", zucker) }
                if let ballaststoffe = n.ballaststoffe { detailZeile("Ballaststoffe", ballaststoffe) }
                if let salz = n.salz { detailZeile("Salz", salz) }
                if let gesFett = n.gesFett { detailZeile("davon gesättigt", gesFett) }
            }
            Text("Pro 100 \(lebensmittel.basisEinheit.rawValue): \(Int(lebensmittel.pro100.kcal.rounded())) kcal")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func makro(_ titel: String, _ wert: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(ErnaehrungLogik.zahl(wert)) g").font(.subheadline.bold()).monospacedDigit()
            Text(titel).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func detailZeile(_ titel: String, _ wert: Double) -> some View {
        HStack {
            Text(titel).font(.footnote).foregroundStyle(.secondary)
            Spacer()
            Text("\(ErnaehrungLogik.zahl(wert)) g").font(.footnote).monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private var aktionen: some View {
        Group {
            if bearbeiten != nil {
                HStack(spacing: 12) {
                    Button("Löschen", role: .destructive) { loeschenFragen = true }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    Button("Sichern") { sichern() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(!kannSichern)
                }
            } else {
                Button("Eintragen") { eintragen() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(!kannSichern)
            }
        }
        .padding(16)
        .background(.bar)
        .confirmationDialog("Eintrag löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { loeschen() }
        }
    }

    private func eintragen() {
        guard let menge else { return }
        modell.eintragen(lebensmittel, menge: menge, einheit: einheit, mahlzeit: mahlzeit, datum: datum)
        Haptik.erfolg()
        fertig()
    }

    private func sichern() {
        guard var eintrag = bearbeiten, let menge else { return }
        eintrag.mahlzeit = mahlzeit
        eintrag.menge = menge
        eintrag.einheit = einheit
        eintrag.lebensmittel = lebensmittel
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
