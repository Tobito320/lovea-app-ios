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
    /// Height factor relative to `scale` for free (non-proportional) scaling. nil = proportional.
    var stretch: Double?

    var scaleY: Double { scale * (stretch ?? 1) }
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
        let id = UUID()
        return ArtworkLayer(id: id, name: name, kind: .paint, contentFile: "\(id.uuidString).png")
    }

    static func image(name: String = "Bild") -> ArtworkLayer {
        let id = UUID()
        return ArtworkLayer(id: id, name: name, kind: .image, contentFile: "image-\(id.uuidString).png")
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
    var schemaVersion = 3
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
