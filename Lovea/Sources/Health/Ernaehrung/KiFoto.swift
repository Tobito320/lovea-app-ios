import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

/// Reine Logik hinter "Essen fotografieren": Tagebuch-Einträge aus der Schätzung, Fehlertexte,
/// Bereich, Rückfrage. Ohne Views und ohne Singletons, damit die Tests nie das echte Tagebuch berühren.
enum KiFotoLogik {
    static let maxGramm = 5000.0

    /// Was der Fehlerbildschirm zeigt und anbietet.
    struct Anzeige: Equatable {
        let titel: String
        let text: String
        let symbol: String
        /// Dasselbe Foto noch einmal schicken (Netz, Auslastung, kaputte Antwort).
        let nochmal: Bool
        /// Ein neues Foto machen hilft (Foto unlesbar oder zu groß).
        let neuesFoto: Bool
    }

    static let fotoUnlesbar = Anzeige(titel: "Foto nicht lesbar", text: "Mach bitte ein neues Foto.",
                                      symbol: "photo.badge.exclamationmark", nochmal: false, neuesFoto: true)

    static func anzeige(_ f: KiFehler) -> Anzeige {
        switch f {
        case .netz:
            Anzeige(titel: "Keine Verbindung", text: "Prüf dein Netz und versuch es nochmal.",
                    symbol: "wifi.slash", nochmal: true, neuesFoto: false)
        case .zuVieleAnfragen:
            Anzeige(titel: "Gerade viel los", text: "Versuch es in einem Moment nochmal.",
                    symbol: "hourglass", nochmal: true, neuesFoto: false)
        case .ungueltig, .unbekannt:
            Anzeige(titel: "Das hat nicht geklappt", text: "Versuch es nochmal oder mach ein neues Foto.",
                    symbol: "exclamationmark.triangle", nochmal: true, neuesFoto: true)
        case .bildZuGross:
            Anzeige(titel: "Foto zu groß", text: "Mach bitte ein neues Foto.",
                    symbol: "photo.badge.exclamationmark", nochmal: false, neuesFoto: true)
        case .tageslimit:
            Anzeige(titel: "Foto-Limit erreicht", text: f.errorDescription ?? "Morgen geht es weiter.",
                    symbol: "moon.zzz", nochmal: false, neuesFoto: false)
        case .guthaben, .nichtEingerichtet:
            Anzeige(titel: "KI gerade nicht erreichbar", text: "Trag die Mahlzeit solange von Hand ein.",
                    symbol: "bolt.slash", nochmal: false, neuesFoto: false)
        }
    }

    /// Auf dem Foto ist nichts zu essen, oder die KI hat nichts erkannt.
    static func keinEssen(_ a: EssenAnalyse) -> Bool { !a.istEssen || a.items.isEmpty }

    static func keinEssenText(_ a: EssenAnalyse) -> String {
        let t = a.bemerkung.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Auf dem Foto ist kein Essen zu erkennen." : t
    }

    /// Ein Tagebuch-Eintrag je Zutat (in g) und je unsichtbarer Zutat. Die Zahl auf dem Knopf ist
    /// `kcal(eintraege)`, also genau das, was danach im Tagebuch steht.
    static func eintraege(komponenten: [EssenKomponente], versteckt: [EssenVersteckt], versteckteZaehlen: Bool,
                          mahlzeit: Mahlzeit, datum: String) -> [EssenEintrag] {
        func eintrag(_ name: String, gramm: Double, pro100: Naehrwerte) -> EssenEintrag {
            let l = Lebensmittel(id: "ki-\(UUID().uuidString)", name: name, marke: "KI-Schätzung", pro100: pro100)
            return EssenEintrag(id: UUID().uuidString, datum: datum, mahlzeit: mahlzeit, menge: gramm, einheit: .g,
                                lebensmittel: l, geloescht: nil)
        }
        let zutaten = komponenten.filter { $0.gramm > 0 }.map {
            eintrag($0.name, gramm: min($0.gramm, maxGramm),
                    pro100: Naehrwerte(kcal: $0.kcalPro100, protein: $0.proteinPro100,
                                       kohlenhydrate: $0.kohlenhydratePro100, fett: $0.fettPro100))
        }
        guard versteckteZaehlen else { return zutaten }
        // Unsichtbares ist meist Öl oder Butter, also als Fett rechnen (9 kcal pro g), wie `EssenMahlzeit`.
        let unsichtbar = versteckt.filter { $0.kcal > 0 }.map { v in
            let g = v.gramm > 0 ? v.gramm : 100
            let kcalProG = Double(v.kcal) / g
            return eintrag("\(v.name) (nicht sichtbar)", gramm: g,
                           pro100: Naehrwerte(kcal: kcalProG * 100, fett: kcalProG / 9 * 100))
        }
        return zutaten + unsichtbar
    }

