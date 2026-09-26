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
    var taper: Float = 0           // Q1: 0 = kein Taper, sonst Taperlänge in pt / 18
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
        case .shanShui:
            // Q5: ibisPaint "Orientalisch (Shan Shui)", retuned to taper both ends.
            BrushTip(hardness: 0.85, spacing: 0.03, flow: 0.95, grain: 0.12,
                     pressureGamma: 1.9, minPressureScale: 0.03, taper: 1.3)
        case .rundKurve:
            // Q5: ibisPaint "Rundpinsel (Kurve)".
            BrushTip(hardness: 0.9, spacing: 0.03, flow: 1, pressureGamma: 1.2, minPressureScale: 0.15, taper: 1)
        case .rundPunkt:
            // Q5: ibisPaint "Rundpinsel (Punkt)".
            BrushTip(hardness: 0.55, spacing: 0.04, flow: 1, pressureGamma: 1.1, minPressureScale: 0.2, taper: 1)
        case .rundEcht:
            // Q5: ibisPaint "Rundpinsel (Echt)".
            BrushTip(hardness: 0.45, spacing: 0.02, flow: 0.45, grain: 0.55, sizeJitter: 0.05,
                     pressureGamma: 1.3, minPressureScale: 0.1, taper: 0.8)
        case .bleistiftEins:
            // Q5: ibisPaint "Bleistift (#1)".
            BrushTip(hardness: 0.5, spacing: 0.1, flow: 0.75, grain: 0.8, pressureGamma: 1,
                     minPressureScale: 0.45, tiltWidens: true, taper: 0.5)
        }
    }

    var pressureControlsSize: Bool {
        switch self {
        case .pen, .gPen, .pencil, .watercolor, .chalk, .calligraphy, .shanShui,
             .rundKurve, .rundPunkt, .rundEcht, .bleistiftEins: true
        case .marker, .airbrush, .highlighter, .pixel: false
        }
    }

    var pressureControlsOpacity: Bool {
        switch self {
        case .pencil, .airbrush, .watercolor, .chalk, .shanShui, .rundEcht, .bleistiftEins: true
        case .pen, .gPen, .marker, .calligraphy, .highlighter, .pixel, .rundKurve, .rundPunkt: false
        }
    }

    var opacityCap: Double {
        self == .highlighter ? 0.4 : 1
    }
}
