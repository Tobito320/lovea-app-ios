import AVFoundation
import CoreMedia
import QuartzCore
import SwiftUI
import UIKit

/// Flattens the Snap editor's overlay (doodle + text + stickers) onto the captured photo/video
/// (Z-6.2). Manual `UIGraphicsImageRenderer`/`AVVideoCompositionCoreAnimationTool` compositing is
/// restricted to files named `*Export.swift` (mirrors Drawing's own export rule) — this is that file.
enum SnapExport {
    /// Capped to the same long edge Z-5.1's `klein` derives from — flattening a full-resolution
    /// (often 12+ MP) photo on the main thread would freeze the UI for real (global.md: "Main
    /// Thread frei"), and nothing about a Snap needs the camera's native resolution.
    /// Only the SwiftUI overlay render (`ImageRenderer`, main-actor API) stays on the main actor;
    /// compositing and the JPEG encode run detached (Z-16.2).
    @MainActor
    static func foto(quelle: UIImage, linien: [SnapEditor.SnapLinie], sticker: [SnapEditor.SnapSticker], text: SnapEditor.SnapText) async -> Data? {
        let groesse = MedienKodierung.skaliert(quelle.size, langeKante: 2048)
        let renderer = ImageRenderer(content: SnapUeberlagerung(linien: linien, sticker: sticker, text: text, groesse: groesse))
        renderer.scale = 1
        let overlayBild = renderer.uiImage

        return await Task.detached(priority: .userInitiated) { () -> Data? in
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let flach = UIGraphicsImageRenderer(size: groesse, format: format).image { _ in
                quelle.draw(in: CGRect(origin: .zero, size: groesse))
                overlayBild?.draw(in: CGRect(origin: .zero, size: groesse))
            }
            return flach.jpegData(compressionQuality: 0.85)
        }.value
    }

    /// Burns one static overlay image onto every frame via `AVVideoCompositionCoreAnimationTool` —
    /// doodle/text/stickers don't animate, so a single flattened `CALayer` held for the whole
    /// duration is simpler and more robust than re-driving SwiftUI per frame.
    ///
    /// `@MainActor` (like `foto` above): `sticker` holds `UIImage`, not `Sendable` — staying on one
    /// actor for the whole function avoids ever having to prove that crossing a boundary is safe.
    /// The actual encode work still runs on `AVAssetExportSession`'s own queue either way; nothing
    /// here blocks the main thread beyond waiting on that callback.
    @MainActor
    static func video(quelle: URL, linien: [SnapEditor.SnapLinie], sticker: [SnapEditor.SnapSticker], text: SnapEditor.SnapText) async -> URL? {
        let asset = AVURLAsset(url: quelle)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let naturalSize = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform),
              let dauer = try? await asset.load(.duration)
        else { return nil }

        let upright = CGSize(width: abs(naturalSize.applying(transform).width), height: abs(naturalSize.applying(transform).height))
        guard upright.width > 0, upright.height > 0 else { return nil }
        let overlayBild = ImageRenderer(content: SnapUeberlagerung(linien: linien, sticker: sticker, text: text, groesse: upright)).uiImage

        let komposition = AVMutableVideoComposition()
        komposition.renderSize = upright
        komposition.frameDuration = CMTime(value: 1, timescale: 30)

        let bereich = CMTimeRange(start: .zero, duration: dauer)
        let anweisung = AVMutableVideoCompositionInstruction()
        anweisung.timeRange = bereich
        let ebene = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        ebene.setTransform(transform, at: .zero)
        anweisung.layerInstructions = [ebene]
        komposition.instructions = [anweisung]

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: upright)
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: upright)
        overlayLayer.contents = overlayBild?.cgImage
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: upright)
        // Core Animation's own coordinate space is Y-up; `SnapUeberlagerung`'s `.position(x:y:)`
        // (like every other SwiftUI/UIKit layout) is Y-down — without this, the overlay composites
        // upside down (a well-known `AVVideoCompositionCoreAnimationTool` gotcha).
        parentLayer.isGeometryFlipped = true
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)
        komposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        session.outputURL = ziel
        session.outputFileType = .mov
        session.timeRange = bereich
        session.videoComposition = komposition

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { continuation.resume() }
        }
        return session.status == .completed ? ziel : nil
    }
}

/// Static re-render of the editor's overlay at a given pixel size, used only for flattening —
/// same fraction→pixel math as the live editor's interactive layer, just without the gestures.
private struct SnapUeberlagerung: View {
    let linien: [SnapEditor.SnapLinie]
    let sticker: [SnapEditor.SnapSticker]
    let text: SnapEditor.SnapText
    let groesse: CGSize

    var body: some View {
        ZStack {
            Canvas { context, _ in
                for linie in linien {
                    var pfad = Path()
                    let punkte = linie.punkte.map { CGPoint(x: $0.x * groesse.width, y: $0.y * groesse.height) }
                    guard let erster = punkte.first else { continue }
                    pfad.move(to: erster)
                    for punkt in punkte.dropFirst() { pfad.addLine(to: punkt) }
                    context.stroke(pfad, with: .color(linie.farbe), style: StrokeStyle(lineWidth: groesse.width * SnapEditor.doodleLinienbreite, lineCap: .round, lineJoin: .round))
                }
            }
            ForEach(sticker) { element in
                Image(uiImage: element.bild).resizable().scaledToFit()
                    .frame(width: groesse.width * 0.28)
                    .position(x: element.x * groesse.width, y: element.y * groesse.height)
            }
            if !text.text.isEmpty {
                Text(text.text)
                    .font(.system(size: groesse.width * 0.07, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 3)
                    .scaleEffect(text.skala)
                    .position(x: groesse.width / 2, y: text.y * groesse.height)
            }
        }
        .frame(width: groesse.width, height: groesse.height)
    }
}
