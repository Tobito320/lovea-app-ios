import SwiftUI
import UIKit

/// A sample stroke drawn with the real engine and stamper, so the preview matches the canvas.
struct ArtworkBrushPreview: View {
    let preset: BrushPreset
    let color: RGBAColor
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color.clear
            }
        }
        .accessibilityHidden(true)
        .task(id: "\(preset.rawValue)\(color.hex)") {
            image = await Self.render(preset, color: color)
        }
    }

    @MainActor private static let scratchLibrary = ArtworkLibrary(
        rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("brush-preview", isDirectory: true)
    )

    @MainActor
    static func render(_ preset: BrushPreset, color: RGBAColor) async -> UIImage? {
        let document = ArtworkDocument.new(name: "", projectID: nil, format: .custom, width: 240, height: 48, background: .transparent)
        guard let engine = try? CanvasEngine(document: document, library: scratchLibrary, budgetBytes: 16 << 20),
              let layer = document.layers.first else { return nil }
        await engine.loading?.value
        let settings = BrushSettings(
            preset: preset,
            size: preset == .pixel ? 6 : min(max(preset.defaultWidth, 8), 22),
            opacity: preset.defaultOpacity,
            color: color,
            pressureSize: preset.pressureControlsSize,
            pressureOpacity: preset.pressureControlsOpacity,
            stabilizer: 0,
            isEraser: false
        )
        let inputs = (0...40).map { step -> StrokeInput in
            let t = Double(step) / 40
            return StrokeInput(location: CGPoint(x: 16 + t * 208, y: 24 + sin(t * .pi * 2) * 10), pressure: 0.25 + 0.75 * sin(t * .pi))
        }
        engine.beginStroke(inputs[0], settings: settings, layerID: layer.id)
        engine.continueStroke(Array(inputs.dropFirst()), predicted: [])
        engine.endStroke()
        return await engine.flattenedImage()
    }
}
