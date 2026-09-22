import PencilKit
import UIKit

// Old stroke format (schema 2). Only read here, once, to rasterize into layer textures.

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

extension CanvasEngine {
    /// Schema < 3: rasterizes old PencilKit drawings and `metal-<id>.json` strokes into the layer
    /// textures, saves them as PNG and renames the old files to `.migrated`. Nothing is deleted.
    func migrateLegacyLayers() async {
        var next = document
        let artworkID = document.id
        for index in next.layers.indices where next.layers[index].kind == .paint {
            let layer = next.layers[index]
            let oldFile = layer.contentFile
            if oldFile.hasSuffix(".drawing"),
               let data = library.layerAsset(fileName: oldFile, artworkID: artworkID),
               let drawing = try? PKDrawing(data: data) {
                var image: UIImage?
                UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                    image = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: 1)
                }
                if let cgImage = image?.cgImage, let pixels = RasterOps.pixels(of: cgImage) {
                    try? setImage(pixels, for: layer.id)
                }
                library.renameLayerAsset(fileName: oldFile, to: oldFile + ".migrated", artworkID: artworkID)
            }
            let strokesFile = "metal-\(layer.id.uuidString).json"
            if let data = library.layerAsset(fileName: strokesFile, artworkID: artworkID),
               let strokes = try? JSONDecoder().decode([MetalPaintStroke].self, from: data) {
                activeLayerID = layer.id
                for stroke in strokes { replay(stroke, on: layer.id) }
                library.renameLayerAsset(fileName: strokesFile, to: strokesFile + ".migrated", artworkID: artworkID)
            }
            next.layers[index].contentFile = "\(layer.id.uuidString).png"
            next.layers[index].alphaMaskFile = nil
            markDirty(layer.id)
        }
        next.schemaVersion = 3
        updateDocument(undoable: false) { $0 = next }
        activeLayerID = next.layers.last(where: { $0.kind == .paint })?.id ?? next.layers.last?.id ?? activeLayerID
        undo.removeAll()
        await saveDirtyLayers()
    }

    private func replay(_ stroke: MetalPaintStroke, on layerID: UUID) {
        let inputs = stroke.points.map {
            StrokeInput(location: CGPoint(x: $0.x, y: $0.y), pressure: $0.pressure, timestamp: $0.timestamp)
        }
        guard let first = inputs.first else { return }
        let settings = BrushSettings(
            preset: BrushPreset(rawValue: stroke.brushPreset) ?? .pen,
            size: stroke.width,
            opacity: stroke.opacity,
            color: stroke.color,
            pressureSize: stroke.pressureControlsSize,
            pressureOpacity: stroke.pressureControlsOpacity,
            stabilizer: Int(stroke.stabilizer),
            isEraser: stroke.tool == .eraser
        )
        beginStroke(first, settings: settings, layerID: layerID)
        continueStroke(Array(inputs.dropFirst()), predicted: [])
        endStroke()
    }
}
