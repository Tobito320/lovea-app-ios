@preconcurrency import Metal
import CoreGraphics
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum BlendKind {
    case none, over, max, erase, atop
}

@MainActor
enum EngineStats {
    /// Counts every texture and buffer the engine creates. Frames must not add to it.
    static var allocations = 0
}

/// Shared Metal plumbing: one device, one queue, so every command runs in order.
@MainActor
enum GPU {
    static let device: MTLDevice? = MTLCreateSystemDefaultDevice()
    static let queue: MTLCommandQueue? = device?.makeCommandQueue()
    static let library: MTLLibrary? = device?.makeDefaultLibrary()
    static let fullScreen: [SIMD2<Float>] = [[-1, 1], [1, 1], [-1, -1], [1, -1]]

    static func makeTexture(
        _ device: MTLDevice,
        width: Int,
        height: Int,
        format: MTLPixelFormat = .rgba8Unorm
    ) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format,
            width: max(width, 1),
            height: max(height, 1),
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        EngineStats.allocations += 1
        return device.makeTexture(descriptor: descriptor)
    }

    static func makeBuffer(_ device: MTLDevice, length: Int) -> MTLBuffer? {
        EngineStats.allocations += 1
        return device.makeBuffer(length: max(length, 256), options: .storageModeShared)
    }

    static func pipeline(
        _ device: MTLDevice,
        _ library: MTLLibrary,
        vertex: String = "quadVertex",
        fragment: String,
        format: MTLPixelFormat = .rgba8Unorm,
        blend: BlendKind
    ) throws -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: vertex)
        descriptor.fragmentFunction = library.makeFunction(name: fragment)
        guard let attachment = descriptor.colorAttachments[0] else { throw EngineError.deviceUnavailable }
        attachment.pixelFormat = format
        attachment.isBlendingEnabled = blend != .none
        switch blend {
        case .none:
            break
        case .over:
            attachment.sourceRGBBlendFactor = .one
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        case .max:
            attachment.rgbBlendOperation = .max
            attachment.alphaBlendOperation = .max
            attachment.sourceRGBBlendFactor = .one
            attachment.destinationRGBBlendFactor = .one
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .one
        case .erase:
            attachment.sourceRGBBlendFactor = .zero
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.sourceAlphaBlendFactor = .zero
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        case .atop:
            attachment.sourceRGBBlendFactor = .destinationAlpha
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.sourceAlphaBlendFactor = .zero
            attachment.destinationAlphaBlendFactor = .one
        }
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func sampler(_ device: MTLDevice, nearest: Bool) -> MTLSamplerState? {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = nearest ? .nearest : .linear
        descriptor.magFilter = nearest ? .nearest : .linear
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        return device.makeSamplerState(descriptor: descriptor)
    }

    static func pass(
        _ command: MTLCommandBuffer,
        target: MTLTexture,
        clear: MTLClearColor? = nil
    ) -> MTLRenderCommandEncoder? {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = clear == nil ? .load : .clear
        pass.colorAttachments[0].clearColor = clear ?? MTLClearColor()
        pass.colorAttachments[0].storeAction = .store
        return command.makeRenderCommandEncoder(descriptor: pass)
    }

    static func drawQuad(_ encoder: MTLRenderCommandEncoder, corners: [SIMD2<Float>]) {
        var corners = corners
        encoder.setVertexBytes(&corners, length: MemoryLayout<SIMD2<Float>>.stride * 4, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    /// Fills a whole texture with one premultiplied color.
    static func fill(_ texture: MTLTexture, color: RGBAColor = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0), command: MTLCommandBuffer) {
        let clear = MTLClearColor(
            red: color.red * color.alpha,
            green: color.green * color.alpha,
            blue: color.blue * color.alpha,
            alpha: color.alpha
        )
        pass(command, target: texture, clear: clear)?.endEncoding()
    }

    static func copy(
        _ source: MTLTexture,
        region: MTLRegion? = nil,
        to target: MTLTexture,
        at origin: MTLOrigin = MTLOrigin(x: 0, y: 0, z: 0),
        command: MTLCommandBuffer
    ) {
        let region = region ?? MTLRegionMake2D(0, 0, source.width, source.height)
        guard let blit = command.makeBlitCommandEncoder() else { return }
        blit.copy(
            from: source, sourceSlice: 0, sourceLevel: 0,
            sourceOrigin: region.origin, sourceSize: region.size,
            to: target, destinationSlice: 0, destinationLevel: 0,
            destinationOrigin: origin
        )
        blit.endEncoding()
    }

    static func ndc(_ point: CGPoint, size: CGSize) -> SIMD2<Float> {
        SIMD2<Float>(Float(2 * point.x / size.width - 1), Float(1 - 2 * point.y / size.height))
    }

    /// Copies texture pixels into memory without blocking the main thread.
    static func readBytes(_ texture: MTLTexture, region: MTLRegion? = nil) async -> [UInt8] {
        let region = region ?? MTLRegionMake2D(0, 0, texture.width, texture.height)
        let bytesPerPixel = texture.pixelFormat == .r8Unorm ? 1 : 4
        let rowBytes = region.size.width * bytesPerPixel
        let count = rowBytes * region.size.height
        guard count > 0,
              let buffer = texture.device.makeBuffer(length: count, options: .storageModeShared),
              let command = queue?.makeCommandBuffer(),
              let blit = command.makeBlitCommandEncoder() else { return [] }
        blit.copy(
            from: texture, sourceSlice: 0, sourceLevel: 0,
            sourceOrigin: region.origin, sourceSize: region.size,
            to: buffer, destinationOffset: 0,
            destinationBytesPerRow: rowBytes, destinationBytesPerImage: count
        )
        blit.endEncoding()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            command.addCompletedHandler { _ in continuation.resume() }
            command.commit()
        }
        let pointer = buffer.contents().bindMemory(to: UInt8.self, capacity: count)
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }

    /// Uploads RGBA8 (premultiplied) or R8 bytes into a new private texture.
    static func upload(
        _ bytes: [UInt8],
        width: Int,
        height: Int,
        format: MTLPixelFormat = .rgba8Unorm,
        into existing: MTLTexture? = nil
    ) -> MTLTexture? {
        let bytesPerPixel = format == .r8Unorm ? 1 : 4
        guard let device, !bytes.isEmpty, bytes.count >= width * height * bytesPerPixel,
              let texture = existing ?? makeTexture(device, width: width, height: height, format: format),
              let staging = bytes.withUnsafeBytes({ raw in
                  raw.baseAddress.flatMap { device.makeBuffer(bytes: $0, length: raw.count, options: .storageModeShared) }
              }),
              let command = queue?.makeCommandBuffer(),
              let blit = command.makeBlitCommandEncoder() else { return nil }
        blit.copy(
            from: staging, sourceOffset: 0,
            sourceBytesPerRow: width * bytesPerPixel,
            sourceBytesPerImage: width * height * bytesPerPixel,
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: texture, destinationSlice: 0, destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blit.endEncoding()
        command.commit()
        return texture
    }
}

