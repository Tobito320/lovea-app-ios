import Combine
import MetalKit
import UIKit

/// Keeps document coordinates independent of the screen size and orientation.
struct ArtworkCanvasViewport {
    private(set) var scale: CGFloat = 1
    private(set) var rotation: CGFloat = 0
    private(set) var offset: CGPoint = .zero
    private var fittedScale: CGFloat = 1

    mutating func fit(document: CGSize, screen: CGSize) {
        guard document.width > 0, document.height > 0,
              screen.width > 0, screen.height > 0 else { return }
        fittedScale = min(screen.width / document.width, screen.height / document.height) * 0.94
        scale = fittedScale
        rotation = 0
        offset = CGPoint(
            x: (screen.width - document.width * scale) / 2,
            y: (screen.height - document.height * scale) / 2
        )
    }

    func screenPoint(_ point: CGPoint) -> CGPoint {
        let x = point.x * scale
        let y = point.y * scale
        return CGPoint(
            x: x * cos(rotation) - y * sin(rotation) + offset.x,
            y: x * sin(rotation) + y * cos(rotation) + offset.y
        )
    }

    func documentPoint(_ point: CGPoint) -> CGPoint {
        let x = point.x - offset.x
        let y = point.y - offset.y
        return CGPoint(
            x: (x * cos(rotation) + y * sin(rotation)) / scale,
            y: (-x * sin(rotation) + y * cos(rotation)) / scale
        )
    }

    mutating func zoom(by factor: CGFloat, around focus: CGPoint) {
        guard factor.isFinite, factor > 0 else { return }
        let anchored = documentPoint(focus)
        scale = min(max(scale * factor, fittedScale * 0.2), fittedScale * 20)
        reanchor(anchored, at: focus)
    }

    mutating func rotate(by angle: CGFloat, around focus: CGPoint) {
        guard angle.isFinite else { return }
        let anchored = documentPoint(focus)
        rotation = atan2(sin(rotation + angle), cos(rotation + angle))
        reanchor(anchored, at: focus)
    }

    mutating func pan(by distance: CGPoint) {
        guard distance.x.isFinite, distance.y.isFinite else { return }
        offset.x += distance.x
        offset.y += distance.y
    }

    private mutating func reanchor(_ point: CGPoint, at focus: CGPoint) {
        let mapped = screenPoint(point)
        offset.x += focus.x - mapped.x
        offset.y += focus.y - mapped.y
    }
}

@MainActor
final class ArtworkMetalCanvasController: ObservableObject {
    weak var canvasView: ArtworkMetalCanvasView?
    weak var session: DrawingSession?

    func undo() { session?.undo() }
    func redo() { session?.redo() }
    func resetView() { canvasView?.resetView() }
}

@MainActor
final class ArtworkMetalCanvasView: MTKView, UIGestureRecognizerDelegate {
    private struct ImageVersion: Equatable {
        var documentID: UUID
        var activeLayerID: UUID
        var layers: [ArtworkLayer]
        var background: CanvasBackground
    }

    private weak var session: DrawingSession?
    private var artworkRenderer: ArtworkMetalRenderer?
    private var viewport = ArtworkCanvasViewport()
    private var fittedBounds: CGSize = .zero
    private var fittedDocument: CGSize = .zero
    private var imageVersion: ImageVersion?
    private var predictedPoints: [StrokePoint] = []
    private weak var drawingTouch: UITouch?

    init() {
        super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        isPaused = true
        enableSetNeedsDisplay = true
        preferredFramesPerSecond = 120
        isMultipleTouchEnabled = true
        artworkRenderer = ArtworkMetalRenderer(view: self)
        delegate = artworkRenderer
        configureGestures()
        updateAppearance()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fitIfNeeded()
        refresh()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAppearance()
        setNeedsDisplay()
    }

    func configure(
        session: DrawingSession,
        lower: UIImage?,
        legacy: UIImage?,
        upper: UIImage?,
        alphaMask: UIImage?,
        clippingMask: UIImage?
    ) {
        self.session = session
        let size = session.canvasSize
        if fittedDocument != size {
            fittedDocument = size
            fittedBounds = .zero
        }
        if let layer = session.activeLayer {
            let version = ImageVersion(
                documentID: session.document.id,
                activeLayerID: layer.id,
                layers: session.document.layers,
                background: session.document.background
            )
            if imageVersion != version {
                artworkRenderer?.setImages(
                    lower: lower,
                    legacy: legacy,
                    upper: upper,
                    alphaMask: alphaMask,
                    clippingMask: clippingMask
                )
                imageVersion = version
            }
        }
        fitIfNeeded()
        refresh()
    }

    func resetView() {
        guard let session else { return }
        viewport.fit(document: session.canvasSize, screen: bounds.size)
        refresh()
    }

