@preconcurrency import Metal
import XCTest
@testable import Lovea

/// Block 2: layer textures, blend modes, clipping, image layers, background, caches, loading.
@MainActor
final class CompositorTests: XCTestCase {
    // MARK: Z-2.2 / Z-2.3 LayerTextureStore

    func testStoreCreatesRemovesAndRespectsBudget() throws {
        let device = try XCTUnwrap(GPU.device)
        let store = LayerTextureStore(device: device, canvasSize: CGSize(width: 64, height: 64), budgetBytes: 64 * 64 * 4 * 2)
        let a = UUID()
        let b = UUID()
        let texture = try store.makeEmpty(for: a)
        XCTAssertEqual(texture.width, 64)
        XCTAssertEqual(texture.pixelFormat, .rgba8Unorm)
        XCTAssertEqual(texture.storageMode, .private)
        try store.makeEmpty(for: b)
        XCTAssertEqual(store.bytesInUse, 64 * 64 * 4 * 2)
        XCTAssertThrowsError(try store.makeEmpty(for: UUID())) { error in
            XCTAssertEqual(error as? EngineError, .memoryBudget)
        }
        store.remove(a)
        XCTAssertNil(store.texture(for: a))
        XCTAssertNoThrow(try store.makeEmpty(for: UUID()))
    }

    func testPNGRoundTripKeepsPixels() async throws {
        let device = try XCTUnwrap(GPU.device)
        let store = LayerTextureStore(device: device, canvasSize: CGSize(width: 64, height: 64), budgetBytes: 1 << 24)
        var bytes = [UInt8](repeating: 0, count: 64 * 64 * 4)
        for y in 0..<64 {
            for x in 0..<64 where (x + y) % 3 != 0 {
                let i = (y * 64 + x) * 4
                bytes[i] = UInt8(x * 4)
                bytes[i + 1] = UInt8(y * 4)
                bytes[i + 2] = 200
                bytes[i + 3] = 255
            }
        }
        let png = try XCTUnwrap(RasterOps.encode(RasterOps.Pixels(bytes: bytes, width: 64, height: 64)))
        let id = UUID()
        try store.load(pngData: png, for: id)
        let savedData = await store.pngData(for: id)
        let saved = try XCTUnwrap(savedData)
        let decoded = try XCTUnwrap(RasterOps.decode(saved))
        XCTAssertEqual(decoded.bytes.count, bytes.count)
        for index in bytes.indices {
            XCTAssertLessThanOrEqual(abs(Int(decoded.bytes[index]) - Int(bytes[index])), 1, "byte \(index)")
        }
    }

    // MARK: Z-2.4 blend modes against the W3C formula

    func testNormal() async throws { try await checkBlend(.normal) }
    func testMultiply() async throws { try await checkBlend(.multiply) }
    func testScreen() async throws { try await checkBlend(.screen) }
    func testOverlay() async throws { try await checkBlend(.overlay) }
    func testDarken() async throws { try await checkBlend(.darken) }
    func testLighten() async throws { try await checkBlend(.lighten) }
    func testAdd() async throws { try await checkBlend(.add) }
    func testSoftLight() async throws { try await checkBlend(.softLight) }

