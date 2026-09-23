import AVFoundation
import CoreGraphics
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Pure-ish encoding helpers for Z-5.1 (photo/video), off the main actor. No `Raum`/`ChatModell`
/// access here — `MedienSenden.swift` wires the result into an upload + `nachricht.neu`.
enum MedienKodierung {
    struct Ergebnis { let original: URL; let klein: URL?; let breite: Double; let hoehe: Double; var dauer: Double? }

    private static let stagingDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Lovea/chat-hochladen", isDirectory: true)

    static func stagingURL(id: String, rolle: String, ext: String) -> URL {
        stagingDir.appendingPathComponent("\(id)-\(rolle).\(ext)")
    }

    @discardableResult
    static func schreibeStaging(_ daten: Data, id: String, rolle: String, ext: String) -> URL? {
        try? FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let url = stagingURL(id: id, rolle: rolle, ext: ext)
        guard (try? daten.write(to: url, options: .atomic)) != nil else { return nil }
        return url
    }

    /// Full-resolution original + a 1280px/JPEG-0.7 `klein` (Z-5.1). Call off the main actor.
    nonisolated static func foto(_ daten: Data, id: String) -> Ergebnis? {
        guard let quelle = CGImageSourceCreateWithData(daten as CFData, nil),
              let typ = CGImageSourceGetType(quelle) else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(quelle, 0, nil) as? [CFString: Any]
        let pixelWidth = (props?[kCGImagePropertyPixelWidth] as? Int) ?? 0
        let pixelHeight = (props?[kCGImagePropertyPixelHeight] as? Int) ?? 0
        let orientation = (props?[kCGImagePropertyOrientation] as? Int) ?? 1
        // EXIF orientation 5–8 swap width/height (rotated 90°/270°).
        let gedreht = (5...8).contains(orientation)
        let breite = Double(gedreht ? pixelHeight : pixelWidth)
        let hoehe = Double(gedreht ? pixelWidth : pixelHeight)

        let ext = UTType(typ as String)?.preferredFilenameExtension ?? "jpg"
        guard let originalURL = schreibeStaging(daten, id: id, rolle: "original", ext: ext) else { return nil }

        guard let thumb = CGImageSourceCreateThumbnailAtIndex(quelle, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1280,
        ] as CFDictionary),
            let kleinData = UIImage(cgImage: thumb).jpegData(compressionQuality: 0.7),
            let kleinURL = schreibeStaging(kleinData, id: id, rolle: "klein", ext: "jpg")
        else {
            return Ergebnis(original: originalURL, klein: nil, breite: breite, hoehe: hoehe, dauer: nil)
        }
        return Ergebnis(original: originalURL, klein: kleinURL, breite: breite, hoehe: hoehe, dauer: nil)
    }

    /// Target size for a scaled export: caps the long edge, keeps aspect, rounds to even pixels
    /// (video encoders need that). Pure — the one thing about video encoding worth a unit test.
    nonisolated static func skaliert(_ size: CGSize, langeKante: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0, langeKante > 0 else { return size }
        let faktor = min(1, langeKante / max(size.width, size.height))
        let w = max(2, (size.width * faktor / 2).rounded() * 2)
        let h = max(2, (size.height * faktor / 2).rounded() * 2)
        return CGSize(width: w, height: h)
    }

    /// 720p HEVC original + 480p `klein`, trimmed to 30s (Z-5.1).
    // ponytail: trims silently to the first 30s instead of opening the system video-trim editor —
    // that's a UIViewController flow (`UIVideoEditorController`) for one edge case. Upgrade path:
    // present it when `dauer > 30` and re-run this with the trimmed asset it hands back.
    static func video(_ quelle: URL, id: String) async -> Ergebnis? {
        let asset = AVURLAsset(url: quelle)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let naturalSize = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform),
              let volleDauer = try? await asset.load(.duration)
        else { return nil }

        let upright = CGSize(width: abs(naturalSize.applying(transform).width), height: abs(naturalSize.applying(transform).height))
        let bereich = CMTimeRange(start: .zero, duration: CMTime(seconds: min(volleDauer.seconds, 30), preferredTimescale: 600))

        let originalSize = skaliert(upright, langeKante: 1280)
        guard let originalURL = await exportiere(asset: asset, track: track, transform: transform, upright: upright, ziel: originalSize, zeit: bereich, id: id, rolle: "original")
        else { return nil }
        let kleinSize = skaliert(upright, langeKante: 480)
        let kleinURL = await exportiere(asset: asset, track: track, transform: transform, upright: upright, ziel: kleinSize, zeit: bereich, id: id, rolle: "klein")

        return Ergebnis(original: originalURL, klein: kleinURL, breite: Double(originalSize.width), hoehe: Double(originalSize.height), dauer: bereich.duration.seconds)
    }

    private static func exportiere(
        asset: AVURLAsset, track: AVAssetTrack, transform: CGAffineTransform, upright: CGSize,
        ziel: CGSize, zeit: CMTimeRange, id: String, rolle: String
    ) async -> URL? {
        guard upright.width > 0, upright.height > 0,
              let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHEVCHighestQuality)
        else { return nil }
        try? FileManager.default.createDirectory(at: stagingURL(id: id, rolle: rolle, ext: "mov").deletingLastPathComponent(), withIntermediateDirectories: true)
        let ausgabe = stagingURL(id: id, rolle: rolle, ext: "mov")
        try? FileManager.default.removeItem(at: ausgabe)
        session.outputURL = ausgabe
        session.outputFileType = .mov
        session.timeRange = zeit

        let komposition = AVMutableVideoComposition()
        komposition.renderSize = ziel
        komposition.frameDuration = CMTime(value: 1, timescale: 30)
        let anweisung = AVMutableVideoCompositionInstruction()
        anweisung.timeRange = zeit
        let ebene = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let skalierung = CGAffineTransform(scaleX: ziel.width / upright.width, y: ziel.height / upright.height)
        ebene.setTransform(transform.concatenating(skalierung), at: .zero)
        anweisung.layerInstructions = [ebene]
        komposition.instructions = [anweisung]
        session.videoComposition = komposition

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { continuation.resume() }
        }
        return session.status == .completed ? ausgabe : nil
    }
}
