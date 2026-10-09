import SwiftUI

/// "Öffne, wenn ..."-Briefe. Oben die versiegelten Umschläge für mich, darunter die, die ich geschrieben habe.
struct BriefeView: View {
    let speicher = BriefeSpeicher.shared
    @State private var lesen: Brief?
    @State private var schreiben = false

    var body: some View {
        List {
            let erhalten = speicher.erhalten
            let geschrieben = speicher.geschrieben
            if erhalten.isEmpty && geschrieben.isEmpty {
                ContentUnavailableView(
                    "Noch keine Briefe",
                    systemImage: "envelope",
                    description: Text("Schreib einen Brief, den sie genau dann öffnet, wenn sie ihn braucht.")
                )
                .listRowBackground(Color.clear)
            }
            if !erhalten.isEmpty {
                Section("Für dich") {
                    ForEach(erhalten) { brief in
                        Button { lesen = brief } label: { BriefZeile(brief: brief, stand: speicher.stand, meine: false) }
                            .buttonStyle(.plain)
                    }
                }
            }
            if !geschrieben.isEmpty {
                Section("Von dir") {
                    ForEach(geschrieben) { brief in
                        Button { lesen = brief } label: { BriefZeile(brief: brief, stand: speicher.stand, meine: true) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Briefe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { schreiben = true } label: { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel("Neuer Brief")
            }
        }
        .sheet(item: $lesen) { brief in BriefLesenBlatt(brief: brief) }
        .sheet(isPresented: $schreiben) { BriefSchreibenBlatt() }
    }
}

/// Wachs-Siegel: roter Kreis mit Herz und feinem Rand.
struct BriefSiegel: View {
    var groesse: CGFloat = 44
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(red: 0.86, green: 0.2, blue: 0.3), Color(red: 0.6, green: 0.08, blue: 0.18)],
                                 center: .topLeading, startRadius: 2, endRadius: groesse))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5).padding(groesse * 0.1))
            .overlay(Image(systemName: "heart.fill").font(.system(size: groesse * 0.4)).foregroundStyle(.white.opacity(0.85)))
            .frame(width: groesse, height: groesse)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .accessibilityHidden(true)
    }
}

private struct BriefZeile: View {
    let brief: Brief
    let stand: BriefeStand
    let meine: Bool

