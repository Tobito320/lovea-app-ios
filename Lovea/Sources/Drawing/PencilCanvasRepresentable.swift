import Combine
import PencilKit
import SwiftUI

@MainActor
final class PencilCanvasController: ObservableObject {
    weak var canvasView: PKCanvasView?

    func undo() {
        canvasView?.undoManager?.undo()
    }

    func redo() {
        canvasView?.undoManager?.redo()
    }

    func resetView(animated: Bool = true) {
        guard let canvasView else { return }
        canvasView.setZoomScale(1, animated: animated)
        canvasView.setContentOffset(.zero, animated: animated)
    }
}

struct PencilCanvasRepresentable: UIViewRepresentable {
    let drawing: PKDrawing
    let canvasSize: CGSize
    let tool: StudioTool
    let brush: BrushPreset
    let color: RGBAColor
    let brushWidth: Double
    let brushOpacity: Double
    let drawsWithFinger: Bool
    let rulerActive: Bool
    let isLocked: Bool
    let backgroundImage: UIImage?
    let foregroundImage: UIImage?
    let controller: PencilCanvasController
    let onDrawingChanged: (PKDrawing) -> Void
    let onCanvasTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView(frame: .zero)
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.contentSize = canvasSize
        canvas.minimumZoomScale = 0.15
        canvas.maximumZoomScale = 8
        canvas.bouncesZoom = true
        canvas.alwaysBounceHorizontal = true
        canvas.alwaysBounceVertical = true
        canvas.drawing = drawing
        context.coordinator.installLayerViews(in: canvas, size: canvasSize)
        context.coordinator.installTapGesture(in: canvas)
        controller.canvasView = canvas
        applyConfiguration(to: canvas, coordinator: context.coordinator)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        controller.canvasView = canvas
        if canvas.contentSize != canvasSize {
            canvas.contentSize = canvasSize
            context.coordinator.resizeLayerViews(to: canvasSize)
        }
        if canvas.drawing.dataRepresentation() != drawing.dataRepresentation() {
            context.coordinator.isApplyingExternalDrawing = true
            canvas.drawing = drawing
            context.coordinator.isApplyingExternalDrawing = false
        }
        applyConfiguration(to: canvas, coordinator: context.coordinator)
        context.coordinator.updateLayerImages(background: backgroundImage, foreground: foregroundImage)
        context.coordinator.keepOverlayOrder(in: canvas)
    }

    private func applyConfiguration(to canvas: PKCanvasView, coordinator: Coordinator) {
        canvas.drawingPolicy = drawsWithFinger ? .anyInput : .pencilOnly
        canvas.isRulerActive = rulerActive
        canvas.isUserInteractionEnabled = !isLocked
        let usesTapTool = tool == .fill || tool == .eyedropper
        canvas.drawingGestureRecognizer.isEnabled = !usesTapTool && !isLocked
        coordinator.tapRecognizer?.isEnabled = usesTapTool && !isLocked

        switch tool {
        case .brush:
            let inkColor = color.uiColor.withAlphaComponent(CGFloat(min(max(brushOpacity, 0.05), 1)))
            canvas.tool = PKInkingTool(
                brush.inkType,
                color: inkColor,
                width: CGFloat(min(max(brushWidth, 1), 180))
            )
        case .eraser:
            canvas.tool = PKEraserTool(.vector)
        case .lasso:
            canvas.tool = PKLassoTool()
        case .fill, .eyedropper:
            canvas.tool = PKLassoTool()
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvasRepresentable
        var isApplyingExternalDrawing = false
        var tapRecognizer: UITapGestureRecognizer?
        private let backgroundView = UIImageView()
        private let foregroundView = UIImageView()

        init(parent: PencilCanvasRepresentable) {
            self.parent = parent
            super.init()
            backgroundView.contentMode = .scaleToFill
            foregroundView.contentMode = .scaleToFill
            backgroundView.isUserInteractionEnabled = false
            foregroundView.isUserInteractionEnabled = false
        }

        func installLayerViews(in canvas: PKCanvasView, size: CGSize) {
            backgroundView.frame = CGRect(origin: .zero, size: size)
            foregroundView.frame = CGRect(origin: .zero, size: size)
            backgroundView.image = parent.backgroundImage
            foregroundView.image = parent.foregroundImage
            canvas.insertSubview(backgroundView, at: 0)
            canvas.addSubview(foregroundView)
            keepOverlayOrder(in: canvas)
        }

        func installTapGesture(in canvas: PKCanvasView) {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.isEnabled = false
            canvas.addGestureRecognizer(recognizer)
            tapRecognizer = recognizer
        }

        func resizeLayerViews(to size: CGSize) {
            backgroundView.frame = CGRect(origin: .zero, size: size)
            foregroundView.frame = CGRect(origin: .zero, size: size)
        }

        func updateLayerImages(background: UIImage?, foreground: UIImage?) {
            backgroundView.image = background
            foregroundView.image = foreground
        }

        func keepOverlayOrder(in canvas: PKCanvasView) {
            canvas.sendSubviewToBack(backgroundView)
            canvas.bringSubviewToFront(foregroundView)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingExternalDrawing else { return }
            parent.onDrawingChanged(canvasView.drawing)
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let canvas = recognizer.view as? PKCanvasView else { return }
            parent.onCanvasTap(recognizer.location(in: canvas))
        }
    }
}
