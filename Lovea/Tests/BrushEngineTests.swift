@preconcurrency import Metal
import XCTest
@testable import Lovea

/// Block 3: brush tips, stabilizer, pressure, stamp spacing, stamper, stroke opacity.
@MainActor
final class BrushEngineTests: XCTestCase {
    // MARK: Z-3.1

    func testEveryPresetHasValidTip() {
        for preset in BrushPreset.allCases {
            let tip = preset.tip
            XCTAssertGreaterThan(tip.spacing, 0, "\(preset)")
            XCTAssert((0...1).contains(tip.hardness), "\(preset)")
            XCTAssert((0...1).contains(tip.flow), "\(preset)")
            XCTAssert((0...1).contains(tip.grain), "\(preset)")
            XCTAssertGreaterThan(tip.aspect, 0, "\(preset)")
        }
        XCTAssertEqual(BrushPreset.calligraphy.tip.aspect, 0.3)
        XCTAssertEqual(BrushPreset.calligraphy.tip.fixedAngle ?? 0, .pi / 4, accuracy: 0.0001)
        XCTAssertTrue(BrushPreset.pixel.tip.pixelSnap)
        XCTAssertTrue(BrushPreset.airbrush.tip.buildsUp)
        XCTAssertEqual(BrushPreset.highlighter.opacityCap, 0.4)
    }

    // MARK: Z-3.2 stabilizer

    func testStabilizerLevelZeroKeepsPoints() {
        var stabilizer = Stabilizer(level: 0)
        for point in [CGPoint(x: 1, y: 2), CGPoint(x: 10, y: -4), CGPoint(x: 3, y: 7)] {
            XCTAssertEqual(stabilizer.smooth(point), point)
        }
    }

    func testStabilizerLevelNineFlattensZigzag() {
        var stabilizer = Stabilizer(level: 9)
        var output: [CGPoint] = []
        for index in 0..<60 {
            output.append(stabilizer.smooth(CGPoint(x: CGFloat(index) * 5, y: index.isMultiple(of: 2) ? 10 : -10)))
        }
        let amplitude = output[30...].map { abs($0.y) }.max() ?? 10
        XCTAssertLessThanOrEqual(amplitude, 3, "at least 70 % smoother than ±10")
    }

    func testCatchUpEndsExactlyAtEndPoint() {
        var stabilizer = Stabilizer(level: 8)
        _ = stabilizer.smooth(.zero)
        _ = stabilizer.smooth(CGPoint(x: 100, y: 50))
        let tail = stabilizer.catchUp(to: CGPoint(x: 100, y: 50))
        XCTAssertEqual(tail.last, CGPoint(x: 100, y: 50))
        XCTAssertGreaterThan(tail.count, 1)
    }

    // MARK: Z-3.3 pressure curve and tilt

    func testPressureCurve() {
        let tip = BrushPreset.pen.tip
        XCTAssertEqual(StrokeSampler.pressureScale(0, tip: tip), 0.35, accuracy: 0.0001)
        XCTAssertEqual(StrokeSampler.pressureScale(1, tip: tip), 1, accuracy: 0.0001)
        XCTAssertEqual(StrokeSampler.pressureScale(0.5, tip: tip), 0.35 + 0.65 * pow(0.5, 0.8), accuracy: 0.0001)
    }

    func testFlatTiltWidensPencil() {
        XCTAssertEqual(StrokeSampler.tiltFactor(altitude: .pi / 2), 1, accuracy: 0.0001)
        XCTAssertEqual(StrokeSampler.tiltFactor(altitude: 0), 2.5, accuracy: 0.0001)
        var settings = TestGPU.settings(.pencil, size: 10)
        settings.pressureSize = false
        var upright = StrokeSampler(settings: settings)
        var flat = StrokeSampler(settings: settings)
        let a = upright.add(StrokeInput(location: .zero, altitude: .pi / 2))
        let b = flat.add(StrokeInput(location: .zero, altitude: 0.1))
        XCTAssertGreaterThan(b[0].radius, a[0].radius * 2)
    }

