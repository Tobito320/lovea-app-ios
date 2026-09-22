import MetalKit
import SwiftUI

struct ArtworkBrushPreview: UIViewRepresentable {
    @ObservedObject var session: DrawingSession

    func makeUIView(context: Context) -> BrushPreviewMetalView {
        BrushPreviewMetalView()
    }

    func updateUIView(_ view: BrushPreviewMetalView, context: Context) {
        view.show(
            color: session.color,
            width: session.brushWidth,
            opacity: session.brushOpacity,
            preset: session.brush,
            pressureControlsSize: session.pressureControlsSize,
            pressureControlsOpacity: session.pressureControlsOpacity,
            stabilizer: session.stabilizer
        )
    }
}

@MainActor
final class BrushPreviewMetalView: MTKView {
    private var artworkRenderer: ArtworkMetalRenderer?
    private var sample: MetalPaintStroke?
    private let sampleSize = CGSize(width: 300, height: 90)

    init() {
        super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
        framebufferOnly = true
        isPaused = true
        enableSetNeedsDisplay = true
        artworkRenderer = ArtworkMetalRenderer(view: self)
        delegate = artworkRenderer
        isUserInteractionEnabled = false
        accessibilityLabel = "Vorschau des aktuellen Pinsels"
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refresh()
    }

    func show(
        color: RGBAColor,
        width: Double,
        opacity: Double,
        preset: BrushPreset,
        pressureControlsSize: Bool,
        pressureControlsOpacity: Bool,
        stabilizer: Double
    ) {
        sample = MetalPaintStroke(
            points: [
                StrokePoint(x: 20, y: 58, pressure: 0.3),
                StrokePoint(x: 65, y: 38, pressure: 0.5),
                StrokePoint(x: 110, y: 30, pressure: 0.8),
                StrokePoint(x: 155, y: 48, pressure: 1),
                StrokePoint(x: 200, y: 55, pressure: 0.7),
                StrokePoint(x: 245, y: 35, pressure: 0.4),
                StrokePoint(x: 280, y: 30, pressure: 0.25)
            ],
            color: color,
            width: width,
            opacity: opacity,
            tool: .brush,
            brushPreset: preset.rawValue,
            pressureControlsSize: pressureControlsSize,
            pressureControlsOpacity: pressureControlsOpacity,
            stabilizer: stabilizer
        )
        refresh()
    }

    private func refresh() {
        guard let sample, bounds.width > 0, bounds.height > 0 else { return }
        var viewport = ArtworkCanvasViewport()
        viewport.fit(document: sampleSize, screen: bounds.size)
        artworkRenderer?.update(
            strokes: [sample],
            preview: nil,
            documentSize: sampleSize,
            viewport: viewport,
            activeOpacity: 1,
            activeBlendMode: .normal,
            activeTransform: LayerTransform()
        )
        setNeedsDisplay()
    }
}
