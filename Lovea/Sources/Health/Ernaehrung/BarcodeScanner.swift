import SwiftUI
import VisionKit
import Vision

/// Barcode-Scanner für Lebensmittel: `DataScannerViewController`, wo verfügbar (nicht im Simulator,
/// nicht ohne Kamera-Erlaubnis), sonst nur die Texteingabe. Meldet den ersten erkannten Code über
/// `gefunden` und schließt sich selbst.
struct BarcodeScannerBlatt: View {
    let gefunden: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""

    private var kannScannen: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if kannScannen {
                    kamera
                } else {
                    ContentUnavailableView("Kein Kamerazugriff", systemImage: "camera.viewfinder",
                                           description: Text("Lovea braucht die Kamera, um Barcodes zu scannen."))
                    Button("Zu den Einstellungen") { einstellungenOeffnen() }
                        .buttonStyle(.bordered)
                }
                Spacer(minLength: 0)
                eingabe
            }
            .navigationTitle("Barcode scannen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
    }

    private var kamera: some View {
        ZStack {
            BarcodeKamera(gefunden: melden)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white, lineWidth: 3)
                .frame(width: 260, height: 150)
        }
        .overlay(alignment: .bottom) {
            Text("Barcode in den Rahmen halten")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.black.opacity(0.6), in: Capsule())
                .padding(.bottom, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .aspectRatio(3 / 4, contentMode: .fit)
        .padding(.horizontal, 16)
    }

    private var eingabe: some View {
        VStack(spacing: 8) {
            TextField("Code eintippen", text: $code)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
            Button("Suchen") { melden(code) }
                .buttonStyle(.borderedProminent)
                .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.bottom, 16)
    }

    private func melden(_ wert: String) {
        gefunden(wert)
        dismiss()
    }

    private func einstellungenOeffnen() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Kamera als `UIViewControllerRepresentable`. `startScanning()` erst, sobald die Ansicht auf dem
/// Bildschirm ist (Flag im Coordinator), nie in `makeUIViewController`.
private struct BarcodeKamera: UIViewControllerRepresentable {
    let gefunden: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .balanced, recognizesMultipleItems: false, isHighlightingEnabled: true)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        guard !context.coordinator.gestartet else { return }
        context.coordinator.gestartet = true
        try? uiViewController.startScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(gefunden: gefunden) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let gefunden: (String) -> Void
        var gestartet = false
        private var gemeldet = false

        init(gefunden: @escaping (String) -> Void) { self.gefunden = gefunden }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !gemeldet else { return }
            for item in addedItems {
                guard case .barcode(let barcode) = item, let wert = barcode.payloadStringValue else { continue }
                gemeldet = true
                gefunden(wert)
                break
            }
        }
    }
}
