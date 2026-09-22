import Foundation

enum CanvasBackground: Codable, Equatable, Sendable {
    case white
    case dark
    case transparent
    case color(RGBAColor)
}

enum ArtworkFormat: String, CaseIterable, Codable, Identifiable, Sendable {
    case square
    case landscape4x3
    case portrait3x4
    case landscape16x9
    case portrait9x16
    case a4
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: "Quadrat"
        case .landscape4x3: "4:3"
        case .portrait3x4: "3:4"
        case .landscape16x9: "16:9"
        case .portrait9x16: "9:16"
        case .a4: "A4"
        case .custom: "Eigene Größe"
        }
    }

    func size(longEdge: Double = 2048) -> (width: Double, height: Double) {
        switch self {
        case .square: (longEdge, longEdge)
        case .landscape4x3: (longEdge, longEdge * 3 / 4)
        case .portrait3x4: (longEdge * 3 / 4, longEdge)
        case .landscape16x9: (longEdge, longEdge * 9 / 16)
        case .portrait9x16: (longEdge * 9 / 16, longEdge)
        case .a4: (longEdge / 1.41421356237, longEdge)
        case .custom: (longEdge, longEdge)
        }
    }
}

enum ArtworkLayerKind: String, Codable, Equatable, Sendable {
    case paint
    case image
}

enum LayerBlendMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case normal
    case multiply
    case screen
    case overlay
    case darken
    case lighten
    case add
    case softLight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .multiply: "Multiplizieren"
        case .screen: "Negativ multiplizieren"
        case .overlay: "Überlagern"
        case .darken: "Abdunkeln"
        case .lighten: "Aufhellen"
        case .add: "Hinzufügen"
        case .softLight: "Weiches Licht"
        }
    }
}

struct LayerTransform: Codable, Equatable, Sendable {
    var offsetX = 0.0
    var offsetY = 0.0
    var scale = 1.0
    var rotation = 0.0
    var flipX = false
    var flipY = false
}

struct ArtworkLayer: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var kind: ArtworkLayerKind
    var isVisible = true
    var isLocked = false
    var opacity = 1.0
    var blendMode: LayerBlendMode = .normal
    var clipping = false
    var alphaLock = false
    var alphaMaskFile: String?
    var transform = LayerTransform()
    var contentFile: String

    static func paint(name: String = "Ebene 1") -> ArtworkLayer {
        ArtworkLayer(name: name, kind: .paint, contentFile: "\(UUID().uuidString).drawing")
    }

    static func image(name: String = "Bild") -> ArtworkLayer {
        ArtworkLayer(name: name, kind: .image, contentFile: "\(UUID().uuidString).png")
    }
}

enum MetalStrokeTool: String, Codable, Equatable, Sendable {
    case brush
    case eraser
}

struct MetalPaintStroke: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var points: [StrokePoint]
    var color: RGBAColor
    var width: Double
    var opacity: Double
    var tool: MetalStrokeTool
    var brushPreset: String
    var pressureControlsSize = true
    var pressureControlsOpacity = false
    var stabilizer = 0.0
}

extension MetalPaintStroke {
    private enum CodingKeys: String, CodingKey {
        case id, points, color, width, opacity, tool, brushPreset
        case pressureControlsSize, pressureControlsOpacity, stabilizer
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        points = try values.decode([StrokePoint].self, forKey: .points)
        color = try values.decode(RGBAColor.self, forKey: .color)
        width = try values.decode(Double.self, forKey: .width)
        opacity = try values.decode(Double.self, forKey: .opacity)
        tool = try values.decode(MetalStrokeTool.self, forKey: .tool)
        brushPreset = try values.decode(String.self, forKey: .brushPreset)
        pressureControlsSize = try values.decodeIfPresent(Bool.self, forKey: .pressureControlsSize) ?? true
        pressureControlsOpacity = try values.decodeIfPresent(Bool.self, forKey: .pressureControlsOpacity) ?? false
        stabilizer = try values.decodeIfPresent(Double.self, forKey: .stabilizer) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(points, forKey: .points)
        try values.encode(color, forKey: .color)
        try values.encode(width, forKey: .width)
        try values.encode(opacity, forKey: .opacity)
        try values.encode(tool, forKey: .tool)
        try values.encode(brushPreset, forKey: .brushPreset)
        try values.encode(pressureControlsSize, forKey: .pressureControlsSize)
        try values.encode(pressureControlsOpacity, forKey: .pressureControlsOpacity)
        try values.encode(stabilizer, forKey: .stabilizer)
    }
}

struct ArtworkProject: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var createdAt = Date()
    var updatedAt = Date()
    var sharedReadOnly = false
}

struct ArtworkDocument: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var projectID: UUID?
    var format: ArtworkFormat
    var canvasWidth: Double
    var canvasHeight: Double
    var background: CanvasBackground
    var createdAt = Date()
    var updatedAt = Date()
    var schemaVersion = 2
    var layers: [ArtworkLayer]
    var liveReadOnlyShare = false

    static func new(
        name: String,
        projectID: UUID?,
        format: ArtworkFormat,
        width: Double,
        height: Double,
        background: CanvasBackground
    ) -> ArtworkDocument {
        ArtworkDocument(
            name: name,
            projectID: projectID,
            format: format,
            canvasWidth: width,
            canvasHeight: height,
            background: background,
            layers: [.paint()]
        )
    }
}

struct ArtworkLibraryIndex: Codable, Equatable, Sendable {
    var projects: [ArtworkProject] = []
    var artworkIDs: [UUID] = []
}

enum ArtworkSort: String, CaseIterable, Identifiable {
    case newest
    case name
    case oldest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "Neueste"
        case .name: "Name"
        case .oldest: "Älteste"
        }
    }
}
