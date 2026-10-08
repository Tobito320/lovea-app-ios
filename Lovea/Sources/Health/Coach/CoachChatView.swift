import SwiftUI

// Health-Coach: Chat und Kachel für Heute. Die Kachel zeigt höchstens eine Regel-Karte aus `CoachRegeln`, der Chat
// fragt über `CoachModell` den Server (KI). Beides respektiert die Pause (`CoachSchluessel.pause`).
//
// Akku: Kein Timer und nichts beim App-Start. Das Einblenden einer frischen Antwort dauert höchstens etwa 2,5 s, der
// Orb atmet nur, solange der Coach denkt oder der Chat leer ist.

// MARK: - Kachel in Heute

/// Eine Kachel, höchstens eine Karte. Öffnet den Chat über `HealthZiel.coach`. Bei Pause nur eine schmale Zeile mit
/// "Fortsetzen", sonst wäre der Chat nicht mehr erreichbar. Nimmt nur Werte (kein Closure), damit Heute sie nicht bei
/// jedem Neuzeichnen neu rechnet; sie rechnet nur, wenn sich ein gelesenes Modell ändert.
struct CoachKachel: View {
    let person: Person
    let heute: String
    @AppStorage(CoachSchluessel.pause) private var pausiert = false

    var body: some View {
        if pausiert { pauseZeile } else { aktiv }
    }

