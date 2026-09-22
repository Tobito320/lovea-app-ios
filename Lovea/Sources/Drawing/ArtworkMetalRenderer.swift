@preconcurrency import MetalKit
import simd
import UIKit

/// One source of truth for saved stroke dynamics in live rendering and export.
enum MetalStrokeRenderingProfile {
    static func smoothedPoints(_ stroke: MetalPaintStroke) -> [StrokePoint] {
        let source = stroke.points
        let radius = min(max(Int(stroke.stabilizer.rounded()), 0), 9)
        guard radius > 0, source.count > 2 else { return source }
        var result = source
        for index in 1..<(source.count - 1) {
            let lower = max(0, index - radius)
            let upper = min(source.count - 1, index + radius)
            var total = 0.0
            var x = 0.0
            var y = 0.0
            for neighbor in lower...upper {
                let weight = 1.0 / Double(1 + abs(neighbor - index))
                total += weight
                x += source[neighbor].x * weight
                y += source[neighbor].y * weight
            }
            result[index].x = x / total
            result[index].y = y / total
        }
        return result
    }

    static func radius(_ stroke: MetalPaintStroke, pressure: Double) -> Double {
        let factor = stroke.pressureControlsSize ? min(max(pressure, 0.1), 1) : 1
        return max(stroke.width, 1) * factor / 2
    }

    static func alpha(_ stroke: MetalPaintStroke, pressure: Double) -> Double {
        let factor = stroke.pressureControlsOpacity ? min(max(pressure, 0.2), 1) : 1
        return min(max(stroke.opacity * stroke.color.alpha * factor, 0), 1)
    }
}

private struct ArtworkMetalVertex {
    var position: SIMD2<Float>
    var texCoord: SIMD2<Float>
    var color: SIMD4<Float>
}

private struct ArtworkBlendUniforms {
    var mode: Int32
    var opacity: Float
}

