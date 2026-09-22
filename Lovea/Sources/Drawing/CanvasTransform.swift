import CoreGraphics

struct CanvasTransform: Equatable, Sendable {
    private(set) var scale: CGFloat
    private(set) var rotation: CGFloat
    private(set) var offset: CGPoint

    init(scale: CGFloat = 1, rotation: CGFloat = 0, offset: CGPoint = .zero) {
        self.scale = scale.isFinite && scale > 0 ? min(max(scale, 0.25), 6) : 1
        self.rotation = rotation.isFinite ? rotation : 0
        self.offset = CGPoint(
            x: offset.x.isFinite ? offset.x : 0,
            y: offset.y.isFinite ? offset.y : 0
        )
    }

    mutating func pan(by translation: CGPoint) {
        guard translation.x.isFinite, translation.y.isFinite else { return }
        offset.x += translation.x
        offset.y += translation.y
    }

    mutating func zoom(by factor: CGFloat, around focus: CGPoint) {
        guard factor.isFinite, factor > 0 else { return }
        let anchor = documentPoint(fromScreen: focus)
        scale = min(max(scale * factor, 0.25), 6)
        reanchor(anchor, at: focus)
    }

    mutating func rotate(by angle: CGFloat, around focus: CGPoint) {
        guard angle.isFinite else { return }
        let anchor = documentPoint(fromScreen: focus)
        rotation = atan2(sin(rotation + angle), cos(rotation + angle))
        reanchor(anchor, at: focus)
    }

    func screenPoint(fromDocument point: CGPoint) -> CGPoint {
        let cosine = cos(rotation)
        let sine = sin(rotation)
        let x = point.x * scale
        let y = point.y * scale
        return CGPoint(
            x: x * cosine - y * sine + offset.x,
            y: x * sine + y * cosine + offset.y
        )
    }

    func documentPoint(fromScreen point: CGPoint) -> CGPoint {
        let cosine = cos(rotation)
        let sine = sin(rotation)
        let x = point.x - offset.x
        let y = point.y - offset.y
        return CGPoint(
            x: (x * cosine + y * sine) / scale,
            y: (-x * sine + y * cosine) / scale
        )
    }

    private mutating func reanchor(_ documentPoint: CGPoint, at screenPoint: CGPoint) {
        let mapped = screenPoint(fromDocument: documentPoint)
        offset.x += screenPoint.x - mapped.x
        offset.y += screenPoint.y - mapped.y
    }
}