/// CPU raster work. Everything here is nonisolated and meant for background tasks.
enum RasterOps {
    struct Pixels: Sendable {
        var bytes: [UInt8]
        var width: Int
        var height: Int
    }

    nonisolated(unsafe) static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    /// Decodes an image to premultiplied RGBA8. `maxPixelSize` downsamples and applies EXIF orientation.
    static func decode(_ data: Data, maxPixelSize: Int? = nil) -> Pixels? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let image: CGImage?
        if let maxPixelSize {
            image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ] as CFDictionary)
        } else {
            image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        return image.flatMap(pixels)
    }

    static func pixels(of image: CGImage) -> Pixels? {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? Pixels(bytes: bytes, width: width, height: height) : nil
    }

    static func cgImage(_ pixels: Pixels) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels.bytes) as CFData) else { return nil }
        return CGImage(
            width: pixels.width, height: pixels.height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: pixels.width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    static func encode(_ pixels: Pixels, type: UTType = .png, quality: Double = 0.9) -> Data? {
        guard let image = cgImage(pixels) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { return nil }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, type == .png ? nil : options)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// Scanline flood fill on premultiplied RGBA. Returns an R8 mask (0 or 255), grown by 1 px
    /// so antialiased line edges leave no gap.
    static func floodFillMask(_ source: Pixels, x startX: Int, y startY: Int, tolerance: Double) -> [UInt8] {
        let width = source.width
        let height = source.height
        guard startX >= 0, startY >= 0, startX < width, startY < height else { return [] }
        var mask = [UInt8](repeating: 0, count: width * height)
        let limit = Int((min(max(tolerance, 0), 1) * 255 * 4).rounded())
        source.bytes.withUnsafeBufferPointer { src in
            mask.withUnsafeMutableBufferPointer { out in
                let start = (startY * width + startX) * 4
                let t0 = Int(src[start]), t1 = Int(src[start + 1]), t2 = Int(src[start + 2]), t3 = Int(src[start + 3])
                func open(_ index: Int) -> Bool {
                    guard out[index] == 0 else { return false }
                    let i = index * 4
                    let distance = abs(Int(src[i]) - t0) + abs(Int(src[i + 1]) - t1)
                        + abs(Int(src[i + 2]) - t2) + abs(Int(src[i + 3]) - t3)
                    return distance <= limit
                }
                var stack = [(startX, startY)]
                while let (seedX, y) = stack.popLast() {
                    let row = y * width
                    var x = seedX
                    guard open(row + x) else { continue }
                    while x > 0, open(row + x - 1) { x -= 1 }
                    var above = false
                    var below = false
                    while x < width, open(row + x) {
                        out[row + x] = 255
                        if y > 0 {
                            let free = open(row - width + x)
                            if free, !above { stack.append((x, y - 1)) }
                            above = free
                        }
                        if y + 1 < height {
                            let free = open(row + width + x)
                            if free, !below { stack.append((x, y + 1)) }
                            below = free
                        }
                        x += 1
                    }
                }
            }
        }
        return dilate(mask, width: width, height: height)
    }

    /// 3x3 max filter, done as two separable passes.
    static func dilate(_ mask: [UInt8], width: Int, height: Int) -> [UInt8] {
        var horizontal = mask
        var result = mask
        mask.withUnsafeBufferPointer { src in
            horizontal.withUnsafeMutableBufferPointer { h in
                for y in 0..<height {
                    let row = y * width
                    for x in 0..<width where src[row + x] == 0 {
                        if (x > 0 && src[row + x - 1] != 0) || (x + 1 < width && src[row + x + 1] != 0) {
                            h[row + x] = 255
                        }
                    }
                }
            }
        }
        horizontal.withUnsafeBufferPointer { h in
            result.withUnsafeMutableBufferPointer { out in
                for y in 0..<height {
                    let row = y * width
                    for x in 0..<width {
                        if h[row + x] != 0
                            || (y > 0 && h[row - width + x] != 0)
                            || (y + 1 < height && h[row + width + x] != 0) {
                            out[row + x] = 255
                        }
                    }
                }
            }
        }
        return result
    }
}

