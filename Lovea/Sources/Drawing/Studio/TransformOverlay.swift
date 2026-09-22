import SwiftUI
import UIKit

/// Everything drawn over the canvas in screen space: lasso, shape preview, marching ants,
/// symmetry axis, hover circle, color loupe and the zoom capsule.
struct CanvasOverlay: View {
    @ObservedObject var state: CanvasViewState
    @ObservedObject var session: DrawingSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let viewport = state.viewport
        ZStack {
            if !state.lasso.isEmpty {
                outline(state.lasso, closed: false, viewport: viewport)
                    .stroke(.primary, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            if !state.shapePreview.isEmpty {
                outline(state.shapePreview, closed: false, viewport: viewport)
                    .stroke(Color(uiColor: session.color.uiColor), lineWidth: max(1, CGFloat(session.brushSize) * viewport.scale))
                    .opacity(0.6)
            }
            if session.hasSelection, !session.selectionOutline.isEmpty {
                MarchingAnts(path: outline(session.selectionOutline, closed: true, viewport: viewport), animated: !reduceMotion)
            }
            if session.symmetry {
                let top = viewport.screenPoint(CGPoint(x: session.canvasSize.width / 2, y: 0))
                let bottom = viewport.screenPoint(CGPoint(x: session.canvasSize.width / 2, y: session.canvasSize.height))
                Path { path in
                    path.move(to: top)
                    path.addLine(to: bottom)
                }
                .stroke(.tint.opacity(0.7), lineWidth: 1)
            }
            if let hover = state.hover {
                Circle()
                    .stroke(.primary.opacity(0.6), lineWidth: 1)
                    .frame(width: max(hover.diameter, 4), height: max(hover.diameter, 4))
                    .position(hover.center)
            }
            if let loupe = state.loupe {
                Circle()
                    .fill(Color(uiColor: loupe.color.uiColor))
                    .overlay(Circle().stroke(.background, lineWidth: 4))
                    .shadow(radius: 4)
                    .frame(width: 64, height: 64)
                    .position(x: loupe.point.x, y: loupe.point.y - 70)
                    .accessibilityHidden(true)
            }
        }
        .allowsHitTesting(false)
        .overlay(alignment: .top) {
            if state.gestureActive {
                Button {
                    state.resetView()
                } label: {
                    Text("\(viewport.zoomPercent) % · \(Int((viewport.rotation * 180 / .pi).rounded()))°")
                        .font(.footnote.monospacedDigit().weight(.medium))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .background(.regularMaterial, in: Capsule())
                .accessibilityLabel("Ansicht zurücksetzen")
                .padding(.top, 8)
            }
        }
    }

    private func outline(_ points: [CGPoint], closed: Bool, viewport: ArtworkCanvasViewport) -> Path {
        Path { path in
            path.addLines(points.map(viewport.screenPoint))
            if closed { path.closeSubpath() }
        }
    }
}

private struct MarchingAnts: View {
    let path: Path
    let animated: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            path.stroke(.white, lineWidth: 1.5)
            path.stroke(.black, style: StrokeStyle(lineWidth: 1.5, dash: [6, 6], dashPhase: phase))
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: false)) { phase = 12 }
        }
    }
}

/// Frame with corner handles for moving, scaling, rotating and flipping the lifted content.
struct TransformOverlay: View {
    @ObservedObject var state: CanvasViewState
    @ObservedObject var session: DrawingSession
    @State private var transform = LayerTransform()
    @State private var gestureStart: LayerTransform?
    @State private var proportional = true
    @State private var snapped = false

    private var engineState: TransformState? { session.engine?.transformState }

