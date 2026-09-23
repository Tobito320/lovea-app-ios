@preconcurrency import Metal
import UIKit

struct LiveStroke {
    var scratch: MTLTexture
    var opacity: Float
    var isEraser: Bool
    var alphaLock: Bool
}

private struct BlendUniforms {
    var mode: Int32
    var opacity: Float
    var useMask: Int32
}

extension LayerBlendMode {
    var shaderIndex: Int32 {
        switch self {
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
}

extension CanvasBackground {
    var clearColor: MTLClearColor {
        switch self {
        case .white: MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        case .dark: MTLClearColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
        case .transparent: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        case .color(let c):
            MTLClearColor(red: c.red * c.alpha, green: c.green * c.alpha, blue: c.blue * c.alpha, alpha: c.alpha)
        }
    }
}

/// Puts the layers together on the GPU. Layers below and above the active one are cached,
/// so a frame only blends below + active (+ stroke) + above.
@MainActor
final class Compositor {
    private let device: MTLDevice
    private let blendPipeline: MTLRenderPipelineState
    private let copyPipelines: [BlendKind: MTLRenderPipelineState]
    private let presentPipeline: MTLRenderPipelineState
    private let checkerPipeline: MTLRenderPipelineState
    let linear: MTLSamplerState
    let nearest: MTLSamplerState

    private var accum: [MTLTexture] = []
    private var below: MTLTexture?
    private var above: MTLTexture?
    private(set) var activeTemp: MTLTexture?
    /// Layer + remote stroke for layers other than the active one.
    private var strokeTemps: [UUID: MTLTexture] = [:]
    private var imageTemp: MTLTexture?
    private var maskTemp: MTLTexture?
    private var belowState: ([ArtworkLayer], CanvasBackground)?
    private var aboveState: [ArtworkLayer]?

    private(set) var belowBuilds = 0
    private(set) var aboveBuilds = 0
    /// Screen pixels per point of the drawable.
    var contentScale: CGFloat = 1
    var viewBackground = MTLClearColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
    /// Replaces a layer's content for one frame, e.g. a live transform or filter preview.
    var override: (layerID: UUID, texture: MTLTexture)?

    init(device: MTLDevice, library: MTLLibrary) throws {
        self.device = device
        blendPipeline = try GPU.pipeline(device, library, fragment: "blendFragment", blend: .none)
        var copies: [BlendKind: MTLRenderPipelineState] = [:]
        for kind in [BlendKind.none, .over, .erase, .atop] {
            copies[kind] = try GPU.pipeline(device, library, fragment: "copyFragment", blend: kind)
        }
        copyPipelines = copies
        presentPipeline = try GPU.pipeline(device, library, fragment: "copyFragment", format: .bgra8Unorm, blend: .over)
        checkerPipeline = try GPU.pipeline(device, library, fragment: "checkerFragment", format: .bgra8Unorm, blend: .none)
        guard let linear = GPU.sampler(device, nearest: false), let nearest = GPU.sampler(device, nearest: true) else {
            throw EngineError.deviceUnavailable
        }
        self.linear = linear
        self.nearest = nearest
    }

    func invalidateCaches() {
        belowState = nil
        aboveState = nil
    }

    /// Frees the caches. They are rebuilt on the next frame.
    func releaseCaches() {
        invalidateCaches()
        accum = []
        below = nil
        above = nil
        activeTemp = nil
        strokeTemps = [:]
        imageTemp = nil
        maskTemp = nil
    }

    /// `remote`: strokes of other people in progress, per layer.
    func encodeFrame(
        document: ArtworkDocument,
        activeLayerID: UUID,
        store: LayerTextureStore,
        stroke: LiveStroke?,
        remote: [UUID: [LiveStroke]] = [:],
        viewport: ArtworkCanvasViewport,
        into drawable: MTLTexture,
        command: MTLCommandBuffer
    ) {
        let layers = document.layers
        guard ensureTextures(width: store.width, height: store.height),
              let below, let above, let activeTemp else { return }
        let active = layers.firstIndex(where: { $0.id == activeLayerID }) ?? layers.count
        var end = active
        while end + 1 < layers.count, layers[end + 1].clipping { end += 1 }
        let liveRange = active..<min(end + 1, layers.count)
        let aboveRange = min(end + 1, layers.count)..<layers.count

        var overrides: [UUID: MTLTexture] = [:]
        if let override { overrides[override.layerID] = override.texture }
        var strokes = remote
        if let stroke, active < layers.count { strokes[activeLayerID, default: []].append(stroke) }
        strokeTemps = strokeTemps.filter { strokes[$0.key] != nil && $0.key != activeLayerID }
        var strokeOutsideLive = false
        for (id, list) in strokes {
            guard let index = layers.firstIndex(where: { $0.id == id }),
                  let layerTexture = overrides[id] ?? store.texture(for: id),
                  let temp = id == activeLayerID ? Optional(activeTemp) : strokeTemp(for: id, store: store) else { continue }
            GPU.copy(layerTexture, to: temp, command: command)
            for live in list {
                let kind: BlendKind = live.isEraser ? .erase : (live.alphaLock ? .atop : .over)
                draw(live.scratch, into: temp, blend: kind, opacity: live.opacity, command: command)
            }
            overrides[id] = temp
            if !liveRange.contains(index) { strokeOutsideLive = true }
        }
        // ponytail: a remote stroke outside the active group rebuilds both caches every frame while it runs;
        // per-layer caches if that ever shows up in the HUD.
        if strokeOutsideLive { invalidateCaches() }

        let belowKey = (Array(layers[..<active]), document.background)
        if belowState == nil || belowState!.0 != belowKey.0 || belowState!.1 != belowKey.1 {
            clear(accum[0], color: document.background.clearColor, command: command)
            let result = composite(0..<active, of: layers, onto: accum[0], store: store, overrides: overrides, command: command)
            GPU.copy(result, to: below, command: command)
            belowState = belowKey
            belowBuilds += 1
        }
        let aboveCacheable = layers[aboveRange].allSatisfy { $0.blendMode == .normal }
        if aboveCacheable, aboveState != Array(layers[aboveRange]) {
            clear(accum[0], color: MTLClearColor(), command: command)
            let result = composite(aboveRange, of: layers, onto: accum[0], store: store, overrides: overrides, command: command)
            GPU.copy(result, to: above, command: command)
            aboveState = Array(layers[aboveRange])
            aboveBuilds += 1
        }

        var current = composite(liveRange, of: layers, onto: below, store: store, overrides: overrides, command: command)
        if current === below {
            GPU.copy(below, to: accum[0], command: command)
            current = accum[0]
        }
        if aboveCacheable {
            if !aboveRange.isEmpty { draw(above, into: current, blend: .over, command: command) }
        } else {
            current = composite(aboveRange, of: layers, onto: current, store: store, overrides: overrides, command: command)
        }
        present(current, document: document, viewport: viewport, into: drawable, command: command)
    }

    /// All visible layers on the background, full document size. Valid until the next frame.
    func flatten(document: ArtworkDocument, store: LayerTextureStore, command: MTLCommandBuffer) -> MTLTexture {
        // ponytail: without the working textures there is nothing sensible to return.
        guard ensureTextures(width: store.width, height: store.height) else { fatalError("GPU-Speicher voll") }
        clear(accum[0], color: document.background.clearColor, command: command)
        var overrides: [UUID: MTLTexture] = [:]
        if let override { overrides[override.layerID] = override.texture }
        return composite(0..<document.layers.count, of: document.layers, onto: accum[0], store: store, overrides: overrides, command: command)
    }

    /// Draws `source` over the whole of `target` (same size) or into `corners` (NDC).
    func draw(
        _ source: MTLTexture,
        into target: MTLTexture,
        blend: BlendKind,
        opacity: Float = 1,
        corners: [SIMD2<Float>]? = nil,
        clearFirst: Bool = false,
        command: MTLCommandBuffer
    ) {
        guard let pipeline = copyPipelines[blend],
              let encoder = GPU.pass(command, target: target, clear: clearFirst ? MTLClearColor() : nil) else { return }
        var opacity = opacity
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(source, index: 0)
        encoder.setFragmentSamplerState(linear, index: 0)
        encoder.setFragmentBytes(&opacity, length: MemoryLayout<Float>.stride, index: 0)
        GPU.drawQuad(encoder, corners: corners ?? GPU.fullScreen)
        encoder.endEncoding()
    }

    /// Corners of an image layer in document pixels: top-left, top-right, bottom-left, bottom-right.
    /// The photo is aspect-fit into the canvas, then offset, scaled, rotated and flipped around the center.
    static func imageCorners(transform: LayerTransform, imageSize: CGSize, canvas: CGSize) -> [CGPoint] {
        guard imageSize.width > 0, imageSize.height > 0 else { return [] }
        let fit = min(canvas.width / imageSize.width, canvas.height / imageSize.height)
        let size = CGSize(width: imageSize.width * fit, height: imageSize.height * fit)
        let sx = CGFloat(transform.scale) * (transform.flipX ? -1 : 1)
        let sy = CGFloat(transform.scaleY) * (transform.flipY ? -1 : 1)
        let angle = CGFloat(transform.rotation)
        let center = CGPoint(x: canvas.width / 2 + CGFloat(transform.offsetX), y: canvas.height / 2 + CGFloat(transform.offsetY))
        return [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)].map { u, v in
            let x = (CGFloat(u) - 0.5) * size.width * sx
            let y = (CGFloat(v) - 0.5) * size.height * sy
            return CGPoint(
                x: center.x + x * cos(angle) - y * sin(angle),
                y: center.y + x * sin(angle) + y * cos(angle)
            )
        }
    }

    /// Renders an image layer into a document-sized texture.
    func renderImage(_ layer: ArtworkLayer, photo: MTLTexture, into target: MTLTexture, command: MTLCommandBuffer) {
        let canvas = CGSize(width: target.width, height: target.height)
        let corners = Self.imageCorners(
            transform: layer.transform,
            imageSize: CGSize(width: photo.width, height: photo.height),
            canvas: canvas
        ).map { GPU.ndc($0, size: canvas) }
        draw(photo, into: target, blend: .over, corners: corners.count == 4 ? corners : nil, clearFirst: true, command: command)
    }

    private func ensureTextures(width: Int, height: Int) -> Bool {
        if let first = accum.first, first.width == width, first.height == height, below != nil { return true }
        invalidateCaches()
        let made = (0..<5).compactMap { _ in GPU.makeTexture(device, width: width, height: height) }
        guard made.count == 5 else { return false }
        accum = [made[0], made[1]]
        below = made[2]
        above = made[3]
        activeTemp = made[4]
        imageTemp = nil
        maskTemp = nil
        return true
    }

    private func strokeTemp(for id: UUID, store: LayerTextureStore) -> MTLTexture? {
        if let temp = strokeTemps[id] { return temp }
        let temp = GPU.makeTexture(device, width: store.width, height: store.height)
        strokeTemps[id] = temp
        return temp
    }

    private func clear(_ texture: MTLTexture, color: MTLClearColor, command: MTLCommandBuffer) {
        GPU.pass(command, target: texture, clear: color)?.endEncoding()
    }

    private func source(
        for layer: ArtworkLayer,
        store: LayerTextureStore,
        overrides: [UUID: MTLTexture],
        useMaskTemp: Bool,
        command: MTLCommandBuffer
    ) -> MTLTexture? {
        if let texture = overrides[layer.id] { return texture }
        guard let texture = store.texture(for: layer.id) else { return nil }
        guard layer.kind == .image else { return texture }
        let temp: MTLTexture?
        if useMaskTemp {
            if maskTemp == nil { maskTemp = GPU.makeTexture(device, width: store.width, height: store.height) }
            temp = maskTemp
        } else {
            if imageTemp == nil { imageTemp = GPU.makeTexture(device, width: store.width, height: store.height) }
            temp = imageTemp
        }
        guard let temp else { return nil }
        renderImage(layer, photo: texture, into: temp, command: command)
        return temp
    }

    private func composite(
        _ range: Range<Int>,
        of layers: [ArtworkLayer],
        onto start: MTLTexture,
        store: LayerTextureStore,
        overrides: [UUID: MTLTexture],
        command: MTLCommandBuffer
    ) -> MTLTexture {
        var current = start
        for index in range {
            let layer = layers[index]
            guard layer.isVisible else { continue }
            var mask: MTLTexture?
            if layer.clipping, let baseIndex = layers[..<index].lastIndex(where: { !$0.clipping }) {
                let base = layers[baseIndex]
                guard base.isVisible else { continue }
                mask = source(for: base, store: store, overrides: overrides, useMaskTemp: true, command: command)
            }
            let out = current === accum[0] ? accum[1] : accum[0]
            guard let source = source(for: layer, store: store, overrides: overrides, useMaskTemp: false, command: command),
                  let encoder = GPU.pass(command, target: out, clear: MTLClearColor())
            else { continue }
            var uniforms = BlendUniforms(
                mode: layer.blendMode.shaderIndex,
                opacity: Float(min(max(layer.opacity, 0), 1)),
                useMask: mask == nil ? 0 : 1
            )
            encoder.setRenderPipelineState(blendPipeline)
            encoder.setFragmentTexture(current, index: 0)
            encoder.setFragmentTexture(source, index: 1)
            encoder.setFragmentTexture(mask ?? source, index: 2)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<BlendUniforms>.stride, index: 0)
            GPU.drawQuad(encoder, corners: GPU.fullScreen)
            encoder.endEncoding()
            current = out
        }
        return current
    }

