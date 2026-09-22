@preconcurrency import MetalKit
import simd

private struct CanvasVertex {
    var position: SIMD2<Float>
    var color: SIMD4<Float>
}

@MainActor
final class MetalCanvasRenderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let brushPipeline: MTLRenderPipelineState
    private let eraserPipeline: MTLRenderPipelineState
    private var document: DrawingDocument = .empty
    private var previewStroke: DrawingStroke?
    private var zoom: CGFloat = 1
    private var offset: CGPoint = .zero

    init?(view: MTKView) {
        guard let device = view.device,
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let vertex = library.makeFunction(name: "canvasVertex"),
              let fragment = library.makeFunction(name: "canvasFragment") else { return nil }

        func makePipeline(eraser: Bool) throws -> MTLRenderPipelineState {
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

        do {
            brushPipeline = try makePipeline(eraser: false)
            eraserPipeline = try makePipeline(eraser: true)
        } catch {
            return nil
        }
        commandQueue = queue
        super.init()
    }

    func update(document: DrawingDocument, previewStroke: DrawingStroke?, zoom: CGFloat, offset: CGPoint) {
        self.document = document
        self.previewStroke = previewStroke
        self.zoom = zoom
        self.offset = offset
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        for layer in document.layers where layer.isVisible {
            for stroke in layer.strokes {
                draw(stroke, layerOpacity: layer.opacity, in: view, encoder: encoder)
            }
        }
        if let previewStroke {
            draw(previewStroke, layerOpacity: 1, in: view, encoder: encoder)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func draw(
        _ stroke: DrawingStroke,
        layerOpacity: Double,
        in view: MTKView,
        encoder: MTLRenderCommandEncoder
    ) {
        let vertices = vertices(for: stroke, layerOpacity: layerOpacity, viewport: view.bounds.size)
        guard !vertices.isEmpty else { return }
        encoder.setRenderPipelineState(stroke.tool == .eraser ? eraserPipeline : brushPipeline)
        vertices.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            encoder.setVertexBytes(
                baseAddress,
                length: buffer.count * MemoryLayout<CanvasVertex>.stride,
                index: 0
            )
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }

    private func vertices(
        for stroke: DrawingStroke,
        layerOpacity: Double,
        viewport: CGSize
    ) -> [CanvasVertex] {
        guard !stroke.points.isEmpty, viewport.width > 0, viewport.height > 0 else { return [] }
        let points = stroke.points.count == 1 ? [stroke.points[0], stroke.points[0]] : stroke.points
        var result: [CanvasVertex] = []
        let color = SIMD4<Float>(
            Float(stroke.color.red),
            Float(stroke.color.green),
            Float(stroke.color.blue),
            Float(stroke.opacity * layerOpacity)
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
