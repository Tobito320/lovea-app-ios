@preconcurrency import Metal
import CoreText
import MetalPerformanceShaders
import UIKit

enum ShapeKind: String, CaseIterable, Identifiable {
    case line, rectangle, ellipse

    var id: String { rawValue }
    var title: String {
        switch self {
        case .line: "Linie"
        case .rectangle: "Rechteck"
        case .ellipse: "Ellipse"
        }
    }
    var symbol: String {
        switch self {
        case .line: "line.diagonal"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        }
    }
}

enum TextFont: String, CaseIterable, Identifiable {
    case system, rounded, serif, mono

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System"
        case .rounded: "Rund"
        case .serif: "Serif"
        case .mono: "Mono"
        }
    }
    var design: UIFontDescriptor.SystemDesign {
        switch self {
        case .system: .default
        case .rounded: .rounded
        case .serif: .serif
        case .mono: .monospaced
        }
    }
}

/// Geometry for selections, shapes and transforms. All nonisolated, all in document pixels.
enum Selection {
    /// Polygon → antialiased R8 mask, 255 inside.
    static func mask(_ polygon: [CGPoint], width: Int, height: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: width * height)
        guard polygon.count >= 3 else { return bytes }
        bytes.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return }
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.setFillColor(gray: 1, alpha: 1)
            context.addLines(between: polygon)
            context.closePath()
            context.fillPath()
        }
        return bytes
    }

    static func rectangle(from a: CGPoint, to b: CGPoint) -> [CGPoint] {
        [a, CGPoint(x: b.x, y: a.y), b, CGPoint(x: a.x, y: b.y)]
    }

    /// Points of a shape outline. `constrained` = square, circle or 45° line (second finger).
    static func shapePoints(_ kind: ShapeKind, from start: CGPoint, to proposed: CGPoint, constrained: Bool) -> [CGPoint] {
        var end = proposed
        let dx = proposed.x - start.x
        let dy = proposed.y - start.y
        if constrained {
            if kind == .line {
                let step = CGFloat.pi / 4
                let angle = (atan2(dy, dx) / step).rounded() * step
                let length = hypot(dx, dy)
                end = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
            } else {
                let side = max(abs(dx), abs(dy))
                end = CGPoint(x: start.x + (dx < 0 ? -side : side), y: start.y + (dy < 0 ? -side : side))
            }
        }
        switch kind {
        case .line:
            return [start, end]
        case .rectangle:
            let corners = rectangle(from: start, to: end)
            return corners + [start]
        case .ellipse:
            let center = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            let rx = abs(end.x - start.x) / 2
            let ry = abs(end.y - start.y) / 2
            return (0...72).map { index in
                let t = CGFloat(index) / 72 * 2 * .pi
                return CGPoint(x: center.x + rx * cos(t), y: center.y + ry * sin(t))
            }
        }
    }

    /// Corners (TL, TR, BL, BR) of a `size` rectangle at the origin after moving it with `transform` around `pivot`.
    static func transformedCorners(size: CGSize, pivot: CGPoint, transform: LayerTransform) -> [CGPoint] {
        let sx = CGFloat(transform.scale) * (transform.flipX ? -1 : 1)
        let sy = CGFloat(transform.scaleY) * (transform.flipY ? -1 : 1)
        let angle = CGFloat(transform.rotation)
        return [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
            .map { point in
                let x = (point.x - pivot.x) * sx
                let y = (point.y - pivot.y) * sy
                return CGPoint(
                    x: pivot.x + CGFloat(transform.offsetX) + x * cos(angle) - y * sin(angle),
                    y: pivot.y + CGFloat(transform.offsetY) + x * sin(angle) + y * cos(angle)
                )
            }
    }

    /// Snaps to 0°, 90°, 180°, 270° within `tolerance` degrees. Returns nil when not close.
    static func snappedRotation(_ angle: Double, tolerance: Double = 3) -> Double? {
        let quarter = Double.pi / 2
        let nearest = (angle / quarter).rounded() * quarter
        return abs(angle - nearest) <= tolerance * .pi / 180 ? nearest : nil
    }

    /// Renders text with CoreText into premultiplied RGBA, sized to the text.
    static func textPixels(_ text: String, font: TextFont, size: CGFloat, color: RGBAColor) -> RasterOps.Pixels? {
        let base = UIFont.systemFont(ofSize: size, weight: .regular)
        let uiFont = base.fontDescriptor.withDesign(font.design).map { UIFont(descriptor: $0, size: size) } ?? base
        let attributed = NSAttributedString(string: text, attributes: [
            .font: uiFont,
            .foregroundColor: UIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        ])
        let setter = CTFramesetterCreateWithAttributedString(attributed)
        let fit = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(), nil, CGSize(width: 4096, height: 4096), nil)
        let width = max(1, Int(fit.width.rounded(.up)) + 4)
        let height = max(1, Int(fit.height.rounded(.up)) + 4)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: RasterOps.colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            let path = CGPath(rect: CGRect(x: 2, y: 2, width: width - 4, height: height - 4), transform: nil)
            CTFrameDraw(CTFramesetterCreateFrame(setter, CFRange(), path, nil), context)
            return true
        }
        return drawn ? RasterOps.Pixels(bytes: bytes, width: width, height: height) : nil
    }
}