    private var aktiv: some View {
        let karte = CoachRegeln.karten(CoachDaten.eingabe(person, heute: heute)).first
        return NavigationLink(value: HealthZiel.coach) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Coach", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(HabitFarbe.mint.farbe)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                if let karte {
                    Text(karte.titel).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(karte.text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("Frag nach deinem Tagesbericht, deinem Training oder dem Essen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .healthKarte(HabitFarbe.mint.farbe)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.federnd)
        .accessibilityHint("Öffnet den Coach-Chat")
    }

    private var pauseZeile: some View {
        HStack(spacing: 12) {
            Label("Coach pausiert", systemImage: "pause.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Fortsetzen") { pausiert = false }
                .font(.footnote.weight(.semibold))
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Chat

/// Was eine Nachrichtenzeile dem Chat zurückgibt: eine Frage senden oder Text ins Eingabefeld legen.
private struct CoachRueckruf {
    let senden: (String) -> Void
    let uebernehmen: (String) -> Void
}

/// Wohin der Verlauf scrollen soll. Ein einziger Weg für Suche, Tagessprung, "Nach unten" und neue Antworten.
private struct CoachSprung: Equatable {
    let id: String
    let anker: UnitPoint

    static let ende = CoachSprung(id: "ende", anker: .bottom)
}

struct CoachChatView: View {
    @AppStorage(CoachSchluessel.pause) private var pausiert = false
    @State private var entwurf = ""
    @State private var ausblendenFragen = false
    @State private var zielFrage = false
    @State private var zielEntwurf = ""
    @State private var sucheOffen = false
    @State private var exportOffen = false
    @State private var exportText = ""
    @State private var gemerktOffen = false
    @State private var amEnde = true
    @State private var ungelesen = false
    @State private var sprung: CoachSprung?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var schema

    private var modell: CoachModell { CoachModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        Group {
            if pausiert { pauseAnsicht } else { chat }
        }
        .background { hintergrund }
        .navigationTitle("Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { titel }
            ToolbarItem(placement: .topBarTrailing) { menue }
        }
        // Erst hier hängt sich der Coach an den Op-Strom. Pausiert lädt er nichts.
        .task(id: pausiert) {
            guard !pausiert else { return }
            modell.oeffnen()
            if entwurf.isEmpty { entwurf = modell.entwurfLesen() }
        }
        .confirmationDialog("Verlauf ausblenden?", isPresented: $ausblendenFragen, titleVisibility: .visible) {
            Button("Ausblenden", role: .destructive) { modell.verlaufAusblenden() }
        } message: {
            Text("Die Nachrichten verschwinden nur auf diesem Gerät. Der Coach kennt die letzten Nachrichten weiter.")
        }
        .alert("Mein Ziel", isPresented: $zielFrage) {
            TextField("z. B. dreimal pro Woche trainieren", text: $zielEntwurf)
            Button("Abbrechen", role: .cancel) {}
            Button("Speichern") { modell.zielSetzen(zielEntwurf) }
        } message: {
            Text("Ein Satz. Leer lassen entfernt das Ziel. Der Coach richtet sich danach.")
        }
        .sheet(isPresented: $sucheOffen) {
            CoachSucheBlatt(nachrichten: modell.liste) { id in sprung = CoachSprung(id: id, anker: .center) }
        }
        .sheet(isPresented: $exportOffen) { CoachExportBlatt(text: exportText) }
        .sheet(isPresented: $gemerktOffen) { CoachGemerktBlatt() }
    }

    /// Inhaltsebene: ein Hauch Mint von oben und Himmel von unten, kein Glas. Glas gehört nur auf die Bedienelemente.
    private var hintergrund: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            RadialGradient(colors: [HabitFarbe.mint.farbe.opacity(schema == .dark ? 0.28 : 0.2), Color.clear], center: .top, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [HabitFarbe.himmel.farbe.opacity(schema == .dark ? 0.18 : 0.12), Color.clear], center: .bottomTrailing, startRadius: 0, endRadius: 380)
        }
        .ignoresSafeArea()
    }

    private var titel: some View {
        HStack(spacing: 8) {
            CoachOrb(groesse: 20)
            Text("Coach").font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Menü

    private var morgenBinding: Binding<Bool> {
        Binding(get: { modell.morgenAn }, set: { modell.morgenSetzen($0) })
    }

    private var menue: some View {
        Menu {
            if !pausiert {
                Button("Suchen", systemImage: "magnifyingglass") { sucheOffen = true }
                Button("Angeheftet", systemImage: "pin") { gemerktOffen = true }
                let tage = CoachLokal.tage(modell.liste, kalender: Datum.kalender)
                if !tage.isEmpty {
                    Menu("Zu Tag springen", systemImage: "calendar") {
                        ForEach(tage, id: \.id) { tag in
                            Button(CoachAnzeige.tagText(tag.zeit)) { sprung = CoachSprung(id: tag.id, anker: .top) }
                        }
                    }
                }
                Button("Verlauf teilen", systemImage: "square.and.arrow.up") {
                    exportText = CoachLokal.export(modell.liste, ich: ich.name) { CoachAnzeige.zeitText($0) }
                    exportOffen = true
                }
                Divider()
                Menu("Ton", systemImage: "text.bubble") {
                    ForEach(Array(CoachModell.toene.enumerated()), id: \.offset) { _, ton in
                        Button {
                            modell.tonSetzen(ton.wert)
                        } label: {
                            if modell.ton == ton.wert { Label(ton.name, systemImage: "checkmark") } else { Text(ton.name) }
                        }
                    }
                }
                Button("Mein Ziel", systemImage: "flag") {
                    zielEntwurf = modell.ziel
                    zielFrage = true
                }
                if !modell.erinnerungen.isEmpty {
                    Button("Erinnerungen entfernen", systemImage: "bell.slash") { modell.erinnerungenEntfernen() }
                }
                Divider()
            }
            Toggle("Morgen-Nachricht um 8 Uhr", isOn: morgenBinding)
            Button(pausiert ? "Coach fortsetzen" : "Coach pausieren", systemImage: pausiert ? "play.circle" : "pause.circle") {
                pausiert.toggle()
            }
            if !pausiert {
                Button("Verlauf ausblenden", systemImage: "eye.slash", role: .destructive) { ausblendenFragen = true }
            }
        } label: {
            Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Coach-Einstellungen")
    }

    // MARK: Pause

    private var pauseAnsicht: some View {
        VStack(spacing: 16) {
            Image(systemName: "pause.circle").font(.system(size: 44)).foregroundStyle(.secondary)
            Text("Coach pausiert").font(.title3.weight(.semibold))
            Text("Kachel und Karten in Heute sind aus. Der Coach lädt und sendet nichts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Coach fortsetzen") { pausiert = false }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
            Toggle("Morgen-Nachricht um 8 Uhr", isOn: morgenBinding)
                .padding(16)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text("Die Morgen-Nachricht kommt vom Server und hängt nur an diesem Schalter, nicht an der Pause.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    // MARK: Chat

    private var chat: some View {
        let nachrichten = modell.liste
        let leer = nachrichten.isEmpty && !modell.sendet
        let fragen = schnellfragen(nachrichten)
        // Beim ersten Öffnen kommt der Verlauf erst nach dem ersten Zeichnen; der Wechsel blendet über statt zu springen.
        return Group {
            if leer { leerAnsicht(fragen).transition(.opacity) } else { verlauf(nachrichten).transition(.opacity) }
        }
        .animation(reduceMotion ? nil : Feder.weich, value: leer)
        .safeAreaBar(edge: .bottom, spacing: 0) { unten(leer: leer, fragen: fragen) }
    }

    /// Je nach Tageszeit und Wochentag; was heute schon gefragt wurde, fällt weg (`CoachLokal`).
    private func schnellfragen(_ nachrichten: [CoachNachricht]) -> [String] {
        let jetzt = Date()
        let kalender = Datum.kalender
        return CoachLokal.schnellfragen(
            stunde: kalender.component(.hour, from: jetzt),
            wochentag: kalender.component(.weekday, from: jetzt),
            schonGefragt: CoachLokal.heuteGefragt(nachrichten, jetzt: jetzt, kalender: kalender)
        )
    }

    // MARK: Leer

    private static func symbol(fuer frage: String) -> String {
        if frage == CoachLokal.wochenrueckblick { return "calendar" }
        if frage == CoachLokal.luecken { return "checklist" }
        if frage.contains("Training") { return "figure.strengthtraining.traditional" }
        if frage.contains("essen") { return "fork.knife" }
        if frage.contains("Tagesbericht") { return "doc.text.magnifyingglass" }
        return "sparkles"
    }

    private func leerAnsicht(_ fragen: [String]) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                CoachOrb(groesse: 84, aktiv: true, lebhaft: !entwurf.isEmpty).padding(.bottom, 16)
                Text("\(CoachText.begruessung(stunde: Datum.kalender.component(.hour, from: Date()))), \(ich.name)")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Ich kenne deine Zahlen aus Training, Essen, Schritten und Gewicht.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    ForEach(fragen, id: \.self) { frage in
                        frageKarte(frage, symbol: Self.symbol(fuer: frage))
                    }
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center)
        .scrollIndicators(.hidden)
    }

    private func frageKarte(_ frage: String, symbol: String) -> some View {
        Button { absenden(frage, ausFeld: false) } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(HabitFarbe.mint.farbe)
                    .frame(width: 36, height: 36)
                    .background(HabitFarbe.mint.farbe.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)
                Text(frage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .healthKarte(HabitFarbe.mint.farbe)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.federnd)
        .disabled(modell.sendet)
    }

    // MARK: Verlauf

    private var rueckruf: CoachRueckruf {
        CoachRueckruf(
            senden: { absenden($0, ausFeld: false) },
            uebernehmen: { text in
                entwurf = String(text.prefix(CoachModell.maxZeichen))
                Haptik.leicht()
            }
        )
    }

    private func verlauf(_ nachrichten: [CoachNachricht]) -> some View {
        // Nur die letzte Antwort trägt Folgefragen und Aktionsleiste.
        let letzteAntwort: String? = nachrichten.last?.rolle == .coach ? nachrichten.last?.id : nil
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(nachrichten.enumerated()), id: \.element.id) { index, nachricht in
                        eintrag(
                            nachricht,
                            vorher: index > 0 ? nachrichten[index - 1] : nil,
                            letzte: nachricht.id == letzteAntwort
                        )
                        .transition(.opacity)
                    }
                    if modell.sendet { denkt.padding(.top, 18).transition(.opacity) }
                    Color.clear.frame(height: 1).id("ende")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(reduceMotion ? nil : Feder.weich, value: nachrichten.count)
                .animation(reduceMotion ? nil : Feder.weich, value: modell.sendet)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.containerSize.height - geo.contentInsets.bottom >= geo.contentSize.height - 24
            } action: { _, neu in
                amEnde = neu
                if neu { ungelesen = false }
            }
            .onChange(of: nachrichten.count) { alt, neu in
                guard neu > alt, let letzte = nachrichten.last else { return }
                if letzte.rolle == .coach, letzte.lokal || modell.frischSeit(letzte.text) != nil {
                    // Eine Antwort, auf die der Nutzer wartet: ihr Anfang kommt in Sicht, nicht ihr Ende.
                    sprung = CoachSprung(id: letzte.id, anker: .top)
                    Haptik.leicht()
                    if UIAccessibility.isVoiceOverRunning {
                        UIAccessibility.post(notification: .announcement, argument: "Coach: " + CoachText.vorschau(letzte.text, maximal: 280))
                    }
                } else if (letzte.rolle == .du && letzte.lokal) || amEnde {
                    sprung = .ende
                } else {
                    ungelesen = true
                }
            }
            .onChange(of: modell.sendet) { _, sendet in
                if sendet && amEnde { sprung = .ende }
            }
            .onChange(of: sprung) { _, ziel in
                guard let ziel else { return }
                if reduceMotion {
                    proxy.scrollTo(ziel.id, anchor: ziel.anker)
                } else {
                    withAnimation(Feder.weich) { proxy.scrollTo(ziel.id, anchor: ziel.anker) }
                }
                sprung = nil
            }
        }
    }

    /// Eine Nachricht, bei Bedarf mit Zeit-Trennzeile davor. Gleicher Absender rückt näher, ein Wechsel lässt Luft.
    private func eintrag(_ nachricht: CoachNachricht, vorher: CoachNachricht?, letzte: Bool) -> some View {
        let neuerBlock = CoachText.trennerNoetig(vorher: vorher?.zeit, jetzt: nachricht.zeit, kalender: Datum.kalender)
        let vorfrage = vorher?.rolle == .du ? vorher?.text : nil
        return VStack(alignment: .leading, spacing: 0) {
            if neuerBlock { trenner(nachricht.zeit) }
            CoachZeile(
                nachricht: nachricht,
                person: ich,
                kopf: nachricht.rolle == .coach && (neuerBlock || vorher?.rolle != .coach),
                letzte: letzte,
                vorfrage: vorfrage,
                rueckruf: rueckruf
            )
            .padding(.top, neuerBlock ? 0 : (vorher?.rolle == nachricht.rolle ? 6 : 18))
        }
    }

    private func trenner(_ zeit: Date) -> some View {
        Text(CoachAnzeige.zeitText(zeit))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .accessibilityAddTraits(.isHeader)
    }

    private var denkt: some View {
        HStack(spacing: 10) {
            CoachOrb(groesse: 24, aktiv: true)
            Text("Coach denkt nach").font(.subheadline).foregroundStyle(.secondary)
            CoachDenkPunkte()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Coach denkt nach")
    }

    // MARK: Unten: Fehler, Schnellfragen, Eingabe

    private func unten(leer: Bool, fragen: [String]) -> some View {
        VStack(spacing: 8) {
            if let fehler = modell.fehler { fehlerZeile(fehler) }
            if !leer && !amEnde { nachUntenKnopf }
            if !leer { schnellfragenLeiste(fragen) }
            if entwurf.count >= 800 { zaehler }
            eingabe(fragen)
            Text("KI-Coach, kein Arzt")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .animation(reduceMotion ? nil : Feder.schnell, value: amEnde)
    }

    private var nachUntenKnopf: some View {
        Button {
            Haptik.auswahl()
            sprung = .ende
        } label: {
            Label(ungelesen ? "Neue Antwort" : "Nach unten", systemImage: "arrow.down")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassEffect(.regular.interactive(), in: .capsule)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .transition(.opacity)
    }

    private func fehlerZeile(_ fehler: CoachFehler) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(HabitFarbe.amber.farbe).frame(minHeight: 44)
            Text(fehler.text).font(.footnote).foregroundStyle(.primary).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            if let frage = modell.letzteFrage, fehler == .netz || fehler == .server {
                Button("Nochmal") { nochmalVersuchen(frage) }
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: 44)
            }
            Button { modell.fehlerLoeschen() } label: {
                Image(systemName: "xmark").font(.footnote.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Hinweis schließen")
        }
        .padding(.leading, 14)
        .background(HabitFarbe.amber.farbe.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// Nach einem Fehler liegt die Frage wieder im Feld; sie soll nicht doppelt dort stehen bleiben.
    private func nochmalVersuchen(_ frage: String) {
        modell.fehlerLoeschen()
        if entwurf.trimmingCharacters(in: .whitespacesAndNewlines) == frage { entwurf = "" }
        absenden(frage, ausFeld: false)
    }

    private func schnellfragenLeiste(_ fragen: [String]) -> some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(fragen, id: \.self) { frage in
                        Button { absenden(frage, ausFeld: false) } label: {
                            Text(frage)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .contentShape(.capsule)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .disabled(modell.sendet)
                    }
                }
                .animation(reduceMotion ? nil : Feder.weich, value: fragen)
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private var zaehler: some View {
        Text("\(entwurf.count) von \(CoachModell.maxZeichen)")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(entwurf.count >= CoachModell.maxZeichen - 50 ? HabitFarbe.amber.farbe : Color.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 8)
    }

    private var kannSenden: Bool {
        !entwurf.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !modell.sendet
    }

    private func eingabe(_ fragen: [String]) -> some View {
        GlassEffectContainer(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Frag den Coach", text: $entwurf, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .glassEffect(.regular, in: .rect(cornerRadius: 22))
                    .onChange(of: entwurf) { _, neu in
                        if neu.count > CoachModell.maxZeichen { entwurf = String(neu.prefix(CoachModell.maxZeichen)) }
                        modell.entwurfSpeichern(neu)
                    }
                // Nicht gesperrt, damit das Menü mit den Schnellfragen auch bei leerem Feld aufgeht; `absenden` prüft selbst.
                Button { absenden(entwurf, ausFeld: true) } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(kannSenden ? Color.personText(ich) : Color.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(kannSenden ? Color.person(ich) : nil).interactive(), in: .circle)
                .animation(reduceMotion ? nil : Feder.schnell, value: kannSenden)
                .contextMenu {
                    ForEach(fragen, id: \.self) { frage in
                        Button(frage) { absenden(frage, ausFeld: false) }
                    }
                }
                .accessibilityLabel("Senden")
                .accessibilityHint("Gedrückt halten für Schnellfragen")
            }
        }
    }

    /// Bei einem Fehler legt die Eingabe den Text zurück ins Feld, aber nur, wenn dort inzwischen nichts Neues steht.
    private func absenden(_ roh: String, ausFeld: Bool) {
        let text = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !modell.sendet else { return }
        Haptik.leicht()
        if ausFeld { entwurf = "" }
        Task {
            let fehler = await modell.frage(text)
            if fehler != nil, ausFeld, entwurf.isEmpty { entwurf = text }
        }
    }
}

// MARK: - Orb

/// Das Gesicht des Coaches: eine Kugel, die einzige auffällige Stelle im Chat. Die Farben folgen der Tageszeit. Sie
/// atmet nur, wenn `aktiv` gesetzt ist und Bewegung erlaubt ist, sonst steht sie still. Rein dekorativ, VoiceOver überspringt sie.
private struct CoachOrb: View {
    let groesse: CGFloat
    var aktiv = false
    /// Der Nutzer tippt: der Orb pulsiert kräftiger.
    var lebhaft = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var schema

    private var palette: (innen: Color, aussen: Color) {
        switch CoachText.tageszeit(stunde: Datum.kalender.component(.hour, from: Date())) {
        case .morgen: (HabitFarbe.amber.farbe, HabitFarbe.mint.farbe)
        case .tag: (HabitFarbe.mint.farbe, HabitFarbe.himmel.farbe)
        case .abend: (HabitFarbe.koralle.farbe, HabitFarbe.indigo.farbe)
        case .nacht: (HabitFarbe.indigo.farbe, HabitFarbe.himmel.farbe)
        }
    }

    var body: some View {
        let farben = palette
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !aktiv || reduceMotion)) { zeit in
            kugel(farben: farben, atem: aktiv && !reduceMotion ? sin(zeit.date.timeIntervalSinceReferenceDate * 2.2) * (lebhaft ? 1.7 : 1) : 0)
        }
        .frame(width: groesse, height: groesse)
        .accessibilityHidden(true)
    }

    private func kugel(farben: (innen: Color, aussen: Color), atem: Double) -> some View {
        Circle()
            .fill(LinearGradient(colors: [farben.innen, farben.aussen], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Circle().fill(RadialGradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0)],
                                             center: UnitPoint(x: 0.3 + 0.05 * atem, y: 0.27),
                                             startRadius: 0, endRadius: groesse * 0.6))
            }
            .overlay { Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1) }
            .shadow(color: farben.innen.opacity(schema == .dark ? 0.65 : 0.4), radius: groesse * 0.22, y: groesse * 0.06)
            .scaleEffect(1 + 0.06 * atem)
    }
}

/// Drei Punkte, die nacheinander hüpfen, solange der Coach denkt. Mit "Bewegung reduzieren" stehen sie still.
private struct CoachDenkPunkte: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { zeit in
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .offset(y: reduceMotion ? 0 : -3 * max(0, sin(zeit.date.timeIntervalSinceReferenceDate * 5 - Double(index) * 0.7)))
                }
            }
            .frame(height: 12)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Nachricht

/// Eigene Nachricht: Blase in der Personenfarbe. Antwort des Coaches: Text ohne Blase, Listen und Fett aus `CoachText`,
/// darunter Diagramm, Fortschritt, Wege und Vorschläge aus `CoachMarker`. Halten öffnet das Menü, Tippen zeigt die Uhrzeit.
private struct CoachZeile: View {
    let nachricht: CoachNachricht
    let person: Person
    /// Erste Antwort eines Blocks trägt Orb und Namen.
    let kopf: Bool
    /// Die letzte Antwort im Verlauf: nur sie trägt Folgefragen und Aktionsleiste.
    let letzte: Bool
    /// Die Frage direkt davor, für "Nochmal fragen".
    let vorfrage: String?
    let rueckruf: CoachRueckruf

