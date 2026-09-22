import MetalKit
import UIKit

@MainActor
final class MetalCanvasView: MTKView, UIGestureRecognizerDelegate {
    private let store: DrawingStore
    private var canvasRenderer: MetalCanvasRenderer?
    private var predictedPoints: [StrokePoint] = []
    private var canvasTransform = CanvasTransform()

    init(store: DrawingStore) {
        self.store = store
        super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        isPaused = true
        enableSetNeedsDisplay = true
        preferredFramesPerSecond = 120
        isMultipleTouchEnabled = true
        canvasRenderer = MetalCanvasRenderer(view: self)
        delegate = canvasRenderer
        configureGestures()
        updateAppearance()
        refresh()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAppearance()
    }

    func refresh() {
        var preview = store.activeStroke
        if !predictedPoints.isEmpty { preview?.points.append(contentsOf: predictedPoints) }
        canvasRenderer?.update(
            document: store.document,
            activeLayerID: store.activeLayerID,
            previewStroke: preview,
            transform: canvasTransform
        )
        setNeedsDisplay()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.count == 1, let touch = touches.first, accepts(touch) else { return }
        if touch.type == .direct {
            let activeTouchCount = event?.allTouches?.filter {
                $0.phase != .ended && $0.phase != .cancelled
            }.count ?? 1
            guard activeTouchCount == 1 else { return }
        }
        predictedPoints.removeAll()
        store.beginStroke(at: drawingPoint(for: touch))
        refresh()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, accepts(touch) else { return }
        predictedPoints.removeAll()
        for sample in event?.coalescedTouches(for: touch) ?? [touch] {
            store.appendPoint(drawingPoint(for: sample))
        }
        predictedPoints = (event?.predictedTouches(for: touch) ?? []).map(drawingPoint)
        refresh()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        predictedPoints.removeAll()
        if let touch = touches.first, accepts(touch) {
            store.appendPoint(drawingPoint(for: touch))
            store.endStroke()
        }
        refresh()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        predictedPoints.removeAll()
        store.cancelStroke()
        refresh()
    }

    private func accepts(_ touch: UITouch) -> Bool {
        touch.type == .pencil || (touch.type == .direct && store.drawsWithFinger)
    }

    private func drawingPoint(for touch: UITouch) -> StrokePoint {
        let point = touch.location(in: self)
        let documentPoint = canvasTransform.documentPoint(fromScreen: point)
        let pressure = touch.maximumPossibleForce > 0 ? touch.force / touch.maximumPossibleForce : 1
        return StrokePoint(
            x: Double(documentPoint.x),
            y: Double(documentPoint.y),
            pressure: Double(max(pressure, 0.2)),
            timestamp: touch.timestamp
        )
    }

    private func configureGestures() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(didPinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)

        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(didRotate(_:)))
        rotation.delegate = self
        addGestureRecognizer(rotation)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pan.delegate = self
        addGestureRecognizer(pan)
    }

    @objc private func didPinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began { cancelDrawingForNavigation() }
        guard gesture.state == .began || gesture.state == .changed else { return }
        canvasTransform.zoom(by: gesture.scale, around: gesture.location(in: self))
        gesture.scale = 1
        refresh()
    }

    @objc private func didRotate(_ gesture: UIRotationGestureRecognizer) {
        if gesture.state == .began { cancelDrawingForNavigation() }
        guard gesture.state == .began || gesture.state == .changed else { return }
        canvasTransform.rotate(by: gesture.rotation, around: gesture.location(in: self))
        gesture.rotation = 0
        refresh()
    }

    @objc private func didPan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began { cancelDrawingForNavigation() }
        guard gesture.state == .began || gesture.state == .changed else { return }
        let translation = gesture.translation(in: self)
        canvasTransform.pan(by: translation)
        gesture.setTranslation(.zero, in: self)
        refresh()
    }

    private func cancelDrawingForNavigation() {
        predictedPoints.removeAll()
        store.cancelStroke()
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    private func updateAppearance() {
        let color = UIColor.systemBackground.resolvedColor(with: traitCollection)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        clearColor = MTLClearColor(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }
}