/// Content lifted for the transform tool. The preview is `base` plus `lifted` at the current transform.
struct TransformState {
    var layerID: UUID
    var lifted: MTLTexture?
    var base: MTLTexture?
    var result: MTLTexture?
    var pivot: CGPoint
    var bounds: CGRect
    var transform = LayerTransform()
    var imageBefore: ArtworkDocument?
    var newLayerName: String?
}

extension CanvasEngine {
    // MARK: Selection

    func select(polygon: [CGPoint]) async {
        let width = store.width
        let height = store.height
        let bytes = await Task.detached(priority: .userInitiated) { Selection.mask(polygon, width: width, height: height) }.value
        selection = GPU.upload(bytes, width: width, height: height, format: .r8Unorm)
        selectionBounds = polygon.isEmpty ? nil : polygonBounds(polygon)
    }

    func clearSelection() {
        selection = nil
        selectionBounds = nil
    }

    func invertSelection() {
        guard let selection, let inverted = GPU.makeTexture(device, width: store.width, height: store.height, format: .r8Unorm),
              let command = makeCommand() else { return }
        ops.invert(selection, into: inverted, command: command)
        command.commit()
        self.selection = inverted
        selectionBounds = CGRect(origin: .zero, size: canvasSize)
    }

    func deleteSelection(in layerID: UUID) {
        guard selection != nil else { return }
        clearLayer(layerID)
    }

    /// Copies (or cuts) the selected pixels to a new layer above. Returns the new layer's id.
    @discardableResult
    func copySelectionToNewLayer(from layerID: UUID, cut: Bool) -> UUID? {
        guard let selection, layer(layerID)?.kind == .paint, let source = store.texture(for: layerID) else { return nil }
        let copy = ArtworkLayer.paint(name: cut ? "Ausschnitt" : "Kopie")
        guard let target = try? store.makeEmpty(for: copy.id), let command = makeCommand() else { return nil }
        ops.maskedCopy(source, mask: selection, invert: false, into: target, clearFirst: true, command: command)
        command.commit()
        if cut { clearLayer(layerID) }
        let index = (document.layers.firstIndex(where: { $0.id == layerID }) ?? document.layers.count - 1) + 1
        updateDocument { $0.layers.insert(copy, at: min(index, $0.layers.count)) }
        activeLayerID = copy.id
        return copy.id
    }

    // MARK: Transform