enum Adjustment: Int32, CaseIterable, Identifiable {
    case blur = 0, grayscale, invert, brightness, saturation, hue

    var id: Int32 { rawValue }

    var title: String {
        switch self {
        case .blur: "Weichzeichnen"
        case .grayscale: "Graustufen"
        case .invert: "Umkehren"
        case .brightness: "Helligkeit"
        case .saturation: "Sättigung"
        case .hue: "Farbton"
        }
    }

    /// Slider range; nil means the adjustment has no amount.
    var range: ClosedRange<Double>? {
        switch self {
        case .blur: 0...50
        case .grayscale, .invert: nil
        case .brightness, .saturation: -1...1
        case .hue: -0.5...0.5
        }
    }
}

/// Mask, copy and filter passes used by fill, selection and adjustments.
@MainActor
final class EngineOps {
    private let maskColor: [BlendKind: MTLRenderPipelineState]
    private let maskedCopyPipeline: MTLRenderPipelineState
    private let invertPipeline: MTLRenderPipelineState
    private let adjustPipeline: MTLRenderPipelineState
    let sampler: MTLSamplerState

    init(device: MTLDevice, library: MTLLibrary) throws {
        var pipelines: [BlendKind: MTLRenderPipelineState] = [:]
        for kind in [BlendKind.over, .atop, .erase] {
            pipelines[kind] = try GPU.pipeline(device, library, fragment: "maskColorFragment", blend: kind)
        }
        maskColor = pipelines
        maskedCopyPipeline = try GPU.pipeline(device, library, fragment: "maskedCopyFragment", blend: .over)
        invertPipeline = try GPU.pipeline(device, library, fragment: "invertMaskFragment", format: .r8Unorm, blend: .none)
        adjustPipeline = try GPU.pipeline(device, library, fragment: "adjustFragment", blend: .none)
        guard let sampler = GPU.sampler(device, nearest: false) else { throw EngineError.deviceUnavailable }
        self.sampler = sampler
    }

