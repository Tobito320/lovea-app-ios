import CoreImage
import CoreVideo
import UIKit
import Vision

/// "Sticker aus Fotos" (Z-5.3): cuts the main subject out with Vision's foreground-instance mask
/// and returns a transparent PNG. Runs off the main actor — mask generation is real CPU work.
enum StickerErstellung {
    static func freistellen(_ daten: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            guard let uiImage = UIImage(data: daten), let cgImage = uiImage.cgImage else { return nil }
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation(uiImage.imageOrientation))
            let request = VNGenerateForegroundInstanceMaskRequest()
            do {
                try handler.perform([request])
                guard let observation = request.results?.first else { return nil }
                let maske = try observation.generateMaskedImage(ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: true)
                return png(from: maske)
            } catch {
                return nil
            }
        }.value
    }

    private static func png(from pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage).pngData()
    }

    private static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

/// Own sticker list (Z-5.3): "eigene Sticker" = every sticker this person has sent, plus any saved
/// here before sending (cut from a photo, or "Als Sticker speichern" from the Drawing Studio).
@MainActor
enum EigeneSticker {
    private static let listURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Lovea/eigene-sticker.json")

    static func gespeicherte() -> [String] {
        guard let data = try? Data(contentsOf: listURL) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    static func hinzufuegen(medienId: String) {
        var liste = gespeicherte()
        guard !liste.contains(medienId) else { return }
        liste.append(medienId)
        try? FileManager.default.createDirectory(at: listURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(liste) else { return }
        try? data.write(to: listURL, options: .atomic)
    }

    /// Hook for the Drawing Studio's "Als Sticker speichern" (Z-5.3) — report: Level-2 calls this
    /// with its transparent PNG export.
    static func hinzufuegen(png: Data) async {
        guard let id = await ChatMedien.stickerHochladen(png: png) else { return }
        hinzufuegen(medienId: id)
    }

    static func alle(ich: Person) -> [String] {
        let gesendet = ChatModell.shared.nachrichten.compactMap { $0.von == ich ? $0.sticker?.medienId : nil }
        var alle = gespeicherte()
        for id in gesendet where !alle.contains(id) { alle.append(id) }
        return alle
    }
}
