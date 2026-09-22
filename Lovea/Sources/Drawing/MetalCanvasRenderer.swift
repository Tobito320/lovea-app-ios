@preconcurrency import MetalKit
import simd

private struct CanvasVertex {
    var position: SIMD2<Float>
    var color: SIMD4<Float>
}

@MainActor
final class MetalCanvasRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let brushPipeline: MTLRenderPipelineState
    private let eraserPipeline: MTLRenderPipelineState
    private let compositePipeline: MTLRenderPipelineState
    private var layerTexture: MTLTexture?
    private var document: DrawingDocument = .empty
    private var activeLayerID: UUID?
    private var previewStroke: DrawingStroke?
    private var zoom: CGFloat = 1
    private var offset: CGPoint = .zero

    init?(view: MTKView) {
        guard let device = view.device,
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let vertex = library.makeFunction(name: "canvasVertex"),
              let fragment = library.makeFunction(name: "canvasFragment"),
              let compositeVertex = library.makeFunction(name: "compositeVertex"),
              let compositeFragment = library.makeFunction(name: "compositeFragment") else { return nil }

        func makeStrokePipeline(eraser: Bool) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            let attachment = descriptor.colorAttachments[0]!
            attachment.isBlendingEnabled = true
            if eraser {
                attachment.sourceRGBBlendFactor = .zero
                attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                attachment.sourceAlphaBlendFactor = .zero
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            } else {
                attachment.sourceRGBBlendFactor = .sourceAlpha
                attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                attachment.sourceAlphaBlendFactor = .one
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }

        func makeCompositePipeline() throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = compositeVertex
            descriptor.fragmentFunction = compositeFragment
            descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            let attachment = descriptor.colorAttachments[0]!
            attachment.isBlendingEnabled = true
            attachment.sourceRGBBlendFactor = .one
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }

        do {
            brushPipeline = try makeStrokePipeline(eraser: false)
            eraserPipeline = try makeStrokePipeline(eraser: true)
            compositePipeline = try makeCompositePipeline()
        } catch {
            return nil
        }
        self.device = device
        commandQueue = queue
        super.init()
    }

    func update(
        document: DrawingDocument,
        activeLayerID: UUID,
        previewStroke: DrawingStroke?,
        zoom: CGFloat,
        offset: CGPoint
    ) {
        self.document = document
        self.activeLayerID = activeLayerID
        self.previewStroke = previewStroke
        self.zoom = zoom
        self.offset = offset
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        layerTexture = nil
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let layerTexture = makeLayerTexture(for: drawable) else { return }

        var hasDrawableContent = false
        for layer in document.layers where layer.isVisible {
            guard render(layer, into: layerTexture, viewport: view.bounds.size, commandBuffer: commandBuffer) else {
                continue
            }
            composite(
                layerTexture,
                opacity: Float(layer.opacity),
                into: drawable.texture,
                clearFirst: !hasDrawableContent,
                clearColor: view.clearColor,
                commandBuffer: commandBuffer
            )
            hasDrawableContent = true
        }

        if !hasDrawableContent {
            clear(drawable.texture, color: view.clearColor, commandBuffer: commandBuffer)
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func makeLayerTexture(for drawable: CAMetalDrawable) -> MTLTexture? {
        if let layerTexture,
           layerTexture.width == drawable.texture.width,
           layerTexture.height == drawable.texture.height,
           layerTexture.pixelFormat == drawable.texture.pixelFormat {
            return layerTexture
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: drawable.texture.pixelFormat,
            width: drawable.texture.width,
            height: drawable.texture.height,
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget, .shaderRead]
        let texture = device.makeTexture(descriptor: descriptor)
        texture?.label = "Lovea Layer"
        layerTexture = texture
        return texture
    }

    private func render(
        _ layer: DrawingLayer,
        into texture: MTLTexture,
        viewport: CGSize,
        commandBuffer: MTLCommandBuffer
    ) -> Bool {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return false }

        for stroke in layer.strokes {
            draw(stroke, viewport: viewport, encoder: encoder)
        }
        if layer.id == activeLayerID, let previewStroke {
            draw(previewStroke, viewport: viewport, encoder: encoder)
        }
        encoder.endEncoding()
        return true
    }

    private func composite(
        _ layer: MTLTexture,
        opacity: Float,
        into destination: MTLTexture,
        clearFirst: Bool,
        clearColor: MTLClearColor,
        commandBuffer: MTLCommandBuffer
    ) {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = destination
        descriptor.colorAttachments[0].loadAction = clearFirst ? .clear : .load
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = clearColor
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        var opacity = min(max(opacity, 0), 1)
        encoder.setRenderPipelineState(compositePipeline)
        encoder.setFragmentTexture(layer, index: 0)
        encoder.setFragmentBytes(&opacity, length: MemoryLayout<Float>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    private func clear(_ texture: MTLTexture, color: MTLClearColor, commandBuffer: MTLCommandBuffer) {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = color
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.endEncoding()
    }

    private func draw(
        _ stroke: DrawingStroke,
        viewport: CGSize,
        encoder: MTLRenderCommandEncoder
    ) {
        let vertices = vertices(for: stroke, viewport: viewport)
        guard !vertices.isEmpty else { return }
        let length = vertices.count * MemoryLayout<CanvasVertex>.stride
        let vertexBuffer = vertices.withUnsafeBufferPointer { buffer -> MTLBuffer? in
            guard let baseAddress = buffer.baseAddress else { return nil }
            return device.makeBuffer(bytes: baseAddress, length: length, options: .storageModeShared)
        }
        guard let vertexBuffer else { return }

        encoder.setRenderPipelineState(stroke.tool == .eraser ? eraserPipeline : brushPipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }

    private func vertices(
        for stroke: DrawingStroke,
        viewport: CGSize
    ) -> [CanvasVertex] {
        guard !stroke.points.isEmpty, viewport.width > 0, viewport.height > 0 else { return [] }
        let points = stroke.points.count == 1 ? [stroke.points[0], stroke.points[0]] : stroke.points
        var result: [CanvasVertex] = []
        result.reserveCapacity((points.count - 1) * 6)
        let color = SIMD4<Float>(
            Float(stroke.color.red),
            Float(stroke.color.green),
            Float(stroke.color.blue),
            Float(stroke.opacity)
        )

        for index in 1..<points.count {
            let start = screenPoint(points[index - 1])
            var end = screenPoint(points[index])
            if start == end { end.x += 0.1 }
            let direction = SIMD2<Float>(Float(end.x - start.x), Float(end.y - start.y))
            let length = max(simd_length(direction), 0.001)
            let normal = SIMD2<Float>(-direction.y, direction.x) / length
            let pressure = max(0.2, (points[index - 1].pressure + points[index].pressure) / 2)
            let radius = Float(stroke.width * pressure) * Float(zoom) / 2
            let delta = normal * radius
            let a = ndc(CGPoint(x: start.x + CGFloat(delta.x), y: start.y + CGFloat(delta.y)), viewport)
            let b = ndc(CGPoint(x: start.x - CGFloat(delta.x), y: start.y - CGFloat(delta.y)), viewport)
            let c = ndc(CGPoint(x: end.x + CGFloat(delta.x), y: end.y + CGFloat(delta.y)), viewport)
            let d = ndc(CGPoint(x: end.x - CGFloat(delta.x), y: end.y - CGFloat(delta.y)), viewport)
            result += [
                CanvasVertex(position: a, color: color), CanvasVertex(position: b, color: color), CanvasVertex(position: c, color: color),
                CanvasVertex(position: c, color: color), CanvasVertex(position: b, color: color), CanvasVertex(position: d, color: color)
            ]
        }
        return result
    }

    private func screenPoint(_ point: StrokePoint) -> CGPoint {
        CGPoint(
            x: CGFloat(point.x) * zoom + offset.x,
            y: CGFloat(point.y) * zoom + offset.y
        )
    }

    private func ndc(_ point: CGPoint, _ viewport: CGSize) -> SIMD2<Float> {
        SIMD2<Float>(
            Float((point.x / viewport.width) * 2 - 1),
            Float(1 - (point.y / viewport.height) * 2)
        )
    }
}
