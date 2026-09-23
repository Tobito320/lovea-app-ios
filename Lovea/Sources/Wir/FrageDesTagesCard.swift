import SwiftUI

/// Spec 8.1 Nr. 3 / 8.3: kompakte Karte auf Home, öffnet die volle Ansicht mit eigener Antwort,
/// „Worüber wir noch reden wollen" und früheren Fragen.
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

struct FrageDesTagesView: View {
    let wir = WirModell.shared
    @State private var meineAntwort = ""
    @State private var neueEigeneFrage = ""
    @State private var neuesThema = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let frage = wir.heute {
                    heutigeFrage(frage)
                }

                eigeneFragen

                themen

                fruehereFragen
            }
            .padding()
        }
        .navigationTitle("Frage des Tages")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func heutigeFrage(_ frage: Frage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(frage.text)
                .font(.title3.weight(.semibold))
            if let meine = wir.meineAntwort(frage.id) {
                Text(meine)
                    .font(.body)
                if let deine = wir.partnerAntwort(frage.id) {
                    Divider()
                    Text("\((Raum.shared.ich ?? .ahmed).partner.name)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(deine)
                        .font(.body)
                } else {
                    Text("Warte auf Antwort")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                TextField("Deine Antwort", text: $meineAntwort, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Antworten") {
                    wir.antworten(frage.id, text: meineAntwort)
                    meineAntwort = ""
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.loveaRose)
                .disabled(meineAntwort.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var eigeneFragen: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Eigene Fragen")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(wir.zustand.eigeneFragen) { frage in
                VStack(alignment: .leading, spacing: 2) {
                    Text(frage.text).font(.subheadline)
                    Text(frage.von.name).font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack {
                TextField("Eigene Frage stellen", text: $neueEigeneFrage)
                    .textFieldStyle(.roundedBorder)
                Button("Stellen") {
                    wir.eigeneFrageStellen(neueEigeneFrage)
                    neueEigeneFrage = ""
                }
                .disabled(neueEigeneFrage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var themen: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Worüber wir noch reden wollen")
                .font(.headline)
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
                    .textFieldStyle(.roundedBorder)
                Button("Hinzufügen") {
                    Raum.shared.senden("thema.setzen", ThemaOp(id: UUID().uuidString, text: neuesThema, besprochen: nil))
                    neuesThema = ""
                }
                .disabled(neuesThema.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var fruehereFragen: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frühere Fragen")
                .font(.headline)
            ForEach(wir.fruehereFragen) { eintrag in
                VStack(alignment: .leading, spacing: 2) {
                    Text(eintrag.frage.text).font(.subheadline.weight(.medium))
                    if let meine = eintrag.meine { Text(meine).font(.caption) }
                    if let deine = eintrag.deine { Text(deine).font(.caption).foregroundStyle(.secondary) }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct ThemaOp: Codable { var id: String; var text: String; var besprochen: String? }
