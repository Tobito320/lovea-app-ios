import PencilKit

@available(iOS 18.0, *)
enum StrokeProcessor {
    static func processLatestStroke(
        in drawing: PKDrawing,
        stabilizer: Double,
        pressureControlsSize: Bool,
        pressureControlsOpacity: Bool
    ) -> PKDrawing {
        var strokes = drawing.strokes
        guard let last = strokes.last else { return drawing }

        let points = Array(last.path)
        guard !points.isEmpty else { return drawing }

        let strength = min(max(stabilizer, 0), 9)
        let radius = Int((strength / 9 * 4).rounded())
        let averageWidth = points.reduce(CGFloat.zero) { $0 + $1.size.width } / CGFloat(points.count)
        let averageHeight = points.reduce(CGFloat.zero) { $0 + $1.size.height } / CGFloat(points.count)

        let adjusted = points.enumerated().map { index, point -> PKStrokePoint in
            let location: CGPoint
            if radius > 0 && points.count > 2 {
                let lower = max(0, index - radius)
                let upper = min(points.count - 1, index + radius)
                let window = points[lower...upper]
                let sum = window.reduce(CGPoint.zero) { partial, candidate in
                    CGPoint(x: partial.x + candidate.location.x, y: partial.y + candidate.location.y)
                }
                location = CGPoint(
                    x: sum.x / CGFloat(window.count),
                    y: sum.y / CGFloat(window.count)
                )
            } else {
                location = point.location
            }

            return PKStrokePoint(
                location: location,
                timeOffset: point.timeOffset,
                size: pressureControlsSize
                    ? point.size
                    : CGSize(width: averageWidth, height: averageHeight),
                opacity: pressureControlsOpacity ? point.opacity : 1,
                force: point.force,
                azimuth: point.azimuth,
                altitude: point.altitude
            )
        }

        let path = PKStrokePath(controlPoints: adjusted, creationDate: last.path.creationDate)
        let processed = PKStroke(
            ink: last.ink,
            path: path,
            transform: last.transform,
            mask: last.mask,
            randomSeed: last.randomSeed
        )
        strokes[strokes.count - 1] = processed
        return PKDrawing(strokes: strokes)
    }
}