    // MARK: Z-3.4 spacing

    func testStraightLineSpacing() {
        // 2 * radius * spacing = 5 px with the pen (spacing 0.08).
        var sampler = StrokeSampler(settings: TestGPU.settings(.pen, size: 62.5))
        var stamps: [Stamp] = []
        for x in stride(from: 0.0, through: 100, by: 10) {
            stamps += sampler.add(StrokeInput(location: CGPoint(x: x, y: 0)))
        }
        XCTAssertEqual(Double(stamps.count), 20, accuracy: 1.5)
        XCTAssertEqual(Double(stamps[1].center.x - stamps[0].center.x), 5, accuracy: 0.01)
    }

    func testSplittingInputGivesSameStamps() {
        let inputs = (0..<30).map { StrokeInput(location: CGPoint(x: Double($0) * 3.7, y: sin(Double($0)) * 9)) }
        var one = StrokeSampler(settings: TestGPU.settings(.chalk, size: 12))
        var two = StrokeSampler(settings: TestGPU.settings(.chalk, size: 12))
        let all = inputs.flatMap { one.add($0) }
        let first = inputs[..<13].flatMap { two.add($0) }
        let second = inputs[13...].flatMap { two.add($0) }
        XCTAssertEqual(all, first + second)
    }

    // MARK: Z-3.5 stamper