/// Composes the current artwork in Metal. The archived PencilKit image is input
/// data only; all newly recorded brush and eraser strokes are rasterized here.
@MainActor
final class ArtworkMetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let textureLoader: MTKTextureLoader
    private let imagePipeline: MTLRenderPipelineState
    private let maskPipeline: MTLRenderPipelineState
    private let blendPipeline: MTLRenderPipelineState
    private let brushPipeline: MTLRenderPipelineState
    private let eraserPipeline: MTLRenderPipelineState

    private var lowerTexture: MTLTexture?
    private var legacyTexture: MTLTexture?
    private var upperTexture: MTLTexture?
    private var alphaMaskTexture: MTLTexture?
    private var clippingMaskTexture: MTLTexture?
    private var activeTexture: MTLTexture?
    private var baseTexture: MTLTexture?
    private var strokes: [MetalPaintStroke] = []
    private var preview: MetalPaintStroke?
    private var documentSize: CGSize = .zero
    private var viewport = ArtworkCanvasViewport()
    private var activeOpacity: Float = 1
    private var activeBlendMode: LayerBlendMode = .normal
    private var activeTransform = LayerTransform()

    init?(view: MTKView) {
        guard let device = view.device,
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let vertex = library.makeFunction(name: "artworkVertex"),
              let imageFragment = library.makeFunction(name: "artworkTextureFragment"),
              let strokeFragment = library.makeFunction(name: "artworkStrokeFragment"),
              let blendFragment = library.makeFunction(name: "artworkBlendFragment") else { return nil }

        func pipeline(
            fragment: MTLFunction,
            textured: Bool = false,
            eraser: Bool = false,
            mask: Bool = false,
            blending: Bool = true
        ) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            let attachment = descriptor.colorAttachments[0]!
            attachment.isBlendingEnabled = blending
            if eraser {
                attachment.sourceRGBBlendFactor = .zero
                attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                attachment.sourceAlphaBlendFactor = .zero
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            } else if mask {
                attachment.sourceRGBBlendFactor = .zero
                attachment.destinationRGBBlendFactor = .sourceAlpha
                attachment.sourceAlphaBlendFactor = .zero
                attachment.destinationAlphaBlendFactor = .sourceAlpha
            } else if textured {
                // UIImage textures supplied by MTKTextureLoader are premultiplied.
                attachment.sourceRGBBlendFactor = .one
                attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                attachment.sourceAlphaBlendFactor = .one
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            } else {
                attachment.sourceRGBBlendFactor = .sourceAlpha
                attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                attachment.sourceAlphaBlendFactor = .one
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }

        do {
            imagePipeline = try pipeline(fragment: imageFragment, textured: true)
            maskPipeline = try pipeline(fragment: imageFragment, mask: true)
            blendPipeline = try pipeline(fragment: blendFragment, blending: false)
            brushPipeline = try pipeline(fragment: strokeFragment)
            eraserPipeline = try pipeline(fragment: strokeFragment, eraser: true)
        } catch {
            return nil
        }

        self.device = device
        self.queue = queue
        textureLoader = MTKTextureLoader(device: device)
        super.init()
    }

    func setImages(
        lower: UIImage?,
        legacy: UIImage?,
        upper: UIImage?,
        alphaMask: UIImage?,
        clippingMask: UIImage?
    ) {
        lowerTexture = texture(for: lower)
        legacyTexture = texture(for: legacy)
        upperTexture = texture(for: upper)
        alphaMaskTexture = texture(for: alphaMask)
        clippingMaskTexture = texture(for: clippingMask)
    }

    func update(
        strokes: [MetalPaintStroke],
        preview: MetalPaintStroke?,
        documentSize: CGSize,
        viewport: ArtworkCanvasViewport,
        activeOpacity: Double,
        activeBlendMode: LayerBlendMode,
        activeTransform: LayerTransform
    ) {
        self.strokes = strokes
        self.preview = preview
        self.documentSize = documentSize
        self.viewport = viewport
        self.activeOpacity = Float(min(max(activeOpacity, 0), 1))
        self.activeBlendMode = activeBlendMode
        self.activeTransform = activeTransform
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        activeTexture = nil
        baseTexture = nil
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let command = queue.makeCommandBuffer() else { return }
        if activeTexture?.width != drawable.texture.width || activeTexture?.height != drawable.texture.height {
            activeTexture = makeRenderTexture(matching: drawable.texture)
        }
        if baseTexture?.width != drawable.texture.width || baseTexture?.height != drawable.texture.height {
            baseTexture = makeRenderTexture(matching: drawable.texture)
        }
        guard let activeTexture, let baseTexture else { return }

        let size = view.bounds.size
        let documentQuad = quad(for: CGRect(origin: .zero, size: documentSize), in: size)
        let activeQuad = quad(for: CGRect(origin: .zero, size: documentSize), in: size, transformed: true)

        // The active layer is isolated so destination-out erasing never removes
        // artwork from a lower layer.
        if let encoder = encoder(to: activeTexture, command: command, clear: true, color: .init(red: 0, green: 0, blue: 0, alpha: 0)) {
            if let legacyTexture { drawTexture(legacyTexture, vertices: activeQuad, encoder: encoder) }
            for stroke in strokes { drawStroke(stroke, in: size, encoder: encoder) }
            if let preview { drawStroke(preview, in: size, encoder: encoder) }
            if let alphaMaskTexture { drawMask(alphaMaskTexture, vertices: activeQuad, encoder: encoder) }
            if let clippingMaskTexture { drawMask(clippingMaskTexture, vertices: activeQuad, encoder: encoder) }
            encoder.endEncoding()
        }

        if let encoder = encoder(to: baseTexture, command: command, clear: true, color: view.clearColor) {
            if let lowerTexture { drawTexture(lowerTexture, vertices: documentQuad, encoder: encoder) }
            encoder.endEncoding()
        }
        if let encoder = encoder(to: drawable.texture, command: command, clear: true, color: view.clearColor) {
            drawBlend(lower: baseTexture, active: activeTexture, encoder: encoder)
            if let upperTexture { drawTexture(upperTexture, vertices: documentQuad, encoder: encoder) }
            encoder.endEncoding()
        }

        command.present(drawable)
        command.commit()
    }

    private func texture(for image: UIImage?) -> MTLTexture? {
        guard let cgImage = image?.cgImage else { return nil }
        return try? textureLoader.newTexture(cgImage: cgImage, options: [
            .origin: MTKTextureLoader.Origin.topLeft,
            .SRGB: false
        ])
    }

    private func makeRenderTexture(matching drawable: MTLTexture) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: drawable.pixelFormat,
            width: drawable.width,
            height: drawable.height,
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget, .shaderRead]
        return device.makeTexture(descriptor: descriptor)
    }

    private func encoder(
        to texture: MTLTexture,
        command: MTLCommandBuffer,
        clear: Bool,
        color: MTLClearColor
    ) -> MTLRenderCommandEncoder? {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = clear ? .clear : .load
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = color
        return command.makeRenderCommandEncoder(descriptor: pass)
    }

    private func drawTexture(
        _ texture: MTLTexture,
        vertices: [ArtworkMetalVertex],
        opacity: Float = 1,
        encoder: MTLRenderCommandEncoder
    ) {
        guard let buffer = makeBuffer(vertices) else { return }
        var opacity = opacity
        encoder.setRenderPipelineState(imagePipeline)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentBytes(&opacity, length: MemoryLayout<Float>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }

    private func drawMask(_ texture: MTLTexture, vertices: [ArtworkMetalVertex], encoder: MTLRenderCommandEncoder) {
        guard let buffer = makeBuffer(vertices) else { return }
        var opacity: Float = 1
        encoder.setRenderPipelineState(maskPipeline)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentBytes(&opacity, length: MemoryLayout<Float>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }

    private func drawBlend(lower: MTLTexture, active: MTLTexture, encoder: MTLRenderCommandEncoder) {
        guard let buffer = makeBuffer(screenQuad()) else { return }
        var uniforms = ArtworkBlendUniforms(mode: blendModeIndex(activeBlendMode), opacity: activeOpacity)
        encoder.setRenderPipelineState(blendPipeline)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setFragmentTexture(lower, index: 0)
        encoder.setFragmentTexture(active, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ArtworkBlendUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }

    private func blendModeIndex(_ mode: LayerBlendMode) -> Int32 {
        switch mode {
        case .normal: 0
        case .multiply: 1
        case .screen: 2
        case .overlay: 3
        case .darken: 4
        case .lighten: 5
        case .add: 6
        case .softLight: 7
        }
    }

    private func drawStroke(_ stroke: MetalPaintStroke, in size: CGSize, encoder: MTLRenderCommandEncoder) {
        let vertices = strokeVertices(stroke, in: size)
        guard let buffer = makeBuffer(vertices) else { return }
        var hardness: Float
        switch stroke.brushPreset {
        case "airbrush", "watercolor": hardness = 0.08
        case "pencil", "chalk": hardness = 0.55
        case "highlighter": hardness = 0.82
        default: hardness = 0.94
        }
        if stroke.tool == .eraser { hardness = 0.94 }
        encoder.setRenderPipelineState(stroke.tool == .eraser ? eraserPipeline : brushPipeline)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setFragmentBytes(&hardness, length: MemoryLayout<Float>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }

    private func makeBuffer(_ vertices: [ArtworkMetalVertex]) -> MTLBuffer? {
        guard !vertices.isEmpty else { return nil }
        return vertices.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return nil }
            return device.makeBuffer(
                bytes: base,
                length: buffer.count * MemoryLayout<ArtworkMetalVertex>.stride,
                options: .storageModeShared
            )
        }
    }

    private func strokeVertices(_ stroke: MetalPaintStroke, in size: CGSize) -> [ArtworkMetalVertex] {
        guard !stroke.points.isEmpty, size.width > 0, size.height > 0 else { return [] }
        let sampled = MetalStrokeRenderingProfile.smoothedPoints(stroke)
        func color(pressure: Double) -> SIMD4<Float> {
            SIMD4<Float>(
                Float(stroke.color.red),
                Float(stroke.color.green),
                Float(stroke.color.blue),
                Float(MetalStrokeRenderingProfile.alpha(stroke, pressure: pressure))
            )
        }
        var vertices: [ArtworkMetalVertex] = []
        vertices.reserveCapacity(sampled.count * 36)

        let points = sampled.map { point in
            viewport.screenPoint(transformActivePoint(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))))
        }
        let documentRadii = sampled.map { point in
            CGFloat(MetalStrokeRenderingProfile.radius(stroke, pressure: point.pressure))
        }
        let radiusScale = max(viewport.scale * CGFloat(activeTransform.scale), 0.0001)
        let radii = documentRadii.map { $0 * radiusScale }

        for index in points.indices {
            let start = points[index]
            let radius = max(radii[index], 0.5 * radiusScale)
            if index == 0 {
                appendStamp(center: start, radius: radius, size: size, color: color(pressure: sampled[index].pressure), to: &vertices)
                continue
            }
            let previous = points[index - 1]
            let distance = hypot(start.x - previous.x, start.y - previous.y)
            let spacing = max(min(documentRadii[index] * 0.4, 3), 0.5) * radiusScale
            let count = max(1, Int(ceil(distance / spacing)))
            for step in 1...count {
                let fraction = CGFloat(step) / CGFloat(count)
                let center = CGPoint(
                    x: previous.x + (start.x - previous.x) * fraction,
                    y: previous.y + (start.y - previous.y) * fraction
                )
                let interpolatedRadius = max(
                    radii[index - 1] + (radii[index] - radii[index - 1]) * fraction,
                    0.5 * radiusScale
                )
                let pressure = sampled[index - 1].pressure
                    + (sampled[index].pressure - sampled[index - 1].pressure) * Double(fraction)
                appendStamp(center: center, radius: interpolatedRadius, size: size, color: color(pressure: pressure), to: &vertices)
            }
        }
        return vertices
    }

    private func appendStamp(
        center: CGPoint,
        radius: CGFloat,
        size: CGSize,
        color: SIMD4<Float>,
        to vertices: inout [ArtworkMetalVertex]
    ) {
        let left = center.x - radius
        let right = center.x + radius
        let top = center.y - radius
        let bottom = center.y + radius
        vertices += [
            ArtworkMetalVertex(position: ndc(CGPoint(x: left, y: top), size), texCoord: [-1, -1], color: color),
            ArtworkMetalVertex(position: ndc(CGPoint(x: right, y: top), size), texCoord: [1, -1], color: color),
            ArtworkMetalVertex(position: ndc(CGPoint(x: left, y: bottom), size), texCoord: [-1, 1], color: color),
            ArtworkMetalVertex(position: ndc(CGPoint(x: right, y: top), size), texCoord: [1, -1], color: color),
            ArtworkMetalVertex(position: ndc(CGPoint(x: right, y: bottom), size), texCoord: [1, 1], color: color),
            ArtworkMetalVertex(position: ndc(CGPoint(x: left, y: bottom), size), texCoord: [-1, 1], color: color)
        ]
    }

    private func quad(for rect: CGRect, in size: CGSize, transformed: Bool = false) -> [ArtworkMetalVertex] {
        guard size.width > 0, size.height > 0 else { return [] }
        let a = viewport.screenPoint(transformed ? transformActivePoint(rect.origin) : rect.origin)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let b = viewport.screenPoint(transformed ? transformActivePoint(topRight) : topRight)
        let c = viewport.screenPoint(transformed ? transformActivePoint(bottomLeft) : bottomLeft)
        let d = viewport.screenPoint(transformed ? transformActivePoint(bottomRight) : bottomRight)
        return texturedQuad(a: a, b: b, c: c, d: d, size: size)
    }

    private func transformActivePoint(_ point: CGPoint) -> CGPoint {
        let center = CGPoint(x: documentSize.width / 2, y: documentSize.height / 2)
        let sx = CGFloat(activeTransform.scale * (activeTransform.flipX ? -1 : 1))
        let sy = CGFloat(activeTransform.scale * (activeTransform.flipY ? -1 : 1))
        let x = (point.x - center.x) * sx
        let y = (point.y - center.y) * sy
        let angle = CGFloat(activeTransform.rotation)
        return CGPoint(
            x: center.x + CGFloat(activeTransform.offsetX) + x * cos(angle) - y * sin(angle),
            y: center.y + CGFloat(activeTransform.offsetY) + x * sin(angle) + y * cos(angle)
        )
    }

    private func screenQuad() -> [ArtworkMetalVertex] {
        [
            ArtworkMetalVertex(position: [-1, 1], texCoord: [0, 0], color: [1, 1, 1, 1]),
            ArtworkMetalVertex(position: [1, 1], texCoord: [1, 0], color: [1, 1, 1, 1]),
            ArtworkMetalVertex(position: [-1, -1], texCoord: [0, 1], color: [1, 1, 1, 1]),
            ArtworkMetalVertex(position: [1, 1], texCoord: [1, 0], color: [1, 1, 1, 1]),
            ArtworkMetalVertex(position: [1, -1], texCoord: [1, 1], color: [1, 1, 1, 1]),
            ArtworkMetalVertex(position: [-1, -1], texCoord: [0, 1], color: [1, 1, 1, 1])
        ]
    }

    private func texturedQuad(a: CGPoint, b: CGPoint, c: CGPoint, d: CGPoint, size: CGSize) -> [ArtworkMetalVertex] {
        let white = SIMD4<Float>(1, 1, 1, 1)
        return [
            ArtworkMetalVertex(position: ndc(a, size), texCoord: [0, 0], color: white),
            ArtworkMetalVertex(position: ndc(b, size), texCoord: [1, 0], color: white),
            ArtworkMetalVertex(position: ndc(c, size), texCoord: [0, 1], color: white),
            ArtworkMetalVertex(position: ndc(b, size), texCoord: [1, 0], color: white),
            ArtworkMetalVertex(position: ndc(d, size), texCoord: [1, 1], color: white),
            ArtworkMetalVertex(position: ndc(c, size), texCoord: [0, 1], color: white)
        ]
    }

    private func ndc(_ point: CGPoint, _ size: CGSize) -> SIMD2<Float> {
        SIMD2<Float>(Float(2 * point.x / size.width - 1), Float(1 - 2 * point.y / size.height))
    }
}
