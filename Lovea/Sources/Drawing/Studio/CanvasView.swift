import Combine
@preconcurrency import MetalKit
import SwiftUI
import UIKit

/// Keeps document coordinates independent of the screen size and orientation.
struct ArtworkCanvasViewport: Equatable {
    private(set) var scale: CGFloat = 1
    private(set) var rotation: CGFloat = 0
    private(set) var offset: CGPoint = .zero
    private var fittedScale: CGFloat = 1
    private var documentWidth: CGFloat = 0
    /// Mirrors only the display, never the image.
    var mirrored = false

    mutating func fit(document: CGSize, screen: CGSize) {
        guard document.width > 0, document.height > 0,
              screen.width > 0, screen.height > 0 else { return }
        documentWidth = document.width
        fittedScale = min(screen.width / document.width, screen.height / document.height) * 0.94
        scale = fittedScale
        rotation = 0
        offset = CGPoint(
            x: (screen.width - document.width * scale) / 2,
            y: (screen.height - document.height * scale) / 2
        )
    }

    /// Zoom relative to "fit to screen", for the zoom capsule.
    var zoomPercent: Int { Int((scale / fittedScale * 100).rounded()) }

    func screenPoint(_ point: CGPoint) -> CGPoint {
        let x = (mirrored ? documentWidth - point.x : point.x) * scale
        let y = point.y * scale
        return CGPoint(
            x: x * cos(rotation) - y * sin(rotation) + offset.x,
            y: x * sin(rotation) + y * cos(rotation) + offset.y
        )
    }

    func documentPoint(_ point: CGPoint) -> CGPoint {
        let x = point.x - offset.x
        let y = point.y - offset.y
        let docX = (x * cos(rotation) + y * sin(rotation)) / scale
        return CGPoint(
            x: mirrored ? documentWidth - docX : docX,
            y: (-x * sin(rotation) + y * cos(rotation)) / scale
        )
    }

    mutating func zoom(by factor: CGFloat, around focus: CGPoint) {
        guard factor.isFinite, factor > 0 else { return }
        let anchored = documentPoint(focus)
        scale = min(max(scale * factor, fittedScale * 0.2), fittedScale * 40)
        reanchor(anchored, at: focus)
    }

    mutating func rotate(by angle: CGFloat, around focus: CGPoint) {
        guard angle.isFinite else { return }
        let anchored = documentPoint(focus)
        rotation = atan2(sin(rotation + angle), cos(rotation + angle))
        reanchor(anchored, at: focus)
    }

    /// Snaps the view rotation back to 0° when it is within `degrees`. Returns true if it snapped.
    @discardableResult
    mutating func snapRotation(around focus: CGPoint, degrees: CGFloat = 4) -> Bool {
        guard rotation != 0, abs(rotation) <= degrees * .pi / 180 else { return false }
        rotate(by: -rotation, around: focus)
        return true
    }

    mutating func pan(by distance: CGPoint) {
        guard distance.x.isFinite, distance.y.isFinite else { return }
        offset.x += distance.x
        offset.y += distance.y
    }

    mutating func setMirrored(_ value: Bool, around focus: CGPoint) {
        let anchored = documentPoint(focus)
        mirrored = value
        reanchor(anchored, at: focus)
    }

    /// Shows `center` in the screen middle with `span` document pixels across the short side ("Folgen").
    mutating func show(center: CGPoint, span: CGFloat, rotation: CGFloat, screen: CGSize) {
        guard span > 0, span.isFinite, rotation.isFinite, screen.width > 0, screen.height > 0 else { return }
        scale = min(max(min(screen.width, screen.height) / span, fittedScale * 0.2), fittedScale * 40)
        self.rotation = rotation
        offset = .zero
        reanchor(center, at: CGPoint(x: screen.width / 2, y: screen.height / 2))
    }

    private mutating func reanchor(_ point: CGPoint, at focus: CGPoint) {
        let mapped = screenPoint(point)
        offset.x += focus.x - mapped.x
        offset.y += focus.y - mapped.y
    }
}