    /// Lifts the selection (or the whole active layer) for moving, scaling, rotating and flipping.
    @discardableResult
    func beginTransform() -> Bool {
        guard transformState == nil, let layer = layer(activeLayerID), !layer.isLocked,
              let texture = store.texture(for: layer.id) else { return false }
        if layer.kind == .image {
            let corners = Compositor.imageCorners(
                transform: LayerTransform(),
                imageSize: CGSize(width: texture.width, height: texture.height),
                canvas: canvasSize
            )
            transformState = TransformState(
                layerID: layer.id, pivot: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
                bounds: polygonBounds(corners), transform: layer.transform, imageBefore: document
            )
            onChange?()
            return true
        }
        guard let lifted = GPU.makeTexture(device, width: store.width, height: store.height),
              let base = GPU.makeTexture(device, width: store.width, height: store.height),
              let result = GPU.makeTexture(device, width: store.width, height: store.height),
              let command = makeCommand() else { return false }
        if let selection {
            ops.maskedCopy(texture, mask: selection, invert: false, into: lifted, clearFirst: true, command: command)
            ops.maskedCopy(texture, mask: selection, invert: true, into: base, clearFirst: true, command: command)
        } else {
            GPU.copy(texture, to: lifted, command: command)
            GPU.fill(base, command: command)
        }
        command.commit()
        let bounds = selectionBounds ?? CGRect(origin: .zero, size: canvasSize)
        transformState = TransformState(
            layerID: layer.id, lifted: lifted, base: base, result: result,
            pivot: CGPoint(x: bounds.midX, y: bounds.midY), bounds: bounds
        )
        updateTransform(LayerTransform())
        return true
    }

    /// Starts a transform with rendered text as content. "Fertig" puts it into a new layer.
    func beginText(_ pixels: RasterOps.Pixels) {
        guard transformState == nil,
              let textTexture = GPU.upload(pixels.bytes, width: pixels.width, height: pixels.height),
              let lifted = GPU.makeTexture(device, width: store.width, height: store.height),
              let base = GPU.makeTexture(device, width: store.width, height: store.height),
              let result = GPU.makeTexture(device, width: store.width, height: store.height),
              let command = makeCommand() else { return }
        let rect = CGRect(
            x: (canvasSize.width - CGFloat(pixels.width)) / 2,
            y: (canvasSize.height - CGFloat(pixels.height)) / 2,
            width: CGFloat(pixels.width), height: CGFloat(pixels.height)
        )
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
            .map { GPU.ndc($0, size: canvasSize) }
        compositor.draw(textTexture, into: lifted, blend: .over, corners: corners, clearFirst: true, command: command)
        if let active = layer(activeLayerID), let texture = store.texture(for: active.id) {
            if active.kind == .image {
                compositor.renderImage(active, photo: texture, into: base, command: command)
            } else {
                GPU.copy(texture, to: base, command: command)
            }
        } else {
            GPU.fill(base, command: command)
        }
        command.commit()
        transformState = TransformState(
            layerID: activeLayerID, lifted: lifted, base: base, result: result,
            pivot: CGPoint(x: rect.midX, y: rect.midY), bounds: rect, newLayerName: "Text"
        )
        updateTransform(LayerTransform())
    }

    func updateTransform(_ transform: LayerTransform) {
        guard var state = transformState else { return }
        state.transform = transform
        transformState = state
        if state.imageBefore != nil {
            updateDocument(undoable: false) { document in
                guard let index = document.layers.firstIndex(where: { $0.id == state.layerID }) else { return }
                document.layers[index].transform = transform
            }
            return
        }
        guard let lifted = state.lifted, let base = state.base, let result = state.result, let command = makeCommand() else { return }
        let corners = Selection.transformedCorners(size: canvasSize, pivot: state.pivot, transform: transform)
            .map { GPU.ndc($0, size: canvasSize) }
        GPU.copy(base, to: result, command: command)
        compositor.draw(lifted, into: result, blend: .over, corners: corners, command: command)
        command.commit()
        compositor.override = (state.layerID, result)
        onChange?()
    }

