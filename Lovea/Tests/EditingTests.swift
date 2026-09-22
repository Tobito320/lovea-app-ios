@preconcurrency import Metal
import XCTest
@testable import Lovea

/// Blocks 4, 5, 8, 9, 11, 13, 15: undo, saving, migration, layer actions, fill, selection,
/// transform, adjustments, export and performance guards.
@MainActor
final class EditingTests: XCTestCase {
    private let red = RGBAColor(red: 1, green: 0, blue: 0)

    // MARK: Z-4.1 undo budget

    func testUndoBudgetEvictsOldestAndPushClearsRedo() throws {
        let device = try XCTUnwrap(GPU.device)
        func entry() throws -> UndoEntry {
            let texture = try XCTUnwrap(GPU.makeTexture(device, width: 16, height: 16))
            return .pixels(layerID: UUID(), region: MTLRegionMake2D(0, 0, 16, 16), before: texture, after: texture)
        }
        let history = UndoHistory(budgetBytes: 16 * 16 * 8 * 3)
        for _ in 0..<5 { history.push(try entry()) }
        XCTAssertEqual(history.count, 3)

        _ = history.popUndo()
        XCTAssertTrue(history.canRedo)
        history.push(try entry())
        XCTAssertFalse(history.canRedo)
    }

    // MARK: Z-4.2 pixel undo per stroke