    private func present(
        _ image: MTLTexture,
        document: ArtworkDocument,
        viewport: ArtworkCanvasViewport,
        into drawable: MTLTexture,
        command: MTLCommandBuffer
    ) {
        guard let encoder = GPU.pass(command, target: drawable, clear: viewBackground) else { return }
        let screen = CGSize(width: CGFloat(drawable.width) / contentScale, height: CGFloat(drawable.height) / contentScale)
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let corners = [CGPoint.zero, CGPoint(x: width, y: 0), CGPoint(x: 0, y: height), CGPoint(x: width, y: height)]
            .map { GPU.ndc(viewport.screenPoint($0), size: screen) }
        if document.background == .transparent {
            var size = SIMD2<Float>(Float(width), Float(height))
            encoder.setRenderPipelineState(checkerPipeline)
            encoder.setFragmentBytes(&size, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
            GPU.drawQuad(encoder, corners: corners)
        }
        var opacity: Float = 1
        encoder.setRenderPipelineState(presentPipeline)
        encoder.setFragmentTexture(image, index: 0)
        encoder.setFragmentSamplerState(viewport.scale * contentScale >= 4 ? nearest : linear, index: 0)
        encoder.setFragmentBytes(&opacity, length: MemoryLayout<Float>.stride, index: 0)
        GPU.drawQuad(encoder, corners: corners)
        encoder.endEncoding()
    }
}
