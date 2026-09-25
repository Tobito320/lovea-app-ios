import CoreGraphics
import Foundation

struct StrokeInput: Equatable, Sendable {
    var location: CGPoint          // Dokumentkoordinaten
    var pressure: Double = 1       // 0...1
    var altitude: Double = .pi / 2 // Pencil altitudeAngle, Finger = .pi/2
    var azimuth: Double = 0
    var timestamp: TimeInterval = 0
}

struct Stamp: Equatable, Sendable {
    var center: SIMD2<Float>       // Dokumentpixel
    var radius: Float
    var opacity: Float             // Flow dieses Stempels
    var angle: Float
    var aspect: Float              // 1 = rund
}

struct BrushSettings: Equatable, Sendable {
    var preset: BrushPreset
    var size: Double               // Durchmesser in Dokumentpixeln, 1...300
    var opacity: Double            // Obergrenze pro Strich
    var color: RGBAColor
    var pressureSize: Bool
    var pressureOpacity: Bool
    var stabilizer: Int            // 0...9
    var isEraser: Bool

    /// Opacity of the whole stroke when it lands on the layer.
    var strokeOpacity: Float {
        Float(min(opacity, preset.opacityCap) * (isEraser ? 1 : color.alpha))
    }
}

/// Live smoothing: the drawn point trails the real one, so the line never jumps after lifting.
struct Stabilizer {
    private let weight: Double
    private var current: CGPoint?

    init(level: Int) {
        weight = 1 - Double(min(max(level, 0), 9)) / 10
    }

    mutating func smooth(_ point: CGPoint) -> CGPoint {
        guard let current else {
            self.current = point
            return point
        }
        let next = CGPoint(
            x: current.x + (point.x - current.x) * weight,
            y: current.y + (point.y - current.y) * weight
        )
        self.current = next
        return next
    }

    mutating func catchUp(to point: CGPoint) -> [CGPoint] {
        var points: [CGPoint] = []
        var steps = 0
        while let current, hypot(point.x - current.x, point.y - current.y) > 0.5, steps < 60 {
            points.append(smooth(point))
            steps += 1
        }
        current = point
        points.append(point)
        return points
    }
}

struct StrokeSampler {
    let settings: BrushSettings
    let tip: BrushTip
    private var stabilizer: Stabilizer
    private var last: (point: CGPoint, radius: Double, opacity: Double)?
    private var lastInput: StrokeInput?
    private var carry = 0.0
    private var index = 0
    private var distanceFromStart = 0.0
    private(set) var bounds = CGRect.null

    init(settings: BrushSettings) {
        self.settings = settings
        tip = settings.preset.tip
        stabilizer = Stabilizer(level: settings.stabilizer)
    }

    mutating func add(_ input: StrokeInput) -> [Stamp] {
        lastInput = input
        return walk(to: stabilizer.smooth(input.location), input: input)
    }

    mutating func finish() -> [Stamp] {
        guard let input = lastInput else { return [] }
        return stabilizer.catchUp(to: input.location).flatMap { walk(to: $0, input: input) }
    }

    static func pressureScale(_ pressure: Double, tip: BrushTip) -> Double {
        let clamped = min(max(pressure, 0), 1)
        return tip.minPressureScale + (1 - tip.minPressureScale) * pow(clamped, tip.pressureGamma)
    }

    static func tiltFactor(altitude: Double) -> Double {
        1 + 1.5 * (1 - min(max(altitude, 0), .pi / 2) / (.pi / 2))
    }

    private func radius(for input: StrokeInput) -> Double {
        var scale = settings.pressureSize ? Self.pressureScale(input.pressure, tip: tip) : 1
        if tip.tiltWidens { scale *= Self.tiltFactor(altitude: input.altitude) }
        return max(0.5, settings.size / 2 * scale)
    }

    private func opacity(for input: StrokeInput) -> Double {
        Double(tip.flow) * (settings.pressureOpacity ? min(max(input.pressure, 0.05), 1) : 1)
    }

