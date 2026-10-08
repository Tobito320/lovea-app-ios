import SwiftUI

// Health-Coach: Chat und Kachel für Heute. Die Kachel zeigt höchstens eine Regel-Karte aus `CoachRegeln`, der Chat
// fragt über `CoachModell` den Server (KI). Beides respektiert die Pause (`CoachSchluessel.pause`).

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

struct CoachChatView: View {
    @AppStorage(CoachSchluessel.pause) private var pausiert = false
    @State private var entwurf = ""
    @State private var ausblendenFragen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            ToolbarItem(placement: .topBarTrailing) { menue }
        }
        // Erst hier hängt sich der Coach an den Op-Strom. Pausiert lädt er nichts.
        .task(id: pausiert) { if !pausiert { modell.oeffnen() } }
        .confirmationDialog("Verlauf ausblenden?", isPresented: $ausblendenFragen, titleVisibility: .visible) {
            Button("Ausblenden", role: .destructive) { modell.verlaufAusblenden() }
        } message: {
            Text("Die Nachrichten verschwinden nur auf diesem Gerät. Der Coach kennt die letzten Nachrichten weiter.")
        }
    }

    /// Inhaltsebene: ein Hauch Mint von oben und Himmel von unten, kein Glas. Glas gehört nur auf die Bedienelemente.
    private var hintergrund: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            RadialGradient(colors: [HabitFarbe.mint.farbe.opacity(0.2), Color.clear], center: .top, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [HabitFarbe.himmel.farbe.opacity(0.12), Color.clear], center: .bottomTrailing, startRadius: 0, endRadius: 380)
        }
        .ignoresSafeArea()
    }

    // MARK: Menü

    private var morgenBinding: Binding<Bool> {
        Binding(get: { modell.morgenAn }, set: { modell.morgenSetzen($0) })
    }

    private var menue: some View {
        Menu {
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
        return Group {
            if leer { leerAnsicht } else { verlauf(nachrichten) }
        }
        .safeAreaBar(edge: .bottom, spacing: 0) { unten(leer: leer) }
    }

    // MARK: Leer

    private static let schnellSymbole = ["doc.text.magnifyingglass", "figure.strengthtraining.traditional", "fork.knife"]

    private var leerAnsicht: some View {
        ScrollView {
            VStack(spacing: 8) {
                CoachOrb(groesse: 84, aktiv: true).padding(.bottom, 16)
                Text("\(CoachText.begruessung(stunde: Datum.kalender.component(.hour, from: Date()))), \(ich.name)")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Ich kenne deine Zahlen aus Training, Essen, Schritten und Gewicht.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    ForEach(Array(CoachRegeln.schnellfragen.enumerated()), id: \.offset) { index, frage in
                        frageKarte(frage, symbol: Self.schnellSymbole.indices.contains(index) ? Self.schnellSymbole[index] : "sparkles")
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
                Text(frage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
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

    private func verlauf(_ nachrichten: [CoachNachricht]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(nachrichten.enumerated()), id: \.element.id) { index, nachricht in
                        eintrag(nachricht, vorher: index > 0 ? nachrichten[index - 1] : nil)
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
            .onChange(of: nachrichten.count) { _, _ in nachUnten(proxy) }
            .onChange(of: modell.sendet) { _, _ in nachUnten(proxy) }
        }
    }

    private func nachUnten(_ proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo("ende", anchor: .bottom)
        } else {
            withAnimation(Feder.weich) { proxy.scrollTo("ende", anchor: .bottom) }
        }
    }

    /// Eine Nachricht, bei Bedarf mit Zeit-Trennzeile davor. Gleicher Absender rückt näher, ein Wechsel lässt Luft.
    @ViewBuilder
    private func eintrag(_ nachricht: CoachNachricht, vorher: CoachNachricht?) -> some View {
        let neuerBlock = CoachText.trennerNoetig(vorher: vorher?.zeit, jetzt: nachricht.zeit, kalender: Datum.kalender)
        if neuerBlock { trenner(nachricht.zeit) }
        CoachZeile(nachricht: nachricht, person: ich, kopf: nachricht.rolle == .coach && (neuerBlock || vorher?.rolle != .coach))
            .padding(.top, neuerBlock ? 0 : (vorher?.rolle == nachricht.rolle ? 6 : 18))
    }

    private static let deutsch = Locale(identifier: "de_DE")

    private func trenner(_ zeit: Date) -> some View {
        let kalender = Datum.kalender
        let stil = Date.FormatStyle(locale: Self.deutsch, calendar: kalender, timeZone: kalender.timeZone)
        let uhr = zeit.formatted(stil.hour().minute())
        let text = if kalender.isDateInToday(zeit) {
            "Heute, \(uhr)"
        } else if kalender.isDateInYesterday(zeit) {
            "Gestern, \(uhr)"
        } else {
            zeit.formatted(stil.weekday(.abbreviated).day().month(.abbreviated)) + ", " + uhr
        }
        return Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 12)
    }

    private var denkt: some View {
        HStack(spacing: 10) {
            CoachOrb(groesse: 24, aktiv: true)
            Text("Coach denkt nach").font(.subheadline).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Unten: Fehler, Schnellfragen, Eingabe

    private func unten(leer: Bool) -> some View {
        VStack(spacing: 8) {
            if let fehler = modell.fehler { fehlerZeile(fehler) }
            if !leer { schnellfragen }
            eingabe
            Text("KI-Coach, kein Arzt")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func fehlerZeile(_ fehler: CoachFehler) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(HabitFarbe.amber.farbe).frame(minHeight: 44)
            Text(fehler.text).font(.footnote).foregroundStyle(.primary).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
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

    private var schnellfragen: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(CoachRegeln.schnellfragen, id: \.self) { frage in
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
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private var kannSenden: Bool {
        !entwurf.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !modell.sendet
    }

    private var eingabe: some View {
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
                    }
                Button { absenden(entwurf, ausFeld: true) } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(kannSenden ? Color.personText(ich) : Color.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(kannSenden ? Color.person(ich) : nil).interactive(), in: .circle)
                .disabled(!kannSenden)
                .animation(reduceMotion ? nil : Feder.schnell, value: kannSenden)
                .accessibilityLabel("Senden")
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

/// Das Gesicht des Coaches: eine Kugel in Mint und Himmel, die einzige auffällige Stelle im Chat. Sie atmet nur,
/// wenn `aktiv` gesetzt ist und Bewegung erlaubt ist, sonst steht sie still. Rein dekorativ, VoiceOver überspringt sie.
private struct CoachOrb: View {
    let groesse: CGFloat
    var aktiv = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !aktiv || reduceMotion)) { zeit in
            kugel(atem: aktiv && !reduceMotion ? sin(zeit.date.timeIntervalSinceReferenceDate * 2.2) : 0)
        }
        .frame(width: groesse, height: groesse)
        .accessibilityHidden(true)
    }

    private func kugel(atem: Double) -> some View {
        let mint = HabitFarbe.mint.farbe
        return Circle()
            .fill(LinearGradient(colors: [mint, HabitFarbe.himmel.farbe], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Circle().fill(RadialGradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0)],
                                             center: UnitPoint(x: 0.3 + 0.05 * atem, y: 0.27),
                                             startRadius: 0, endRadius: groesse * 0.6))
            }
            .overlay { Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1) }
            .shadow(color: mint.opacity(0.4), radius: groesse * 0.22, y: groesse * 0.06)
            .scaleEffect(1 + 0.06 * atem)
    }
}

// MARK: - Nachricht

/// Eigene Nachricht: Blase in der Personenfarbe. Antwort des Coaches: Text ohne Blase, Listen und Fett aus `CoachText`.
private struct CoachZeile: View {
    let nachricht: CoachNachricht
    let person: Person
    /// Erste Antwort eines Blocks trägt Orb und Namen.
    let kopf: Bool

    private var eigene: Bool { nachricht.rolle == .du }

    var body: some View {
        Group {
            if eigene { eigeneBlase } else { antwort }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(eigene ? "Du" : "Coach"): \(nachricht.text)")
    }

    private var eigeneBlase: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 56)
            Text(CoachText.inline(nachricht.text))
                .font(.body)
                .foregroundStyle(Color.personText(person))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.person(person), in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22, bottomTrailingRadius: 6, topTrailingRadius: 22))
                .textSelection(.enabled)
        }
    }

    private var antwort: some View {
        VStack(alignment: .leading, spacing: 8) {
            if kopf {
                HStack(spacing: 8) {
                    CoachOrb(groesse: 20)
                    Text("Coach").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            inhalt
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 24)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private var inhalt: some View {
        let zeilen = CoachText.zeilen(nachricht.text)
        if zeilen.isEmpty {
            Text(nachricht.text).font(.body)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(zeilen.enumerated()), id: \.offset) { _, zeile in ansicht(zeile) }
            }
            .font(.body)
            .lineSpacing(2)
        }
    }

    @ViewBuilder
    private func ansicht(_ zeile: CoachText.Zeile) -> some View {
        switch zeile.art {
        case .absatz:
            Text(CoachText.inline(zeile.text))
        case .ueberschrift:
            Text(CoachText.inline(zeile.text)).font(.headline).padding(.top, 4)
        case .punkt:
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: "•").foregroundStyle(HabitFarbe.mint.farbe).accessibilityHidden(true)
                Text(CoachText.inline(zeile.text))
            }
        case .nummer(let n):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "\(n).").monospacedDigit().foregroundStyle(.secondary).frame(minWidth: 22, alignment: .trailing)
                Text(CoachText.inline(zeile.text))
            }
        }
    }
}
