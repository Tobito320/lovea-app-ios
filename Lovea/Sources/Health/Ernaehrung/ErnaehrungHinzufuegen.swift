import SwiftUI

/// Hinzufügen-Blatt wie YAZIO: Barcode, Schnelleintrag, Suche (lokal + Open Food Facts) und die
/// vier Listen Zuletzt/Favoriten/Eigene/Rezepte. Bleibt nach dem Eintragen offen.
struct HinzufuegenBlatt: View {
    let datum: String
    @State private var mahlzeit: Mahlzeit
    @Environment(\.dismiss) private var dismiss

    @State private var suchtext = ""
    @State private var offTreffer: [Lebensmittel] = []
    @State private var suchLaedt = false
    @State private var suchFehler = false
    @State private var segment: Segment = .zuletzt

    @State private var pfad: [Lebensmittel] = []
    @State private var hinweis: String?
    @State private var barcodeOffen = false
    @State private var schnellOffen = false
    @State private var barcodeVorgang: BarcodeVorgang?
    @State private var eigenesZiel: EigenesBlattZiel?
    @State private var eigenesNeuBarcode: BarcodeVorlage?
    @State private var rezeptNeuOffen = false
    @State private var rezeptBearbeiten: Rezept?
    /// Ein Blatt darf erst aufgehen, wenn das vorige ganz zu ist: Scanner und Barcode-Hinweis merken
    /// sich hier, was danach passieren soll, `onDismiss` führt es aus.
    @State private var gescannt: String?
    @State private var barcodeLaedt = false
    @State private var folge: BarcodeFolge?

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }
    private var ich: Person { modell.ich }

    init(mahlzeit: Mahlzeit, datum: String) {
        self.datum = datum
        _mahlzeit = State(initialValue: mahlzeit)
    }

    var body: some View {
        NavigationStack(path: $pfad) {
            liste
                .searchable(text: $suchtext, placement: .navigationBarDrawer(displayMode: .always), prompt: "Lebensmittel suchen")
                .onSubmit(of: .search) { Task { await suchen() } }
                .navigationTitle("Hinzufügen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
                }
                .navigationDestination(for: Lebensmittel.self) { l in
                    LebensmittelDetailView(lebensmittel: l, mahlzeit: mahlzeit, datum: datum) {
                        zeigeHinweis(l.name)
                        if !pfad.isEmpty { pfad.removeLast() }
                    }
                }
                .overlay(alignment: .top) {
                    if let hinweis { hinweisBanner(hinweis) }
                }
                .overlay {
                    if barcodeLaedt {
                        ProgressView("Suche Produkt…")
                            .padding(24)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .animation(Feder.weich, value: hinweis)
        }
        .sheet(isPresented: $barcodeOffen, onDismiss: scannerZu) {
            BarcodeScannerBlatt { code in gescannt = code }
        }
        .sheet(isPresented: $schnellOffen) {
            SchnellEintragenBlatt(mahlzeit: mahlzeit, datum: datum) { l in
                schnellOffen = false
                zeigeHinweis(l.name)
            }
        }
        .sheet(item: $barcodeVorgang, onDismiss: vorgangZu) { vorgang in
            BarcodeVorgangBlatt(vorgang: vorgang, nochmal: { code in
                folge = .nochmal(code)
                barcodeVorgang = nil
            }, selbstAnlegen: { code in
                folge = .anlegen(code)
                barcodeVorgang = nil
            })
        }
        .sheet(item: $eigenesZiel) { ziel in
            switch ziel {
            case .neu: EigenesLebensmittelEditor()
            case .bearbeiten(let l): EigenesLebensmittelEditor(start: l)
            }
        }
        .sheet(item: $eigenesNeuBarcode) { vorlage in
            EigenesLebensmittelEditor(barcode: vorlage.id) { l in pfad.append(l) }
        }
        .sheet(isPresented: $rezeptNeuOffen) {
            RezeptEditor()
        }
        .sheet(item: $rezeptBearbeiten) { r in
            RezeptEditor(start: r)
        }
    }

    // MARK: - Liste

    private var liste: some View {
        List {
            Section {
                mahlzeitAuswahl
                aktionsKnoepfe
            }
            if suchtext.trimmingCharacters(in: .whitespaces).isEmpty {
                Section {
                    Picker("Ansicht", selection: $segment) {
                        ForEach(Segment.allCases) { s in Text(s.titel).tag(s) }
                    }
                    .pickerStyle(.segmented)
                }
                segmentInhalt
            } else {
                sucheInhalt
            }
        }
    }

    private var mahlzeitAuswahl: some View {
        Menu {
            ForEach(Mahlzeit.allCases) { m in
                Button { mahlzeit = m } label: { Label(m.name, systemImage: m.symbol) }
            }
        } label: {
            Label(mahlzeit.name, systemImage: mahlzeit.symbol).font(.subheadline.weight(.semibold))
        }
    }

    private var aktionsKnoepfe: some View {
        VStack(spacing: 10) {
            Button { barcodeOffen = true } label: {
                Label("Barcode scannen", systemImage: "barcode.viewfinder").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            Button { schnellOffen = true } label: {
                Label("Schnell eintragen", systemImage: "bolt.fill").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var segmentInhalt: some View {
        switch segment {
        case .zuletzt:
            let liste = modell.zuletzt(ich)
            Section {
                if liste.isEmpty { Text("Noch nichts gegessen.").foregroundStyle(.secondary) }
                ForEach(liste) { zeile($0) }
            }
        case .favoriten:
            let liste = modell.favoriten(ich)
            Section {
                if liste.isEmpty { Text("Noch keine Favoriten.").foregroundStyle(.secondary) }
                ForEach(liste) { zeile($0) }
            }
        case .eigene:
            Section {
                Button("Neues Lebensmittel", systemImage: "plus") { eigenesZiel = .neu }
                ForEach(modell.eigene) { l in
                    zeile(l)
                        .swipeActions {
                            Button("Löschen", role: .destructive) { modell.eigenesLoeschen(l) }
                            Button("Bearbeiten") { eigenesZiel = .bearbeiten(l) }.tint(.blue)
                        }
                }
            }
        case .rezepte:
            Section {
                Button("Neues Rezept", systemImage: "plus") { rezeptNeuOffen = true }
                ForEach(modell.rezepte) { r in
                    zeile(ErnaehrungLogik.alsLebensmittel(r))
                        .swipeActions {
                            Button("Löschen", role: .destructive) { modell.rezeptLoeschen(r) }
                            Button("Bearbeiten") { rezeptBearbeiten = r }.tint(.blue)
                        }
                }
            }
        }
    }

    @ViewBuilder private var sucheInhalt: some View {
        let treffer = lokaleTreffer
        if !treffer.isEmpty {
            Section("Deine Lebensmittel") { ForEach(treffer) { zeile($0) } }
        }
        Section("Open Food Facts") {
            if suchLaedt {
                ProgressView()
            } else if suchFehler {
                Button("Keine Verbindung. Nochmal versuchen?") { Task { await suchen() } }
            } else if offTreffer.isEmpty {
                Text("Eingabetaste zum Suchen.").foregroundStyle(.secondary)
            } else {
                ForEach(offTreffer) { zeile($0) }
            }
        }
    }

    private var lokaleTreffer: [Lebensmittel] {
        let t = suchtext.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return [] }
        var gesehen: Set<String> = []
        return (modell.eigene + modell.zuletzt(ich))
            .filter { $0.name.localizedCaseInsensitiveContains(t) }
            .filter { gesehen.insert($0.id).inserted }
    }

    /// Name, Marke, kcal, rechts ein Plus zum Direkt-Eintragen. Tipp öffnet das Detail.
    private func zeile(_ l: Lebensmittel) -> some View {
        HStack(spacing: 8) {
            Button { pfad.append(l) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.name).foregroundStyle(.primary)
                    if let marke = l.marke { Text(marke).font(.caption).foregroundStyle(.secondary) }
                    Text(kcalText(l)).font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button { direktEintragen(l) } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(l.name) eintragen")
        }
    }

    private func kcalText(_ l: Lebensmittel) -> String {
        if let portion = l.portionMenge {
            let kcal = Int((l.pro100.kcal * portion / 100).rounded())
            return "\(kcal) kcal pro \(ErnaehrungLogik.einheitName(.portion, l))"
        }
        return "\(Int(l.pro100.kcal.rounded())) kcal pro 100 \(l.basisEinheit.rawValue)"
    }

    private func hinweisBanner(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color(uiColor: .secondarySystemBackground)))
            .shadow(radius: 4)
            .padding(.top, 8)
    }

    // MARK: - Aktionen

    private func direktEintragen(_ l: Lebensmittel) {
        let start = modell.letzteMenge(ich, l) ?? ErnaehrungLogik.startMenge(l)
        modell.eintragen(l, menge: start.menge, einheit: start.einheit, mahlzeit: mahlzeit, datum: datum)
        zeigeHinweis(l.name)
    }

    private func zeigeHinweis(_ name: String) {
        Haptik.erfolg()
        let text = "\(name) eingetragen"
        hinweis = text
        Task {
            try? await Task.sleep(for: .seconds(2))
            if hinweis == text { hinweis = nil }
        }
    }

    private func suchen() async {
        let t = suchtext.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        suchLaedt = true
        suchFehler = false
        do {
            offTreffer = try await OFFClient.suchen(t)
        } catch {
            suchFehler = true
        }
        suchLaedt = false
    }

    private func scannerZu() {
        guard let code = gescannt else { return }
        gescannt = nil
        barcodeGefunden(code)
    }

    private func vorgangZu() {
        guard let f = folge else { return }
        folge = nil
        switch f {
        case .nochmal(let code): barcodeSuchen(code)
        case .anlegen(let code): eigenesNeuBarcode = BarcodeVorlage(id: code)
        }
    }

    private func barcodeGefunden(_ code: String) {
        if let l = modell.offline(barcode: code) {
            pfad.append(l)
            return
        }
        barcodeSuchen(code)
    }

    private func barcodeSuchen(_ code: String) {
        barcodeLaedt = true
        Task {
            do {
                let l = try await OFFClient.produkt(code)
                barcodeLaedt = false
                if let l { pfad.append(l) } else { barcodeVorgang = .unbekannt(code) }
            } catch {
                barcodeLaedt = false
                barcodeVorgang = .fehler(code)
            }
        }
    }
}

private enum Segment: String, CaseIterable, Identifiable {
    case zuletzt, favoriten, eigene, rezepte

    var id: String { rawValue }
    var titel: String {
        switch self {
        case .zuletzt: "Zuletzt"
        case .favoriten: "Favoriten"
        case .eigene: "Eigene"
        case .rezepte: "Rezepte"
        }
    }
}

private enum EigenesBlattZiel: Identifiable {
    case neu
    case bearbeiten(Lebensmittel)

    var id: String {
        switch self {
        case .neu: "neu"
        case .bearbeiten(let l): l.id
        }
    }
}

private enum BarcodeFolge {
    case nochmal(String)
    case anlegen(String)
}

private struct BarcodeVorlage: Identifiable {
    let id: String
}

private enum BarcodeVorgang: Identifiable {
    case unbekannt(String)
    case fehler(String)

    var id: String {
        switch self {
        case .unbekannt(let code): "unbekannt-\(code)"
        case .fehler(let code): "fehler-\(code)"
        }
    }
}

/// Ladeanzeige, "Produkt nicht gefunden" oder "Keine Verbindung", je nach `vorgang`.
private struct BarcodeVorgangBlatt: View {
    let vorgang: BarcodeVorgang
    let nochmal: (String) -> Void
    let selbstAnlegen: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            switch vorgang {
            case .unbekannt(let code):
                Group {
                    ContentUnavailableView("Produkt nicht gefunden", systemImage: "barcode",
                                           description: Text("Barcode \(code)"))
                    Button("Selbst anlegen") { selbstAnlegen(code) }.buttonStyle(.borderedProminent)
                }
            case .fehler(let code):
                Group {
                    ContentUnavailableView("Keine Verbindung", systemImage: "wifi.slash")
                    Button("Nochmal versuchen") { nochmal(code) }.buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}

/// Name optional, kcal Pflicht, Rest optional. Trägt sofort als Portion "100 g" ein.
private struct SchnellEintragenBlatt: View {
    let mahlzeit: Mahlzeit
    let datum: String
    let fertig: (Lebensmittel) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var kohlenhydrate = ""
    @State private var fett = ""

    private var kannSichern: Bool { ErnaehrungLogik.eingabe(kcal) != nil }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (optional)", text: $name)
                zahlfeld("Kalorien (kcal)", $kcal)
                zahlfeld("Protein (g)", $protein)
                zahlfeld("Kohlenhydrate (g)", $kohlenhydrate)
                zahlfeld("Fett (g)", $fett)
            }
            .navigationTitle("Schnell eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Eintragen") { eintragen() }.disabled(!kannSichern) }
            }
        }
        .presentationDetents([.medium])
    }

    private func zahlfeld(_ titel: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(titel)
            Spacer()
            TextField("0", text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 100)
        }
    }

    private func eintragen() {
        guard let kcalWert = ErnaehrungLogik.eingabe(kcal) else { return }
        let werte = Naehrwerte(kcal: kcalWert, protein: ErnaehrungLogik.eingabe(protein) ?? 0,
                               kohlenhydrate: ErnaehrungLogik.eingabe(kohlenhydrate) ?? 0, fett: ErnaehrungLogik.eingabe(fett) ?? 0)
        let titel = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = Lebensmittel(id: "schnell-\(UUID().uuidString)", name: titel.isEmpty ? "Schnell eingetragen" : titel,
                             pro100: werte, portionMenge: 100, portionName: "Eintrag")
        ErnaehrungModell.shared.eintragen(l, menge: 1, einheit: .portion, mahlzeit: mahlzeit, datum: datum)
        dismiss()
        fertig(l)
    }
}