/// View state for the SwiftUI overlays. Kept apart from the session so gestures
/// only redraw the overlays, not the whole studio.
@MainActor
final class CanvasViewState: ObservableObject {
    @Published var viewport = ArtworkCanvasViewport()
    @Published var gestureActive = false
    @Published var lasso: [CGPoint] = []
    @Published var shapePreview: [CGPoint] = []
    @Published var hover: (center: CGPoint, diameter: CGFloat)?
    @Published var loupe: (point: CGPoint, color: RGBAColor)?
    @Published var quickMenu: CGPoint?
    /// Viewer: move the own view along with the drawer's.
    @Published var folgen = false
    /// Screen point of the emoji picker (two fingers long, partner in the drawing).
    @Published var emojiAuswahl: CGPoint?
    weak var canvas: CanvasView?

    func resetView() { canvas?.resetView() }
    func setMirrored(_ value: Bool) { canvas?.setMirrored(value) }
}

/// Q-R10 Review-Fix: Ergebnis von `CanvasView.strichBeiZweiterBeruehrung`.
enum ZweiteBeruehrungEntscheidung: Equatable {
    case landen, verwerfen
}

struct CanvasRepresentable: UIViewRepresentable {
    let session: DrawingSession

    func makeUIView(context: Context) -> CanvasView {
        CanvasView(session: session)
    }

    /// No redraw here: the engine asks for one on every pixel change (`requestRedraw`). Redrawing on every
    /// SwiftUI update of the studio (thumbnails, notices, autosave) cost a full composite each time.
    func updateUIView(_ view: CanvasView, context: Context) {}
}

@MainActor
final class CanvasView: MTKView, UIGestureRecognizerDelegate, UIPencilInteractionDelegate {
    private weak var session: DrawingSession?
    private let state: CanvasViewState
    private var viewport = ArtworkCanvasViewport() {
        didSet {
            state.viewport = viewport
            session?.live.ansichtGeaendert(viewport, screen: bounds.size)
        }
    }
    private var fittedBounds: CGSize = .zero
    private weak var activeTouch: UITouch?
    private var pencilSeen = false
    private var shapeStart: CGPoint?
    private var tapCandidate = false
    private var tapStart: CGPoint?
    private var lastEyedropperSample: CFTimeInterval = 0
    /// Q-R10 Kandidat 1 / Review-Fix: wie alt der laufende Strich ist und wie weit er schon gewandert
    /// ist (Bildschirmpunkte), für `strichBeiZweiterBeruehrung`.
    private var strokeStartTime: CFTimeInterval?
    private var strokePathLength: CGFloat = 0
    private var strokeLastPoint: CGPoint?
    private var strokeIsPencil = false
    /// Q-R10 Kandidat 3: wann zuletzt ein Strich wirklich gelandet ist, als Sperrzeit für die
    /// Zwei-/Drei-Finger-Tipp-Gesten (Undo/Redo).
    private var lastStrokeLandTime: CFTimeInterval = 0
    /// Für die Undo/Redo-Gesten-Prüfung: Kennzahlen der gerade unten liegenden Touch-Gruppe (nicht nur
    /// `activeTouch`). Bleiben nach `touchesEnded` absichtlich stehen, bis die nächste Gruppe beginnt –
    /// die Reihenfolge von `touchesEnded` und `gestureRecognizerShouldBegin` ist zwischen View und
    /// Gesture Recognizer nicht festgelegt, Löschen in `touchesEnded` könnte die Prüfung zu früh leeren.
    private var groupTouchCount = 0
    private var groupFirstStart: CFTimeInterval = 0
    private var groupLastStart: CFTimeInterval = 0
    private var groupMaxTravel: CGFloat = 0
    private var groupOrigins: [ObjectIdentifier: CGPoint] = [:]
    private var multiTouchGroupHadPencilStroke = false
    private weak var undoTapRecognizer: UITapGestureRecognizer?
    private weak var redoTapRecognizer: UITapGestureRecognizer?

