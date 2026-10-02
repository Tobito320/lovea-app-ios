import SwiftUI
import UIKit

/// Suchfeld mit Treffern. Gespeichert wird nur Name, Koordinate und kurze Adresse.
struct OrtWahlZeile: View {
    @Binding var ort: PunktOrt?
    @State private var text: String
    @State private var modell = OrtSucheModell()
    @FocusState private var fokus: Bool

    init(ort: Binding<PunktOrt?>) {
        _ort = ort
        _text = State(initialValue: ort.wrappedValue?.name ?? "")
    }

    private var zeigeTreffer: Bool { fokus && text != ort?.name && !modell.treffer.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Ort suchen", text: $text)
                    .focused($fokus)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                if ort != nil || !text.isEmpty {
                    Button {
                        text = ""
                        ort = nil
                        modell.leeren()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ort entfernen")
                }
            }
            .padding(.vertical, 12)

            if zeigeTreffer {
                ForEach(modell.treffer, id: \.self) { treffer in
                    Divider()
                    Button { waehlen(treffer) } label: { zeile(treffer) }
                        .buttonStyle(.plain)
                }
            }
        }
        .task(id: text) {
            if text == ort?.name { modell.leeren(); return }
            await modell.suchen(text)
        }
    }

    private func zeile(_ treffer: PunktOrt) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.and.ellipse")
            Text(treffer.name).fontWeight(.semibold).lineLimit(1)
            if let adresse = treffer.adresse {
                Text(adresse).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            if treffer == ort { Image(systemName: "checkmark").foregroundStyle(.tint) }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func waehlen(_ treffer: PunktOrt) {
        ort = treffer
        text = treffer.name
        modell.leeren()
        fokus = false
    }
}

extension EnvironmentValues {
    /// Nur für die Render-Tafel: `ImageRenderer` zeichnet die Vorschau mit Buttons und Dialogen nicht.
    @Entry var ortVorschauEinfach: Bool = false
}

/// Kleine Karte als Schnappschuss mit Nadel, darunter "Karte zeigen" und "In Karten öffnen".
struct OrtVorschau: View {
    let ort: PunktOrt
    @Environment(\.colorScheme) private var schema
    @Environment(\.openURL) private var openURL
    @State private var bild: UIImage?
    @State private var zeigeKarte = false
    @State private var zeigeWahl = false

    @Environment(\.ortVorschauEinfach) private var einfach

    init(ort: PunktOrt) { self.ort = ort }

    /// Feste Höhe, damit die Karte in keinem Container ohne Breite oder Höhe landet; bis zum Schnappschuss grau.
    private var karte: some View {
        Color.secondary.opacity(0.12)
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .overlay {
                if let bild {
                    Image(uiImage: bild).resizable().scaledToFill()
                    Image(systemName: "mappin")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.red)
                        .offset(y: -15)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }

    var body: some View {
        if einfach { einfacheAnsicht } else { echteAnsicht }
    }

    /// Render-Tafel: nur Fläche und zwei Beschriftungen, kein Button, Dialog, Blatt oder Schnappschuss.
    private var einfacheAnsicht: some View {
        VStack(spacing: 8) {
            karte
            HStack(spacing: 0) {
                Label("Karte zeigen", systemImage: "map").frame(maxWidth: .infinity)
                Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 1, height: 24)
                Label("In Karten öffnen", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }
            .font(.subheadline)
            .foregroundStyle(.tint)
        }
    }

    private var echteAnsicht: some View {
        VStack(spacing: 8) {
            karte

            HStack(spacing: 0) {
                Button { zeigeKarte = true } label: {
                    Label("Karte zeigen", systemImage: "map").frame(maxWidth: .infinity)
                }
                Divider().frame(height: 24)
                Button(action: oeffnen) {
                    Label("In Karten öffnen", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
            }
            .font(.subheadline)
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        }
        .task(id: "\(OrtLinks.cacheSchluessel(ort))\(schema == .dark)") {
            bild = await OrtSchnappschuss.bild(fuer: ort, dunkel: schema == .dark)
        }
        .sheet(isPresented: $zeigeKarte) { OrtKartenBlatt(ort: ort) }
        .confirmationDialog("In Karten öffnen", isPresented: $zeigeWahl, titleVisibility: .visible) {
            Button("Apple Karten") { OrtOeffnen.apple(ort) }
            Button("Google Maps") { openURL(OrtLinks.googleMapsURL(ort)) }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    private func oeffnen() {
        if OrtOeffnen.googleDa(ort) { zeigeWahl = true } else { OrtOeffnen.apple(ort) }
    }
}