    /// Seit wann die Antwort frisch ist, solange sie noch eingeblendet wird. Wird einmal beim Anlegen entschieden, damit
    /// der Wechsel von der lokalen zur bestätigten Nachricht (neue Id) das Einblenden nicht neu startet.
    @State private var einblendStart: Date?
    /// Das Einblenden ist vorbei; erst dann erscheinen Diagramm, Vorschläge und Aktionen.
    @State private var fertig: Bool
    @State private var zeigtZeit = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var modell: CoachModell { CoachModell.shared }
    private var eigene: Bool { nachricht.rolle == .du }
    private var schluessel: String { CoachLokal.schluessel(nachricht.text) }

    init(nachricht: CoachNachricht, person: Person, kopf: Bool, letzte: Bool, vorfrage: String?, rueckruf: CoachRueckruf) {
        self.nachricht = nachricht
        self.person = person
        self.kopf = kopf
        self.letzte = letzte
        self.vorfrage = vorfrage
        self.rueckruf = rueckruf
        var start: Date?
        if nachricht.rolle == .coach, let seit = CoachModell.shared.frischSeit(nachricht.text) {
            let gesamt = CoachText.gesamtWoerter(CoachText.zeilen(CoachMarker.zerlegen(nachricht.text).text))
            if CoachText.einblendenLohnt(gesamt: gesamt), Date().timeIntervalSince(seit) < CoachText.einblendDauer(gesamt: gesamt) {
                start = seit
            }
        }
        _einblendStart = State(initialValue: start)
        _fertig = State(initialValue: start == nil)
    }