    init(session: DrawingSession) {
        self.session = session
        state = session.canvasState
        super.init(frame: .zero, device: GPU.device)
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        isPaused = true
        enableSetNeedsDisplay = true
        preferredFramesPerSecond = 120
        isMultipleTouchEnabled = true
        state.canvas = self
        configureGestures()
        let pencil = UIPencilInteraction()
        pencil.delegate = self
        addInteraction(pencil)
        updateAppearance()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: CanvasView, _: UITraitCollection) in
            view.updateAppearance()
            view.setNeedsDisplay()
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        session?.engine?.draw(in: self, viewport: viewport)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let session, bounds.width > 0, bounds.height > 0, fittedBounds != bounds.size else { return }
        fittedBounds = bounds.size
        viewport.fit(document: session.canvasSize, screen: bounds.size)
        setNeedsDisplay()
    }

    func resetView() {
        guard let session else { return }
        let mirrored = viewport.mirrored
        viewport.fit(document: session.canvasSize, screen: bounds.size)
        if mirrored { viewport.setMirrored(true, around: CGPoint(x: bounds.midX, y: bounds.midY)) }
        setNeedsDisplay()
    }

    func setMirrored(_ value: Bool) {
        viewport.setMirrored(value, around: CGPoint(x: bounds.midX, y: bounds.midY))
        setNeedsDisplay()
    }

    func folgen(_ ansicht: AnsichtNachricht.Transform) {
        viewport.show(
            center: CGPoint(x: ansicht.x, y: ansicht.y), span: CGFloat(ansicht.spanne),
            rotation: CGFloat(ansicht.drehung), screen: bounds.size
        )
        setNeedsDisplay()
    }

    /// Own pen for the partner's screen.
    private func sendPen(_ touch: UITouch, active: Bool) {
        guard let session else { return }
        session.live.stift(
            viewport.documentPoint(touch.location(in: self)), werkzeug: session.werkzeugName,
            farbe: session.color, groesse: session.brushSize, schwebt: false, aktiv: active
        )
    }

    // MARK: Touches

    private var fingerDraws: Bool {
        guard let session else { return false }
        return session.drawsWithFinger || (!pencilSeen && !UIPencilInteraction.prefersPencilOnlyDrawing)
    }

    private func accepts(_ touch: UITouch) -> Bool {
        if touch.type == .pencil {
            pencilSeen = true
            return true
        }
        return touch.type == .direct && fingerDraws
    }

    private func input(_ touch: UITouch) -> StrokeInput {
        let isPencil = touch.type == .pencil
        let pressure = isPencil && touch.maximumPossibleForce > 0 ? touch.force / touch.maximumPossibleForce : 1
        return StrokeInput(
            location: viewport.documentPoint(touch.preciseLocation(in: self)),
            pressure: Double(pressure),
            altitude: isPencil ? Double(touch.altitudeAngle) : .pi / 2,
            azimuth: isPencil ? Double(touch.azimuthAngle(in: self)) : 0,
            timestamp: touch.timestamp
        )
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        trackTouchesBegan(touches, wasPencilActive: activeTouch?.type == .pencil)
        guard let session, !session.nurAnsehen else { return }
        let live = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled } ?? touches
        if activeTouch != nil, live.count > 1 {
            // A second finger during a stroke usually means "I want to zoom" – but a palm resting
            // mid-stroke must not silently erase what is already on the canvas (Q-R10 Kandidat 1).
            resolveSecondTouch()
            return
        }
        guard activeTouch == nil, touches.count == 1, live.count == 1,
              let touch = touches.first, accepts(touch) else { return }
        state.hover = nil
        let point = viewport.documentPoint(touch.location(in: self))
        switch session.tool {
        case .brush, .eraser:
            guard session.ensureDrawable() else { return }
            session.markColorUsed()
            activeTouch = touch
            session.engine?.beginStroke(input(touch), settings: session.brushSettings, layerID: session.activeLayerID)
            if let engine = session.engine, engine.isStroking {
                strokeStartTime = CACurrentMediaTime()
                strokePathLength = 0
                strokeLastPoint = touch.location(in: self)
                strokeIsPencil = touch.type == .pencil
                session.live.strichBeginnen(
                    input(touch), settings: session.brushSettings, ebene: session.activeLayerID,
                    spiegel: engine.mirrorX, auswahl: engine.selection != nil
                )
            }
        case .lasso:
            activeTouch = touch
            state.lasso = [point]
        case .shape:
            guard session.ensureDrawable() else { return }
            activeTouch = touch
            shapeStart = point
        case .fill, .eyedropper:
            activeTouch = touch
            tapCandidate = true
            tapStart = touch.location(in: self)
        case .transform, .text:
            return
        }
        if session.tool != .brush, session.tool != .eraser { sendPen(touch, active: true) }
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        trackTouchesMoved(touches)
        guard let touch = activeTouch, touches.contains(touch), let session else { return }
        let point = viewport.documentPoint(touch.location(in: self))
        switch session.tool {
        case .brush, .eraser:
            let samples = (event?.coalescedTouches(for: touch) ?? [touch]).map(input)
            let predicted = (event?.predictedTouches(for: touch) ?? []).map(input)
            session.engine?.continueStroke(samples, predicted: predicted)
            session.live.strichWeiter(samples)
            // Bildschirmpunkte, nicht Dokumentpixel: die Länge geht in `strichBeiZweiterBeruehrung`,
            // deren 40-pt-Schwelle an echte Fingerbewegung auf dem Glas gedacht ist, nicht an Zoom.
            let screenPoint = touch.location(in: self)
            if let last = strokeLastPoint { strokePathLength += hypot(screenPoint.x - last.x, screenPoint.y - last.y) }
            strokeLastPoint = screenPoint
        case .lasso:
            state.lasso.append(point)
        case .shape:
            if let shapeStart {
                let constrained = (event?.allTouches?.count ?? 1) > 1
                state.shapePreview = Selection.shapePoints(session.shapeKind, from: shapeStart, to: point, constrained: constrained)
            }
        case .fill, .eyedropper:
            if let tapStart, hypot(touch.location(in: self).x - tapStart.x, touch.location(in: self).y - tapStart.y) > 12 {
                tapCandidate = false
            }
            if session.tool == .eyedropper {
                let now = CACurrentMediaTime()
                if now - lastEyedropperSample >= 0.05 {
                    lastEyedropperSample = now
                    session.tap(at: point, final: false)
                }
            }
        case .transform, .text:
            break
        }
        if session.tool != .brush, session.tool != .eraser { sendPen(touch, active: true) }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        trackTouchesEnded(touches)
        guard let touch = activeTouch, touches.contains(touch), let session else { return }
        activeTouch = nil
        let point = viewport.documentPoint(touch.location(in: self))
        switch session.tool {
        case .brush, .eraser:
            session.engine?.continueStroke([input(touch)], predicted: [])
            session.engine?.endStroke()
            strokeStartTime = nil
            strokeLastPoint = nil
            lastStrokeLandTime = CACurrentMediaTime()
            session.live.strichWeiter([input(touch)])
            session.live.strichEnde()
        case .lasso:
            let polygon = session.lassoRectangle && state.lasso.count > 1
                ? Selection.rectangle(from: state.lasso[0], to: point)
                : state.lasso
            state.lasso = []
            session.select(polygon: polygon)
        case .shape:
            if !state.shapePreview.isEmpty { session.drawShape(state.shapePreview) }
            state.shapePreview = []
            shapeStart = nil
        case .fill:
            if tapCandidate { session.tap(at: point) }
            tapCandidate = false
            tapStart = nil
        case .eyedropper:
            // No slop check here: a drag is a live preview (touchesMoved), lifting always commits.
            session.tap(at: point)
            tapCandidate = false
            tapStart = nil
        case .transform, .text:
            break
        }
        if session.tool != .brush, session.tool != .eraser { sendPen(touch, active: false) }
        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        trackTouchesEnded(touches)
        cancelActive("touchesCancelled")
    }

    private func cancelActive(_ grund: String) {
        activeTouch = nil
        strokeStartTime = nil
        strokeLastPoint = nil
        shapeStart = nil
        tapCandidate = false
        tapStart = nil
        state.lasso = []
        state.shapePreview = []
        session?.engine?.cancelStroke(grund: grund)
        session?.live.strichEnde(abbruch: true)
        setNeedsDisplay()
    }

    /// Q-R10 Review-Fix: reine Entscheidung, ob ein zweiter Touch während eines Strichs ihn landet oder
    /// verwirft. Pencil: ein zweiter Touch ist praktisch immer ein Handballen – man zoomt nicht mit der
    /// Hand, die gerade den Stift hält – also immer landen. Finger: nur landen, wenn der Strich schon
    /// "substanziell" ist (alt UND lang genug); sonst ist "kurz zeichnen, dann zoomen" ein ganz normaler
    /// Ablauf, der keinen ungewollten Teilstrich festschreiben darf. Schwellen bewusst beide nötig
    /// (UND, nicht ODER): ein langsamer, kurzer Tupfer ist genauso wenig "fertig gezeichnet" wie ein
    /// schneller, langer Wisch, der nach 50 ms schon über die Schwelle rauscht.
    nonisolated static func strichBeiZweiterBeruehrung(alterMs: Double, laengePunkte: Double, istStift: Bool) -> ZweiteBeruehrungEntscheidung {
        if istStift { return .landen }
        return alterMs >= 300 && laengePunkte >= 40 ? .landen : .verwerfen
    }

    private func resolveSecondTouch() {
        guard let session, let engine = session.engine, engine.isStroking, let start = strokeStartTime else {
            cancelActive("zweiter Touch ohne laufenden Strich")
            return
        }
        let alterMs = (CACurrentMediaTime() - start) * 1000
        guard Self.strichBeiZweiterBeruehrung(alterMs: alterMs, laengePunkte: strokePathLength, istStift: strokeIsPencil) == .landen else {
            cancelActive("zweiter Touch, Strich zu jung oder kurz")
            return
        }
        activeTouch = nil
        strokeStartTime = nil
        strokeLastPoint = nil
        engine.endStroke()
        lastStrokeLandTime = CACurrentMediaTime()
        session.live.strichEnde()
        ZeichenProtokoll.log("Palm-Schutz: zweiter Touch, Strich gelandet statt verworfen (alter=\(Int(alterMs))ms länge=\(Int(strokePathLength))pt stift=\(strokeIsPencil))")
        setNeedsDisplay()
    }

    // MARK: Mehr-Finger-Erkennung für Undo/Redo (Q-R10 Kandidat 3)

    private func trackTouchesBegan(_ touches: Set<UITouch>, wasPencilActive: Bool) {
        let now = CACurrentMediaTime()
        if groupTouchCount == 0 {
            groupFirstStart = now
            groupMaxTravel = 0
            groupOrigins = [:]
            multiTouchGroupHadPencilStroke = wasPencilActive
        } else if wasPencilActive {
            multiTouchGroupHadPencilStroke = true
        }
        groupLastStart = now
        groupTouchCount += touches.count
        for touch in touches { groupOrigins[ObjectIdentifier(touch)] = touch.location(in: self) }
    }

    private func trackTouchesMoved(_ touches: Set<UITouch>) {
        for touch in touches {
            guard let origin = groupOrigins[ObjectIdentifier(touch)] else { continue }
            let point = touch.location(in: self)
            groupMaxTravel = max(groupMaxTravel, hypot(point.x - origin.x, point.y - origin.y))
        }
    }

    private func trackTouchesEnded(_ touches: Set<UITouch>) {
        // Zahlen bewusst stehen lassen (siehe Kommentar bei den gespeicherten Properties); nur den
        // Zähler senken, damit die nächste Gruppe korrekt bei 0 neu beginnt.
        groupTouchCount = max(0, groupTouchCount - touches.count)
    }

    /// Ein Zwei- oder Drei-Finger-Tipp ist eine bewusste Geste – ein nachlässiger Handballen beim
    /// schnellen Zeichnen kann dieselbe Form erzeugen. Deshalb nur zulassen, wenn jeder beteiligte
    /// Touch innerhalb von 100 ms nach dem ersten begonnen hat und unter 10 pt gewandert ist (ein
    /// echtes Tippen schafft das mühelos, ein absetzender Handballen meist nicht alle Finger gleich-
    /// zeitig), wenn dabei kein Pencil-Strich lief, und erst 300 ms nachdem der letzte Strich gelandet
    /// ist (ein Strich braucht einen Moment, um zu committen, bevor ein Tipp ihn rückgängig machen darf).
    /// Reine Funktion (Q-R10 Review-Fix): nimmt `now` statt `CACurrentMediaTime()` selbst zu lesen, damit
    /// sie ohne echte Uhr testbar ist. Jede Regel ist ein eigenes `guard`, damit ein Test gezielt genau
    /// eine Regel brechen kann.
    nonisolated static func erlaubtMehrFingerGeste(
        hadPencilStroke: Bool,
        now: CFTimeInterval,
        lastStrokeLandTime: CFTimeInterval,
        groupFirstStart: CFTimeInterval,
        groupLastStart: CFTimeInterval,
        groupMaxTravel: CGFloat
    ) -> Bool {
        guard !hadPencilStroke else { return false }
        guard now - lastStrokeLandTime > 0.3 else { return false }
        guard groupLastStart - groupFirstStart < 0.1 else { return false }
        return groupMaxTravel < 10
    }

    private func allowsAccidentalUndoGesture() -> Bool {
        Self.erlaubtMehrFingerGeste(
            hadPencilStroke: multiTouchGroupHadPencilStroke,
            now: CACurrentMediaTime(),
            lastStrokeLandTime: lastStrokeLandTime,
            groupFirstStart: groupFirstStart,
            groupLastStart: groupLastStart,
            groupMaxTravel: groupMaxTravel
        )
    }

    // MARK: Gestures

    private func configureGestures() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(didPinch(_:)))
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(didRotate(_:)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        let undoTap = UITapGestureRecognizer(target: self, action: #selector(didUndoTap(_:)))
        undoTap.numberOfTouchesRequired = 2
        let redoTap = UITapGestureRecognizer(target: self, action: #selector(didRedoTap(_:)))
        redoTap.numberOfTouchesRequired = 3
        undoTapRecognizer = undoTap
        redoTapRecognizer = redoTap
        let fitTap = UITapGestureRecognizer(target: self, action: #selector(didFitTap(_:)))
        fitTap.numberOfTouchesRequired = 2
        fitTap.numberOfTapsRequired = 2
        undoTap.require(toFail: fitTap)
        let loupe = UILongPressGestureRecognizer(target: self, action: #selector(didLoupe(_:)))
        loupe.minimumPressDuration = 0.4
        loupe.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        let pick = UILongPressGestureRecognizer(target: self, action: #selector(didPickLayer(_:)))
        pick.numberOfTouchesRequired = 2
        pick.minimumPressDuration = 0.5
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(didHover(_:)))
        for recognizer in [pinch, rotation, pan, undoTap, redoTap, fitTap, loupe, pick, hover] as [UIGestureRecognizer] {
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            addGestureRecognizer(recognizer)
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UILongPressGestureRecognizer, gestureRecognizer.numberOfTouches < 2 {
            return !fingerDraws && activeTouch?.type != .pencil
        }
        if gestureRecognizer === undoTapRecognizer || gestureRecognizer === redoTapRecognizer {
            return allowsAccidentalUndoGesture()
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }

    private func navigationChanged(_ recognizer: UIGestureRecognizer) {
        switch recognizer.state {
        case .began:
            cancelActive("Zoom-, Dreh- oder Schiebegeste")
            state.gestureActive = true
            state.folgen = false
        case .ended, .cancelled, .failed:
            if viewport.snapRotation(around: recognizer.location(in: self)) {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            state.gestureActive = false
        default:
            break
        }
        setNeedsDisplay()
    }

    @objc private func didPinch(_ gesture: UIPinchGestureRecognizer) {
        viewport.zoom(by: gesture.scale, around: gesture.location(in: self))
        gesture.scale = 1
        navigationChanged(gesture)
    }

    @objc private func didRotate(_ gesture: UIRotationGestureRecognizer) {
        viewport.rotate(by: gesture.rotation, around: gesture.location(in: self))
        gesture.rotation = 0
        navigationChanged(gesture)
    }

    @objc private func didPan(_ gesture: UIPanGestureRecognizer) {
        viewport.pan(by: gesture.translation(in: self))
        gesture.setTranslation(.zero, in: self)
        navigationChanged(gesture)
    }

    @objc private func didUndoTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        cancelActive("Zwei-Finger-Undo-Tipp")
        session?.undo(source: .geste)
    }

    @objc private func didRedoTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        cancelActive("Drei-Finger-Redo-Tipp")
        session?.redo(source: .geste)
    }

    @objc private func didFitTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        resetView()
    }

    @objc private func didLoupe(_ gesture: UILongPressGestureRecognizer) {
        guard session?.nurAnsehen == false else { return }
        let screen = gesture.location(in: self)
        switch gesture.state {
        case .began, .changed:
            cancelActive("Lupe")
            Task { [weak self] in
                guard let self, let color = await self.session?.engine?.sampleColor(at: self.viewport.documentPoint(screen)) else { return }
                self.state.loupe = (screen, color)
            }
        case .ended:
            if let color = state.loupe?.color, color.alpha > 0 { session?.setColor(RGBAColor(red: color.red, green: color.green, blue: color.blue)) }
            state.loupe = nil
        default:
            state.loupe = nil
        }
    }

    @objc private func didPickLayer(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let session else { return }
        cancelActive("Ebenenwahl per Zwei-Finger-Halten")
        // Partner in the drawing: two fingers long put an emoji on the canvas (Spec 10.3) instead.
        if LiveZeichnung.shared.partnerIstDrin(session.live.zeichnungId) {
            state.emojiAuswahl = gesture.location(in: self)
            return
        }
        session.selectTopLayer(at: viewport.documentPoint(gesture.location(in: self)))
    }

    @objc private func didHover(_ gesture: UIHoverGestureRecognizer) {
        guard let session, !session.nurAnsehen else { return }
        let hovering = gesture.state == .began || gesture.state == .changed
        session.live.stift(
            viewport.documentPoint(gesture.location(in: self)), werkzeug: session.werkzeugName,
            farbe: session.color, groesse: session.brushSize, schwebt: hovering, aktiv: false
        )
        guard session.tool == .brush || session.tool == .eraser else {
            state.hover = nil
            return
        }
        switch gesture.state {
        case .began, .changed:
            state.hover = (gesture.location(in: self), CGFloat(session.brushSize) * viewport.scale)
        default:
            state.hover = nil
        }
    }

    // MARK: Apple Pencil

    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        guard session?.nurAnsehen == false else { return }
        switch UIPencilInteraction.preferredTapAction {
        case .switchEraser:
            session?.toggleEraser()
        case .showColorPalette:
            session?.showsColorPanel = true
        case .switchPrevious:
            session?.switchToPreviousTool()
        default:
            break
        }
    }

    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        guard squeeze.phase == .ended, session?.nurAnsehen == false else { return }
        state.quickMenu = squeeze.hoverPose?.location ?? CGPoint(x: bounds.midX, y: bounds.midY)
    }

    private func updateAppearance() {
        let color = UIColor.secondarySystemBackground.resolvedColor(with: traitCollection)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let clear = MTLClearColor(red: Double(red), green: Double(green), blue: Double(blue), alpha: 1)
        clearColor = clear
        session?.engine?.compositor.viewBackground = clear
    }
}