    func testStrokeUndoRedoRestoresPixels() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        let id = engine.activeLayerID
        let before = await TestGPU.bytes(engine, id)
        TestGPU.stroke(engine, TestGPU.line(from: CGPoint(x: 8, y: 8), to: CGPoint(x: 56, y: 40)), settings: TestGPU.settings())
        let after = await TestGPU.bytes(engine, id)
        XCTAssertNotEqual(before, after)
        engine.performUndo()
        let undone = await TestGPU.bytes(engine, id)
        XCTAssertEqual(undone, before)
        engine.performRedo()
        let redone = await TestGPU.bytes(engine, id)
        XCTAssertEqual(redone, after)
    }

    // MARK: Z-4.4 fifty steps

    func testSixtyStrokesKeepFiftyUndoSteps() async throws {
        let engine = try await TestGPU.engine(TestGPU.document(width: 2048, height: 2048))
        for index in 0..<60 {
            let x = CGFloat(20 + index * 30)
            TestGPU.stroke(engine, [CGPoint(x: x, y: 100), CGPoint(x: x + 10, y: 120)], settings: TestGPU.settings())
        }
        for step in 0..<50 {
            XCTAssertTrue(engine.undo.canUndo, "step \(step)")
            engine.performUndo()
        }
    }

    // MARK: Z-4.5 autosave round trip

    func testSaveAndReloadKeepsPixels() async throws {
        let library = TestGPU.library()
        let artwork = library.createArtwork(name: "Speichern", projectID: nil, format: .custom, customWidth: 64, customHeight: 64, background: .white)
        let engine = try await TestGPU.engine(artwork, library: library)
        TestGPU.stroke(engine, TestGPU.line(from: CGPoint(x: 5, y: 30), to: CGPoint(x: 60, y: 30)), settings: TestGPU.settings(size: 8))
        let drawn = await TestGPU.bytes(engine, engine.activeLayerID)
        await engine.saveDirtyLayers()

        let reopened = try await TestGPU.engine(try XCTUnwrap(ArtworkLibrary(rootURL: libraryRoot(library)).document(artwork.id)), library: library)
        let loaded = await TestGPU.bytes(reopened, reopened.activeLayerID)
        XCTAssertEqual(loaded.count, drawn.count)
        XCTAssertLessThanOrEqual(zip(loaded, drawn).map { abs(Int($0) - Int($1)) }.max() ?? 0, 1)
    }

    private func libraryRoot(_ library: ArtworkLibrary) -> URL {
        library.previewURL(for: UUID()).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    // MARK: Z-4.8 migration of old stroke files

    func testLegacyStrokeFileIsRasterized() async throws {
        let library = TestGPU.library()
        var layer = ArtworkLayer.paint(name: "Alt")
        layer.contentFile = "\(UUID().uuidString).drawing"
        var document = TestGPU.document(background: .white, layers: [layer])
        document.schemaVersion = 2
        library.saveDocument(document)
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "legacy-strokes", withExtension: "json"))
        library.saveLayerAsset(try Data(contentsOf: url), fileName: "metal-\(layer.id.uuidString).json", artworkID: document.id)

        let engine = try await TestGPU.engine(document, library: library)
        let pixel = TestGPU.pixel(await TestGPU.bytes(engine, layer.id), width: 64, x: 32, y: 32)
        XCTAssertGreaterThan(pixel[0], 200)
        XCTAssertGreaterThan(pixel[3], 200)
        XCTAssertEqual(engine.document.schemaVersion, 3)
        XCTAssertEqual(engine.document.layers[0].contentFile, "\(layer.id.uuidString).png")
        XCTAssertFalse(engine.undo.canUndo)
        await library.waitForWrites()
        XCTAssertNotNil(library.layerAsset(fileName: "metal-\(layer.id.uuidString).json.migrated", artworkID: document.id))
        XCTAssertNotNil(library.layerAsset(fileName: "\(layer.id.uuidString).png", artworkID: document.id))
    }

    // MARK: Z-5.7 alpha lock

    func testAlphaLockOnlyRecolorsExistingPixels() async throws {
        let layer = ArtworkLayer.paint()
        let engine = try await TestGPU.engine(TestGPU.document(layers: [layer]))
        var mask = [UInt8](repeating: 0, count: 64 * 64)
        mask[32 * 64 + 32] = 255
        engine.paintMask(try XCTUnwrap(GPU.upload(mask, width: 64, height: 64, format: .r8Unorm)), color: RGBAColor(red: 0, green: 0, blue: 1), layerID: layer.id)
        engine.updateDocument { $0.layers[0].alphaLock = true }
        TestGPU.stroke(engine, TestGPU.line(from: CGPoint(x: 0, y: 32), to: CGPoint(x: 64, y: 32)), settings: TestGPU.settings(size: 12))
        let bytes = await TestGPU.bytes(engine, layer.id)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 32, y: 32), [255, 0, 0, 255])
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 20, y: 32)[3], 0)
    }

    // MARK: Z-5.8 merge down

    func testMergeDownKeepsFlattenAndGivesPaintLayer() async throws {
        let lower = ArtworkLayer.paint(name: "Unten")
        var upper = ArtworkLayer.paint(name: "Oben")
        upper.blendMode = .multiply
        upper.opacity = 0.8
        let engine = try await TestGPU.engine(TestGPU.document(background: .white, layers: [lower, upper]))
        var half = [UInt8](repeating: 0, count: 64 * 64)
        for index in 0..<(64 * 32) { half[index] = 255 }
        engine.paintMask(try XCTUnwrap(GPU.upload(half, width: 64, height: 64, format: .r8Unorm)), color: RGBAColor(red: 0.2, green: 0.8, blue: 0.4), layerID: lower.id)
        TestGPU.fill(engine, upper.id, RGBAColor(red: 0.9, green: 0.5, blue: 0.1, alpha: 0.6))
        let before = await TestGPU.flatten(engine).bytes

        engine.mergeDown(upper.id)
        XCTAssertEqual(engine.document.layers.count, 1)
        XCTAssertEqual(engine.document.layers[0].kind, .paint)
        XCTAssertEqual(engine.document.layers[0].name, "Unten")
        let after = await TestGPU.flatten(engine).bytes
        XCTAssertLessThanOrEqual(zip(before, after).map { abs(Int($0) - Int($1)) }.max() ?? 0, 2)

        engine.performUndo()
        XCTAssertEqual(engine.document.layers.map(\.id), [lower.id, upper.id])
    }

    // MARK: Z-5.9 rasterize

    func testRasterizeKeepsPixels() async throws {
        var image = ArtworkLayer.image(name: "Foto")
        image.transform.scale = 0.5
        image.transform.rotation = 0.3
        let engine = try await TestGPU.engine(TestGPU.document(layers: [image]))
        let bytes = (0..<(32 * 32)).flatMap { index -> [UInt8] in [UInt8(index % 256), 90, 200, 255] }
        try engine.setImage(RasterOps.Pixels(bytes: bytes, width: 32, height: 32), for: image.id)
        let before = await TestGPU.flatten(engine).bytes
        engine.rasterize(image.id)
        XCTAssertEqual(engine.document.layers[0].kind, .paint)
        let after = await TestGPU.flatten(engine).bytes
        XCTAssertLessThanOrEqual(zip(before, after).map { abs(Int($0) - Int($1)) }.max() ?? 0, 1)
    }

    // MARK: Z-5.10 clear and flip

    func testClearAndFlipLayer() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        let id = engine.activeLayerID
        var left = [UInt8](repeating: 0, count: 64 * 64)
        for y in 0..<64 { for x in 0..<16 { left[y * 64 + x] = 255 } }
        engine.paintMask(try XCTUnwrap(GPU.upload(left, width: 64, height: 64, format: .r8Unorm)), color: red, layerID: id)

        engine.flipLayer(id, horizontal: true)
        var bytes = await TestGPU.bytes(engine, id)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 60, y: 10)[3], 255)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 4, y: 10)[3], 0)

        engine.flipLayer(id, horizontal: false)
        bytes = await TestGPU.bytes(engine, id)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 60, y: 60)[3], 255)

        engine.clearLayer(id)
        bytes = await TestGPU.bytes(engine, id)
        XCTAssertTrue(bytes.allSatisfy { $0 == 0 })
        engine.performUndo()
        bytes = await TestGPU.bytes(engine, id)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 60, y: 60)[3], 255)
    }

    // MARK: Z-5.11 32 layers at 2048²

    func testThirtyTwoLayersAt2048() async throws {
        let engine = try await TestGPU.engine(TestGPU.document(width: 2048, height: 2048), budget: 1 << 30)
        for index in 2...32 {
            XCTAssertTrue(engine.addLayer(.paint(name: "Ebene \(index)")), "layer \(index)")
        }
        XCTAssertEqual(engine.document.layers.count, 32)
    }

    func testBudgetStopsNewLayers() async throws {
        let engine = try await TestGPU.engine(TestGPU.document(), budget: 64 * 64 * 4 * 2)
        XCTAssertTrue(engine.addLayer(.paint(name: "Zwei")))
        XCTAssertFalse(engine.addLayer(.paint(name: "Drei")))
    }

    // MARK: Z-5.14 pick layer by content

    func testTopLayerAtPoint() async throws {
        let lower = ArtworkLayer.paint(name: "Unten")
        let upper = ArtworkLayer.paint(name: "Oben")
        let engine = try await TestGPU.engine(TestGPU.document(layers: [lower, upper]))
        TestGPU.fill(engine, lower.id, red)
        let first = await engine.topLayer(at: CGPoint(x: 10, y: 10))
        XCTAssertEqual(first, lower.id)
        TestGPU.fill(engine, upper.id, red)
        let second = await engine.topLayer(at: CGPoint(x: 10, y: 10))
        XCTAssertEqual(second, upper.id)
    }

    // MARK: Z-6.1 / Z-6.7 photo import

    func testLargePhotoIsDownscaled() throws {
        let big = RasterOps.Pixels(bytes: [UInt8](repeating: 128, count: 8000 * 8 * 4), width: 8000, height: 8)
        let png = try XCTUnwrap(RasterOps.encode(big))
        let decoded = try XCTUnwrap(RasterOps.decode(png, maxPixelSize: 4096))
        XCTAssertLessThanOrEqual(max(decoded.width, decoded.height), 4096)
    }

    func testTransparentPNGKeepsAlpha() throws {
        let pixels = RasterOps.Pixels(bytes: [255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255], width: 2, height: 2)
        let decoded = try XCTUnwrap(RasterOps.decode(try XCTUnwrap(RasterOps.encode(pixels)), maxPixelSize: 64))
        XCTAssertEqual(decoded.bytes[3], 255)
        XCTAssertEqual(decoded.bytes[7], 0)
        XCTAssertEqual(decoded.bytes[15], 255)
    }

    // MARK: Z-8.1 eyedropper

    func testSampleColorReadsOnePixel() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        TestGPU.fill(engine, engine.activeLayerID, RGBAColor(red: 0.2, green: 0.6, blue: 1))
        let color = try XCTUnwrap(await engine.sampleColor(at: CGPoint(x: 7, y: 9)))
        XCTAssertEqual(color.red, 0.2, accuracy: 0.01)
        XCTAssertEqual(color.green, 0.6, accuracy: 0.01)
        XCTAssertEqual(color.blue, 1, accuracy: 0.01)
    }

    // MARK: Z-8.2 flood fill

    func testFillFillsClosedCircleInside() {
        let size = 64
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        for y in 0..<size {
            for x in 0..<size {
                let d = hypot(Double(x) - 32, Double(y) - 32)
                if abs(d - 20) < 1.5 {
                    let i = (y * size + x) * 4
                    bytes[i + 3] = 255
                }
            }
        }
        let mask = RasterOps.floodFillMask(RasterOps.Pixels(bytes: bytes, width: size, height: size), x: 32, y: 32, tolerance: 0)
        for y in 0..<size {
            for x in 0..<size where hypot(Double(x) - 32, Double(y) - 32) < 18 {
                XCTAssertEqual(mask[y * size + x], 255, "inside \(x),\(y)")
            }
        }
        XCTAssertEqual(mask[0], 0, "outside stays empty")
    }

    func testFillToleranceZeroStopsAtNeighborColor() {
        var bytes: [UInt8] = []
        for _ in 0..<8 { bytes += [10, 10, 10, 255, 10, 10, 10, 255, 11, 10, 10, 255, 11, 10, 10, 255, 11, 10, 10, 255] }
        let pixels = RasterOps.Pixels(bytes: bytes, width: 5, height: 8)
        let mask = RasterOps.floodFillMask(pixels, x: 0, y: 0, tolerance: 0)
        XCTAssertEqual(mask[0], 255)
        XCTAssertEqual(mask[2], 255, "1 px growth into the border")
        XCTAssertEqual(mask[4], 0, "no fill in the neighbor color")
    }

    func testFillGrowsOnePixel() {
        let mask = RasterOps.dilate([0, 0, 0, 0, 255, 0, 0, 0, 0], width: 3, height: 3)
        XCTAssertEqual(mask, Array(repeating: 255, count: 9))
    }

    func testFillPaintsIntoActiveLayer() async throws {
        let engine = try await TestGPU.engine(TestGPU.document(background: .white))
        await engine.fill(at: CGPoint(x: 10, y: 10), color: red, tolerance: 0.1, reference: .allVisible, layerID: engine.activeLayerID)
        XCTAssertEqual(engine.document.layers.count, 1)
        let bytes = await TestGPU.bytes(engine, engine.activeLayerID)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 40, y: 40), [255, 0, 0, 255])
        XCTAssertTrue(engine.undo.canUndo)
    }

    // MARK: Z-8.4 fill speed

    func testFill2048IsUnderOneSecond() async throws {
        let engine = try await TestGPU.engine(TestGPU.document(width: 2048, height: 2048, background: .white))
        let start = Date()
        await engine.fill(at: CGPoint(x: 1000, y: 1000), color: red, tolerance: 0.1, reference: .allVisible, layerID: engine.activeLayerID)
        let seconds = Date().timeIntervalSince(start)
        print("Füllen 2048²: \(seconds) s")
        XCTAssertLessThan(seconds, 1)
    }

    // MARK: Z-8.5 fill respects selection and alpha lock

    func testFillRespectsSelectionAndAlphaLock() async throws {
        let engine = try await TestGPU.engine(TestGPU.document(background: .white))
        await engine.select(polygon: Selection.rectangle(from: .zero, to: CGPoint(x: 32, y: 64)))
        await engine.fill(at: CGPoint(x: 10, y: 10), color: red, tolerance: 0.1, reference: .allVisible, layerID: engine.activeLayerID)
        var bytes = await TestGPU.bytes(engine, engine.activeLayerID)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 10, y: 10)[3], 255)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 50, y: 10)[3], 0)

        engine.clearSelection()
        engine.updateDocument { $0.layers[0].alphaLock = true }
        await engine.fill(at: CGPoint(x: 50, y: 10), color: RGBAColor(red: 0, green: 0, blue: 1), tolerance: 0.1, reference: .allVisible, layerID: engine.activeLayerID)
        bytes = await TestGPU.bytes(engine, engine.activeLayerID)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 50, y: 10)[3], 0, "alpha lock keeps empty pixels empty")
    }

    // MARK: Z-9.1 / Z-9.6 selection masks

    func testLassoSquareMask() {
        let mask = Selection.mask([CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 10), CGPoint(x: 50, y: 50), CGPoint(x: 10, y: 50)], width: 64, height: 64)
        XCTAssertEqual(mask[30 * 64 + 30], 255)
        XCTAssertEqual(mask[5 * 64 + 5], 0)
        XCTAssertEqual(mask[55 * 64 + 30], 0)
    }

    func testRectangleSelectionMask() {
        let mask = Selection.mask(Selection.rectangle(from: CGPoint(x: 40, y: 8), to: CGPoint(x: 20, y: 24)), width: 64, height: 64)
        XCTAssertEqual(mask[16 * 64 + 30], 255)
        XCTAssertEqual(mask[16 * 64 + 45], 0)
        XCTAssertEqual(mask[30 * 64 + 30], 0)
    }

    // MARK: Z-9.4 painting only inside the selection

    func testStrokeStaysInsideSelection() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        await engine.select(polygon: Selection.rectangle(from: .zero, to: CGPoint(x: 32, y: 64)))
        TestGPU.stroke(engine, TestGPU.line(from: CGPoint(x: 5, y: 32), to: CGPoint(x: 60, y: 32)), settings: TestGPU.settings(size: 8))
        let bytes = await TestGPU.bytes(engine, engine.activeLayerID)
        XCTAssertGreaterThan(TestGPU.pixel(bytes, width: 64, x: 16, y: 32)[3], 200)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 48, y: 32)[3], 0)
    }

    // MARK: Z-9.5 selection actions

    func testInvertDeleteAndCopySelection() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        let id = engine.activeLayerID
        TestGPU.fill(engine, id, red)
        await engine.select(polygon: Selection.rectangle(from: .zero, to: CGPoint(x: 32, y: 64)))

        let copy = try XCTUnwrap(engine.copySelectionToNewLayer(from: id, cut: false))
        let copied = await TestGPU.bytes(engine, copy)
        XCTAssertEqual(TestGPU.pixel(copied, width: 64, x: 10, y: 10)[3], 255)
        XCTAssertEqual(TestGPU.pixel(copied, width: 64, x: 50, y: 10)[3], 0)

        engine.invertSelection()
        let inverted = await GPU.readBytes(try XCTUnwrap(engine.selection))
        XCTAssertEqual(inverted[10 * 64 + 10], 0)
        XCTAssertEqual(inverted[10 * 64 + 50], 255)

        engine.deleteSelection(in: id)
        let remaining = await TestGPU.bytes(engine, id)
        XCTAssertEqual(TestGPU.pixel(remaining, width: 64, x: 10, y: 10)[3], 255)
        XCTAssertEqual(TestGPU.pixel(remaining, width: 64, x: 50, y: 10)[3], 0)
        engine.performUndo()
        let restored = await TestGPU.bytes(engine, id)
        XCTAssertEqual(TestGPU.pixel(restored, width: 64, x: 50, y: 10)[3], 255)
    }

    // MARK: Z-9.9 / Z-9.10 / Z-9.11 transform

    func testScaleUpAndDownStaysClose() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        let id = engine.activeLayerID
        let blob = (0..<(64 * 64)).flatMap { index -> [UInt8] in
            let x = Double(index % 64) - 32
            let y = Double(index / 64) - 32
            let a = UInt8(255 * exp(-(x * x + y * y) / 60))
            return [a, a / 2, 0, a]
        }
        try engine.setImage(RasterOps.Pixels(bytes: blob, width: 64, height: 64), for: id)
        let original = await TestGPU.bytes(engine, id)

        XCTAssertTrue(engine.beginTransform())
        engine.updateTransform(LayerTransform(scale: 2))
        engine.commitTransform()
        XCTAssertTrue(engine.beginTransform())
        engine.updateTransform(LayerTransform(scale: 0.5))
        engine.commitTransform()

        let result = await TestGPU.bytes(engine, id)
        let error = zip(original, result).map { Double(abs(Int($0) - Int($1))) }.reduce(0, +) / Double(original.count)
        XCTAssertLessThan(error, 3)
    }

    func testImageTransformIsLossless() async throws {
        let image = ArtworkLayer.image(name: "Foto")
        let engine = try await TestGPU.engine(TestGPU.document(layers: [image]))
        try engine.setImage(RasterOps.Pixels(bytes: [UInt8](repeating: 200, count: 32 * 32 * 4), width: 32, height: 32), for: image.id)
        let texture = engine.texture(for: image.id)
        let before = await TestGPU.bytes(engine, image.id)
        XCTAssertTrue(engine.beginTransform())
        engine.updateTransform(LayerTransform(offsetX: 5, scale: 1.7, rotation: 0.4))
        engine.commitTransform()
        XCTAssertEqual(engine.document.layers[0].transform.scale, 1.7)
        XCTAssertTrue(engine.texture(for: image.id) === texture)
        let after = await TestGPU.bytes(engine, image.id)
        XCTAssertEqual(before, after)
        engine.performUndo()
        XCTAssertEqual(engine.document.layers[0].transform, LayerTransform())
    }

    func testRotationSnaps() {
        XCTAssertEqual(Selection.snappedRotation(2 * .pi / 180), 0)
        XCTAssertEqual(Selection.snappedRotation(.pi / 2 + 0.04) ?? 0, .pi / 2, accuracy: 0.0001)
        XCTAssertNil(Selection.snappedRotation(0.1))
    }

    // MARK: Z-10.1 shapes

    func testShapePoints() {
        let line = Selection.shapePoints(.line, from: .zero, to: CGPoint(x: 10, y: 3), constrained: true)
        XCTAssertEqual(line.count, 2)
        XCTAssertEqual(line[1].y, 0, accuracy: 0.001, "snaps to 0°")

        let rect = Selection.shapePoints(.rectangle, from: .zero, to: CGPoint(x: 10, y: 4), constrained: true)
        XCTAssertEqual(rect.count, 5)
        XCTAssertEqual(rect[2], CGPoint(x: 10, y: 10), "square")

        let ellipse = Selection.shapePoints(.ellipse, from: .zero, to: CGPoint(x: 20, y: 10), constrained: false)
        for point in ellipse {
            let value = pow((point.x - 10) / 10, 2) + pow((point.y - 5) / 5, 2)
            XCTAssertEqual(value, 1, accuracy: 0.001)
        }
    }

    func testShapeIsStampedIntoActiveLayer() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        let points = Selection.shapePoints(.rectangle, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 50), constrained: false)
        await engine.drawShape(points, filled: false, settings: TestGPU.settings(size: 4), layerID: engine.activeLayerID)
        await engine.drawShape(Selection.shapePoints(.ellipse, from: CGPoint(x: 20, y: 20), to: CGPoint(x: 40, y: 40), constrained: true), filled: true, settings: TestGPU.settings(), layerID: engine.activeLayerID)
        let bytes = await TestGPU.bytes(engine, engine.activeLayerID)
        XCTAssertGreaterThan(TestGPU.pixel(bytes, width: 64, x: 30, y: 10)[3], 200, "outline")
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 15, y: 30)[3], 0, "inside the outline stays empty")
        XCTAssertGreaterThan(TestGPU.pixel(bytes, width: 64, x: 30, y: 30)[3], 200, "filled ellipse")
        XCTAssertEqual(engine.document.layers.count, 1)
    }

    // MARK: Z-11 adjustments

    func testAdjustmentMenuHasSixEntries() {
        XCTAssertEqual(Adjustment.allCases.count, 6)
    }

    func testGrayscaleAndInvertOnKnownPixels() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        let id = engine.activeLayerID
        TestGPU.fill(engine, id, RGBAColor(red: 1, green: 0, blue: 0))
        engine.previewAdjustment(.grayscale, amount: 0)
        engine.commitAdjustment()
        var pixel = TestGPU.pixel(await TestGPU.bytes(engine, id), width: 64, x: 3, y: 3)
        XCTAssertEqual(pixel[0], 54, accuracy: 2)
        XCTAssertEqual(pixel[1], 54, accuracy: 2)

        TestGPU.fill(engine, id, RGBAColor(red: 0.2, green: 0.4, blue: 0.6))
        engine.previewAdjustment(.invert, amount: 0)
        engine.commitAdjustment()
        pixel = TestGPU.pixel(await TestGPU.bytes(engine, id), width: 64, x: 3, y: 3)
        XCTAssertEqual(pixel[0], 204, accuracy: 2)
        XCTAssertEqual(pixel[1], 153, accuracy: 2)
        XCTAssertEqual(pixel[2], 102, accuracy: 2)
    }

    func testInvertOnlyInsideSelectionAndUndo() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        let id = engine.activeLayerID
        TestGPU.fill(engine, id, RGBAColor(red: 1, green: 0, blue: 0))
        await engine.select(polygon: Selection.rectangle(from: .zero, to: CGPoint(x: 32, y: 64)))
        engine.previewAdjustment(.invert, amount: 0)
        engine.commitAdjustment()
        let bytes = await TestGPU.bytes(engine, id)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 10, y: 10), [0, 255, 255, 255])
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 50, y: 10), [255, 0, 0, 255])

        engine.performUndo()
        let undone = await TestGPU.bytes(engine, id)
        XCTAssertEqual(TestGPU.pixel(undone, width: 64, x: 10, y: 10), [255, 0, 0, 255])
    }

    // MARK: Z-13.1 / Z-13.2 export

    func testExportHasFullSizeAndPixels() async throws {
        let engine = try await TestGPU.engine(TestGPU.document(width: 120, height: 80, background: .white))
        TestGPU.fill(engine, engine.activeLayerID, RGBAColor(red: 0, green: 0, blue: 1))
        let image = try XCTUnwrap(await engine.flattenedImage())
        XCTAssertEqual(image.size, CGSize(width: 120, height: 80))
        let decoded = try XCTUnwrap(RasterOps.decode(try XCTUnwrap(ArtworkExport.encode(image, format: .png))))
        XCTAssertEqual(TestGPU.pixel(decoded.bytes, width: 120, x: 60, y: 40), [0, 0, 255, 255])
    }

    func testTransparentExportKeepsAlphaInPNG() async throws {
        let engine = try await TestGPU.engine(TestGPU.document(background: .transparent))
        let image = try XCTUnwrap(await engine.flattenedImage())
        let decoded = try XCTUnwrap(RasterOps.decode(try XCTUnwrap(ArtworkExport.encode(image, format: .png))))
        XCTAssertEqual(TestGPU.pixel(decoded.bytes, width: 64, x: 5, y: 5)[3], 0)
    }

    // MARK: Z-15.2 / Z-15.3 frames

    func testFramesAllocateNothingAfterTheFirst() async throws {
        let engine = try await TestGPU.engine(TestGPU.document(width: 512, height: 512))
        engine.beginStroke(StrokeInput(location: CGPoint(x: 10, y: 10)), settings: TestGPU.settings(), layerID: engine.activeLayerID)
        engine.renderOffscreen()
        let allocations = EngineStats.allocations
        for frame in 0..<100 {
            let x = 10 + Double(frame) * 4.5
            engine.continueStroke([StrokeInput(location: CGPoint(x: x, y: 10 + Double(frame % 7)))], predicted: [StrokeInput(location: CGPoint(x: x + 5, y: 12))])
            engine.renderOffscreen()
        }
        XCTAssertEqual(EngineStats.allocations, allocations)
        engine.cancelStroke()
    }

    func testEveryStampIsDrawnOnce() async throws {
        let engine = try await TestGPU.engine(TestGPU.document(width: 1024, height: 1024))
        let inputs = (0..<1000).map { StrokeInput(location: CGPoint(x: 10 + Double($0), y: 500 + sin(Double($0) / 30) * 200)) }
        var reference = StrokeSampler(settings: TestGPU.settings())
        let expected = inputs.reduce(0) { $0 + reference.add($1).count }

        engine.beginStroke(inputs[0], settings: TestGPU.settings(), layerID: engine.activeLayerID)
        for frame in 0..<10 {
            let start = frame == 0 ? 1 : frame * 100
            engine.continueStroke(Array(inputs[start..<(frame + 1) * 100]), predicted: [])
            engine.renderOffscreen()
        }
        XCTAssertEqual(engine.fixedStampsEncoded, expected)
        engine.cancelStroke()
    }

    // MARK: Z-15.5 memory warning

    func testMemoryWarningDropsHalfTheUndo() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        for index in 0..<10 {
            TestGPU.stroke(engine, [CGPoint(x: 5, y: 5 + index * 5), CGPoint(x: 50, y: 5 + index * 5)], settings: TestGPU.settings(size: 2))
        }
        XCTAssertEqual(engine.undo.count, 10)
        engine.renderOffscreen()
        engine.handleMemoryWarning()
        XCTAssertEqual(engine.undo.count, 5)
        engine.renderOffscreen()
        XCTAssertGreaterThan(engine.compositor.belowBuilds, 1, "caches were rebuilt")
    }

    // MARK: Z-15.6 stress

    func testStressManyLayersStrokesAndUndo() async throws {
        let start = Date()
        let engine = try await TestGPU.engine(TestGPU.document(width: 2048, height: 2048))
        for index in 2...20 { XCTAssertTrue(engine.addLayer(.paint(name: "Ebene \(index)"))) }
        let ids = engine.document.layers.map(\.id)
        for index in 0..<500 {
            engine.activeLayerID = ids[index % ids.count]
            let x = CGFloat(50 + (index * 37) % 1900)
            let y = CGFloat(50 + (index * 53) % 1900)
            TestGPU.stroke(engine, [CGPoint(x: x, y: y), CGPoint(x: x + 40, y: y + 25), CGPoint(x: x + 60, y: y - 10)], settings: TestGPU.settings(size: 12))
            if index % 50 == 0 { engine.renderOffscreen() }
        }
        for _ in 0..<50 { engine.performUndo() }
        engine.renderOffscreen()
        _ = await TestGPU.flatten(engine)
        print("Stresstest 2048², 20 Ebenen, 500 Striche, 50 × Undo: \(Date().timeIntervalSince(start)) s")
    }

    // MARK: Z-15.7 idle

    func testCanvasDoesNotDrawWhenIdle() async throws {
        let library = TestGPU.library()
        let artwork = library.createArtwork(name: "Ruhe", projectID: nil, format: .custom, customWidth: 64, customHeight: 64)
        let session = DrawingSession(artworkID: artwork.id, library: library)
        let view = CanvasView(session: session)
        view.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        XCTAssertTrue(view.isPaused)
        XCTAssertTrue(view.enableSetNeedsDisplay)
        await session.engine?.loading?.value
        let frames = session.engine?.frameCount ?? -1
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(session.engine?.frameCount, frames)
    }
}
