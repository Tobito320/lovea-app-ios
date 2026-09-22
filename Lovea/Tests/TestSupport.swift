@preconcurrency import Metal
import XCTest
@testable import Lovea

/// Small helpers shared by the engine tests.
@MainActor
enum TestGPU {
    static func library() -> ArtworkLibrary {
        ArtworkLibrary(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("LoveaTests-\(UUID().uuidString)"))
    }

    static func document(
        width: Double = 64,
        height: Double = 64,
        background: CanvasBackground = .transparent,
        layers: [ArtworkLayer] = [.paint()]
    ) -> ArtworkDocument {
        var document = ArtworkDocument.new(name: "Test", projectID: nil, format: .custom, width: width, height: height, background: background)
        document.layers = layers
        return document
    }

    static func engine(
        _ document: ArtworkDocument,
        library: ArtworkLibrary? = nil,
        budget: Int = 1 << 30
    ) async throws -> CanvasEngine {
        let engine = try CanvasEngine(document: document, library: library ?? Self.library(), budgetBytes: budget)
        await engine.loading?.value
        return engine
    }

    static func fill(_ engine: CanvasEngine, _ layerID: UUID, _ color: RGBAColor) {
        guard let texture = engine.texture(for: layerID), let command = engine.makeCommand() else { return }
        GPU.fill(texture, color: color, command: command)
        command.commit()
    }

    static func bytes(_ engine: CanvasEngine, _ layerID: UUID) async -> [UInt8] {
        guard let texture = engine.texture(for: layerID) else { return [] }
        return await GPU.readBytes(texture)
    }

    static func flatten(_ engine: CanvasEngine) async -> RasterOps.Pixels {
        await engine.flattenedPixels() ?? RasterOps.Pixels(bytes: [], width: 0, height: 0)
    }

    /// RGBA bytes of one pixel.
    static func pixel(_ bytes: [UInt8], width: Int, x: Int, y: Int) -> [Int] {
        let index = (y * width + x) * 4
        return (0..<4).map { Int(bytes[index + $0]) }
    }

    static func settings(
        _ preset: BrushPreset = .pen,
        size: Double = 10,
        opacity: Double = 1,
        color: RGBAColor = RGBAColor(red: 1, green: 0, blue: 0),
        eraser: Bool = false
    ) -> BrushSettings {
        BrushSettings(
            preset: preset, size: size, opacity: opacity, color: color,
            pressureSize: false, pressureOpacity: false, stabilizer: 0, isEraser: eraser
        )
    }

    static func stroke(_ engine: CanvasEngine, _ points: [CGPoint], settings: BrushSettings, layerID: UUID? = nil) {
        let inputs = points.map { StrokeInput(location: $0) }
        engine.beginStroke(inputs[0], settings: settings, layerID: layerID ?? engine.activeLayerID)
        engine.continueStroke(Array(inputs.dropFirst()), predicted: [])
        engine.endStroke()
    }

    static func line(from a: CGPoint, to b: CGPoint, steps: Int = 20) -> [CGPoint] {
        (0...steps).map { index in
            let t = CGFloat(index) / CGFloat(steps)
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }
}
