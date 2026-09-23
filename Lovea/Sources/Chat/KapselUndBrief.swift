import SwiftUI

/// Z-27.2: Zeitkapsel und Liebesbrief. Verschlossene Kapsel mit Countdown (`ChatNachrichtRow`),
/// Brief mit Siegel und Öffnen-Animation. Composer-Einstieg: `KapselBriefBlatt` (in `ChatEingabeleiste`).
struct KapselVerschlossenBlase: View {
    let oeffnetAm: String
    let von: Person

    private var tageBis: Int { max(Datum.tageZwischen(Datum.text(Date()), oeffnetAm), 0) }

    private var countdown: String {
        switch tageBis {
        case 0: "öffnet sich heute"
        case 1: "öffnet sich morgen"
        default: "öffnet sich in \(tageBis) Tagen"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill").font(.title2)
            Text("Zeitkapsel").font(.subheadline.weight(.semibold))
            Text(countdown).font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: 160, height: 110)
        .foregroundStyle(Color.personText(von))
        .background(Color.person(von), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Zeitkapsel, \(countdown)")
    }
}

/// Sealed until tapped; opens with a small spring pop, in place (no sheet) — the text then stays
/// visible for the rest of the conversation, like any other message.
struct BriefBlase: View {
    let titel: String
    let text: String
    let von: Person
    @State private var geoeffnet = false

    var body: some View {
        Group {
            if geoeffnet {
                VStack(alignment: .leading, spacing: 6) {
                    Label(titel, systemImage: "envelope.open.fill").font(.headline)
                    Text(text)
                }
                .padding(10)
                .foregroundStyle(Color.personText(von))
                .background(Color.person(von), in: RoundedRectangle(cornerRadius: 18))
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                Button {
                    ChatHaptik.mittel()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { geoeffnet = true }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "envelope.fill").font(.title2)
                        Text("Brief").font(.subheadline.weight(.semibold))
                        Text("„\(titel)“").font(.caption).lineLimit(1)
                    }
                    .frame(width: 160, height: 110)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.personText(von))
                .background(Color.person(von), in: RoundedRectangle(cornerRadius: 18))
                .accessibilityLabel("Brief „\(titel)“")
                .accessibilityHint("Öffnen")
            }
        }
    }
}

/// Small "just opened" marker above a capsule's now-visible text, with a one-shot pop each time the
/// row appears. // ponytail: replays the pop on every appearance (e.g. scrolling past it again), not
/// only the very first time it unlocked — a persisted "seen" flag would fix that, not worth it yet.
struct KapselGeoeffnetKennzeichen: View {
    @State private var sichtbar = false

    var body: some View {
        Label("Zeitkapsel geöffnet", systemImage: "lock.open.fill")
            .font(.caption2.weight(.semibold))
            .scaleEffect(sichtbar ? 1 : 0.5)
            .opacity(sichtbar ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { sichtbar = true } }
    }
}

/// Composer sheet (Z-27.2), reached from `ChatEingabeleiste`'s attachment row: choose Zeitkapsel or
/// Brief, then a short form. Sending clears the sheet like any other compose flow.
struct KapselBriefBlatt: View {
    let onFertig: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var art = Art.kapsel
    @State private var text = ""
    @State private var titel = ""
    @State private var oeffnetAm = Date().addingTimeInterval(86_400)

    private enum Art: String, CaseIterable { case kapsel = "Zeitkapsel", brief = "Brief" }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Art", selection: $art) {
                    ForEach(Art.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                if art == .kapsel {
                    Section("Öffnet am") {
                        DatePicker("Öffnet am", selection: $oeffnetAm, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                    }
                } else {
                    Section("Titel") {
                        TextField("z. B. Für dich", text: $titel)
                    }
                }
                Section(art == .kapsel ? "Nachricht" : "Brief") {
                    TextField("Text", text: $text, axis: .vertical).lineLimit(5...12)
                }
            }
            .navigationTitle(art.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Senden") { senden() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (art == .brief && titel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
        }
        .presentationDetents([.large])
    }

    private func senden() {
        switch art {
        case .kapsel: ChatModell.shared.kapselSenden(text: text, oeffnetAm: oeffnetAm)
        case .brief: ChatModell.shared.briefSenden(titel: titel, text: text)
        }
        ChatHaptik.leicht()
        onFertig()
        dismiss()
    }
}

/// Chat-tab start screen sections (Spec 2): "Zeitkapseln" (own + partner's, locked ones show their
/// countdown) and "Briefbox". Both only appear when there's something — the surrounding `List` in
/// `ChatTab.swift` already only inserts this row when it renders non-empty content.
/// // ponytail: tapping opens the conversation but doesn't scroll to the exact message — that jump
/// target lives as private `@State` inside `Unterhaltung`; upgrade if Ahmed wants the precise jump.
struct KapselnUndBriefeSektion: View {
    let modell: ChatModell
    let ich: Person
    @Binding var offen: Bool

    private var kapseln: [ChatModell.Nachricht] { modell.nachrichten.filter { $0.kapsel != nil && !$0.geloescht }.sorted { $0.zeit > $1.zeit } }
    private var briefe: [ChatModell.Nachricht] { modell.nachrichten.filter { $0.brief != nil && !$0.geloescht }.sorted { $0.zeit > $1.zeit } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !kapseln.isEmpty { kapselReihe }
            if !briefe.isEmpty { briefBox }
        }
    }

    private var kapselReihe: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Zeitkapseln").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(kapseln) { n in kapselKachel(n) }
                }
            }
        }
    }

    @ViewBuilder
    private func kapselKachel(_ n: ChatModell.Nachricht) -> some View {
        if let kapsel = n.kapsel {
            Button { ChatHaptik.leicht(); offen = true } label: {
                if ChatModell.verschlossen(n) {
                    KapselVerschlossenBlase(oeffnetAm: kapsel.oeffnetAm, von: n.von)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "lock.open.fill").font(.title2)
                        Text("Zeitkapsel").font(.subheadline.weight(.semibold))
                        Text("geöffnet").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(width: 160, height: 110)
                    .foregroundStyle(Color.personText(n.von))
                    .background(Color.person(n.von), in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var briefBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Briefbox").font(.headline)
            ForEach(briefe) { n in
                Button { ChatHaptik.leicht(); offen = true } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text(n.brief?.titel ?? "").lineLimit(1)
                        Spacer()
                        Text(n.von == ich ? "Du" : n.von.name).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
