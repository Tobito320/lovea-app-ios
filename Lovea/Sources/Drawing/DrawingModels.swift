import Foundation

struct RGBAColor: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    static let ink = RGBAColor(red: 0.96, green: 0.96, blue: 0.97)
    static let blue = RGBAColor(red: 0.04, green: 0.52, blue: 1)
    static let red = RGBAColor(red: 1, green: 0.27, blue: 0.23)
    static let orange = RGBAColor(red: 1, green: 0.62, blue: 0.04)
}

struct StrokePoint: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var pressure: Double
    var timestamp: TimeInterval = 0
}

enum DrawingTool: String, Codable, Equatable, Sendable {
    case brush
    case eraser
}

struct DrawingStroke: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var points: [StrokePoint]
    var color: RGBAColor
    var width: Double
    var opacity: Double
    var tool: DrawingTool
}

struct DrawingLayer: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var isVisible = true
    var opacity = 1.0
    var strokes: [DrawingStroke] = []
}

struct DrawingDocument: Codable, Equatable, Sendable {
    var canvasWidth: Double
    var canvasHeight: Double
    var layers: [DrawingLayer]

    static let empty = DrawingDocument(
        canvasWidth: 2048,
        canvasHeight: 2048,
        layers: [DrawingLayer(name: "Ebene 1")]
    )
}
