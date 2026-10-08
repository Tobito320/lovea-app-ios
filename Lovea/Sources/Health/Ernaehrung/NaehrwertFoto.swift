import SwiftUI
import UIKit
import Vision

/// Liest eine Nährwert-Tabelle vom Foto (Vision auf dem Gerät, kein KI-Dienst). Erste Zahl je Zeile = pro 100 g.
enum NaehrwertLeser {
    static func parsen(_ zeilen: [String]) -> Naehrwerte? {
        func zahl(_ s: Substring) -> Double? { Double(s.replacingOccurrences(of: ",", with: ".")) }
        func ersteZahl(_ s: String, vor einheit: String? = nil) -> Double? {
            let re = einheit.map { "([0-9]+(?:[.,][0-9]+)?)\\s*\($0)" } ?? "([0-9]+(?:[.,][0-9]+)?)"
            guard let r = s.range(of: re, options: [.regularExpression, .caseInsensitive]) else { return nil }
            let treffer = s[r]
            guard let zr = treffer.range(of: "[0-9]+(?:[.,][0-9]+)?", options: .regularExpression) else { return nil }
            return zahl(treffer[zr])
        }
        let klein = zeilen.map { $0.lowercased() }
        func wert(_ woerter: [String], ohne: [String] = []) -> Double? {
            for (i, z) in klein.enumerated() where woerter.contains(where: z.contains) && !ohne.contains(where: z.contains) {
                if let x = ersteZahl(z, vor: "g") ?? ersteZahl(z) { return x }
                if i + 1 < klein.count, let x = ersteZahl(klein[i + 1]) { return x }
            }
            return nil
        }
        var kcal: Double?
        for (i, z) in klein.enumerated() {
            if let x = ersteZahl(z, vor: "kcal") { kcal = x; break }
            if i + 1 < klein.count, z.contains("energie") || z.contains("brennwert"), let x = ersteZahl(klein[i + 1], vor: "kcal") { kcal = x; break }
        }
        if kcal == nil, let kj = klein.lazy.compactMap({ ersteZahl($0, vor: "kj") }).first { kcal = kj / 4.184 }
        guard let kcal else { return nil }
        return Naehrwerte(kcal: kcal,
                          protein: wert(["eiweiß", "eiweiss", "protein"]) ?? 0,
                          kohlenhydrate: wert(["kohlenhydrat"]) ?? 0,
                          fett: wert(["fett"], ohne: ["gesättigt", "gesaettigt", "fettsäuren"]) ?? 0,
                          zucker: wert(["zucker"]),
                          ballaststoffe: wert(["ballaststoff"]),
                          salz: wert(["salz"]),
                          gesFett: wert(["gesättigt", "gesaettigt"]))
    }

    static func erkennen(_ bild: CGImage) async -> [String] {
        await withCheckedContinuation { fortsetzung in
            let anfrage = VNRecognizeTextRequest { req, _ in
                let zeilen = (req.results as? [VNRecognizedTextObservation] ?? []).compactMap { $0.topCandidates(1).first?.string }
                fortsetzung.resume(returning: zeilen)
            }
            anfrage.recognitionLevel = .accurate
            anfrage.recognitionLanguages = ["de-DE"]
            anfrage.usesLanguageCorrection = false
            do { try VNImageRequestHandler(cgImage: bild).perform([anfrage]) } catch { fortsetzung.resume(returning: []) }
        }
    }
}

/// Nährwert-Tabelle fotografieren (Kamera, `UIImagePickerController` wie `BarcodeScannerBlatt` es für
/// den Barcode über `DataScannerViewController` macht) und die erkannten Werte in einem Formular
/// prüfen, bevor sie als eigenes Lebensmittel gesichert werden.
struct NaehrwertFotoBlatt: View {
    let barcode: String
    let fertig: (Lebensmittel) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kameraOffen = true
    @State private var bild: UIImage?
    @State private var name = ""
    @State private var fehler = false
    @State private var kcal = ""
    @State private var protein = ""
    @State private var kohlenhydrate = ""
    @State private var fett = ""
    @State private var zucker = ""
    @State private var salz = ""

