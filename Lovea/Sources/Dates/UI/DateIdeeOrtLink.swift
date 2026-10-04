import SwiftUI
import UIKit

struct DatesAbschnittsTitel: View {
    let text: String

    var body: some View {
        Text(text.uppercased()).font(.caption.weight(.bold)).tracking(1).foregroundStyle(DatesStil.grau)
    }
}

/// Rand wie bei den Rose-Knöpfen im Entwurf.
private extension View {
    func dateRoseRand() -> some View {
        overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.loveaRose.opacity(0.4), lineWidth: 1))
    }
}

/// Ort am Blatt: Suchfeld mit Treffern (`OrtWahlZeile`, wie am Treffen-Punkt), darunter Adresse und Karte.
struct DateOrtAbschnitt: View {
    @Binding var ort: PunktOrt?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatesAbschnittsTitel(text: "Ort")
            OrtWahlZeile(ort: $ort)
                .padding(.horizontal, 14)
                .dateRoseRand()
            if let ort {
                if let adresse = ort.adresse { Text(adresse).font(.subheadline).foregroundStyle(.secondary) }
                if DateLogik.hatKoordinate(ort) { OrtVorschau(ort: ort) }
            }
        }
    }
}

struct DateLinkChip: View {
    let link: DateLink

    var body: some View {
        DatesChip(titel: DateLogik.chipText(link), symbol: DateIdeeBearbeitung.symbol(DateLogik.linkArt(link.url)))
    }
}

struct DateLinkNeuChip: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "plus").font(.caption2.weight(.bold))
            Text("Link").font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Color.loveaRose)
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .dateRoseRand()
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// Links am Blatt: Chips mit Domain, Tipp öffnet, Gedrückthalten bietet Löschen, "+ Link" öffnet die Eingabe.
struct DateLinkAbschnitt: View {
    @Binding var links: [DateLink]
    @Environment(\.openURL) private var openURL
    @State private var eingabeOffen = false
    @State private var text = ""
    @State private var fehler: String?
    @FocusState private var fokus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatesAbschnittsTitel(text: "Links")
            ZyklusFlussLayout {
                ForEach(links) { link in
                    Button { oeffnen(link) } label: { DateLinkChip(link: link) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { oeffnen(link) } label: { Label("Öffnen", systemImage: "arrow.up.right") }
                            Button(role: .destructive) { entfernen(link) } label: { Label("Löschen", systemImage: "trash") }
                        }
                        .accessibilityHint("Öffnet den Link")
                        .accessibilityAction(named: "Link löschen") { entfernen(link) }
                }
                Button {
                    eingabeOffen = true
                    fokus = true
                } label: { DateLinkNeuChip() }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Link hinzufügen")
            }
            if eingabeOffen { eingabe }
        }
    }

    private var eingabe: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Adresse des Links", text: $text)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($fokus)
                    .onSubmit(hinzufuegen)
                    .onChange(of: text) { fehler = nil }
                if text.isEmpty, UIPasteboard.general.hasStrings {
                    Button("Einfügen") {
                        text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                }
                Button("Hinzufügen", action: hinzufuegen)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 14)
            .dateRoseRand()
            if let fehler { Text(fehler).font(.footnote).foregroundStyle(.red) }
        }
    }

    private func hinzufuegen() {
        switch DateIdeeBearbeitung.linkAufnehmen(text, in: links) {
        case .neu(let link):
            links.append(link)
            text = ""
            fehler = nil
            eingabeOffen = false
        case .ungueltig: fehler = "Das ist keine Webadresse (http oder https)."
        case .doppelt: fehler = "Diesen Link gibt es schon."
        }
    }

    private func oeffnen(_ link: DateLink) {
        if let url = DateLogik.oeffnenURL(link) { openURL(url) }
    }

    private func entfernen(_ link: DateLink) {
        links.removeAll { $0.id == link.id }
    }
}