    func paintMask(
        _ mask: MTLTexture,
        selection: MTLTexture,
        color: RGBAColor,
        blend: BlendKind,
        into target: MTLTexture,
        command: MTLCommandBuffer
    ) {
        guard let pipeline = maskColor[blend], let encoder = GPU.pass(command, target: target) else { return }
        var rgba = SIMD4<Float>(Float(color.red), Float(color.green), Float(color.blue), Float(color.alpha))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(mask, index: 0)
        encoder.setFragmentTexture(selection, index: 1)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.setFragmentBytes(&rgba, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        GPU.drawQuad(encoder, corners: GPU.fullScreen)
        encoder.endEncoding()
    }

    /// `target` = `source` × mask (or × inverted mask), drawn over what `target` holds.
    func maskedCopy(_ source: MTLTexture, mask: MTLTexture, invert: Bool, into target: MTLTexture, clearFirst: Bool, command: MTLCommandBuffer) {
        guard let encoder = GPU.pass(command, target: target, clear: clearFirst ? MTLClearColor() : nil) else { return }
        var flag: Int32 = invert ? 1 : 0
        encoder.setRenderPipelineState(maskedCopyPipeline)
        encoder.setFragmentTexture(source, index: 0)
        encoder.setFragmentTexture(mask, index: 1)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.setFragmentBytes(&flag, length: MemoryLayout<Int32>.stride, index: 0)
        GPU.drawQuad(encoder, corners: GPU.fullScreen)
        encoder.endEncoding()
    }

    func invert(_ mask: MTLTexture, into target: MTLTexture, command: MTLCommandBuffer) {
        guard let encoder = GPU.pass(command, target: target, clear: MTLClearColor()) else { return }
        encoder.setRenderPipelineState(invertPipeline)
        encoder.setFragmentTexture(mask, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)
        GPU.drawQuad(encoder, corners: GPU.fullScreen)
        encoder.endEncoding()
    }

    /// Color adjustment (not blur) of `source` into `target`, only inside `selection`.
    func adjust(_ source: MTLTexture, selection: MTLTexture, mode: Adjustment, amount: Float, into target: MTLTexture, command: MTLCommandBuffer) {
        guard let encoder = GPU.pass(command, target: target, clear: MTLClearColor()) else { return }
        var uniforms = (mode.rawValue, amount)
        encoder.setRenderPipelineState(adjustPipeline)
        encoder.setFragmentTexture(source, index: 0)
        encoder.setFragmentTexture(selection, index: 1)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.setFragmentBytes(&uniforms, length: 8, index: 0)
        GPU.drawQuad(encoder, corners: GPU.fullScreen)
        encoder.endEncoding()
    }
}