    static func kcal(_ liste: [EssenEintrag]) -> Int { Int(ErnaehrungLogik.summe(liste).kcal.rounded()) }

    /// Name für die Bestätigung: die ersten zwei Zutaten.
    static func titel(_ komponenten: [EssenKomponente]) -> String {
        let namen = komponenten.prefix(2).map(\.name).joined(separator: ", ")
        if namen.isEmpty { return "Foto-Mahlzeit" }
        return komponenten.count > 2 ? namen + " …" : namen
    }

    /// "wahrscheinlich zwischen X und Y": nur sinnvoll, solange niemand Gramm geändert oder Zutaten entfernt hat.
    /// Der Server rechnet `kcal_min` nur aus den Zutaten, `kcal_max` aber schon mit den versteckten Kalorien.
    static func bereich(_ g: EssenAnalyse.Gesamt, versteckteKcal v: Int, gezaehlt: Bool) -> ClosedRange<Int>? {
        guard g.kcalMin > 0 else { return nil }
        let unten = g.kcalMin + (gezaehlt ? v : 0)
        let oben = gezaehlt ? g.kcalMax : g.kcalMax - v
        guard oben > unten else { return nil }
        return unten...oben
    }

    /// Wie sicher die KI bei einer Zutat ist, als Wort, nicht nur als Farbe.
    static func sicherheit(_ s: String) -> (text: String, symbol: String) {
        switch s {
        case "hoch": ("sicher", "checkmark.circle.fill")
        case "niedrig": ("unsicher", "questionmark.circle.fill")
        default: ("ungefähr", "circle.lefthalf.filled")
        }
    }

    /// Gramm, die der Nutzer gegenüber der Schätzung geändert hat, für `KiClient.korrigieren`.
    static func korrekturen(_ komponenten: [EssenKomponente], urspruenglich: [UUID: Double], entfernt: Set<UUID>) -> [KiKorrektur] {
        komponenten.compactMap { k in
            guard !entfernt.contains(k.id), k.gramm > 0, let alt = urspruenglich[k.id], abs(k.gramm - alt) >= 1 else { return nil }
            return KiKorrektur(name: k.name, gramm: k.gramm)
        }
    }

    /// Der Server liest höchstens 300 Zeichen. Bei Überlänge bleibt das Ende, also die Antwort.
    static func hinweis(frage: String, antwort: String) -> String {
        String("Frage: \(frage) Antwort: \(antwort.trimmingCharacters(in: .whitespacesAndNewlines))".suffix(300))
    }

    /// Erst kurz vor Schluss sagen, wie viele Fotos heute noch gehen.
    static func restText(_ rest: Int?) -> String? {
        guard let rest, rest <= 5 else { return nil }
        switch rest {
        case ..<1: return "Das war dein letztes Foto für heute."
        case 1: return "Noch 1 Foto für heute."
        default: return "Noch \(rest) Fotos für heute."
        }
    }
}

/// Kamera -> KI-Schätzung -> prüfen und anpassen -> ins Tagebuch (`ErnaehrungModell`). Die Kamera geht
/// sofort auf, Abbrechen führt zurück ins Hinzufügen. Nichts wird eingetragen, bevor der Nutzer es bestätigt.
struct KiFotoBlatt: View {
    let datum: String
    /// Name der Mahlzeit für die Bestätigung im Hinzufügen-Blatt.
    let fertig: (String) -> Void
    let vonHand: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: Equatable {
        case start, laedt, ergebnis
        case keinEssen(String)
        case fehler(KiFotoLogik.Anzeige)
    }

