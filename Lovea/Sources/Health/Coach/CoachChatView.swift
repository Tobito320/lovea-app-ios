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

    private var modell: CoachModell { CoachModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        Group {
            if pausiert { pauseAnsicht } else { chat }
        }
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
        VStack(spacing: 0) {
            verlauf(modell.liste)
            Divider()
            unten
        }
    }

    private func verlauf(_ nachrichten: [CoachNachricht]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if nachrichten.isEmpty && !modell.sendet {
                        Text("Ich kenne deine Zahlen aus Training, Essen, Schritten und Gewicht. Frag mich etwas oder nimm eine Schnellfrage.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                    ForEach(nachrichten) { CoachBlase(nachricht: $0, person: ich) }
                    if modell.sendet { denkt }
                    Color.clear.frame(height: 1).id("ende")
                }
                .padding(16)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: nachrichten.count) { _, _ in proxy.scrollTo("ende", anchor: .bottom) }
            .onChange(of: modell.sendet) { _, _ in proxy.scrollTo("ende", anchor: .bottom) }
        }
    }

    private var denkt: some View {
        HStack {
            HStack(spacing: 8) {
                ProgressView()
                Text("Coach denkt nach").font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Spacer(minLength: 48)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Unten: Fehler, Schnellfragen, Eingabe

    private var unten: some View {
        VStack(spacing: 8) {
            if let fehler = modell.fehler { fehlerZeile(fehler) }
            schnellfragen
            eingabe
            Text("KI-Coach, kein Arzt")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }

    private func fehlerZeile(_ fehler: CoachFehler) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(HabitFarbe.amber.farbe)
            Text(fehler.text).font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            Button { modell.fehlerLoeschen() } label: {
                Image(systemName: "xmark").font(.footnote.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Hinweis schließen")
        }
        .padding(.leading, 12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var schnellfragen: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(CoachRegeln.schnellfragen, id: \.self) { frage in
                    Button { absenden(frage, ausFeld: false) } label: {
                        Text(frage)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(Color(uiColor: .secondarySystemBackground)))
                    }
                    .buttonStyle(.federnd)
                    .disabled(modell.sendet)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var kannSenden: Bool {
        !entwurf.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !modell.sendet
    }

    private var eingabe: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Frag den Coach", text: $entwurf, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onChange(of: entwurf) { _, neu in
                    if neu.count > CoachModell.maxZeichen { entwurf = String(neu.prefix(CoachModell.maxZeichen)) }
                }
            Button { absenden(entwurf, ausFeld: true) } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.federnd)
            .foregroundStyle(kannSenden ? Color.person(ich) : Color.secondary)
            .disabled(!kannSenden)
            .accessibilityLabel("Senden")
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

// MARK: - Blase

private struct CoachBlase: View {
    let nachricht: CoachNachricht
    let person: Person

    private var eigene: Bool { nachricht.rolle == .du }

    /// Das Modell antwortet gern mit **fett** und Listen; Zeilenumbrüche bleiben, ohne gültiges Markdown gilt der Rohtext.
    private var inhalt: AttributedString {
        let optionen = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: nachricht.text, options: optionen)) ?? AttributedString(nachricht.text)
    }

    var body: some View {
        HStack {
            if eigene { Spacer(minLength: 48) }
            Text(inhalt)
                .font(.body)
                .foregroundStyle(eigene ? Color.personText(person) : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(eigene ? Color.person(person) : Color(uiColor: .secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .textSelection(.enabled)
            if !eigene { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(eigene ? "Du" : "Coach"): \(nachricht.text)")
    }
}