    var body: some View {
        let offen = BriefeLogik.geoeffnetAm(brief, stand)
        HStack(spacing: 14) {
            if offen == nil {
                BriefSiegel()
            } else {
                Image(systemName: "envelope.open.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(brief.titel).font(.headline).multilineTextAlignment(.leading)
                Text(untertitel(offen)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .frame(minHeight: 56)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint(offen == nil && !meine ? "Versiegelt. Zum Öffnen tippen." : "")
    }

    private func untertitel(_ offen: Date?) -> String {
        if meine, let a = brief.ankunft, BriefeLogik.unterwegs(brief) { return "Unterwegs, kommt am \(NaeheDatum.kurz(a)) an" }
        if let offen { return meine ? "Geöffnet am \(NaeheDatum.kurz(offen))" : "Geöffnet" }
        return meine ? "Noch versiegelt" : "Versiegelt von \(brief.von.name)"
    }
}

// MARK: - Lesen und Öffnen

struct BriefLesenBlatt: View {
    let brief: Brief
    let speicher = BriefeSpeicher.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Absender liest seinen eigenen Brief immer offen. Die Empfängerin siegelt auf, falls noch nicht geöffnet.
    @State private var offen: Bool
    @State private var klappe = false

    init(brief: Brief) {
        self.brief = brief
        let ich = BriefeSpeicher.shared.ich
        _offen = State(initialValue: brief.von == ich || BriefeSpeicher.shared.stand.geoeffnet[brief.id] != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if offen { brieftext } else { umschlag }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(offen ? "" : "Versiegelt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }

    private var umschlag: some View {
        VStack(spacing: 24) {
            Text(brief.titel).font(.title2.weight(.semibold)).multilineTextAlignment(.center)
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                Image(systemName: "envelope.fill").resizable().scaledToFit().padding(40).foregroundStyle(Color.accentColor.opacity(0.12))
                BriefSiegel(groesse: 64)
                    .scaleEffect(klappe ? 0.2 : 1)
                    .opacity(klappe ? 0 : 1)
                    .rotation3DEffect(.degrees(klappe ? 80 : 0), axis: (x: 1, y: 0, z: 0))
            }
            .frame(height: 180)
            .padding(.horizontal, 32)
            Button("Siegel brechen", action: aufmachen)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(klappe)
            Text("Von \(brief.von.name)").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.top, 40)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .onTapGesture(perform: aufmachen)
        .accessibilityAction(named: "Siegel brechen", aufmachen)
    }

    private var brieftext: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(brief.titel).font(.title3.weight(.semibold))
            if !brief.text.isEmpty {
                Text(brief.text).font(.body).lineSpacing(4).textSelection(.enabled)
            }
            if let sprache = brief.sprache {
                NaeheAbspielen(medienId: sprache, dauer: brief.dauer ?? 0, pegel: brief.pegel ?? [])
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            Divider()
            Text("Von \(brief.von.name), geschrieben am \(NaeheDatum.kurz(brief.zeit))")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let am = speicher.stand.geoeffnet[brief.id], brief.von == speicher.ich {
                Label("Geöffnet am \(NaeheDatum.kurz(am))", systemImage: "envelope.open")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(16)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
    }

    private func aufmachen() {
        guard !offen, !klappe else { return }
        Haptik.mittel()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Feder.weich) { klappe = true }
        speicher.oeffnen(brief)
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 550))
            Haptik.erfolg()
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Feder.federnd) { offen = true }
        }
    }
}

// MARK: - Schreiben

private struct BriefSchreibenBlatt: View {
    let speicher = BriefeSpeicher.shared
    @Environment(\.dismiss) private var dismiss
    @State private var titel = ""
    @State private var text = ""
    @State private var steuerung = AufnahmeSteuerung()
    @State private var aufnahme: SprachEntwurf?
    @State private var sendet = false
    @State private var mikroFehler = false
    @State private var langsam = false
    @State private var tage = 2

    private var gueltig: Bool {
        BriefeLogik.titel(fuer: titel) != nil && (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aufnahme != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(BriefeLogik.vorschlaege, id: \.self) { v in
                        Button { Haptik.auswahl(); titel = v } label: {
                            HStack {
                                Text("Öffne, wenn \(v)").foregroundStyle(.primary).multilineTextAlignment(.leading)
                                Spacer()
                                if titel == v { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                            }
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("Öffne, wenn").foregroundStyle(.secondary)
                        TextField("du ...", text: $titel)
                    }
                } header: {
                    Text("Wann soll sie ihn öffnen?")
                } footer: {
                    Text("Such einen Satz aus oder schreib einen eigenen.")
                }

                Section("Brief") {
                    TextEditor(text: $text).frame(minHeight: 160)
                }

                Section {
                    Toggle("Langsam senden", isOn: $langsam)
                    if langsam {
                        Stepper("Kommt in \(tage) \(tage == 1 ? "Tag" : "Tagen") an", value: $tage, in: 1...3)
                    }
                } footer: {
                    Text("Der Brief reist per Flugzeug und kommt erst nach 1 bis 3 Tagen im Briefkasten an.")
                }

                Section("Stimme (optional)") {
                    if let aufnahme {
                        NaeheAbspielen(medienId: "entwurf-" + aufnahme.url.lastPathComponent, dauer: aufnahme.dauer, pegel: aufnahme.pegel, lokal: aufnahme.url)
                        Button("Aufnahme löschen", role: .destructive) {
                            steuerung.verwerfen()
                            self.aufnahme = nil
                        }
                    } else {
                        Button { Task { await umschalten() } } label: {
                            Label(steuerung.laeuft ? "Stopp  \(zeit(steuerung.dauer))" : "Aufnehmen",
                                  systemImage: steuerung.laeuft ? "stop.circle.fill" : "mic.fill")
                                .foregroundStyle(steuerung.laeuft ? Color.red : Color.accentColor)
                                .frame(minHeight: 44)
                        }
                        if mikroFehler { Text("Mikrofon nicht erlaubt.").font(.footnote).foregroundStyle(.red) }
                    }
                }
            }
            .navigationTitle("Neuer Brief")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { steuerung.verwerfen(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if sendet { ProgressView() } else { Button("Versiegeln") { Task { await versiegeln() } }.disabled(!gueltig) }
                }
            }
            .interactiveDismissDisabled(steuerung.laeuft || sendet)
        }
    }

    private func umschalten() async {
        mikroFehler = false
        if steuerung.laeuft {
            aufnahme = await steuerung.zusammenfuegen()
        } else {
            let ok = await steuerung.start()
            mikroFehler = !ok
        }
    }

    private func versiegeln() async {
        sendet = true
        var medienId: String?
        if let aufnahme { medienId = await ChatMedien.entwurfSprachHochladen(aufnahme.url) }
        if speicher.schreiben(titel: titel, text: text, sprache: medienId, dauer: medienId == nil ? nil : aufnahme?.dauer, pegel: medienId == nil ? nil : aufnahme?.pegel, ankunft: langsam ? BriefeLogik.ankunft(tage: tage, ab: Date()) : nil) != nil {
            steuerung.zuruecksetzen()
            Haptik.erfolg()
            dismiss()
        } else {
            sendet = false
            Haptik.warnung()
        }
    }

    private func zeit(_ s: TimeInterval) -> String { String(format: "%d:%02d", Int(s) / 60, Int(s) % 60) }
}
