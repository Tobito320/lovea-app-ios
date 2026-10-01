import SwiftUI

/// Hinzufügen-Blatt wie YAZIO: Kacheln (Suche/Kamera/Barcode/Sprache/Mehr), eigenes Suchfeld mit
/// Such-Modus, Typ/Sortierung, Barcode-Kette (lokal -> Server -> Open Food Facts -> Vorschläge) und
/// das Erstellen-Blatt. Bleibt nach dem Eintragen offen.
struct HinzufuegenBlatt: View {
    let datum: String
    @State private var mahlzeit: Mahlzeit
    @Environment(\.dismiss) private var dismiss

    @State private var typ: HinzuTyp = .lebensmittel
    @State private var sortierung: HinzuSortierung = .haeufig
    @State private var zaehler = 0
    @State private var suchtext = ""
    @State private var suche = SuchStand()
    @State private var suchAufgabe: Task<Void, Never>?
    @State private var suchModus = false
    @State private var chip: SuchChip?
    @State private var erstellenOffen = false
    @State private var kommtBald: String?
    @State private var vorschlaege: (name: String, liste: [Lebensmittel], code: String)?
    @State private var fotoBarcode: BarcodeVorlage?
    @State private var serverFehlt = false
    @State private var geradeEingetragen: Set<String> = []

