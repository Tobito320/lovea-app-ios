import SwiftUI

/// Spec 8.1 Nr. 3 / 8.3: kompakte Karte auf Home, öffnet die volle Ansicht (eine große Karte, letzte Fragen, Verlauf).
struct FrageDesTagesCard: View {
    let wir = WirModell.shared

    var body: some View {
        NavigationLink(value: FrageZiel()) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Frage des Tages", systemImage: "text.bubble.fill")
                    .font(.headline)
                    .foregroundStyle(Color.loveaRose)
                if let frage = wir.heute {
                    Text(frage.text)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(wir.meineAntwort(frage.id) == nil ? "Noch nicht beantwortet" : (wir.partnerAntwort(frage.id) == nil ? "Warte auf Antwort" : "Beide haben geantwortet"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct FrageZiel: Hashable {}

/// Eine große Karte für die heutige Frage, darunter dezent die letzten Fragen und „Alle Fragen".
struct FrageDesTagesView: View {
    let wir = WirModell.shared
    @State private var meineAntwort = ""
    @FocusState private var fokus: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let frage = wir.heute {
                    karte(frage)
                } else {
                    ContentUnavailableView("Heute keine Frage", systemImage: "heart")
                }
                letzteFragen
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Frage des Tages")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var kartenDunkel: Color { Color(red: 0x8E / 255, green: 0x1B / 255, blue: 0x3A / 255) }

    private func karte(_ frage: Frage) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "heart.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.9))
                .accessibilityHidden(true)
            Text(frage.text)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if let meine = wir.meineAntwort(frage.id) {
                VStack(spacing: 10) {
                    blase(name: "Du", text: meine, von: ich, rechts: true)
                    if let deine = wir.partnerAntwort(frage.id) {
                        blase(name: ich.partner.name, text: deine, von: ich.partner, rechts: false)
                    } else {
                        Text("Warte auf \(ich.partner.name)")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if wir.zustand.antworten[frage.id]?[ich.partner] != nil {
                        Text("\(ich.partner.name) hat schon geantwortet")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    TextField("Deine Antwort", text: $meineAntwort, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($fokus)
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Button {
                        wir.antworten(frage.id, text: meineAntwort)
                        meineAntwort = ""
                        fokus = false
                        Haptik.erfolg()
                    } label: {
                        Text("Antworten")
                            .font(.headline)
                            .foregroundStyle(kartenDunkel)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .opacity(meineAntwort.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    .disabled(meineAntwort.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.person(.annika), kartenDunkel],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .shadow(color: Color.loveaRose.opacity(0.25), radius: 16, y: 8)
        .animation(Feder.weich, value: wir.meineAntwort(frage.id))
    }

    private func blase(name: String, text: String, von: Person, rechts: Bool) -> some View {
        VStack(alignment: rechts ? .trailing : .leading, spacing: 3) {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text(text)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.person(von), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: rechts ? .trailing : .leading)
    }

    private var letzteFragen: some View {
        let letzte = Array(wir.fruehereFragen.prefix(3))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Letzte Fragen")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                NavigationLink {
                    FrageHistorieView()
                } label: {
                    Text("Alle Fragen")
                        .font(.subheadline)
                        .frame(minHeight: 44)
                }
                .tint(Color.loveaRose)
            }
            if letzte.isEmpty {
                Text("Hier erscheinen die Fragen, die ihr schon beantwortet habt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(letzte) { eintrag in
                            kleineKarte(eintrag)
                        }
                    }
                }
            }
        }
    }

    private func kleineKarte(_ eintrag: WirModell.FruehereFrage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eintrag.frage.text)
                .font(.subheadline.weight(.medium))
                .lineLimit(3)
            if let meine = eintrag.meine {
                Text(meine).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(14)
        .frame(width: 220, height: 120, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Alle bisherigen Fragen mit beiden Antworten, plus „Themen für später" (früher „Worüber wir noch reden wollen").
struct FrageHistorieView: View {
    let wir = WirModell.shared
    @State private var neuesThema = ""

    var body: some View {
        List {
            Section("Themen für später") {
                ForEach(wir.zustand.themen) { thema in
                    Button {
                        Raum.shared.senden("thema.setzen", ThemaOp(id: thema.id, text: thema.text, besprochen: thema.besprochen == nil ? Datum.text(Date()) : nil))
                    } label: {
                        HStack {
                            Image(systemName: thema.besprochen == nil ? "circle" : "checkmark.circle.fill")
                                .accessibilityHidden(true)
                            Text(thema.text)
                                .strikethrough(thema.besprochen != nil)
                            Spacer()
                        }
                        .foregroundStyle(thema.besprochen == nil ? .primary : .secondary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(thema.besprochen == nil ? "offen" : "besprochen")
                }
                HStack {
                    TextField("Neues Thema", text: $neuesThema)
                    Button("Hinzufügen") {
                        Raum.shared.senden("thema.setzen", ThemaOp(id: UUID().uuidString, text: neuesThema, besprochen: nil))
                        neuesThema = ""
                    }
                    .disabled(neuesThema.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section("Alle Fragen") {
                if wir.fruehereFragen.isEmpty {
                    Text("Noch keine früheren Fragen.").foregroundStyle(.secondary)
                }
                ForEach(wir.fruehereFragen) { eintrag in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(eintrag.frage.text).font(.subheadline.weight(.medium))
                        if let meine = eintrag.meine { Text("Du: \(meine)").font(.caption) }
                        if let deine = eintrag.deine {
                            Text("\((Raum.shared.ich ?? .ahmed).partner.name): \(deine)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Alle Fragen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ThemaOp: Codable { var id: String; var text: String; var besprochen: String? }