    @State private var phase: Phase = .start
    @State private var kameraOffen: Bool
    /// Die erste Kamera geht von selbst auf; bricht man sie ab, ist man schon fertig.
    @State private var autoKamera: Bool
    @State private var gesperrt = KiFotoBlatt.kameraGesperrt
    @State private var auswahl: PhotosPickerItem?
    @State private var aufgabe: Task<Void, Never>?
    @State private var bildDaten: Data?
    @State private var vorschau: UIImage?
    @State private var analyse: EssenAnalyse?
    @State private var komponenten: [EssenKomponente] = []
    @State private var urspruenglich: [UUID: Double] = [:]
    @State private var entfernt: Set<UUID> = []
    @State private var versteckt: [EssenVersteckt] = []
    @State private var versteckteZaehlen = true
    @State private var mahlzeitWahl: Mahlzeit
    @State private var antwort = ""
    @State private var hinweisText = ""
    @State private var neuFehler: String?
    @State private var verwerfenFrage = false
    @State private var speichert = false

    init(mahlzeit: Mahlzeit, datum: String, fertig: @escaping (String) -> Void, vonHand: @escaping () -> Void) {
        self.datum = datum
        self.fertig = fertig
        self.vonHand = vonHand
        _mahlzeitWahl = State(initialValue: mahlzeit)
        _kameraOffen = State(initialValue: false)
        _autoKamera = State(initialValue: Self.kameraVorhanden && !Self.kameraGesperrt)
    }