    var body: some View {
        if let engineState {
            let viewport = state.viewport
            let corners = frameCorners(engineState).map(viewport.screenPoint)
            ZStack {
                Path { path in
                    guard corners.count == 4 else { return }
                    path.addLines([corners[0], corners[1], corners[3], corners[2]])
                    path.closeSubpath()
                }
                .fill(Color.accentColor.opacity(0.001))
                .overlay {
                    Path { path in
                        guard corners.count == 4 else { return }
                        path.addLines([corners[0], corners[1], corners[3], corners[2]])
                        path.closeSubpath()
                    }
                    .stroke(Color.accentColor, lineWidth: 1.5)
                }
                .gesture(moveGesture(viewport))
                .simultaneousGesture(pinchRotateGesture)

                ForEach(corners.indices, id: \.self) { index in
                    Circle()
                        .fill(.background)
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                        .frame(width: 22, height: 22)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .position(corners[index])
                        .gesture(cornerGesture(index: index, engineState: engineState, viewport: viewport))
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .top) { topBar }
            .overlay(alignment: .bottom) { valueCapsule }
            .onAppear { transform = engineState.transform }
            .sensoryFeedback(.selection, trigger: snapped)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button("Abbrechen", role: .cancel) { session.cancelTransform() }
                .frame(minHeight: 44)
            Spacer()
            Button {
                transform.flipX.toggle()
                apply()
            } label: { Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right") }
                .frame(width: 44, height: 44)
                .accessibilityLabel("Horizontal spiegeln")
            Button {
                transform.flipY.toggle()
                apply()
            } label: { Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down") }
                .frame(width: 44, height: 44)
                .accessibilityLabel("Vertikal spiegeln")
            Toggle(isOn: $proportional) { Image(systemName: "lock") }
                .toggleStyle(.button)
                .accessibilityLabel("Seitenverhältnis beibehalten")
            Spacer()
            Button("Fertig") { session.commitTransform() }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var valueCapsule: some View {
        Text("\(Int((transform.scale * 100).rounded())) % · \(Int((transform.rotation * 180 / .pi).rounded()))°")
            .font(.footnote.monospacedDigit().weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .padding(.bottom, 110)
            .accessibilityLabel("Skalierung \(Int((transform.scale * 100).rounded())) Prozent, Drehung \(Int((transform.rotation * 180 / .pi).rounded())) Grad")
    }

    private func frameCorners(_ engineState: TransformState) -> [CGPoint] {
        let bounds = engineState.bounds
        guard !bounds.isNull else { return [] }
        let local = [CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.minY),
                     CGPoint(x: bounds.minX, y: bounds.maxY), CGPoint(x: bounds.maxX, y: bounds.maxY)]
        return local.map { Self.apply(transform, to: $0, pivot: engineState.pivot) }
    }

    static func apply(_ transform: LayerTransform, to point: CGPoint, pivot: CGPoint) -> CGPoint {
        let x = Double(point.x - pivot.x) * transform.scale * (transform.flipX ? -1 : 1)
        let y = Double(point.y - pivot.y) * transform.scaleY * (transform.flipY ? -1 : 1)
        let angle = transform.rotation
        return CGPoint(
            x: Double(pivot.x) + transform.offsetX + x * cos(angle) - y * sin(angle),
            y: Double(pivot.y) + transform.offsetY + x * sin(angle) + y * cos(angle)
        )
    }

    private func moveGesture(_ viewport: ArtworkCanvasViewport) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if gestureStart == nil { gestureStart = transform }
                guard let start = gestureStart else { return }
                let a = viewport.documentPoint(value.startLocation)
                let b = viewport.documentPoint(value.location)
                transform.offsetX = start.offsetX + Double(b.x - a.x)
                transform.offsetY = start.offsetY + Double(b.y - a.y)
                apply()
            }
            .onEnded { _ in gestureStart = nil }
    }

    private var pinchRotateGesture: some Gesture {
        MagnifyGesture().simultaneously(with: RotateGesture())
            .onChanged { value in
                if gestureStart == nil { gestureStart = transform }
                guard let start = gestureStart else { return }
                if let magnification = value.first?.magnification {
                    transform.scale = min(max(start.scale * magnification, 0.02), 50)
                }
                if let rotation = value.second?.rotation {
                    setRotation(start.rotation + rotation.radians)
                }
                apply()
            }
            .onEnded { _ in gestureStart = nil }
    }

    private func cornerGesture(index: Int, engineState: TransformState, viewport: ArtworkCanvasViewport) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if gestureStart == nil { gestureStart = transform }
                guard let start = gestureStart else { return }
                let pivot = CGPoint(x: Double(engineState.pivot.x) + start.offsetX, y: Double(engineState.pivot.y) + start.offsetY)
                let from = viewport.documentPoint(value.startLocation)
                let to = viewport.documentPoint(value.location)
                let startDistance = max(hypot(from.x - pivot.x, from.y - pivot.y), 1)
                if proportional {
                    let factor = Double(hypot(to.x - pivot.x, to.y - pivot.y) / startDistance)
                    transform.scale = min(max(start.scale * factor, 0.02), 50)
                    transform.stretch = start.stretch
                } else {
                    // Measure along the content's own axes.
                    let c = CGFloat(cos(-start.rotation))
                    let s = CGFloat(sin(-start.rotation))
                    func local(_ p: CGPoint) -> CGPoint {
                        let dx = p.x - pivot.x
                        let dy = p.y - pivot.y
                        return CGPoint(x: dx * c - dy * s, y: dx * s + dy * c)
                    }
                    let a = local(from)
                    let b = local(to)
                    let sx = abs(a.x) > 1 ? Double(abs(b.x / a.x)) : 1
                    let sy = abs(a.y) > 1 ? Double(abs(b.y / a.y)) : 1
                    transform.scale = min(max(start.scale * sx, 0.02), 50)
                    transform.stretch = (start.scaleY * sy) / max(transform.scale, 0.02)
                }
                apply()
            }
            .onEnded { _ in gestureStart = nil }
    }

    private func setRotation(_ angle: Double) {
        if let snappedAngle = Selection.snappedRotation(angle) {
            if transform.rotation != snappedAngle { snapped.toggle() }
            transform.rotation = snappedAngle
        } else {
            transform.rotation = angle
        }
    }

    private func apply() {
        session.updateTransform(transform)
    }
}
