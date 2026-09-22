import Foundation

struct BrushTip: Equatable, Sendable {
    var hardness: Float            // 0 weich … 1 hart
    var spacing: Float             // Anteil des Durchmessers
    var flow: Float
    var aspect: Float = 1
    var fixedAngle: Float?         // nil = Strichrichtung
    var grain: Float = 0
    var sizeJitter: Float = 0
    var pressureGamma: Double = 1
    var minPressureScale: Double = 0.2
    var tiltWidens = false
    var pixelSnap = false
    var buildsUp = false           // Airbrush: Deckkraft wächst innerhalb des Strichs
}

extension BrushPreset {
    /// Start values from the brush table in the Level 1 plan. Tune on the iPad.
    var tip: BrushTip {
        switch self {
        case .pen:
            BrushTip(hardness: 0.95, spacing: 0.08, flow: 1, pressureGamma: 0.8, minPressureScale: 0.35)
        case .gPen:
            BrushTip(hardness: 0.98, spacing: 0.05, flow: 1, pressureGamma: 1.4, minPressureScale: 0.1)
        case .pencil:
            BrushTip(hardness: 0.6, spacing: 0.1, flow: 0.8, grain: 0.6, tiltWidens: true)
        case .marker:
            BrushTip(hardness: 0.9, spacing: 0.06, flow: 1)
        case .airbrush:
            BrushTip(hardness: 0, spacing: 0.1, flow: 0.08, buildsUp: true)
        case .watercolor:
            BrushTip(hardness: 0.2, spacing: 0.08, flow: 0.25)
        case .chalk:
            BrushTip(hardness: 0.5, spacing: 0.12, flow: 0.9, grain: 0.8, sizeJitter: 0.1)
        case .calligraphy:
            BrushTip(hardness: 0.95, spacing: 0.04, flow: 1, aspect: 0.3, fixedAngle: Float.pi / 4)
        case .highlighter:
            BrushTip(hardness: 0.9, spacing: 0.06, flow: 1)
        case .pixel:
            // ponytail: spacing is ignored for pixelSnap, the sampler steps 1 px.
            BrushTip(hardness: 1, spacing: 0.5, flow: 1, pixelSnap: true)
        }
    }

    var pressureControlsSize: Bool {
        switch self {
        case .pen, .gPen, .pencil, .watercolor, .chalk, .calligraphy: true
        case .marker, .airbrush, .highlighter, .pixel: false
        }
    }

    var pressureControlsOpacity: Bool {
        switch self {
        case .pencil, .airbrush, .watercolor, .chalk: true
        default: false
        }
    }

    var opacityCap: Double {
        self == .highlighter ? 0.4 : 1
    }
}