    private var kannSichern: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && ErnaehrungLogik.eingabe(kcal) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if let bild {
                    Section {
                        Image(uiImage: bild).resizable().scaledToFit().frame(maxHeight: 200)
                    }
                }
                if fehler {
                    Section {
                        Text("Bitte näher und gerade fotografieren")
                        Button("Nochmal") { erneutFotografieren() }
                    }
                }
                Section("Lebensmittel") {
                    TextField("Name", text: $name)
                }
                Section("Pro 100 g") {
                    zahlfeld("Kalorien (kcal)", $kcal)
                    zahlfeld("Eiweiß (g)", $protein)
                    zahlfeld("Kohlenhydrate (g)", $kohlenhydrate)
                    zahlfeld("Fett (g)", $fett)
                    zahlfeld("davon Zucker (g)", $zucker)
                    zahlfeld("Salz (g)", $salz)
                }
            }
            .navigationTitle("Nährwerte fotografieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { sichern() }.disabled(!kannSichern) }
            }
        }
        .fullScreenCover(isPresented: $kameraOffen) {
            NaehrwertKamera(aufgenommen: verarbeiten).ignoresSafeArea()
        }
    }

    private func zahlfeld(_ titel: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(titel)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
        }
    }

    /// Abbruch ohne Foto (erster Aufruf, noch kein Bild da) schließt das ganze Blatt; nach "Nochmal"
    /// bleibt das schon ausgefüllte Formular stehen.
    private func verarbeiten(_ aufgenommen: UIImage?) {
        kameraOffen = false
        guard let aufgenommen, let cg = aufgenommen.cgImage else {
            if bild == nil { dismiss() }
            return
        }
        bild = aufgenommen
        Task {
            let zeilen = await NaehrwertLeser.erkennen(cg)
            let n = NaehrwertLeser.parsen(zeilen)
            fehler = n == nil
            uebernehmen(n)
        }
    }

    private func uebernehmen(_ n: Naehrwerte?) {
        guard let n else { return }
        kcal = ErnaehrungLogik.zahl(n.kcal)
        protein = ErnaehrungLogik.zahl(n.protein)
        kohlenhydrate = ErnaehrungLogik.zahl(n.kohlenhydrate)
        fett = ErnaehrungLogik.zahl(n.fett)
        zucker = n.zucker.map(ErnaehrungLogik.zahl) ?? ""
        salz = n.salz.map(ErnaehrungLogik.zahl) ?? ""
    }

    private func erneutFotografieren() {
        fehler = false
        kameraOffen = true
    }

    private func sichern() {
        guard let kcalWert = ErnaehrungLogik.eingabe(kcal) else { return }
        let w = Naehrwerte(kcal: kcalWert, protein: ErnaehrungLogik.eingabe(protein) ?? 0,
                          kohlenhydrate: ErnaehrungLogik.eingabe(kohlenhydrate) ?? 0, fett: ErnaehrungLogik.eingabe(fett) ?? 0,
                          zucker: ErnaehrungLogik.eingabe(zucker), salz: ErnaehrungLogik.eingabe(salz))
        let l = Lebensmittel(id: "eigen-\(UUID().uuidString)", name: name.trimmingCharacters(in: .whitespaces), barcode: barcode, pro100: w)
        ErnaehrungModell.shared.eigenesSichern(l)
        Haptik.erfolg()
        dismiss()
        fertig(l)
    }
}

/// Kamera-Aufnahme über `UIImagePickerController` (`.camera`), analog zu `BarcodeKamera` in
/// `BarcodeScanner.swift`, die dort `DataScannerViewController` genauso als
/// `UIViewControllerRepresentable` einbindet. `nil` bei Abbruch.
struct NaehrwertKamera: UIViewControllerRepresentable {
    let aufgenommen: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(aufgenommen: aufgenommen) }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let aufgenommen: (UIImage?) -> Void
        init(aufgenommen: @escaping (UIImage?) -> Void) { self.aufgenommen = aufgenommen }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            aufgenommen(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            aufgenommen(nil)
        }
    }
}