    private static var kameraVorhanden: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    private static var kameraGesperrt: Bool {
        let s = AVCaptureDevice.authorizationStatus(for: .video)
        return s == .denied || s == .restricted
    }

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }
    private var anim: Animation? { reduceMotion ? nil : Feder.weich }

    private var aktive: [EssenKomponente] { komponenten.filter { !entfernt.contains($0.id) } }
    private var versteckteKcal: Int { versteckt.reduce(0) { $0 + $1.kcal } }
    private var liste: [EssenEintrag] {
        KiFotoLogik.eintraege(komponenten: aktive, versteckt: versteckt, versteckteZaehlen: versteckteZaehlen,
                              mahlzeit: mahlzeitWahl, datum: datum)
    }
    /// Unverändert gegenüber der Schätzung: dann gilt der Bereich der KI noch.
    private var unveraendert: Bool {
        entfernt.isEmpty && komponenten.allSatisfy { k in urspruenglich[k.id].map { abs($0 - k.gramm) < 1 } ?? false }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .start: startAnsicht.transition(.opacity)
                case .laedt: ladeAnsicht.transition(.opacity)
                case .ergebnis: ergebnisAnsicht.transition(.opacity)
                case .keinEssen(let text):
                    meldung("fork.knife", "Kein Essen erkannt", text) {
                        Button("Anderes Foto") { neuesFoto() }.buttonStyle(.borderedProminent)
                        Button("Von Hand eintragen") { vonHand() }.buttonStyle(.bordered)
                    }.transition(.opacity)
                case .fehler(let a):
                    meldung(a.symbol, a.titel, a.text) {
                        if a.nochmal { Button("Nochmal versuchen") { nochmal() }.buttonStyle(.borderedProminent) }
                        if a.neuesFoto {
                            if a.nochmal {
                                Button("Anderes Foto") { neuesFoto() }.buttonStyle(.bordered)
                            } else {
                                Button("Anderes Foto") { neuesFoto() }.buttonStyle(.borderedProminent)
                            }
                        }
                        Button("Von Hand eintragen") { vonHand() }.buttonStyle(.bordered)
                    }.transition(.opacity)
                }
            }
            .animation(anim, value: phase)
            .navigationTitle("Essen fotografieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
            }
        }
        .fontDesign(.rounded)
        .interactiveDismissDisabled(phase == .ergebnis)
        .confirmationDialog("Schätzung verwerfen?", isPresented: $verwerfenFrage, titleVisibility: .visible) {
            Button("Verwerfen", role: .destructive) { dismiss() }
            Button("Weiter prüfen", role: .cancel) {}
        } message: {
            Text("Das Foto zählt schon für heute.")
        }
        .fullScreenCover(isPresented: $kameraOffen) {
            NaehrwertKamera(aufgenommen: kameraFertig).ignoresSafeArea()
        }
        .task {
            // Erst nach dem Aufklappen des Blatts: ein Cover im selben Frame wird von SwiftUI manchmal verschluckt.
            guard autoKamera else { return }
            try? await Task.sleep(for: .milliseconds(350))
            if autoKamera, !Task.isCancelled { kameraOffen = true }
        }
        .onChange(of: auswahl) { _, neu in fotoGewaehlt(neu) }
        .onChange(of: scenePhase) { _, neu in if neu == .active { gesperrt = Self.kameraGesperrt } }
        .onDisappear { aufgabe?.cancel() }
    }

    // MARK: - Bildschirme

    private var startAnsicht: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(spacing: 6) {
                    Text(gesperrt ? "Kein Kamerazugriff" : "Foto vom Essen").font(.title2.bold())
                    Text(gesperrt
                         ? "Lovea darf die Kamera nicht nutzen. Du kannst es in den Einstellungen erlauben oder ein Foto aus deiner Bibliothek wählen."
                         : "Fotografier dein Essen von oben. Die KI schätzt Zutaten und Kalorien, du prüfst und passt an.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 12) {
                    if gesperrt {
                        Button { einstellungenOeffnen() } label: { Text("Einstellungen öffnen").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                    } else if Self.kameraVorhanden {
                        Button { kameraOffen = true } label: { Label("Foto aufnehmen", systemImage: "camera.fill").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                    }
                    PhotosPicker(selection: $auswahl, matching: .images) {
                        Label("Aus Fotos wählen", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    Button("Von Hand eintragen") { vonHand() }
                }
                Text("Das Foto wird verkleinert und ohne Ort und Zeit an deinen Lovea-Server geschickt. Gespeichert wird nur auf diesem Gerät.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }

    private var ladeAnsicht: some View {
        VStack(spacing: 20) {
            Spacer()
            if let vorschau {
                Image(uiImage: vorschau)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityHidden(true)
            }
            ProgressView().controlSize(.large).accessibilityLabel("Kalorien werden geschätzt")
            Text("Ich schätze die Kalorien …").font(.headline)
            Button("Abbrechen") { ladenAbbrechen() }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private func meldung<Knoepfe: View>(_ symbol: String, _ titel: String, _ text: String,
                                        @ViewBuilder knoepfe: () -> Knoepfe) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: symbol).font(.system(size: 48)).foregroundStyle(.secondary).accessibilityHidden(true)
            Text(titel).font(.title2.bold())
            Text(text).foregroundStyle(.secondary).multilineTextAlignment(.center)
            VStack(spacing: 10) { knoepfe() }.controlSize(.large).padding(.top, 8)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var ergebnisAnsicht: some View {
        let eintraege = liste
        let gesamt = KiFotoLogik.kcal(eintraege)
        return List {
            Section {
                kopf(summe: ErnaehrungLogik.summe(eintraege), kcal: gesamt)
            }
            Section("Erkannt") {
                ForEach(komponenten.indices.filter { !entfernt.contains(komponenten[$0].id) }, id: \.self) { zeile($0) }
                if aktive.isEmpty {
                    Text("Alles entfernt. Hol unten etwas zurück oder brich ab.").foregroundStyle(.secondary)
                }
            }
            if !entfernt.isEmpty {
                Section("Entfernt") {
                    ForEach(komponenten.filter { entfernt.contains($0.id) }) { k in
                        HStack {
                            Text(k.name).foregroundStyle(.secondary)
                            Spacer()
                            Button("Zurück") { zurueckholen(k.id) }.buttonStyle(.borderless)
                        }
                    }
                }
            }
            if !versteckt.isEmpty {
                Section {
                    Toggle(isOn: $versteckteZaehlen) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nicht Sichtbares mitzählen")
                            Text(versteckt.map { "\($0.name) \(ErnaehrungLogik.zahl($0.gramm)) g" }.joined(separator: ", ")
                                 + " · \(versteckteKcal) kcal")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Öl, Butter oder Soße sieht man auf dem Foto nicht. Schalte aus, wenn bei dir nichts davon drin ist.")
                }
            }
            if let frage = analyse?.frage, !frage.isEmpty { frageAbschnitt(frage) }
            Section {
                Picker("Eintragen bei", selection: $mahlzeitWahl) {
                    ForEach(Mahlzeit.allCases) { Text(modell.mahlzeitName($0)).tag($0) }
                }
            } footer: {
                if let rest = KiFotoLogik.restText(analyse?.rest) { Text(rest) }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .tastaturFertig()
        .safeAreaInset(edge: .bottom) {
            Button { eintragen() } label: {
                Text(eintraege.isEmpty ? "Nichts zum Eintragen" : "\(ErnaehrungLogik.zahl(Double(gesamt))) kcal eintragen")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(eintraege.isEmpty || speichert)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.bar)
        }
    }

    private func kopf(summe: Naehrwerte, kcal: Int) -> some View {
        VStack(spacing: 8) {
            if let vorschau {
                Image(uiImage: vorschau)
                    .resizable().scaledToFill()
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
            }
            Text("ca. \(ErnaehrungLogik.zahl(Double(kcal))) kcal")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .contentTransition(.numericText())
                .animation(anim, value: kcal)
            if unveraendert, let a = analyse,
               let b = KiFotoLogik.bereich(a.gesamt, versteckteKcal: versteckteKcal, gezaehlt: versteckteZaehlen) {
                Text("wahrscheinlich zwischen \(b.lowerBound) und \(b.upperBound)")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Text("Eiweiß \(ErnaehrungLogik.zahl(summe.protein)) g · Kohlenhydrate \(ErnaehrungLogik.zahl(summe.kohlenhydrate)) g · Fett \(ErnaehrungLogik.zahl(summe.fett)) g")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let b = analyse?.bemerkung, !b.isEmpty {
                Text(b).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func zeile(_ i: Int) -> some View {
        let k = komponenten[i]
        let s = KiFotoLogik.sicherheit(k.sicherheit)
        let farbe: Color = k.sicherheit == "hoch" ? .green : k.sicherheit == "niedrig" ? .orange : .secondary
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(k.name).font(.headline)
                Spacer(minLength: 8)
                Text("\(k.kcal) kcal").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    Label(s.text, systemImage: s.symbol).font(.caption).foregroundStyle(farbe)
                    Spacer()
                    grammEingabe(i)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label(s.text, systemImage: s.symbol).font(.caption).foregroundStyle(farbe)
                    grammEingabe(i)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { entfernen(k.id) } label: { Label("Entfernen", systemImage: "trash") }
        }
        .accessibilityAction(named: "Entfernen") { entfernen(k.id) }
    }

    private func grammEingabe(_ i: Int) -> some View {
        HStack(spacing: 8) {
            GrammFeld(gramm: $komponenten[i].gramm)
            Text("g").foregroundStyle(.secondary)
            Stepper("Gramm \(komponenten[i].name)", value: $komponenten[i].gramm, in: 0...KiFotoLogik.maxGramm, step: 5)
                .labelsHidden()
        }
    }

    private func frageAbschnitt(_ frage: String) -> some View {
        Section {
            Text(frage)
            TextField("Deine Antwort", text: $antwort).submitLabel(.done)
            Button("Neu schätzen") { neuSchaetzen(frage: frage) }
                .disabled(antwort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if let neuFehler { Text(neuFehler).font(.footnote).foregroundStyle(.red) }
        } header: {
            Label("Rückfrage der KI", systemImage: "questionmark.bubble")
        } footer: {
            Text("Zählt als weiteres Foto. Deine Änderungen an den Gramm gehen dabei verloren.")
        }
    }

    // MARK: - Ablauf

    private func schliessen() {
        if phase == .ergebnis {
            verwerfenFrage = true
        } else {
            aufgabe?.cancel()
            dismiss()
        }
    }

    private func einstellungenOeffnen() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    private func kameraFertig(_ bild: UIImage?) {
        kameraOffen = false
        gesperrt = Self.kameraGesperrt
        let auto = autoKamera
        autoKamera = false
        guard let bild, let daten = bild.jpegData(compressionQuality: 0.9) else {
            // Erste Kamera abgebrochen: zurück ins Hinzufügen. Gesperrt: die Erklärung zeigen.
            if auto, !gesperrt { dismiss() }
            return
        }
        phase = .laedt
        aufgabe = Task { await verarbeiten(daten) }
    }

    private func fotoGewaehlt(_ item: PhotosPickerItem?) {
        guard let item else { return }
        auswahl = nil
        phase = .laedt
        aufgabe = Task {
            guard let daten = try? await item.loadTransferable(type: Data.self) else {
                guard !Task.isCancelled else { return }
                Haptik.warnung()
                phase = .fehler(KiFotoLogik.fotoUnlesbar)
                return
            }
            await verarbeiten(daten)
        }
    }

    /// Verkleinern (Dateigröße, kein Ort und keine Zeit) abseits des Hauptthreads, dann schätzen.
    private func verarbeiten(_ roh: Data) async {
        let klein = await Task.detached(priority: .userInitiated) { EssenBild.verkleinern(roh) }.value
        guard !Task.isCancelled else { return }
        guard let klein else {
            Haptik.warnung()
            phase = .fehler(KiFotoLogik.fotoUnlesbar)
            return
        }
        bildDaten = klein
        vorschau = UIImage(data: klein)
        await schaetzen(hinweis: "")
    }

    private func schaetzen(hinweis: String) async {
        guard let daten = bildDaten else { return }
        hinweisText = hinweis
        phase = .laedt
        do {
            let a = try await KiClient.essen(bild: daten, hinweis: hinweis, mahlzeit: mahlzeitWahl.rawValue)
            guard !Task.isCancelled else { return }
            uebernehmen(a)
        } catch {
            // Ein Abbruch kommt von URLSession als Fehler zurück; wer abbricht, will keine Fehlermeldung.
            guard !Task.isCancelled else { return }
            Haptik.warnung()
            let a = KiFotoLogik.anzeige((error as? KiFehler) ?? .unbekannt)
            if komponenten.isEmpty {
                phase = .fehler(a)
            } else {
                // Neu schätzen ist schiefgegangen: die bisherige Schätzung bleibt.
                neuFehler = a.text
                phase = .ergebnis
            }
        }
    }

    private func uebernehmen(_ a: EssenAnalyse) {
        if KiFotoLogik.keinEssen(a) {
            Haptik.warnung()
            phase = .keinEssen(KiFotoLogik.keinEssenText(a))
            return
        }
        analyse = a
        komponenten = a.komponenten
        urspruenglich = Dictionary(uniqueKeysWithValues: komponenten.map { ($0.id, $0.gramm) })
        entfernt = []
        versteckt = a.versteckteListe
        versteckteZaehlen = true
        antwort = ""
        neuFehler = nil
        Haptik.leicht()
        phase = .ergebnis
    }

    private func ladenAbbrechen() {
        aufgabe?.cancel()
        phase = komponenten.isEmpty ? .start : .ergebnis
    }

    private func nochmal() {
        aufgabe?.cancel()
        aufgabe = Task { await schaetzen(hinweis: hinweisText) }
    }

    private func neuSchaetzen(frage: String) {
        let hinweis = KiFotoLogik.hinweis(frage: frage, antwort: antwort)
        neuFehler = nil
        aufgabe?.cancel()
        aufgabe = Task { await schaetzen(hinweis: hinweis) }
    }

    private func neuesFoto() {
        bildDaten = nil
        vorschau = nil
        komponenten = []
        analyse = nil
        hinweisText = ""
        phase = .start
        gesperrt = Self.kameraGesperrt
        if Self.kameraVorhanden, !gesperrt { kameraOffen = true }
    }

    private func entfernen(_ id: UUID) {
        Haptik.leicht()
        withAnimation(anim) { _ = entfernt.insert(id) }
    }

    private func zurueckholen(_ id: UUID) {
        Haptik.leicht()
        withAnimation(anim) { _ = entfernt.remove(id) }
    }

    private func eintragen() {
        guard !speichert else { return }
        let neu = liste
        guard !neu.isEmpty else { return }
        speichert = true
        for e in neu {
            modell.eintragen(e.lebensmittel, menge: e.menge, einheit: e.einheit, mahlzeit: e.mahlzeit, datum: e.datum, id: e.id)
        }
        let korrekturen = KiFotoLogik.korrekturen(komponenten, urspruenglich: urspruenglich, entfernt: entfernt)
        Task { await KiClient.korrigieren(korrekturen) }
        let name = KiFotoLogik.titel(aktive)
        dismiss()
        fertig(name)
    }
}

/// Gramm per Zahlentastatur. Leer heißt 0 g (die Zutat zählt dann nicht); über 5000 g wird gekappt.
private struct GrammFeld: View {
    @Binding var gramm: Double
    @State private var text = ""

    var body: some View {
        TextField("g", text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(minWidth: 56, maxWidth: 80)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel("Gramm")
            .onAppear { text = ErnaehrungLogik.zahl(gramm) }
            .onChange(of: text) { _, neu in
                let x = min(ErnaehrungLogik.eingabe(neu) ?? 0, KiFotoLogik.maxGramm)
                if x != gramm { gramm = x }
            }
            .onChange(of: gramm) { _, neu in
                if (ErnaehrungLogik.eingabe(text) ?? 0) != neu { text = ErnaehrungLogik.zahl(neu) }
            }
    }
}