    private func checkBlend(_ mode: LayerBlendMode) async throws {
        var upper = ArtworkLayer.paint(name: "Oben")
        upper.blendMode = mode
        let lower = ArtworkLayer.paint(name: "Unten")
        let engine = try await TestGPU.engine(TestGPU.document(width: 1, height: 1, layers: [lower, upper]))
        let backdrop = RGBAColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1)
        let source = RGBAColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.7)
        TestGPU.fill(engine, lower.id, backdrop)
        TestGPU.fill(engine, upper.id, source)
        let result = await TestGPU.flatten(engine).bytes
        let expected = Self.w3c(backdrop: backdrop, source: source, mode: mode)
        for channel in 0..<4 {
            XCTAssertEqual(Double(result[channel]) / 255, expected[channel], accuracy: 2.0 / 255, "\(mode) channel \(channel)")
        }
    }

    /// Premultiplied result of `source` over `backdrop` with a separable blend mode.
    static func w3c(backdrop: RGBAColor, source: RGBAColor, mode: LayerBlendMode) -> [Double] {
        let cb = [backdrop.red, backdrop.green, backdrop.blue]
        let cs = [source.red, source.green, source.blue]
        let ab = backdrop.alpha
        let as_ = source.alpha
        func blend(_ b: Double, _ s: Double) -> Double {
            switch mode {
            case .normal: return s
            case .multiply: return b * s
            case .screen: return b + s - b * s
            case .overlay: return b <= 0.5 ? 2 * b * s : 1 - 2 * (1 - b) * (1 - s)
            case .darken: return min(b, s)
            case .lighten: return max(b, s)
            case .add: return min(b + s, 1)
            case .softLight:
                if s <= 0.5 { return b - (1 - 2 * s) * b * (1 - b) }
                let d = b <= 0.25 ? ((16 * b - 12) * b + 4) * b : sqrt(b)
                return b + (2 * s - 1) * (d - b)
            }
        }
        let rgb = (0..<3).map { i in
            (1 - as_) * ab * cb[i] + (1 - ab) * as_ * cs[i] + ab * as_ * blend(cb[i], cs[i])
        }
        return rgb + [as_ + ab * (1 - as_)]
    }

    // MARK: Z-2.5 clipping like ibisPaint

    func testClippingUsesFirstUnclippedLayerBelow() async throws {
        let base = ArtworkLayer.paint(name: "Basis")
        var first = ArtworkLayer.paint(name: "Clip 1")
        first.clipping = true
        var second = ArtworkLayer.paint(name: "Clip 2")
        second.clipping = true
        let top = ArtworkLayer.paint(name: "Normal")
        let engine = try await TestGPU.engine(TestGPU.document(width: 2, height: 1, layers: [base, first, second, top]))
        // Base covers only pixel 0. Clip 1 is empty. Clip 2 is red everywhere.
        let mask = try XCTUnwrap(GPU.upload([255, 0], width: 2, height: 1, format: .r8Unorm))
        engine.paintMask(mask, color: RGBAColor(red: 1, green: 1, blue: 1), layerID: base.id)
        TestGPU.fill(engine, second.id, RGBAColor(red: 1, green: 0, blue: 0))
        let flat = await TestGPU.flatten(engine).bytes

        // Pixel 0: Clip 2 hangs on the base, not on the empty Clip 1 → red.
        XCTAssertEqual(Array(flat[0..<4]), [255, 0, 0, 255])
        // Pixel 1: the base is empty there → nothing.
        XCTAssertEqual(flat[7], 0)

        // A normal layer on top is not clipped.
        TestGPU.fill(engine, top.id, RGBAColor(red: 0, green: 0, blue: 1))
        engine.compositor.invalidateCaches()
        let withTop = await TestGPU.flatten(engine).bytes
        XCTAssertEqual(Array(withTop[4..<8]), [0, 0, 255, 255])
    }

    // MARK: Z-2.6 image layers with transform

    func testImageLayerRotatedNinetyDegrees() async throws {
        var image = ArtworkLayer.image(name: "Foto")
        image.transform.rotation = .pi / 2
        let engine = try await TestGPU.engine(TestGPU.document(layers: [image]))
        var bytes = [UInt8](repeating: 0, count: 64 * 64 * 4)
        for y in 0..<32 {
            for x in 0..<32 {
                let i = (y * 64 + x) * 4
                bytes[i] = 255
                bytes[i + 3] = 255
            }
        }
        try engine.setImage(RasterOps.Pixels(bytes: bytes, width: 64, height: 64), for: image.id)
        let flat = await TestGPU.flatten(engine)
        // Top-left quadrant, turned 90° clockwise, lands top-right.
        XCTAssertGreaterThan(TestGPU.pixel(flat.bytes, width: 64, x: 48, y: 16)[0], 240)
        XCTAssertLessThan(TestGPU.pixel(flat.bytes, width: 64, x: 16, y: 16)[3], 10)
    }

    // MARK: Z-2.7 background

    func testTransparentBackgroundStaysTransparentInFlatten() async throws {
        let engine = try await TestGPU.engine(TestGPU.document(background: .transparent))
        let flat = await TestGPU.flatten(engine)
        XCTAssertEqual(TestGPU.pixel(flat.bytes, width: 64, x: 10, y: 10)[3], 0)

        let white = try await TestGPU.engine(TestGPU.document(background: .white))
        let whiteFlat = await TestGPU.flatten(white)
        XCTAssertEqual(TestGPU.pixel(whiteFlat.bytes, width: 64, x: 10, y: 10), [255, 255, 255, 255])
    }

    // MARK: Z-2.8 caches / Z-5.12 opacity without rebuild

    func testBelowCacheIsNotRebuiltWithoutChanges() async throws {
        let layers = [ArtworkLayer.paint(name: "A"), ArtworkLayer.paint(name: "B"), ArtworkLayer.paint(name: "C")]
        let engine = try await TestGPU.engine(TestGPU.document(layers: layers))
        engine.activeLayerID = layers[1].id
        for _ in 0..<10 { engine.renderOffscreen() }
        XCTAssertEqual(engine.compositor.belowBuilds, 1)
    }

    func testActiveOpacityDoesNotRebuildCaches() async throws {
        let layers = [ArtworkLayer.paint(name: "A"), ArtworkLayer.paint(name: "B"), ArtworkLayer.paint(name: "C")]
        let engine = try await TestGPU.engine(TestGPU.document(layers: layers))
        engine.activeLayerID = layers[1].id
        engine.renderOffscreen()
        let below = engine.compositor.belowBuilds
        let above = engine.compositor.aboveBuilds
        for step in 1...10 {
            engine.updateDocument(undoable: false) { $0.layers[1].opacity = 1 - Double(step) / 20 }
            engine.renderOffscreen()
        }
        XCTAssertEqual(engine.compositor.belowBuilds, below)
        XCTAssertEqual(engine.compositor.aboveBuilds, above)
    }

    // MARK: Z-2.10 loading a saved document

    func testEngineLoadsThreeLayersFromLibrary() async throws {
        let library = TestGPU.library()
        var artwork = library.createArtwork(name: "Drei", projectID: nil, format: .custom, customWidth: 64, customHeight: 64, background: .transparent)
        let layers = [ArtworkLayer.paint(name: "Rot"), ArtworkLayer.paint(name: "Leer"), ArtworkLayer.paint(name: "Blau")]
        artwork.layers = layers
        library.saveDocument(artwork)
        func png(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8) -> Data {
            RasterOps.encode(RasterOps.Pixels(bytes: Array(repeating: [r, g, b, a], count: 64 * 64).flatMap { $0 }, width: 64, height: 64))!
        }
        library.saveLayerData(png(255, 0, 0, 255), layer: layers[0], artworkID: artwork.id)
        library.saveLayerData(png(0, 0, 0, 0), layer: layers[1], artworkID: artwork.id)
        library.saveLayerData(png(0, 0, 255, 128), layer: layers[2], artworkID: artwork.id)

        let engine = try await TestGPU.engine(try XCTUnwrap(library.document(artwork.id)), library: library)
        let pixel = TestGPU.pixel(await TestGPU.flatten(engine).bytes, width: 64, x: 5, y: 5)
        XCTAssertEqual(pixel[0], 127, accuracy: 3)
        XCTAssertEqual(pixel[1], 0, accuracy: 2)
        XCTAssertEqual(pixel[2], 128, accuracy: 3)
        XCTAssertEqual(pixel[3], 255, accuracy: 1)
    }
}
