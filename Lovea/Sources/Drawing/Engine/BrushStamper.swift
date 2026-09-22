@preconcurrency import Metal
import UIKit

private struct StampUniforms {
    var docSize: SIMD2<Float>
    var color: SIMD4<Float>
    var hardness: Float
    var grain: Float
    var pixel: Int32
    var useMask: Int32
}

/// Draws all stamps of one call with a single instanced draw.
@MainActor
final class BrushStamper {
    private let device: MTLDevice
    private let maxPipeline: MTLRenderPipelineState
    private let overPipeline: MTLRenderPipelineState
    private var buffers: [MTLBuffer]
    private var slot = 0
    private var offset = 0
    private weak var lastCommand: MTLCommandBuffer?
    private let inFlight = DispatchSemaphore(value: 3)
    let whiteMask: MTLTexture
    private(set) var stampsEncoded = 0

    init(device: MTLDevice, library: MTLLibrary) throws {
        self.device = device
        maxPipeline = try GPU.pipeline(device, library, vertex: "stampVertex", fragment: "stampFragment", blend: .max)
        overPipeline = try GPU.pipeline(device, library, vertex: "stampVertex", fragment: "stampFragment", blend: .over)
        // ponytail: ring of 3 buffers, 4096 stamps each; grows only if a frame needs more.
        buffers = try (0..<3).map { _ -> MTLBuffer in
            guard let buffer = GPU.makeBuffer(device, length: 4096 * MemoryLayout<Stamp>.stride) else {
                throw EngineError.deviceUnavailable
            }
            return buffer
        }
        guard let white = GPU.upload([255], width: 1, height: 1, format: .r8Unorm) else {
            throw EngineError.deviceUnavailable
        }
        whiteMask = white
    }

    func encode(
        _ stamps: [Stamp],
        tip: BrushTip,
        color: RGBAColor,
        into target: MTLTexture,
        mask: MTLTexture?,
        mirrorX: Float?,
        command: MTLCommandBuffer
    ) {
        guard !stamps.isEmpty else { return }
        var all = stamps
        if let mirrorX {
            all += stamps.map { stamp in
                var mirrored = stamp
                mirrored.center.x = 2 * mirrorX - stamp.center.x
                mirrored.angle = -stamp.angle
                return mirrored
            }
        }
        if command !== lastCommand {
            inFlight.wait()
            let semaphore = inFlight
            command.addCompletedHandler { _ in semaphore.signal() }
            lastCommand = command
            slot = (slot + 1) % buffers.count
            offset = 0
        }
        let length = all.count * MemoryLayout<Stamp>.stride
        if offset + length > buffers[slot].length {
            guard let bigger = GPU.makeBuffer(device, length: max(length, buffers[slot].length * 2)) else { return }
            buffers[slot] = bigger
            offset = 0
        }
        let buffer = buffers[slot]
        all.withUnsafeBytes { raw in
            if let base = raw.baseAddress {
                buffer.contents().advanced(by: offset).copyMemory(from: base, byteCount: length)
            }
        }
        var uniforms = StampUniforms(
            docSize: SIMD2(Float(target.width), Float(target.height)),
            color: SIMD4(Float(color.red), Float(color.green), Float(color.blue), 1),
            hardness: tip.hardness,
            grain: tip.grain,
            pixel: tip.pixelSnap ? 1 : 0,
            useMask: mask == nil ? 0 : 1
        )
        guard let encoder = GPU.pass(command, target: target) else { return }
        encoder.setRenderPipelineState(tip.buildsUp ? overPipeline : maxPipeline)
        encoder.setVertexBuffer(buffer, offset: offset, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<StampUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<StampUniforms>.stride, index: 1)
        encoder.setFragmentTexture(mask ?? whiteMask, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: all.count)
        encoder.endEncoding()
        offset += (length + 255) / 256 * 256
        stampsEncoded += stamps.count
    }
}
