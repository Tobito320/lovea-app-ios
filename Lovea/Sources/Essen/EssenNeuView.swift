import PhotosUI
import SwiftUI
import UIKit

/// Neue Mahlzeit (Foto -> KI -> prüfen und korrigieren -> speichern) oder bestehende bearbeiten.
/// Die KI schätzt Zutaten mit Gramm. Du korrigierst die Gramm, alles rechnet sofort neu.
struct EssenNeuView: View {
    private enum Phase { case wahl, laedt, ergebnis }

    @Environment(\.dismiss) private var dismiss

    private let bestehend: EssenMahlzeit?
    @State private var phase: Phase
    @State private var auswahl: PhotosPickerItem?
    @State private var bildDaten: Data?
    @State private var vorschau: UIImage?
    @State private var kameraOffen = false
    @State private var art: MahlzeitArt
    @State private var hinweis: String
    @State private var komponenten: [EssenKomponente]
    @State private var versteckt: [EssenVersteckt]
    @State private var versteckteZaehlen: Bool
    @State private var frage: String?
    @State private var bemerkung = ""
    @State private var kcalMin: Int?
    @State private var kcalMax: Int?
    @State private var urspruenglich: [UUID: Double]
    @State private var fehlerText: String?

    init(bestehend: EssenMahlzeit? = nil) {
        self.bestehend = bestehend
        _phase = State(initialValue: bestehend == nil ? .wahl : .ergebnis)
        _art = State(initialValue: bestehend?.art ?? MahlzeitArt.vorschlag())
        _hinweis = State(initialValue: bestehend?.hinweis ?? "")
        _komponenten = State(initialValue: bestehend?.komponenten ?? [])
        _versteckt = State(initialValue: bestehend?.versteckt ?? [])
        _versteckteZaehlen = State(initialValue: bestehend?.versteckteZaehlen ?? true)
        _urspruenglich = State(initialValue: Dictionary(uniqueKeysWithValues: (bestehend?.komponenten ?? []).map { ($0.id, $0.gramm) }))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .wahl: wahlAnsicht
                case .laedt: ladeAnsicht
                case .ergebnis: ergebnisAnsicht
                }
            }
            .navigationTitle(bestehend == nil ? "Neue Mahlzeit" : "Mahlzeit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                if phase == .ergebnis {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") { speichern() }.disabled(komponenten.isEmpty)
                    }
                }
            }
        }
        .onChange(of: auswahl) { _, neu in
            guard let neu else { return }
            Task {
                if let daten = try? await neu.loadTransferable(type: Data.self) { bildSetzen(daten) }
            }
        }
        .fullScreenCover(isPresented: $kameraOffen) {
            KameraPicker { daten in
                if let daten { bildSetzen(daten) }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Foto wählen

    private var wahlAnsicht: some View {
        Form {
            Section {
                if let vorschau {
                    Image(uiImage: vorschau)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Foto der Mahlzeit")
                }
                HStack(spacing: 12) {
                    Button {
                        kameraOffen = true
                    } label: {
                        Label("Kamera", systemImage: "camera")
                    }
                    .buttonStyle(.bordered)
                    PhotosPicker(selection: $auswahl, matching: .images) {
                        Label("Fotos", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                }
            }
            Section("Mahlzeit") {
                Picker("Art", selection: $art) {
                    ForEach(MahlzeitArt.allCases) { Text($0.titel).tag($0) }
                }
            }
            Section {
                TextField("Hinweis, zum Beispiel \"Hähnchen 200 g\"", text: $hinweis, axis: .vertical)
                    .lineLimit(1...3)
            } footer: {
                Text("Was du hier schreibst, hat Vorrang vor der Schätzung der KI.")
            }
            if let fehlerText {
                Section { Text(fehlerText).foregroundStyle(.red) }
            }
            Section {
                Button("Analysieren") { analysieren() }
                    .frame(maxWidth: .infinity)
                    .disabled(bildDaten == nil)
            } footer: {
                Text("Das Foto wird verkleinert und ohne Ort und Zeit an deinen Lovea-Server geschickt. Gespeichert wird nur auf diesem Gerät.")
            }
        }
    }

    private var ladeAnsicht: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Ich schaue mir dein Essen an …").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Ergebnis prüfen

    private var summeKcal: Int {
        let zutaten = komponenten.reduce(0) { $0 + $1.kcal }
        let extra = versteckteZaehlen ? versteckt.reduce(0) { $0 + $1.kcal } : 0
        return zutaten + extra
    }

    private var unveraendert: Bool {
        komponenten.allSatisfy { k in urspruenglich[k.id].map { abs($0 - k.gramm) < 1 } ?? false }
    }

    private var ergebnisAnsicht: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(summeKcal) kcal").font(.largeTitle.bold()).monospacedDigit()
                    if unveraendert, let kcalMin, let kcalMax, !versteckteZaehlen || versteckt.isEmpty {
                        Text("wahrscheinlich zwischen \(kcalMin) und \(kcalMax)").font(.caption).foregroundStyle(.secondary)
                    }
                    if !bemerkung.isEmpty { Text(bemerkung).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            if let frage {
                Section("Kurze Frage") { Text(frage) }
            }
            Section("Zutaten (Gramm anpassen)") {
                ForEach($komponenten) { $k in
                    zutatZeile($k)
                }
                .onDelete { komponenten.remove(atOffsets: $0) }
            }
            if !versteckt.isEmpty {
                Section {
                    Toggle(isOn: $versteckteZaehlen) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Versteckte Kalorien mitzählen")
                            Text(versteckt.map { "\($0.name) \(Int($0.gramm)) g (\($0.kcal) kcal)" }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Öl, Butter oder Soße sieht man auf dem Foto nicht. Schalte aus, wenn bei dir nichts davon drin ist.")
                }
            }
        }
    }

    private func zutatZeile(_ k: Binding<EssenKomponente>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(k.wrappedValue.name).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(k.wrappedValue.kcal) kcal").font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            }
            HStack {
                Stepper(value: k.gramm, in: 5...2000, step: 5) {
                    Text("\(Int(k.wrappedValue.gramm)) g").monospacedDigit()
                }
                Image(systemName: symbol(k.wrappedValue.sicherheit))
                    .foregroundStyle(farbe(k.wrappedValue.sicherheit))
                    .accessibilityLabel("Sicherheit: \(k.wrappedValue.sicherheit)")
            }
        }
    }

    private func symbol(_ sicherheit: String) -> String {
        switch sicherheit {
        case "hoch": "checkmark.circle.fill"
        case "niedrig": "questionmark.circle.fill"
        default: "circle.lefthalf.filled"
        }
    }

    private func farbe(_ sicherheit: String) -> Color {
        switch sicherheit {
        case "hoch": .green
        case "niedrig": .orange
        default: .secondary
        }
    }

    // MARK: - Aktionen

    private func bildSetzen(_ original: Data) {
        guard let klein = EssenBild.verkleinern(original) else {
            fehlerText = "Das Bild konnte nicht gelesen werden."
            return
        }
        fehlerText = nil
        bildDaten = klein
        vorschau = UIImage(data: klein)
    }

    private func analysieren() {
        guard let bild = bildDaten else { return }
        phase = .laedt
        fehlerText = nil
        let hinweisText = hinweis.trimmingCharacters(in: .whitespacesAndNewlines)
        let mahlzeit = art.rawValue
        Task {
            do {
                let a = try await KiClient.essen(bild: bild, hinweis: hinweisText, mahlzeit: mahlzeit)
                guard a.istEssen, !a.items.isEmpty else {
                    fehlerText = a.bemerkung.isEmpty ? "Auf dem Foto ist kein Essen zu erkennen." : a.bemerkung
                    phase = .wahl
                    return
                }
                komponenten = a.komponenten
                urspruenglich = Dictionary(uniqueKeysWithValues: a.komponenten.map { ($0.id, $0.gramm) })
                versteckt = a.versteckteListe
                versteckteZaehlen = true
                frage = a.frage
                bemerkung = a.bemerkung
                kcalMin = a.gesamt.kcalMin
                kcalMax = a.gesamt.kcalMax
                phase = .ergebnis
            } catch {
                fehlerText = (error as? LocalizedError)?.errorDescription ?? "Das hat nicht geklappt."
                phase = .wahl
            }
        }
    }

    private func speichern() {
        guard let ich = Raum.shared.ich else { return }
        var mahlzeit = bestehend ?? EssenMahlzeit(tag: Datum.text(Date()), zeit: Date(), art: art, komponenten: [])
        mahlzeit.art = art
        mahlzeit.komponenten = komponenten
        mahlzeit.versteckt = versteckt
        mahlzeit.versteckteZaehlen = versteckteZaehlen
        mahlzeit.hinweis = hinweis
        EssenStore.shared.speichern(mahlzeit, fuer: ich)
        // Nur echte Korrekturen lernen: was du geändert hast, nicht was die KI selbst geraten hat.
        let korrekturen = komponenten.compactMap { k -> KiKorrektur? in
            guard let vorher = urspruenglich[k.id], abs(vorher - k.gramm) >= 1 else { return nil }
            return KiKorrektur(name: k.name, gramm: k.gramm)
        }
        if !korrekturen.isEmpty {
            Task { await KiClient.korrigieren(korrekturen) }
        }
        dismiss()
    }
}

/// Kamera für ein Foto (UIImagePickerController). Ohne Kamera (Simulator) fällt es auf Fotos zurück.
struct KameraPicker: UIViewControllerRepresentable {
    let fertig: (Data?) -> Void
    @Environment(\.dismiss) private var dismiss

    init(fertig: @escaping (Data?) -> Void) { self.fertig = fertig }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Koordinator { Koordinator(eltern: self) }

    @MainActor
    final class Koordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let eltern: KameraPicker

        init(eltern: KameraPicker) { self.eltern = eltern }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let bild = info[.originalImage] as? UIImage
            eltern.fertig(bild?.jpegData(compressionQuality: 0.9))
            eltern.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            eltern.fertig(nil)
            eltern.dismiss()
        }
    }
}
