import AVFoundation
import CoreImage
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
    static func foto(quelle: UIImage, linien: [SnapEditor.SnapLinie], sticker: [SnapEditor.SnapSticker], text: SnapEditor.SnapText, filter: SnapFilter, filterStaerke: Double = 1) async -> Data? {
        let groesse = MedienKodierung.skaliert(quelle.size, langeKante: 2048)
        let renderer = ImageRenderer(content: SnapUeberlagerung(linien: linien, sticker: sticker, text: text, groesse: groesse))
        renderer.scale = 1
        let overlayBild = renderer.uiImage

        return await Task.detached(priority: .userInitiated) { () -> Data? in
            let basis = Self.gefiltertesBild(quelle: quelle, filter: filter, groesse: groesse, staerke: filterStaerke) ?? quelle
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let flach = UIGraphicsImageRenderer(size: groesse, format: format).image { _ in
                basis.draw(in: CGRect(origin: .zero, size: groesse))
                overlayBild?.draw(in: CGRect(origin: .zero, size: groesse))
            }
            return flach.jpegData(compressionQuality: 0.85)
        }.value
    }

    /// Filter vor dem Overlay anwenden (Anforderung: Filter zuerst, Doodle/Text/Sticker obendrauf).
    /// `.original` übersprungen — identisch zum Quellbild, ein Render weniger.
    private static func gefiltertesBild(quelle: UIImage, filter: SnapFilter, groesse: CGSize, staerke: Double) -> UIImage? {
        guard filter != .original else { return nil }
        // Erst aufrecht in die Zielgröße zeichnen: `CIImage(image:)` ignoriert `imageOrientation`,
        // das Kamerabild kam dann mit Filter um 90° gedreht und verzerrt an (Ahmed, 01.10., iPad).
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let aufrecht = UIGraphicsImageRenderer(size: groesse, format: format).image { _ in
            quelle.draw(in: CGRect(origin: .zero, size: groesse))
        }
        guard let cgAufrecht = aufrecht.cgImage else { return nil }
        let gefiltert = filter.anwenden(auf: CIImage(cgImage: cgAufrecht), staerke: staerke)
        guard let cgBild = SnapFilterKontext.shared.context.createCGImage(gefiltert, from: gefiltert.extent) else { return nil }
        return UIImage(cgImage: cgBild)
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
    static func video(quelle: URL, linien: [SnapEditor.SnapLinie], sticker: [SnapEditor.SnapSticker], text: SnapEditor.SnapText, filter: SnapFilter, filterStaerke: Double = 1) async -> URL? {
        // Most snaps have no doodle/sticker/text/filter — nothing to burn in, so skip the full-quality
        // `AVAssetExportSession` pass entirely. For a 19s gallery video that pass alone was the
        // biggest single delay before the Snap editor could dismiss (Z-Report Kamera).
        guard !linien.isEmpty || !sticker.isEmpty || !text.text.isEmpty || filter != .original else { return quelle }

        // Filter zuerst, eigener einfacher Pass (CI-Filter pro Frame über `applyingCIFiltersWithHandler`).
        // Der bestehende Overlay-Pass unten läuft danach unverändert auf dem gefilterten Clip weiter.
        // ponytail: zwei einfache Pässe statt eines eigenen `AVVideoCompositing`, das CI-Filter und
        // CALayer-Overlay in einem Durchgang mischt — kostet bei Filter+Overlay zusammen (selten: Filter
        // UND Doodle/Text/Sticker) einen zweiten verlustbehafteten Encode. Upgrade-Pfad, falls das stört:
        // eine eigene `AVVideoCompositing`-Klasse, die pro Frame erst den CI-Filter rendert und dann das
        // Overlay zeichnet (ersetzt `applyingCIFiltersWithHandler` UND `AVVideoCompositionCoreAnimationTool`).
        // Schalter "Videos schneller senden": derselbe Deckel (720p) wie `MedienKodierung.video`s
        // eigener Export danach — ohne das hier hat ein Snap mit Filter/Doodle/Text/Sticker zwei
        // volle Kodierungen in Originalauflösung mit `HighestQuality` hintereinander (diese hier,
        // dann noch mal beim Senden), bevor der Editor überhaupt zumacht. Mit dem Deckel ist diese
        // Kodierung selbst kleiner UND das Ergebnis trifft beim Senden oft schon `videoPlan`s
        // "unverändert"-Pfad (≤1280 Kante, ≤5 Mbit/s), die zweite Kodierung entfällt dann ganz.
        let schnell = MedienKodierung.videoSchnell()
        let preset = schnell ? AVAssetExportPreset1280x720 : AVAssetExportPresetHighestQuality

        var quelle = quelle
        var zwischenDatei: URL?
        if filter != .original {
            guard let gefiltert = await Self.gefiltertesVideo(quelle: quelle, filter: filter, preset: preset, staerke: filterStaerke) else { return nil }
            quelle = gefiltert
            zwischenDatei = gefiltert
        }
        guard !linien.isEmpty || !sticker.isEmpty || !text.text.isEmpty else { return quelle }

        let asset = AVURLAsset(url: quelle)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let naturalSize = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform),
              let dauer = try? await asset.load(.duration)
        else { return nil }

        let upright = CGSize(width: abs(naturalSize.applying(transform).width), height: abs(naturalSize.applying(transform).height))
        guard upright.width > 0, upright.height > 0 else { return nil }
        let zielGroesse = schnell ? MedienKodierung.skaliert(upright, langeKante: 1280) : upright
        let skalierung = CGAffineTransform(scaleX: zielGroesse.width / upright.width, y: zielGroesse.height / upright.height)
        let overlayBild = ImageRenderer(content: SnapUeberlagerung(linien: linien, sticker: sticker, text: text, groesse: zielGroesse)).uiImage

        let komposition = AVMutableVideoComposition()
        komposition.renderSize = zielGroesse
        komposition.frameDuration = CMTime(value: 1, timescale: 30)

        let bereich = CMTimeRange(start: .zero, duration: dauer)
        let anweisung = AVMutableVideoCompositionInstruction()
        anweisung.timeRange = bereich
        let ebene = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        ebene.setTransform(transform.concatenating(skalierung), at: .zero)
        anweisung.layerInstructions = [ebene]
        komposition.instructions = [anweisung]

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: zielGroesse)
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: zielGroesse)
        overlayLayer.contents = overlayBild?.cgImage
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: zielGroesse)
        // Core Animation's own coordinate space is Y-up; `SnapUeberlagerung`'s `.position(x:y:)`
        // (like every other SwiftUI/UIKit layout) is Y-down — without this, the overlay composites
        // upside down (a well-known `AVVideoCompositionCoreAnimationTool` gotcha).
        parentLayer.isGeometryFlipped = true
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)
        komposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)

        // Sicherheitsnetz ohne Gerätetest (wie `MedienKodierung.exportiere`): kennt das Gerät das
        // 720p-Preset für dieses Asset nicht, einmal mit `HighestQuality` probieren statt aufzugeben.
        guard let session = AVAssetExportSession(asset: asset, presetName: preset)
            ?? (preset != AVAssetExportPresetHighestQuality ? AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) : nil)
        else { return nil }
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        session.outputURL = ziel
        session.outputFileType = .mov
        session.timeRange = bereich
        session.videoComposition = komposition

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { continuation.resume() }
        }
        // Zwischendatei des Filter-Passes wird nie wieder gebraucht, sobald der Overlay-Pass fertig ist.
        if let zwischenDatei { try? FileManager.default.removeItem(at: zwischenDatei) }
        return session.status == .completed ? ziel : nil
    }

    /// Eigener Export-Pass, der nur den Filter brennt (kein Overlay) — Baustein für `video(…)` oben.
    /// `preset`: schnell-aware (siehe `video(…)`), mit demselben Sicherheitsnetz auf `HighestQuality`.
    @MainActor
    private static func gefiltertesVideo(quelle: URL, filter: SnapFilter, preset: String, staerke: Double) async -> URL? {
        let asset = AVURLAsset(url: quelle)
        guard let komposition = await filter.videoKomposition(fuer: asset, staerke: staerke) else { return nil }
        guard let session = AVAssetExportSession(asset: asset, presetName: preset)
            ?? (preset != AVAssetExportPresetHighestQuality ? AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) : nil)
        else { return nil }
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        session.outputURL = ziel
        session.outputFileType = .mov
        session.videoComposition = komposition
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { continuation.resume() }
        }
        return session.status == .completed ? ziel : nil
    }
}

/// Static re-render of the editor's overlay at a given pixel size, used only for flattening —
/// same fraction→pixel math as the live editor's interactive layer, just without the gestures.
struct SnapUeberlagerung: View {
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
                    .frame(width: groesse.width * 0.28 * element.skala)
                    .rotationEffect(.degrees(element.winkel))
                    .position(x: element.x * groesse.width, y: element.y * groesse.height)
            }
            if !text.text.isEmpty {
                SnapTextAnzeige(text: text, breite: groesse.width)
                    .rotationEffect(.degrees(text.winkel))
                    .position(x: text.x * groesse.width, y: text.y * groesse.height)
            }
        }
        .frame(width: groesse.width, height: groesse.height)
    }
}