    func testSingleStampHasHardEdge() async throws {
        let device = try XCTUnwrap(GPU.device)
        let library = try XCTUnwrap(GPU.library)
        let stamper = try BrushStamper(device: device, library: library)
        let target = try XCTUnwrap(GPU.makeTexture(device, width: 64, height: 64))
        let command = try XCTUnwrap(GPU.queue?.makeCommandBuffer())
        GPU.fill(target, command: command)
        let stamp = Stamp(center: SIMD2(32, 32), radius: 10, opacity: 1, angle: 0, aspect: 1)
        stamper.encode([stamp], tip: BrushPreset.pen.tip, color: RGBAColor(red: 0, green: 0, blue: 0), into: target, mask: nil, mirrorX: nil, command: command)
        command.commit()
        let bytes = await GPU.readBytes(target)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 32, y: 32)[3], 255)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 44, y: 32)[3], 0)
    }

    // MARK: Z-3.6 no build-up inside a stroke

    func testSelfCrossingStrokeNeverExceedsItsOpacity() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        let loop = [CGPoint(x: 10, y: 32), CGPoint(x: 54, y: 32), CGPoint(x: 32, y: 10), CGPoint(x: 32, y: 54), CGPoint(x: 10, y: 32)]
        let points = zip(loop, loop.dropFirst()).flatMap { TestGPU.line(from: $0, to: $1) }
        TestGPU.stroke(engine, points, settings: TestGPU.settings(.pen, size: 12, opacity: 0.5))
        let bytes = await TestGPU.bytes(engine, engine.activeLayerID)
        let maxAlpha = stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }.max() ?? 0
        XCTAssertGreaterThan(maxAlpha, 100)
        XCTAssertLessThanOrEqual(maxAlpha, 129)
    }

    // MARK: Z-3.7 airbrush builds up

    func testAirbrushBuildsUp() async throws {
        func alpha(stamps count: Int) async throws -> UInt8 {
            let device = try XCTUnwrap(GPU.device)
            let stamper = try BrushStamper(device: device, library: try XCTUnwrap(GPU.library))
            let target = try XCTUnwrap(GPU.makeTexture(device, width: 32, height: 32))
            let command = try XCTUnwrap(GPU.queue?.makeCommandBuffer())
            GPU.fill(target, command: command)
            let stamp = Stamp(center: SIMD2(16, 16), radius: 8, opacity: BrushPreset.airbrush.tip.flow, angle: 0, aspect: 1)
            stamper.encode(Array(repeating: stamp, count: count), tip: BrushPreset.airbrush.tip, color: RGBAColor(red: 0, green: 0, blue: 0), into: target, mask: nil, mirrorX: nil, command: command)
            command.commit()
            return TestGPU.pixel(await GPU.readBytes(target), width: 32, x: 16, y: 16)[3].toUInt8
        }
        let one = try await alpha(stamps: 1)
        let ten = try await alpha(stamps: 10)
        XCTAssertGreaterThan(ten, one)
    }

    // MARK: Z-3.8 eraser

    func testEraserClearsOpaquePixel() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        TestGPU.fill(engine, engine.activeLayerID, RGBAColor(red: 0, green: 0, blue: 1))
        TestGPU.stroke(engine, TestGPU.line(from: CGPoint(x: 20, y: 32), to: CGPoint(x: 44, y: 32)), settings: TestGPU.settings(.pen, size: 16, eraser: true))
        let bytes = await TestGPU.bytes(engine, engine.activeLayerID)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 32, y: 32)[3], 0)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 32, y: 5)[3], 255)
    }

    // MARK: Z-3.9 pixel brush

    func testPixelBrushHasNoPartialPixels() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        TestGPU.stroke(engine, TestGPU.line(from: CGPoint(x: 5.3, y: 7.8), to: CGPoint(x: 58.1, y: 50.6), steps: 40), settings: TestGPU.settings(.pixel, size: 3))
        let bytes = await TestGPU.bytes(engine, engine.activeLayerID)
        let alphas = Set(stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] })
        XCTAssertEqual(alphas, [0, 255])
    }

    // MARK: Z-3.10 predicted touches

    func testPredictedTouchesDoNotChangeFixedStamps() {
        let inputs = (0..<20).map { StrokeInput(location: CGPoint(x: Double($0) * 4, y: 0)) }
        var plain = StrokeSampler(settings: TestGPU.settings())
        var guessed = StrokeSampler(settings: TestGPU.settings())
        var fixedPlain: [Stamp] = []
        var fixedGuessed: [Stamp] = []
        for input in inputs {
            fixedPlain += plain.add(input)
            fixedGuessed += guessed.add(input)
            var preview = guessed
            _ = preview.add(StrokeInput(location: CGPoint(x: input.location.x + 30, y: 40)))
        }
        XCTAssertEqual(fixedPlain, fixedGuessed)
    }

    // MARK: Z-3.15 cancel

    func testCancelStrokeLeavesNoPixelsAndNoUndo() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        let inputs = TestGPU.line(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 60, y: 60)).map { StrokeInput(location: $0) }
        engine.beginStroke(inputs[0], settings: TestGPU.settings(), layerID: engine.activeLayerID)
        engine.continueStroke(Array(inputs.dropFirst()), predicted: [])
        engine.renderOffscreen()
        engine.cancelStroke()
        let bytes = await TestGPU.bytes(engine, engine.activeLayerID)
        XCTAssertTrue(bytes.allSatisfy { $0 == 0 })
        XCTAssertFalse(engine.undo.canUndo)
    }

    // MARK: Z-10.4 symmetry

    func testSymmetryMirrorsStamps() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        engine.mirrorX = 32
        TestGPU.stroke(engine, TestGPU.line(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 10, y: 50)), settings: TestGPU.settings(size: 6))
        let bytes = await TestGPU.bytes(engine, engine.activeLayerID)
        XCTAssertGreaterThan(TestGPU.pixel(bytes, width: 64, x: 10, y: 30)[3], 200)
        XCTAssertGreaterThan(TestGPU.pixel(bytes, width: 64, x: 54, y: 30)[3], 200)
        engine.performUndo()
        let undone = await TestGPU.bytes(engine, engine.activeLayerID)
        XCTAssertEqual(TestGPU.pixel(undone, width: 64, x: 54, y: 30)[3], 0, "undo covers the mirrored side")
    }
}

private extension Int {
    var toUInt8: UInt8 { UInt8(clamping: self) }
}