    /// Writes the transformed content back once (bilinear) as one undo step.
    func commitTransform() {
        guard let state = transformState else { return }
        transformState = nil
        compositor.override = nil
        if let before = state.imageBefore {
            recordDocumentStep(from: before)
        } else if let result = state.result {
            if let name = state.newLayerName {
                // Pixels first, then the layer step, so the step (and a shared drawing's op) already has the text.
                let layer = ArtworkLayer.paint(name: name)
                if prepareTexture(for: layer), let target = store.texture(for: layer.id), let lifted = state.lifted,
                   let command = makeCommand() {
                    let corners = Selection.transformedCorners(size: canvasSize, pivot: state.pivot, transform: state.transform)
                        .map { GPU.ndc($0, size: canvasSize) }
                    compositor.draw(lifted, into: target, blend: .over, corners: corners, clearFirst: true, command: command)
                    command.commit()
                    let index = (document.layers.firstIndex(where: { $0.id == activeLayerID }) ?? document.layers.count - 1) + 1
                    updateDocument { $0.layers.insert(layer, at: min(index, $0.layers.count)) }
                    activeLayerID = layer.id
                }
            } else {
                editPixels(of: state.layerID) { command, target in
                    GPU.copy(result, to: target, command: command)
                }
            }
        }
        clearSelection()
        onChange?()
    }

    func cancelTransform() {
        guard let state = transformState else { return }
        transformState = nil
        compositor.override = nil
        if let before = state.imageBefore {
            updateDocument(undoable: false) { $0 = before }
        }
        onChange?()
    }

    // MARK: Shapes

    /// Paints a shape with the current brush as stamps (outline) or as a filled mask into the layer.
    func drawShape(_ points: [CGPoint], filled: Bool, settings: BrushSettings, layerID: UUID) async {
        guard points.count >= 2 else { return }
        if filled, points.count >= 3 {
            let width = store.width
            let height = store.height
            let bytes = await Task.detached(priority: .userInitiated) { Selection.mask(points, width: width, height: height) }.value
            guard let mask = GPU.upload(bytes, width: width, height: height, format: .r8Unorm) else { return }
            var color = settings.color
            color.alpha *= min(settings.opacity, settings.preset.opacityCap)
            paintMask(mask, color: color, layerID: layerID)
            return
        }
        var steady = settings
        steady.stabilizer = 0
        steady.pressureSize = false
        let inputs = points.map { StrokeInput(location: $0) }
        beginStroke(inputs[0], settings: steady, layerID: layerID)
        continueStroke(Array(inputs.dropFirst()), predicted: [])
        endStroke()
    }

    // MARK: Adjustments

    func previewAdjustment(_ adjustment: Adjustment, amount: Double) {
        guard let layer = layer(activeLayerID), layer.kind == .paint, let source = store.texture(for: layer.id),
              let command = makeCommand() else { return }
        if adjustmentResult == nil { adjustmentResult = GPU.makeTexture(device, width: store.width, height: store.height) }
        guard let result = adjustmentResult else { return }
        let mask = selection ?? stamper.whiteMask
        if adjustment == .blur {
            if adjustmentTemp == nil { adjustmentTemp = GPU.makeTexture(device, width: store.width, height: store.height, writable: true) }
            guard let blurred = adjustmentTemp else { return }
            if MPSSupportsMTLDevice(device), amount > 0.05 {
                MPSImageGaussianBlur(device: device, sigma: Float(amount)).encode(
                    commandBuffer: command, sourceTexture: source, destinationTexture: blurred
                )
            } else {
                GPU.copy(source, to: blurred, command: command)
            }
            ops.maskedCopy(source, mask: mask, invert: true, into: result, clearFirst: true, command: command)
            ops.maskedCopy(blurred, mask: mask, invert: false, into: result, clearFirst: false, command: command)
        } else {
            ops.adjust(source, selection: mask, mode: adjustment, amount: Float(amount), into: result, command: command)
        }
        command.commit()
        compositor.override = (layer.id, result)
        onChange?()
    }

    func commitAdjustment() {
        guard let override = compositor.override, let result = adjustmentResult, override.texture === result else { return }
        compositor.override = nil
        editPixels(of: override.layerID) { command, target in
            GPU.copy(result, to: target, command: command)
        }
        adjustmentResult = nil
        adjustmentTemp = nil
    }

    func cancelAdjustment() {
        compositor.override = nil
        adjustmentResult = nil
        adjustmentTemp = nil
        onChange?()
    }

    private func polygonBounds(_ points: [CGPoint]) -> CGRect {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return .null }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