    func refresh() {
        guard let session, let layer = session.activeLayer else { return }
        var preview = session.activeMetalStroke
        if !predictedPoints.isEmpty { preview?.points.append(contentsOf: predictedPoints) }
        artworkRenderer?.update(
            strokes: session.metalStrokes(for: layer.id),
            preview: preview,
            documentSize: session.canvasSize,
            viewport: viewport,
            activeOpacity: layer.opacity,
            activeBlendMode: layer.blendMode,
            activeTransform: layer.transform
        )
        setNeedsDisplay()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let session, session.canDraw, session.tool == .brush || session.tool == .eraser,
              touches.count == 1, let touch = touches.first, accepts(touch, session: session) else { return }
        let touchCount = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled }.count ?? 1
        guard touch.type == .pencil || touchCount == 1 else { return }
        predictedPoints.removeAll()
        drawingTouch = touch
        session.beginMetalStroke(at: drawingPoint(for: touch))
        refresh()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, touch === drawingTouch, let session else { return }
        predictedPoints.removeAll()
        for sample in event?.coalescedTouches(for: touch) ?? [touch] {
            session.appendMetalStrokePoint(drawingPoint(for: sample))
        }
        predictedPoints = (event?.predictedTouches(for: touch) ?? []).map(drawingPoint)
        refresh()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let session else { return }
        if touch === drawingTouch {
            predictedPoints.removeAll()
            drawingTouch = nil
            session.appendMetalStrokePoint(drawingPoint(for: touch))
            session.endMetalStroke()
        } else if touches.count == 1,
                  session.canDraw,
                  (session.tool == .fill || session.tool == .eyedropper),
                  touch.type == .direct || touch.type == .pencil {
            session.handleCanvasTap(viewport.documentPoint(touch.location(in: self)))
        }
        refresh()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelActiveStroke()
    }

    private func accepts(_ touch: UITouch, session: DrawingSession) -> Bool {
        touch.type == .pencil || (touch.type == .direct && session.drawsWithFinger)
    }

    private func drawingPoint(for touch: UITouch) -> StrokePoint {
        let transformedPoint = viewport.documentPoint(touch.location(in: self))
        let point = inverseActiveTransform(transformedPoint)
        let pressure = touch.maximumPossibleForce > 0 ? touch.force / touch.maximumPossibleForce : 1
        return StrokePoint(
            x: Double(point.x),
            y: Double(point.y),
            pressure: Double(max(pressure, 0.1)),
            timestamp: touch.timestamp
        )
    }

    private func inverseActiveTransform(_ point: CGPoint) -> CGPoint {
        guard let session else { return point }
        let transform = session.activeLayer?.transform ?? LayerTransform()
        let center = CGPoint(x: session.canvasSize.width / 2, y: session.canvasSize.height / 2)
        let x = point.x - center.x - CGFloat(transform.offsetX)
        let y = point.y - center.y - CGFloat(transform.offsetY)
        let angle = CGFloat(transform.rotation)
        let rotatedX = x * cos(angle) + y * sin(angle)
        let rotatedY = -x * sin(angle) + y * cos(angle)
        let scaleX = CGFloat(max(transform.scale, 0.001) * (transform.flipX ? -1 : 1))
        let scaleY = CGFloat(max(transform.scale, 0.001) * (transform.flipY ? -1 : 1))
        return CGPoint(x: center.x + rotatedX / scaleX, y: center.y + rotatedY / scaleY)
    }

    private func fitIfNeeded() {
        guard let session, bounds.size.width > 0, bounds.size.height > 0 else { return }
        guard fittedBounds != bounds.size else { return }
        fittedBounds = bounds.size
        viewport.fit(document: session.canvasSize, screen: bounds.size)
    }

    private func cancelActiveStroke() {
        predictedPoints.removeAll()
        drawingTouch = nil
        session?.cancelMetalStroke()
        refresh()
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

        let undoTap = UITapGestureRecognizer(target: self, action: #selector(didUndoTap(_:)))
        undoTap.numberOfTouchesRequired = 2
        undoTap.cancelsTouchesInView = false
        addGestureRecognizer(undoTap)

        let redoTap = UITapGestureRecognizer(target: self, action: #selector(didRedoTap(_:)))
        redoTap.numberOfTouchesRequired = 3
        redoTap.cancelsTouchesInView = false
        addGestureRecognizer(redoTap)
    }

    @objc private func didPinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began { cancelActiveStroke() }
        guard gesture.state == .began || gesture.state == .changed else { return }
        viewport.zoom(by: gesture.scale, around: gesture.location(in: self))
        gesture.scale = 1
        refresh()
    }

    @objc private func didRotate(_ gesture: UIRotationGestureRecognizer) {
        if gesture.state == .began { cancelActiveStroke() }
        guard gesture.state == .began || gesture.state == .changed else { return }
        viewport.rotate(by: gesture.rotation, around: gesture.location(in: self))
        gesture.rotation = 0
        refresh()
    }

    @objc private func didPan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began { cancelActiveStroke() }
        guard gesture.state == .began || gesture.state == .changed else { return }
        viewport.pan(by: gesture.translation(in: self))
        gesture.setTranslation(.zero, in: self)
        refresh()
    }

    @objc private func didUndoTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        cancelActiveStroke()
        session?.undo()
        refresh()
    }

    @objc private func didRedoTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        cancelActiveStroke()
        session?.redo()
        refresh()
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }

    private func updateAppearance() {
        let color = UIColor.secondarySystemBackground.resolvedColor(with: traitCollection)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        clearColor = MTLClearColor(red: Double(red), green: Double(green), blue: Double(blue), alpha: 1)
    }
}