    private func step(_ radius: Double) -> Double {
        tip.pixelSnap ? 1 : max(0.5, 2 * radius * Double(tip.spacing))
    }

    private mutating func walk(to point: CGPoint, input: StrokeInput) -> [Stamp] {
        let radius = radius(for: input)
        let opacity = opacity(for: input)
        guard let previous = last else {
            last = (point, radius, opacity)
            return [stamp(at: point, radius: radius, opacity: opacity, direction: 0, distanceFromStart: distanceFromStart)]
        }
        let dx = Double(point.x - previous.point.x)
        let dy = Double(point.y - previous.point.y)
        let distance = hypot(dx, dy)
        guard distance > 0 else { return [] }
        let direction = atan2(dy, dx)
        let baseDistance = distanceFromStart
        var stamps: [Stamp] = []
        var position = 0.0
        var since = carry
        while true {
            let fraction = position / distance
            let need = max(0, step(previous.radius + (radius - previous.radius) * fraction) - since)
            guard position + need <= distance else { break }
            position += need
            since = 0
            let t = position / distance
            stamps.append(stamp(
                at: CGPoint(x: Double(previous.point.x) + dx * t, y: Double(previous.point.y) + dy * t),
                radius: previous.radius + (radius - previous.radius) * t,
                opacity: previous.opacity + (opacity - previous.opacity) * t,
                direction: direction,
                distanceFromStart: baseDistance + position
            ))
        }
        carry = since + distance - position
        distanceFromStart = baseDistance + distance
        last = (point, radius, opacity)
        return stamps
    }

    /// Q1: strokes without pressure (finger) have constant width. `taper` fades the first
    /// `18 * taper` pt of the stroke from 0.15x up to full width, ease-out.
    // ponytail: start-only. The end can't taper the same way: stamps land on the scratch texture
    // live as they are drawn (see CanvasEngine.flushStamps), so by the time a stroke ends the last
    // points are already composited at full size. Retroactively shrinking them needs buffering the
    // whole stroke before it reaches the canvas; add that if the ink brush needs a tapered tail too.
    private func taperScale(distanceFromStart: Double) -> Double {
        guard tip.taper > 0 else { return 1 }
        let taperLength = 18.0 * Double(tip.taper)
        guard distanceFromStart < taperLength else { return 1 }
        let t = max(0, min(1, distanceFromStart / taperLength))
        let easedOut = 1 - (1 - t) * (1 - t)
        return 0.15 + 0.85 * easedOut
    }

    private mutating func stamp(at point: CGPoint, radius: Double, opacity: Double, direction: Double, distanceFromStart: Double) -> Stamp {
        defer { index += 1 }
        let radius = radius * taperScale(distanceFromStart: distanceFromStart)
        var stamp: Stamp
        if tip.pixelSnap {
            let half = Float(max(settings.size.rounded(), 1)) / 2
            stamp = Stamp(
                center: SIMD2(Float(point.x.rounded(.down)) + 0.5, Float(point.y.rounded(.down)) + 0.5),
                radius: half, opacity: 1, angle: 0, aspect: 1
            )
        } else {
            let jitter = 1 + tip.sizeJitter * (Self.hash01(index) * 2 - 1)
            stamp = Stamp(
                center: SIMD2(Float(point.x), Float(point.y)),
                radius: Float(radius) * jitter,
                opacity: Float(opacity),
                angle: tip.fixedAngle ?? Float(direction),
                aspect: tip.aspect
            )
        }
        let r = CGFloat(stamp.radius)
        bounds = bounds.union(CGRect(x: CGFloat(stamp.center.x) - r, y: CGFloat(stamp.center.y) - r, width: 2 * r, height: 2 * r))
        return stamp
    }

    /// Deterministic 0...1 noise, so the same input always gives the same stamps.
    static func hash01(_ value: Int) -> Float {
        var x = UInt32(truncatingIfNeeded: value) &* 747_796_405 &+ 2_891_336_453
        x = ((x >> ((x >> 28) &+ 4)) ^ x) &* 277_803_737
        x = (x >> 22) ^ x
        return Float(x) / Float(UInt32.max)
    }
}
