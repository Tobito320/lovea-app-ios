import AVFoundation
import SwiftUI
import UIKit

/// Flattens the Snap editor's overlay (doodle + text + stickers) onto the captured photo/video
/// (Z-6.2). Manual `UIGraphicsImageRenderer`/`AVVideoCompositionCoreAnimationTool` compositing is
/// restricted to files named `*Export.swift` (mirrors Drawing's own export rule) — this is that file.
enum SnapExport {
    @MainActor
    static func foto(quelle: UIImage, linien: [SnapEditor.SnapLinie], sticker: [SnapEditor.SnapSticker], text: SnapEditor.SnapText) -> UIImage {
        let groesse = quelle.size
        let renderer = ImageRenderer(content: SnapUeberlagerung(linien: linien, sticker: sticker, text: text, groesse: groesse))
        renderer.scale = quelle.scale
        let overlayBild = renderer.uiImage

        let format = UIGraphicsImageRendererFormat()
        format.scale = quelle.scale
        return UIGraphicsImageRenderer(size: groesse, format: format).image { _ in
            quelle.draw(in: CGRect(origin: .zero, size: groesse))
            overlayBild?.draw(in: CGRect(origin: .zero, size: groesse))
        }
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
                    context.stroke(pfad, with: .color(linie.farbe), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
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