    var body: some View {
        Group {
            if eigene { eigeneBlase } else { antwort }
        }
        .contextMenu { aktionen }
    }

    // MARK: Eigene Nachricht

    private var eigeneBlase: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 0) {
                Spacer(minLength: 56)
                Text(CoachText.inline(nachricht.text))
                    .font(.body)
                    .foregroundStyle(Color.personText(person))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(LinearGradient(colors: [Color.person(person), Color.person(person).opacity(0.88)], startPoint: .top, endPoint: .bottom),
                                in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22, bottomTrailingRadius: 6, topTrailingRadius: 22))
            }
            if zeigtZeit { zeitZeile }
        }
        .contentShape(Rectangle())
        .onTapGesture { zeitUmschalten() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Du, \(CoachAnzeige.zeitText(nachricht.zeit)): \(nachricht.text)")
    }

    private var zeitZeile: some View {
        Text(CoachAnzeige.zeitText(nachricht.zeit))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .transition(.opacity)
    }

    private func zeitUmschalten() {
        if reduceMotion { zeigtZeit.toggle() } else { withAnimation(Feder.schnell) { zeigtZeit.toggle() } }
    }

    // MARK: Antwort

    @ViewBuilder
    private var antwort: some View {
        let zerlegt = CoachMarker.zerlegen(nachricht.text)
        let zeilen = CoachText.zeilen(zerlegt.text)
        VStack(alignment: .leading, spacing: 8) {
            if kopf {
                HStack(spacing: 8) {
                    CoachOrb(groesse: 20)
                    Text("Coach").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            textBlock(zeilen, roh: zerlegt.text)
                .animation(nil, value: fertig)
                .contentShape(Rectangle())
                .onTapGesture { zeitUmschalten() }
            if zeigtZeit { zeitZeile }
            if fertig {
                extras(zerlegt)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Feder.weich, value: fertig)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Coach, \(CoachAnzeige.zeitText(nachricht.zeit))")
        .task {
            guard let start = einblendStart, !fertig else { return }
            let gesamt = CoachText.gesamtWoerter(CoachText.zeilen(CoachMarker.zerlegen(nachricht.text).text))
            let rest = start.addingTimeInterval(CoachText.einblendDauer(gesamt: gesamt)).timeIntervalSinceNow
            if rest > 0, !reduceMotion { try? await Task.sleep(for: .seconds(rest)) }
            fertig = true
        }
    }

    @ViewBuilder
    private func textBlock(_ zeilen: [CoachText.Zeile], roh: String) -> some View {
        if zeilen.isEmpty {
            // Nur Marker, kein Text: nichts zu zeigen. Ein leerer Text würde eine leere Zeile mit Abstand belegen.
            EmptyView()
        } else if let start = einblendStart, !fertig, !reduceMotion {
            let gesamt = CoachText.gesamtWoerter(zeilen)
            // Die volle Antwort steht unsichtbar darunter und hält die Höhe, damit der Verlauf beim Einblenden nicht springt.
            ZStack(alignment: .topLeading) {
                zeilenAnsicht(zeilen).opacity(0).allowsHitTesting(false)
                TimelineView(.explicit(CoachText.einblendTermine(start: start, gesamt: gesamt))) { kontext in
                    // Kleiner Aufschlag, damit ein Wort nicht wegen Rundung einen Takt zu spät erscheint.
                    let woerter = CoachText.sichtbareWoerter(vergangen: kontext.date.timeIntervalSince(start) + 0.002, gesamt: gesamt)
                    zeilenAnsicht(CoachText.eingeblendet(zeilen, woerter: woerter))
                }
                .accessibilityHidden(true)
            }
        } else {
            zeilenAnsicht(zeilen)
        }
    }

    private func zeilenAnsicht(_ zeilen: [CoachText.Zeile]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(zeilen.enumerated()), id: \.offset) { _, zeile in ansicht(zeile) }
        }
        .font(.body)
        .lineSpacing(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func ansicht(_ zeile: CoachText.Zeile) -> some View {
        switch zeile.art {
        case .absatz:
            Text(CoachAnzeige.hervorgehoben(zeile.text)).monospacedDigit()
        case .ueberschrift:
            Text(CoachText.inline(zeile.text)).font(.headline).padding(.top, 4)
        case .punkt:
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: "•").foregroundStyle(HabitFarbe.mint.farbe).accessibilityHidden(true)
                Text(CoachAnzeige.hervorgehoben(zeile.text)).monospacedDigit()
            }
        case .nummer(let n):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "\(n).").monospacedDigit().foregroundStyle(.secondary).frame(minWidth: 22, alignment: .trailing)
                Text(CoachAnzeige.hervorgehoben(zeile.text)).monospacedDigit()
            }
        case .aufgabe:
            CoachAufgabeZeile(text: zeile.text, erledigt: modell.hat(.haken, hakenSchluessel(zeile.text))) { haken(zeile.text) }
        case .tabelle(let kopfzeile, let reihen):
            CoachTabelle(kopf: kopfzeile, zeilen: reihen)
        }
    }

    /// Eine Aufgabe ist an ihre Antwort gebunden: gleicher Satz in einer anderen Antwort ist eine andere Aufgabe.
    private func hakenSchluessel(_ text: String) -> String { schluessel + "." + CoachLokal.schluessel(text) }

    private func haken(_ text: String) {
        let eintrag = hakenSchluessel(text)
        modell.setzen(.haken, eintrag, an: !modell.hat(.haken, eintrag))
        Haptik.auswahl()
    }

    // MARK: Zusätze unter der Antwort

    @ViewBuilder
    private func extras(_ zerlegt: CoachMarker.Zerlegt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let diagramm = zerlegt.diagramm {
                CoachDiagramm(titel: diagramm.titel, punkte: diagramm.punkte)
            }
            if let stand = zerlegt.fortschritt {
                CoachFortschritt(label: stand.label, aktuell: stand.aktuell, ziel: stand.ziel)
            }
            if let erinnerung = zerlegt.erinnerung {
                CoachErinnerungsKnopf(stunde: erinnerung.stunde, minute: erinnerung.minute, text: erinnerung.text)
            }
            if let ziel = zerlegt.vorgeschlagenesZiel {
                CoachZielKnopf(text: ziel)
            }
            ForEach(Array(zerlegt.wege.enumerated()), id: \.offset) { _, weg in
                CoachWeg(ziel: healthZiel(weg.ziel), beschriftung: weg.beschriftung)
            }
            if letzte {
                if !zerlegt.folgefragen.isEmpty {
                    CoachFolgefragen(fragen: zerlegt.folgefragen) { rueckruf.senden($0) }
                }
                aktionsleiste
            }
        }
    }

    private func healthZiel(_ ziel: CoachMarker.Ziel) -> HealthZiel {
        switch ziel {
        case .schritte: .schritte(person)
        case .training: .trainingsPlan(person)
        case .gewicht: .habit(Habit.gewicht.id)
        case .verlauf: .gymVerlauf
        }
    }

    private var nochmal: (() -> Void)? {
        guard let frage = vorfrage else { return nil }
        return { rueckruf.senden(frage) }
    }

    private var aktionsleiste: some View {
        CoachAktionsLeiste(
            hoch: modell.hat(.daumenHoch, schluessel),
            runter: modell.hat(.daumenRunter, schluessel),
            daumenHoch: {
                modell.daumen(schluessel, hoch: true)
                Haptik.leicht()
            },
            daumenRunter: {
                modell.daumen(schluessel, hoch: false)
                Haptik.leicht()
            },
            kopieren: { kopieren() },
            kuerzer: { rueckruf.senden("Fass deine letzte Antwort kürzer zusammen.") },
            genauer: { rueckruf.senden("Erkläre deine letzte Antwort genauer, mit meinen Zahlen.") },
            nochmal: nochmal
        )
    }

    // MARK: Menü beim Halten

    private func kopieren() {
        UIPasteboard.general.string = eigene ? nachricht.text : CoachAnzeige.kopierText(nachricht.text)
        Haptik.leicht()
    }

    @ViewBuilder
    private var aktionen: some View {
        let angeheftet = modell.hat(.gemerkt, schluessel)
        Button("Kopieren", systemImage: "doc.on.doc") { kopieren() }
        ShareLink(item: eigene ? nachricht.text : CoachAnzeige.kopierText(nachricht.text)) {
            Label("Teilen", systemImage: "square.and.arrow.up")
        }
        Button(angeheftet ? "Lösen" : "Anheften", systemImage: angeheftet ? "pin.slash" : "pin") {
            modell.setzen(.gemerkt, schluessel, an: !angeheftet)
            Haptik.leicht()
        }
        if eigene {
            Button("In Eingabe übernehmen", systemImage: "square.and.pencil") { rueckruf.uebernehmen(nachricht.text) }
        }
        // Eine noch unbestätigte Nachricht hat nur eine vorläufige Id; verstecken geht erst, wenn der Server sie kennt.
        if !nachricht.lokal {
            Button("Ausblenden", systemImage: "eye.slash", role: .destructive) {
                modell.setzen(.versteckt, nachricht.id, an: true)
            }
        }
    }
}