    @State private var pfad: [Lebensmittel] = []
    @State private var hinweis: String?
    @State private var barcodeOffen = false
    @State private var schnellOffen = false
    @State private var eigenesNeuOffen = false
    @State private var eigenesBearbeiten: Lebensmittel?
    @State private var rezeptNeuOffen = false
    @State private var rezeptBearbeiten: Rezept?
    @State private var rezeptArt: RezeptArt = .rezept
    /// Einmal pro Erscheinen berechnet statt pro Tastendruck (Favoriten/Häufig/Eigene/Rezepte ändern
    /// sich während des Tippens nicht).
    @State private var suchVorne: [Lebensmittel] = []
    /// Welcher Scan-Zweck gerade läuft: normale Suche (Barcode-Kette) oder "Neues Lebensmittel mit
    /// Barcode" aus dem Erstellen-Blatt (direkt zu `NaehrwertFotoBlatt`, ohne Kette).
    @State private var scanZweck: ScanZweck = .suchen
    @State private var gescannt: String?
    @State private var barcodeLaedt = false

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }
    private var ich: Person { modell.ich }

    /// `scannen`: öffnet sofort die Kamera (Barcode-Knopf im Tagebuch).
    private let sofortScannen: Bool
    @State private var sofortErledigt = false

    init(mahlzeit: Mahlzeit, datum: String, scannen: Bool = false) {
        self.datum = datum
        self.sofortScannen = scannen
        _mahlzeit = State(initialValue: mahlzeit)
    }

    var body: some View {
        NavigationStack(path: $pfad) {
            VStack(spacing: 0) {
                if suchModus {
                    SuchKopf(text: $suchtext, abbrechen: suchBeenden)
                    SuchChips(auswahl: $chip, partner: ich.partner)
                } else {
                    HinzuKopf(titel: modell.mahlzeitName(mahlzeit), zaehler: zaehler, schliessen: { dismiss() })
                    KachelReihe(aktiv: .suche, tippen: kachel)
                    SuchFeldKnopf(platzhalter: "Was hattest du zum \(modell.mahlzeitName(mahlzeit))?") { suchModus = true }
                    HStack(spacing: 10) {
                        AuswahlKnopf(wert: $typ)
                        AuswahlKnopf(wert: $sortierung)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                ScrollView {
                    LazyVStack(spacing: suchModus ? 12 : 0) { inhalt }
                        .padding(.horizontal, suchModus ? 16 : 0)
                        .padding(.top, suchModus ? 12 : 0)
                    if suchModus, serverFehlt {
                        Text("Markenprodukte gerade nicht erreichbar")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { if !suchModus { FertigKnopf { dismiss() } } }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Lebensmittel.self) { l in
                LebensmittelDetailView(lebensmittel: l, mahlzeit: mahlzeit, datum: datum) {
                    zeigeHinweis(l.name)
                    if !pfad.isEmpty { pfad.removeLast() }
                }
            }
            .overlay(alignment: .top) { if let hinweis { hinweisBanner(hinweis) } }
            .overlay {
                if barcodeLaedt {
                    ProgressView("Suche Produkt…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .animation(Feder.weich, value: hinweis)
        }
        .fontDesign(.rounded)
        .onAppear {
            suchVorne = modell.favoriten(ich) + modell.haeufig(ich) + modell.eigene + modell.rezepte.map(ErnaehrungLogik.alsLebensmittel)
            if sofortScannen, !sofortErledigt {
                sofortErledigt = true
                scanZweck = .suchen
                barcodeOffen = true
            }
            guard !modell.offeneBarcodes.isEmpty else { return }
            Task {
                for l in await modell.nachholen() { zeigeHinweis(l.name) }
            }
        }
        .onChange(of: suchtext) { _, neu in suchtextGeaendert(neu) }
        .sheet(isPresented: $barcodeOffen, onDismiss: scannerZu) {
            BarcodeScannerBlatt { code in gescannt = code }
        }
        .sheet(isPresented: $schnellOffen) {
            SchnellEintragenBlatt(mahlzeit: mahlzeit, datum: datum) { l in
                schnellOffen = false
                zeigeHinweis(l.name)
            }
        }
        .sheet(isPresented: $eigenesNeuOffen) {
            EigenesLebensmittelEditor()
        }
        .sheet(item: $eigenesBearbeiten) { l in
            EigenesLebensmittelEditor(start: l)
        }
        .sheet(isPresented: $rezeptNeuOffen) {
            RezeptEditor(art: rezeptArt)
        }
        .sheet(item: $rezeptBearbeiten) { r in
            RezeptEditor(start: r)
        }
        .sheet(isPresented: $erstellenOffen) {
            ErstellenBlatt(tippen: erstellenGewaehlt)
        }
        .sheet(isPresented: Binding(get: { kommtBald != nil }, set: { if !$0 { kommtBald = nil } })) {
            KommtBaldBlatt(titel: kommtBald ?? "")
        }
        .sheet(isPresented: Binding(get: { vorschlaege != nil }, set: { if !$0 { vorschlaege = nil } })) {
            if let v = vorschlaege {
                VorschlaegeBlatt(name: v.name, treffer: v.liste,
                                 auswahl: { l in vorschlaegeAuswahl(l, code: v.code) },
                                 keinesDavon: { fotoBarcode = BarcodeVorlage(id: v.code); vorschlaege = nil })
            }
        }
        .sheet(item: $fotoBarcode) { vorlage in
            NaehrwertFotoBlatt(barcode: vorlage.id) { l in pfad.append(l) }
        }
    }

    // MARK: - Inhalt

    @ViewBuilder private var inhalt: some View {
        if suchModus {
            ForEach(suchKarten) { l in
                SuchKarte(lebensmittel: l, typLabel: typLabel(l),
                          plus: { direktEintragenUndMarkieren(l) },
                          tippen: { pfad.append(l) },
                          kannKopieren: ersteller(l) == ich.partner,
                          kopieren: { kopieren(l) },
                          istFavorit: modell.istFavorit(l),
                          favoritUmschalten: { modell.favoritSetzen(l, an: !modell.istFavorit(l)) },
                          istEigen: ersteller(l) == ich,
                          bearbeiten: { bearbeitenOeffnen(l) },
                          loeschen: { loeschen(l) })
            }
        } else {
            ForEach(listeInhalt) { l in
                HinzuZeile(lebensmittel: l, eingetragen: geradeEingetragen.contains(l.id),
                           tippen: { pfad.append(l) }, plus: { direktEintragenUndMarkieren(l) },
                           istEigen: ersteller(l) == ich,
                           bearbeiten: { bearbeitenOeffnen(l) },
                           loeschen: { loeschen(l) })
            }
        }
    }

    /// Lebensmittel: Häufig/Zuletzt/Favoriten direkt. Mahlzeiten/Rezepte: dieselben Listen, nur auf
    /// `rezept-`-IDs gefiltert, Rest alphabetisch hinten.
    private var listeInhalt: [Lebensmittel] {
        switch typ {
        case .lebensmittel:
            switch sortierung {
            case .haeufig: return modell.haeufig(ich)
            case .zuletzt: return modell.zuletzt(ich)
            case .favoriten: return modell.favoriten(ich).filter { !$0.istRezept }
            }
        case .mahlzeiten, .rezepte:
            let art: RezeptArt = typ == .mahlzeiten ? .mahlzeit : .rezept
            let alle = modell.rezepte(von: ich, art: art).map(ErnaehrungLogik.alsLebensmittel)
            switch sortierung {
            case .favoriten:
                let favoritIds = Set(modell.favoriten(ich).filter(\.istRezept).map(\.id))
                return alle.filter { favoritIds.contains($0.id) }
            case .haeufig, .zuletzt:
                let ids = Set(alle.map(\.id))
                let basis = sortierung == .haeufig ? modell.haeufig(ich) : modell.zuletzt(ich)
                let erst = basis.filter { ids.contains($0.id) }
                let erstIds = Set(erst.map(\.id))
                let rest = alle.filter { !erstIds.contains($0.id) }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                return erst + rest
            }
        }
    }

    /// Chip gewählt: filtert die Suchtreffer, bei leerer Suche zeigt er direkt die passende Grundliste.
    private var suchKarten: [Lebensmittel] {
        guard let chip else { return suche.sichtbar }
        let basis: [Lebensmittel]
        switch chip {
        case .favoriten: basis = modell.favoriten(ich)
        case .vonMir: basis = modell.eigene(von: ich) + modell.rezepte(von: ich, art: nil).map(ErnaehrungLogik.alsLebensmittel)
        case .vonPartner: basis = modell.eigene(von: ich.partner) + modell.rezepte(von: ich.partner, art: nil).map(ErnaehrungLogik.alsLebensmittel)
        }
        guard !suche.sichtbar.isEmpty else { return basis }
        let ids = Set(suche.sichtbar.map(\.id))
        return basis.filter { ids.contains($0.id) }
    }

    private func typLabel(_ l: Lebensmittel) -> String {
        guard l.id.hasPrefix("rezept-") else { return "Lebensmittel" }
        let id = String(l.id.dropFirst("rezept-".count))
        return modell.rezepte.first { $0.id == id }?.istMahlzeit == true ? "Mahlzeit" : "Rezept"
    }

    private func ersteller(_ l: Lebensmittel) -> Person? {
        if l.id.hasPrefix("rezept-"), let r = modell.rezepte.first(where: { $0.id == String(l.id.dropFirst("rezept-".count)) }) {
            return modell.ersteller(r)
        }
        return modell.ersteller(l)
    }

    private func kopieren(_ l: Lebensmittel) {
        if l.id.hasPrefix("rezept-"), let r = modell.rezepte.first(where: { $0.id == String(l.id.dropFirst("rezept-".count)) }) {
            modell.kopieren(r)
        } else {
            modell.kopieren(l)
        }
    }

    /// Eigenes Lebensmittel oder Rezept: öffnet den passenden Editor mit `start:` vorausgefüllt.
    private func bearbeitenOeffnen(_ l: Lebensmittel) {
        if l.id.hasPrefix("rezept-"), let r = modell.rezepte.first(where: { $0.id == String(l.id.dropFirst("rezept-".count)) }) {
            rezeptBearbeiten = r
        } else {
            eigenesBearbeiten = l
        }
    }

    private func loeschen(_ l: Lebensmittel) {
        if l.id.hasPrefix("rezept-"), let r = modell.rezepte.first(where: { $0.id == String(l.id.dropFirst("rezept-".count)) }) {
            modell.rezeptLoeschen(r)
        } else {
            modell.eigenesLoeschen(l)
        }
    }

    private func hinweisBanner(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color(uiColor: .secondarySystemBackground)))
            .shadow(radius: 4)
            .padding(.top, 8)
    }

    // MARK: - Kacheln und Erstellen

    private func kachel(_ k: HinzuKachel) {
        switch k {
        case .suche: suchModus = true
        case .kamera: kommtBald = "KI-Kalorien-Tracking"
        case .barcode: scanZweck = .suchen; barcodeOffen = true
        case .sprache: kommtBald = "Sprache und Text"
        case .mehr: erstellenOffen = true
        }
    }

    private func erstellenGewaehlt(_ e: ErstellenEintrag) {
        switch e {
        case .schnell: schnellOffen = true
        case .mitBarcode: scanZweck = .erstellen; barcodeOffen = true
        case .ohneBarcode: eigenesNeuOffen = true
        case .mahlzeit: rezeptArt = .mahlzeit; rezeptNeuOffen = true
        case .rezept: rezeptArt = .rezept; rezeptNeuOffen = true
        }
    }

    // MARK: - Suche

    /// Lokale Suche läuft synchron (unter 16 ms laut Task 3), die Server-Suche folgt mit 150 ms
    /// Debounce und wird verworfen, wenn seither erneut getippt wurde. Eine Barcode-Zahl läuft durch
    /// dieselbe Debounce+Abbruch-Kette, damit Tippen/Einfügen keinen Treffer pro Tastendruck auslöst.
    private func suchtextGeaendert(_ neu: String) {
        suchAufgabe?.cancel()
        serverFehlt = false
        suche.nummer += 1
        let nummer = suche.nummer
        let t = neu.trimmingCharacters(in: .whitespaces)
        if BarcodeLogik.istBarcodeEingabe(t) {
            suche.sichtbar = []
            scanZweck = .suchen
            suchAufgabe = Task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled, nummer == suche.nummer else { return }
                await barcodeSuchen(t, nummer: nummer)
            }
            return
        }
        suche.lokal = LebensmittelIndex.shared.suchen(t, vorne: suchVorne)
        suche.sichtbar = suche.lokal
        guard t.count >= 2 else { return }
        suchAufgabe = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            do {
                let antwort = try await EssenServer.suchen(t)
                guard !Task.isCancelled, nummer == suche.nummer else { return }
                serverFehlt = false
                suche = SuchZusammenfuehrung.server(suche, antwort: antwort, nummer: nummer)
            } catch {
                if !Task.isCancelled, nummer == suche.nummer { serverFehlt = true }
            }
        }
    }

    private func suchBeenden() {
        suchAufgabe?.cancel()
        suchModus = false
        suchtext = ""
        chip = nil
        suche = SuchStand()
        serverFehlt = false
    }

    // MARK: - Aktionen

    private func direktEintragen(_ l: Lebensmittel) {
        let start = modell.letzteMenge(ich, l) ?? ErnaehrungLogik.startMenge(l)
        modell.eintragen(l, menge: start.menge, einheit: start.einheit, mahlzeit: mahlzeit, datum: datum)
        zeigeHinweis(l.name)
    }

    /// Direkt eintragen plus Zähler hoch und Plus wird 1 s lang zum Häkchen.
    private func direktEintragenUndMarkieren(_ l: Lebensmittel) {
        direktEintragen(l)
        zaehler += 1
        geradeEingetragen.insert(l.id)
        Task {
            try? await Task.sleep(for: .seconds(1))
            geradeEingetragen.remove(l.id)
        }
    }

    private func zeigeText(_ text: String) {
        hinweis = text
        Task {
            try? await Task.sleep(for: .seconds(2))
            if hinweis == text { hinweis = nil }
        }
    }

    private func zeigeHinweis(_ name: String) {
        Haptik.erfolg()
        zeigeText("\(name) eingetragen")
    }

    private func scannerZu() {
        guard let code = gescannt else { return }
        gescannt = nil
        if scanZweck == .erstellen {
            fotoBarcode = BarcodeVorlage(id: BarcodeLogik.normal(code))
        } else {
            Task { await barcodeSuchen(code) }
        }
    }

    /// Lokal -> Server -> Open Food Facts live -> Namens-Vorschläge -> unbekannt (Task 6).
    /// `nummer`: aus dem Suchfeld gesetzt; ist seither erneut getippt worden, wird das Ergebnis
    /// verworfen (kein `pfad.append`/Sheet aus einer überholten Eingabe).
    private func barcodeSuchen(_ code: String, nummer: Int? = nil) async {
        barcodeLaedt = true
        let ergebnis = await BarcodeKette.suchen(code, .echt)
        barcodeLaedt = false
        if let nummer, nummer != suche.nummer { return }
        switch ergebnis {
        case .gefunden(let l): pfad.append(l)
        case .vorschlaege(let name, let liste): vorschlaege = (name, liste, BarcodeLogik.normal(code))
        case .unbekannt(let c): fotoBarcode = BarcodeVorlage(id: c)
        case .offline(let c):
            modell.merken(c)
            zeigeText("Kein Netz. Barcode gemerkt, wir suchen, sobald du online bist.")
        }
    }

    private func vorschlaegeAuswahl(_ l: Lebensmittel, code: String) {
        vorschlaege = nil
        var k = l
        k.id = "eigen-\(UUID().uuidString)"
        k.barcode = code
        modell.eigenesSichern(k)
        pfad.append(k)
    }
}

// Kein Associated Value, Swift synthetisiert `Equatable` hier schon automatisch – `Equatable`
// trotzdem explizit, damit `scanZweck == .erstellen` unten als Absicht erkennbar ist.
private enum ScanZweck: Equatable { case suchen, erstellen }

private struct BarcodeVorlage: Identifiable {
    let id: String
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
