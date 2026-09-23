@preconcurrency import Metal
@preconcurrency import MetalKit
import MetalPerformanceShaders
import UIKit
import UniformTypeIdentifiers

enum EngineError: Error {
    case memoryBudget, deviceUnavailable, decode
}

enum FillReference: String, CaseIterable, Identifiable {
    case activeLayer, allVisible

    var id: String { rawValue }
    var title: String { self == .activeLayer ? "Diese Ebene" : "Alle Ebenen" }
}

/// The one entry point for pixels. Session and view only talk to this.
@MainActor
final class CanvasEngine {
    private(set) var document: ArtworkDocument
    let undo: UndoHistory
    let library: ArtworkLibrary
    let device: MTLDevice
    let store: LayerTextureStore
    let compositor: Compositor
    let stamper: BrushStamper
    let ops: EngineOps
    private let queue: MTLCommandQueue
    private let scratch: MTLTexture
    private let preview: MTLTexture
    private var offscreen: MTLTexture?

    var activeLayerID: UUID {
        didSet { if oldValue != activeLayerID { onChange?() } }
    }
    /// R8 mask in document size. Painting, filling and filters only act inside it.
    var selection: MTLTexture? { didSet { onChange?() } }
    /// Symmetry axis x in document pixels.
    var mirrorX: Float?
    /// Called after every change to the document or its pixels.
    var onChange: (() -> Void)?
    /// Called once per finished own non-stroke action (fill, layer change, transform …), for `zeichnung.op`.
    var onAction: (() -> Void)?
    private(set) var loading: Task<Void, Never>?

    private var sampler: StrokeSampler?
    private var strokeLayerID: UUID?
    private var pending: [Stamp] = []
    private var predicted: [Stamp] = []
    /// Live stroke frames only touch what changed: stamps flushed since the last frame plus the old
    /// and new predicted stamps. The first frame of a stroke syncs `preview` with `scratch` in full.
    private var liveSynced = false
    private var liveChanged = CGRect.null
    private var lastPredicted = CGRect.null
    /// Bumped whenever layer pixels change outside the live stroke; the compositor then refreshes its copy in full.
    private var liveSerial = 0
    private var detached: [UUID: MTLTexture] = [:]
    private var remoteStrokes: [String: RemoteStroke] = [:]
    private var spareScratches: [MTLTexture] = []
    private(set) var dirtyLayers: Set<UUID> = []
    private(set) var frameCount = 0
    private(set) var fixedStampsEncoded = 0
    private(set) var lastGPUTime: Double = 0
    /// Start time and CPU encode time (ms) of the frames of the last 2 s, for the performance HUD.
    private(set) var frameLog: [(time: CFTimeInterval, milliseconds: Double)] = []
    /// Start time and GPU time (ms) of the same frames, filled in when the GPU is done.
    private(set) var gpuLog: [(time: CFTimeInterval, milliseconds: Double)] = []
    var transformState: TransformState?
    var selectionBounds: CGRect?
    var adjustmentResult: MTLTexture?
    var adjustmentTemp: MTLTexture?

    init(document: ArtworkDocument, library: ArtworkLibrary, budgetBytes: Int = LayerTextureStore.defaultBudget()) throws {
        guard let device = GPU.device, let queue = GPU.queue, let metalLibrary = GPU.library else {
            throw EngineError.deviceUnavailable
        }
        self.document = document
        self.library = library
        self.device = device
        self.queue = queue
        undo = UndoHistory()
        let size = CGSize(width: document.canvasWidth, height: document.canvasHeight)
        store = LayerTextureStore(device: device, canvasSize: size, budgetBytes: budgetBytes)
        compositor = try Compositor(device: device, library: metalLibrary)
        stamper = try BrushStamper(device: device, library: metalLibrary)
        ops = try EngineOps(device: device, library: metalLibrary)
        guard let scratch = GPU.makeTexture(device, width: store.width, height: store.height),
              let preview = GPU.makeTexture(device, width: store.width, height: store.height) else {
            throw EngineError.deviceUnavailable
        }
        self.scratch = scratch
        self.preview = preview
        activeLayerID = document.layers.last(where: { $0.kind == .paint })?.id ?? document.layers.last?.id ?? UUID()
        for layer in document.layers where layer.kind == .paint {
            try store.makeEmpty(for: layer.id)
        }
        loading = Task { await self.loadContents() }
    }

    var canvasSize: CGSize { store.canvasSize }

    func layer(_ id: UUID) -> ArtworkLayer? {
        document.layers.first(where: { $0.id == id })
    }

    // MARK: Loading and saving

    private func loadContents() async {
        await library.waitForWrites()
        for layer in document.layers {
            if let pixels = await decodeLayer(layer, artworkID: document.id) { try? store.setPixels(pixels, for: layer.id) }
        }
        if document.schemaVersion < 3 { await migrateLegacyLayers() }
        compositor.invalidateCaches()
        onChange?()
    }

    private func decodeLayer(_ layer: ArtworkLayer, artworkID: UUID) async -> RasterOps.Pixels? {
        let url = library.layerAssetURL(fileName: layer.contentFile, artworkID: artworkID)
        let isImage = layer.kind == .image
        let limit = Int(max(canvasSize.width, canvasSize.height) * 2)
        return await Task.detached(priority: .userInitiated) { () -> RasterOps.Pixels? in
            guard url.pathExtension == "png", let data = try? Data(contentsOf: url) else { return nil }
            return RasterOps.decode(data, maxPixelSize: isImage ? limit : nil)
        }.value
    }

    /// Swaps in a newer version of the same artwork from the library (a partner's shared stand).
    /// Decodes everything first so the canvas never shows empty layers. Remote strokes in flight stay.
    func reload(_ next: ArtworkDocument) async {
        await library.waitForWrites()
        var decoded: [UUID: RasterOps.Pixels] = [:]
        for layer in next.layers {
            decoded[layer.id] = await decodeLayer(layer, artworkID: next.id)
        }
        resetStroke()
        undo.removeAll()
        detached.removeAll()
        let keep = Set(next.layers.map(\.id))
        for layer in document.layers where !keep.contains(layer.id) {
            store.remove(layer.id)
        }
        document = next
        for layer in next.layers {
            if let pixels = decoded[layer.id] {
                try? store.setPixels(pixels, for: layer.id)
            } else if layer.kind == .paint {
                try? store.makeEmpty(for: layer.id)
            }
        }
        dirtyLayers.removeAll()
        if !keep.contains(activeLayerID) { activeLayerID = next.layers.last?.id ?? activeLayerID }
        compositor.invalidateCaches()
        onChange?()
    }

    /// Shared drawing: which ops the next save contains. No undo step, no `onChange`.
    func setzeBasis(_ basis: Int, offen: [String]) {
        document.basis = basis
        document.offen = offen.isEmpty ? nil : offen
    }

    /// Writes changed layers as PNG, then `document.json`. Runs in the background.
    func saveDirtyLayers() async {
        let ids = dirtyLayers
        dirtyLayers.removeAll()
        for id in ids {
            guard let layer = layer(id), let data = await store.pngData(for: id) else { continue }
            library.saveLayerData(data, layer: layer, artworkID: document.id)
        }
        library.saveDocument(document)
        await library.waitForWrites()
    }

    func markDirty(_ id: UUID) {
        dirtyLayers.insert(id)
    }

    // MARK: Strokes

    func beginStroke(_ input: StrokeInput, settings: BrushSettings, layerID: UUID) {
        guard let layer = layer(layerID), layer.kind == .paint, !layer.isLocked,
              store.texture(for: layerID) != nil, let command = queue.makeCommandBuffer() else { return }
        GPU.fill(scratch, command: command)
        command.commit()
        var sampler = StrokeSampler(settings: settings)
        pending = sampler.add(input)
        predicted = []
        self.sampler = sampler
        strokeLayerID = layerID
        liveSynced = false
        liveChanged = .null
        lastPredicted = .null
        liveSerial += 1
    }

    var isStroking: Bool { sampler != nil }

    func continueStroke(_ inputs: [StrokeInput], predicted: [StrokeInput]) {
        guard var sampler else { return }
        for input in inputs { pending += sampler.add(input) }
        var guess = sampler
        self.predicted = predicted.flatMap { guess.add($0) }
        self.sampler = sampler
    }

    func endStroke() {
        guard var sampler, let layerID = strokeLayerID, let target = store.texture(for: layerID),
              let command = queue.makeCommandBuffer() else {
            cancelStroke()
            return
        }
        pending += sampler.finish()
        flushStamps(command: command)
        land(scratch, sampler: sampler, into: target, layerID: layerID, mirrorX: mirrorX, autor: nil, command: command)
        resetStroke()
        didEditPixels(of: layerID)
    }

    /// Puts a finished stroke from its scratch onto the layer and records one undo step.
    private func land(
        _ scratch: MTLTexture, sampler: StrokeSampler, into target: MTLTexture, layerID: UUID,
        mirrorX: Float?, autor: String?, command: MTLCommandBuffer
    ) {
        let settings = sampler.settings
        let alphaLock = layer(layerID)?.alphaLock ?? false
        var bounds = sampler.bounds
        if let mirrorX, !bounds.isNull {
            bounds = bounds.union(CGRect(x: 2 * CGFloat(mirrorX) - bounds.maxX, y: bounds.minY, width: bounds.width, height: bounds.height))
        }
        let region = pixelRegion(bounds.insetBy(dx: -2, dy: -2))
        let before = region.flatMap { snapshot(target, region: $0, command: command) }
        let kind: BlendKind = settings.isEraser ? .erase : (alphaLock ? .atop : .over)
        compositor.draw(scratch, into: target, blend: kind, opacity: settings.strokeOpacity, command: command)
        let after = region.flatMap { snapshot(target, region: $0, command: command) }
        command.commit()
        if let region, let before, let after {
            undo.push(.pixels(layerID: layerID, region: region, before: before, after: after), autor: autor)
        }
    }

    // MARK: Remote strokes

    /// A partner's stroke in progress: own sampler and scratch, same stamping path as a local stroke.
    private struct RemoteStroke {
        var sampler: StrokeSampler
        let layerID: UUID
        let scratch: MTLTexture
        let mirrorX: Float?
        let autor: String?
    }

    func hasRemoteStroke(_ id: String) -> Bool {
        remoteStrokes[id] != nil
    }

    /// Starts a stroke from someone else. It ignores the local selection and lock; the caller redraws.
    func remoteBegin(id: String, layerID: UUID, settings: BrushSettings, first: StrokeInput, mirrorX: Float? = nil, autor: String? = nil) {
        guard remoteStrokes[id] == nil, layer(layerID)?.kind == .paint, store.texture(for: layerID) != nil,
              let scratch = spareScratches.popLast() ?? GPU.makeTexture(device, width: store.width, height: store.height),
              let command = queue.makeCommandBuffer() else { return }
        GPU.fill(scratch, command: command)
        var sampler = StrokeSampler(settings: settings)
        stamper.encode(sampler.add(first), tip: sampler.tip, color: settings.color, into: scratch,
                       mask: nil, mirrorX: mirrorX, command: command)
        command.commit()
        remoteStrokes[id] = RemoteStroke(sampler: sampler, layerID: layerID, scratch: scratch, mirrorX: mirrorX, autor: autor)
    }

    func remoteContinue(id: String, _ inputs: [StrokeInput]) {
        guard var stroke = remoteStrokes[id], let command = queue.makeCommandBuffer() else { return }
        var stamps: [Stamp] = []
        for input in inputs { stamps += stroke.sampler.add(input) }
        stamper.encode(stamps, tip: stroke.sampler.tip, color: stroke.sampler.settings.color, into: stroke.scratch,
                       mask: nil, mirrorX: stroke.mirrorX, command: command)
        command.commit()
        remoteStrokes[id] = stroke
    }

    /// Lands the stroke. The undo step carries `autor`, so local undo never takes it back.
    func remoteEnd(id: String) {
        guard var stroke = remoteStrokes.removeValue(forKey: id), let target = store.texture(for: stroke.layerID),
              let command = queue.makeCommandBuffer() else { return }
        stamper.encode(stroke.sampler.finish(), tip: stroke.sampler.tip, color: stroke.sampler.settings.color,
                       into: stroke.scratch, mask: nil, mirrorX: stroke.mirrorX, command: command)
        land(stroke.scratch, sampler: stroke.sampler, into: target, layerID: stroke.layerID,
             mirrorX: stroke.mirrorX, autor: stroke.autor, command: command)
        keepSpare(stroke.scratch)
        didEditPixels(of: stroke.layerID)
    }

    func remoteCancel(id: String) {
        if let stroke = remoteStrokes.removeValue(forKey: id) { keepSpare(stroke.scratch) }
    }

    /// A partner draws several strokes a second; a document-sized scratch each would churn 16 MB at 2048².
    /// Reuse is safe: everything runs on one queue, so the next clear waits for the last use.
    private func keepSpare(_ scratch: MTLTexture) {
        if spareScratches.count < 2 { spareScratches.append(scratch) }
    }

    func cancelStroke() {
        resetStroke()
        onChange?()
    }

    private func resetStroke() {
        sampler = nil
        strokeLayerID = nil
        pending = []
        predicted = []
    }

    private func flushStamps(command: MTLCommandBuffer) {
        guard let sampler, !pending.isEmpty else { return }
        liveChanged = liveChanged.union(stampBounds(pending))
        stamper.encode(pending, tip: sampler.tip, color: sampler.settings.color, into: scratch,
                       mask: selection, mirrorX: mirrorX, command: command)
        fixedStampsEncoded += pending.count
        pending = []
    }

    /// Document rect that `stamps` can touch, mirror included. A stamp quad is `radius × radius·aspect`,
    /// rotated, so √2 · the longer side covers it; 2 px for antialiasing.
    private func stampBounds(_ stamps: [Stamp]) -> CGRect {
        var rect = CGRect.null
        for stamp in stamps {
            let r = CGFloat(stamp.radius * max(1, stamp.aspect)) * 1.415 + 2
            rect = rect.union(CGRect(x: CGFloat(stamp.center.x) - r, y: CGFloat(stamp.center.y) - r, width: 2 * r, height: 2 * r))
        }
        if let mirrorX, !rect.isNull {
            rect = rect.union(CGRect(x: 2 * CGFloat(mirrorX) - rect.maxX, y: rect.minY, width: rect.width, height: rect.height))
        }
        return rect
    }

    // MARK: Rendering

    func draw(in view: MTKView, viewport: ArtworkCanvasViewport) {
        guard let drawable = view.currentDrawable, let command = queue.makeCommandBuffer() else { return }
        let start = CACurrentMediaTime()
        compositor.contentScale = view.contentScaleFactor
        render(into: drawable.texture, viewport: viewport, command: command)
        frameLog.append((start, (CACurrentMediaTime() - start) * 1000))
        frameLog.removeAll { start - $0.time > 2 }
        command.addCompletedHandler { [weak self] buffer in
            let time = buffer.gpuEndTime - buffer.gpuStartTime
            Task { @MainActor in
                guard let self else { return }
                self.lastGPUTime = time
                self.gpuLog.append((start, time * 1000))
                self.gpuLog.removeAll { start - $0.time > 2 }
            }
        }
        command.present(drawable)
        command.commit()
    }

    /// Draws one frame without a screen, for tests.
    func renderOffscreen(viewport: ArtworkCanvasViewport = ArtworkCanvasViewport()) {
        if offscreen == nil { offscreen = GPU.makeTexture(device, width: 64, height: 64, format: .bgra8Unorm) }
        guard let offscreen, let command = queue.makeCommandBuffer() else { return }
        render(into: offscreen, viewport: viewport, command: command)
        command.addCompletedHandler { [weak self] buffer in
            let time = buffer.gpuEndTime - buffer.gpuStartTime
            Task { @MainActor in self?.lastGPUTime = time }
        }
        command.commit()
    }

    private func render(into target: MTLTexture, viewport: ArtworkCanvasViewport, command: MTLCommandBuffer) {
        frameCount += 1
        flushStamps(command: command)
        var live: LiveStroke?
        if let sampler, let layerID = strokeLayerID {
            // `preview` = scratch + predicted stamps. Only the changed rect is refreshed; before this a
            // stroke frame blitted the whole document twice (scratch → preview, layer → activeTemp).
            let guess = stampBounds(predicted)
            let region: MTLRegion?
            if liveSynced {
                region = pixelRegion(liveChanged.union(lastPredicted).union(guess)) ?? MTLRegionMake2D(0, 0, 0, 0)
            } else {
                region = nil
            }
            if let region {
                if region.size.width > 0 { GPU.copy(scratch, region: region, to: preview, at: region.origin, command: command) }
            } else {
                GPU.copy(scratch, to: preview, command: command)
            }
            stamper.encode(predicted, tip: sampler.tip, color: sampler.settings.color, into: preview,
                           mask: selection, mirrorX: mirrorX, command: command)
            liveSynced = true
            liveChanged = .null
            lastPredicted = guess
            live = LiveStroke(
                scratch: preview,
                opacity: sampler.settings.strokeOpacity,
                isEraser: sampler.settings.isEraser,
                alphaLock: layer(layerID)?.alphaLock ?? false,
                changed: region,
                serial: liveSerial
            )
        }
        var remote: [UUID: [LiveStroke]] = [:]
        for stroke in remoteStrokes.values {
            remote[stroke.layerID, default: []].append(LiveStroke(
                scratch: stroke.scratch,
                opacity: stroke.sampler.settings.strokeOpacity,
                isEraser: stroke.sampler.settings.isEraser,
                alphaLock: layer(stroke.layerID)?.alphaLock ?? false
            ))
        }
        compositor.encodeFrame(document: document, activeLayerID: activeLayerID, store: store,
                               stroke: live, remote: remote, viewport: viewport, into: target, command: command)
    }

    // MARK: Undo

    func performUndo() {
        cancelStroke()
        guard let entry = undo.popUndo() else { return }
        apply(entry, forward: false)
    }

    func performRedo() {
        cancelStroke()
        guard let entry = undo.popRedo() else { return }
        apply(entry, forward: true)
    }

    /// Also used by `GemeinsamVerlauf` to roll back one step.
    func apply(_ entry: UndoEntry, forward: Bool) {
        switch entry {
        case let .pixels(layerID, region, before, after):
            guard let target = store.texture(for: layerID), let command = queue.makeCommandBuffer() else { return }
            GPU.copy(forward ? after : before, to: target, at: region.origin, command: command)
            command.commit()
            dirtyLayers.insert(layerID)
        case let .document(before, after, removed):
            setDocument(forward ? after : before, removed: removed)
        }
        liveSerial += 1
        compositor.invalidateCaches()
        onChange?()
    }

    // MARK: Document changes

    /// Changes layer structure or properties. One call is one undo step.
    func updateDocument(undoable: Bool = true, removed: [UUID: MTLTexture] = [:], _ change: (inout ArtworkDocument) -> Void) {
        var next = document
        change(&next)
        guard next != document else { return }
        let before = document
        setDocument(next, removed: removed)
        if undoable { record(.document(before: before, after: next, removedTextures: removed)) }
        onChange?()
    }

    /// Records a document step that already happened in several silent updates (slider gestures).
    func recordDocumentStep(from before: ArtworkDocument) {
        guard before != document else { return }
        record(.document(before: before, after: document, removedTextures: [:]))
    }

    /// Own non-stroke action: one undo step, then `onAction`.
    private func record(_ entry: UndoEntry) {
        undo.push(entry)
        onAction?()
    }

    private func setDocument(_ next: ArtworkDocument, removed: [UUID: MTLTexture]) {
        let oldIDs = Set(document.layers.map(\.id))
        let newIDs = Set(next.layers.map(\.id))
        for id in oldIDs.subtracting(newIDs) {
            if let texture = store.texture(for: id) { detached[id] = texture }
            store.remove(id)
        }
        for id in newIDs.subtracting(oldIDs) {
            if let texture = removed[id] ?? detached[id] {
                store.set(texture, for: id)
                detached[id] = nil
            }
            dirtyLayers.insert(id)
        }
        document = next
        if !document.layers.contains(where: { $0.id == activeLayerID }) {
            activeLayerID = document.layers.last?.id ?? activeLayerID
        }
    }

    /// Creates a texture for a new layer. Returns false when the memory budget is reached.
    func prepareTexture(for layer: ArtworkLayer, copying source: UUID? = nil) -> Bool {
        guard let texture = try? store.makeEmpty(for: layer.id) else { return false }
        if let source, let original = store.texture(for: source), let command = queue.makeCommandBuffer() {
            if original.width == texture.width, original.height == texture.height {
                GPU.copy(original, to: texture, command: command)
            } else {
                store.set(original, for: layer.id)
            }
            command.commit()
        }
        return true
    }

    func setImage(_ pixels: RasterOps.Pixels, for layerID: UUID) throws {
        try store.setPixels(pixels, for: layerID)
    }

    func texture(for layerID: UUID) -> MTLTexture? {
        store.texture(for: layerID)
    }

    // MARK: Pixel edits

    /// Runs `edit` on a layer texture and records one pixel undo step for `region` (default: whole layer).
    func editPixels(of layerID: UUID, region: MTLRegion? = nil, _ edit: (MTLCommandBuffer, MTLTexture) -> Void) {
        guard let target = store.texture(for: layerID), let command = queue.makeCommandBuffer() else { return }
        let region = region ?? MTLRegionMake2D(0, 0, target.width, target.height)
        let before = snapshot(target, region: region, command: command)
        edit(command, target)
        let after = snapshot(target, region: region, command: command)
        command.commit()
        if let before, let after {
            record(.pixels(layerID: layerID, region: region, before: before, after: after))
        }
        didEditPixels(of: layerID)
    }

    func makeCommand() -> MTLCommandBuffer? {
        queue.makeCommandBuffer()
    }

    private func didEditPixels(of layerID: UUID) {
        liveSerial += 1
        dirtyLayers.insert(layerID)
        if layerID != activeLayerID { compositor.invalidateCaches() }
        onChange?()
    }

    /// A private copy of a layer as it is now (queued after every earlier GPU work).
    func kopie(of layerID: UUID) -> MTLTexture? {
        guard let texture = store.texture(for: layerID), let command = queue.makeCommandBuffer() else { return nil }
        let copy = snapshot(texture, region: MTLRegionMake2D(0, 0, texture.width, texture.height), command: command)
        command.commit()
        return copy
    }

    func kopie(_ texture: MTLTexture) -> MTLTexture? {
        guard let command = queue.makeCommandBuffer() else { return nil }
        let copy = snapshot(texture, region: MTLRegionMake2D(0, 0, texture.width, texture.height), command: command)
        command.commit()
        return copy
    }

    private func snapshot(_ texture: MTLTexture, region: MTLRegion, command: MTLCommandBuffer) -> MTLTexture? {
        guard let copy = GPU.makeTexture(device, width: region.size.width, height: region.size.height) else { return nil }
        GPU.copy(texture, region: region, to: copy, command: command)
        return copy
    }

    private func pixelRegion(_ rect: CGRect) -> MTLRegion? {
        let clipped = rect.intersection(CGRect(origin: .zero, size: canvasSize))
        guard !clipped.isNull, clipped.width >= 1, clipped.height >= 1 else { return nil }
        let x = Int(clipped.minX.rounded(.down))
        let y = Int(clipped.minY.rounded(.down))
        let maxX = min(Int(clipped.maxX.rounded(.up)), store.width)
        let maxY = min(Int(clipped.maxY.rounded(.up)), store.height)
        return MTLRegionMake2D(x, y, maxX - x, maxY - y)
    }

    // MARK: Reading pixels

    func flattenedPixels() async -> RasterOps.Pixels? {
        guard let command = queue.makeCommandBuffer() else { return nil }
        let flat = compositor.flatten(document: document, store: store, command: command)
        command.commit()
        let bytes = await GPU.readBytes(flat)
        return bytes.isEmpty ? nil : RasterOps.Pixels(bytes: bytes, width: flat.width, height: flat.height)
    }

    func sampleColor(at point: CGPoint) async -> RGBAColor? {
        guard point.x >= 0, point.y >= 0, point.x < canvasSize.width, point.y < canvasSize.height,
              let command = queue.makeCommandBuffer() else { return nil }
        let flat = compositor.flatten(document: document, store: store, command: command)
        command.commit()
        let bytes = await GPU.readBytes(flat, region: MTLRegionMake2D(Int(point.x), Int(point.y), 1, 1))
        guard bytes.count == 4 else { return nil }
        let alpha = Double(bytes[3]) / 255
        guard alpha > 0 else { return RGBAColor(red: 0, green: 0, blue: 0, alpha: 0) }
        return RGBAColor(
            red: min(Double(bytes[0]) / 255 / alpha, 1),
            green: min(Double(bytes[1]) / 255 / alpha, 1),
            blue: min(Double(bytes[2]) / 255 / alpha, 1),
            alpha: alpha
        )
    }

    /// The topmost visible layer with a pixel at `point`.
    func topLayer(at point: CGPoint) async -> UUID? {
        let x = Int(point.x)
        let y = Int(point.y)
        guard x >= 0, y >= 0, x < store.width, y < store.height else { return nil }
        for layer in document.layers.reversed() where layer.isVisible {
            guard var texture = store.texture(for: layer.id) else { continue }
            if layer.kind == .image {
                guard let temp = GPU.makeTexture(device, width: store.width, height: store.height),
                      let command = queue.makeCommandBuffer() else { continue }
                compositor.renderImage(layer, photo: texture, into: temp, command: command)
                command.commit()
                texture = temp
            }
            let bytes = await GPU.readBytes(texture, region: MTLRegionMake2D(x, y, 1, 1))
            if bytes.count == 4, bytes[3] > 8 { return layer.id }
        }
        return nil
    }

    func flattenedImage() async -> UIImage? {
        // ponytail: CGImage only wraps the bytes, so building it here costs a copy, not a render.
        guard let pixels = await flattenedPixels(), let image = RasterOps.cgImage(pixels) else { return nil }
        return UIImage(cgImage: image)
    }

    func thumbnail(maxDimension: CGFloat) async -> UIImage? {
        guard let pixels = await thumbnailPixels(maxDimension: maxDimension), let image = RasterOps.cgImage(pixels) else { return nil }
        return UIImage(cgImage: image)
    }

    /// Gallery preview: GPU downscale, JPEG encode in the background.
    func thumbnailJPEG(maxDimension: CGFloat) async -> Data? {
        guard let pixels = await thumbnailPixels(maxDimension: maxDimension) else { return nil }
        return await Task.detached(priority: .utility) { RasterOps.encode(pixels, type: .jpeg, quality: 0.8) }.value
    }

    func layerThumbnail(_ id: UUID, maxDimension: CGFloat = 64) async -> UIImage? {
        guard let pixels = await layerPixels(id, maxDimension: maxDimension), let image = RasterOps.cgImage(pixels) else { return nil }
        return UIImage(cgImage: image)
    }

    func layerHasContent(_ id: UUID) async -> Bool {
        guard let pixels = await layerPixels(id, maxDimension: 128) else { return false }
        return stride(from: 3, to: pixels.bytes.count, by: 4).contains { pixels.bytes[$0] > 0 }
    }

    private func thumbnailPixels(maxDimension: CGFloat) async -> RasterOps.Pixels? {
        guard let command = queue.makeCommandBuffer() else { return nil }
        let flat = compositor.flatten(document: document, store: store, command: command)
        return await scaled(flat, maxDimension: maxDimension, command: command)
    }

    private func layerPixels(_ id: UUID, maxDimension: CGFloat) async -> RasterOps.Pixels? {
        guard let layer = layer(id), let texture = store.texture(for: id), let command = queue.makeCommandBuffer() else { return nil }
        var source = texture
        if layer.kind == .image, let temp = GPU.makeTexture(device, width: store.width, height: store.height) {
            compositor.renderImage(layer, photo: texture, into: temp, command: command)
            source = temp
        }
        return await scaled(source, maxDimension: maxDimension, command: command)
    }

    /// GPU downscale (MPSImageBilinearScale), then one small readback.
    private func scaled(_ texture: MTLTexture, maxDimension: CGFloat, command: MTLCommandBuffer) async -> RasterOps.Pixels? {
        let factor = min(1, maxDimension / CGFloat(max(texture.width, texture.height)))
        let width = max(1, Int(CGFloat(texture.width) * factor))
        let height = max(1, Int(CGFloat(texture.height) * factor))
        guard let small = GPU.makeTexture(device, width: width, height: height, writable: true) else {
            command.commit()
            return nil
        }
        if MPSSupportsMTLDevice(device) {
            MPSImageBilinearScale(device: device).encode(commandBuffer: command, sourceTexture: texture, destinationTexture: small)
        } else {
            compositor.draw(texture, into: small, blend: .none, command: command)
        }
        command.commit()
        let bytes = await GPU.readBytes(small)
        return bytes.isEmpty ? nil : RasterOps.Pixels(bytes: bytes, width: width, height: height)
    }

    /// Full-size image of any artwork, e.g. for export from the gallery.
    static func renderImage(document: ArtworkDocument, library: ArtworkLibrary) async -> UIImage? {
        guard let engine = try? CanvasEngine(document: document, library: library) else { return nil }
        await engine.loading?.value
        return await engine.flattenedImage()
    }

    // MARK: Fill

    func fill(at point: CGPoint, color: RGBAColor, tolerance: Double, reference: FillReference, layerID: UUID) async {
        guard let layer = layer(layerID), layer.kind == .paint, !layer.isLocked,
              let target = store.texture(for: layerID) else { return }
        var source = target
        if reference == .allVisible, let command = queue.makeCommandBuffer() {
            source = compositor.flatten(document: document, store: store, command: command)
            command.commit()
        }
        let pixels = RasterOps.Pixels(bytes: await GPU.readBytes(source), width: source.width, height: source.height)
        let x = Int(point.x)
        let y = Int(point.y)
        let mask = await Task.detached(priority: .userInitiated) {
            RasterOps.floodFillMask(pixels, x: x, y: y, tolerance: tolerance)
        }.value
        guard !mask.isEmpty, let maskTexture = GPU.upload(mask, width: pixels.width, height: pixels.height, format: .r8Unorm) else { return }
        paintMask(maskTexture, color: color, layerID: layerID)
    }

    /// Paints `color` through an R8 mask into a layer, respecting selection and alpha lock.
    func paintMask(_ mask: MTLTexture, color: RGBAColor, layerID: UUID, ignoreSelection: Bool = false) {
        guard let layer = layer(layerID) else { return }
        editPixels(of: layerID) { command, target in
            ops.paintMask(mask, selection: ignoreSelection ? stamper.whiteMask : selection ?? stamper.whiteMask, color: color,
                          blend: layer.alphaLock ? .atop : .over, into: target, command: command)
        }
    }

    /// The same fill, finished before it returns and without the local selection, so a shared drawing
    /// can replay it in op order without another step slipping in between.
    /// ponytail: blocks the main thread for the readback and flood fill (tens of ms at 2048²);
    /// a background fill needs the shared history to queue own input meanwhile.
    func fillNow(at point: CGPoint, color: RGBAColor, tolerance: Double, allVisible: Bool, layerID: UUID) {
        guard let layer = layer(layerID), layer.kind == .paint, let target = store.texture(for: layerID),
              let command = queue.makeCommandBuffer() else { return }
        let source = allVisible ? compositor.flatten(document: document, store: store, command: command) : target
        guard let buffer = device.makeBuffer(length: source.width * source.height * 4, options: .storageModeShared),
              let blit = command.makeBlitCommandEncoder() else { return }
        blit.copy(
            from: source, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: source.width, height: source.height, depth: 1),
            to: buffer, destinationOffset: 0, destinationBytesPerRow: source.width * 4,
            destinationBytesPerImage: source.width * source.height * 4
        )
        blit.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        let count = source.width * source.height * 4
        let bytes = Array(UnsafeBufferPointer(start: buffer.contents().bindMemory(to: UInt8.self, capacity: count), count: count))
        let pixels = RasterOps.Pixels(bytes: bytes, width: source.width, height: source.height)
        let mask = RasterOps.floodFillMask(pixels, x: Int(point.x), y: Int(point.y), tolerance: tolerance)
        guard !mask.isEmpty, let maskTexture = GPU.upload(mask, width: pixels.width, height: pixels.height, format: .r8Unorm) else { return }
        paintMask(maskTexture, color: color, layerID: layerID, ignoreSelection: true)
    }


    // MARK: Memory

    func handleMemoryWarning() {
        undo.dropOldestHalf()
        detached.removeAll()
        spareScratches.removeAll()
        compositor.releaseCaches()
        onChange?()
    }
}

// MARK: Layer actions. Each one is exactly one undo step.

extension CanvasEngine {
    /// Adds a layer above `index` (default: top). Returns false when memory is full.
    @discardableResult
    func addLayer(_ layer: ArtworkLayer, at index: Int? = nil, copying source: UUID? = nil) -> Bool {
        guard layer.kind == .image || prepareTexture(for: layer, copying: source) else { return false }
        updateDocument { document in
            document.layers.insert(layer, at: min(index ?? document.layers.count, document.layers.count))
        }
        activeLayerID = layer.id
        return true
    }

    func deleteLayer(_ id: UUID) {
        guard document.layers.count > 1 else { return }
        updateDocument(removed: store.texture(for: id).map { [id: $0] } ?? [:]) { $0.layers.removeAll { $0.id == id } }
    }

    /// Merges the layer into the one below. The result is a new paint layer with the lower layer's
    /// name, position and properties; the upper layer's blend mode and opacity are baked in.
    func mergeDown(_ upperID: UUID) {
        guard let upperIndex = document.layers.firstIndex(where: { $0.id == upperID }), upperIndex > 0 else { return }
        let lower = document.layers[upperIndex - 1]
        let upper = document.layers[upperIndex]
        var base = lower
        base.opacity = 1
        base.blendMode = .normal
        base.isVisible = true
        base.clipping = false
        var top = upper
        top.isVisible = true
        var pair = document
        pair.background = .transparent
        pair.layers = [base, top]
        var merged = ArtworkLayer.paint(name: lower.name)
        merged.opacity = lower.opacity
        merged.blendMode = lower.blendMode
        merged.isVisible = lower.isVisible
        merged.clipping = lower.clipping
        merged.alphaLock = lower.alphaLock
        guard let lowerTexture = store.texture(for: lower.id), let upperTexture = store.texture(for: upper.id),
              let target = try? store.makeEmpty(for: merged.id), let command = makeCommand() else { return }
        let flat = compositor.flatten(document: pair, store: store, command: command)
        GPU.copy(flat, to: target, command: command)
        command.commit()
        compositor.invalidateCaches()
        updateDocument(removed: [lower.id: lowerTexture, upper.id: upperTexture]) { document in
            document.layers.remove(at: upperIndex)
            document.layers[upperIndex - 1] = merged
        }
        activeLayerID = merged.id
    }

    /// Turns an image layer into a paint layer with the same pixels.
    func rasterize(_ id: UUID) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }),
              document.layers[index].kind == .image, let photo = store.texture(for: id) else { return }
        let image = document.layers[index]
        var paint = ArtworkLayer.paint(name: image.name)
        paint.opacity = image.opacity
        paint.blendMode = image.blendMode
        paint.isVisible = image.isVisible
        paint.clipping = image.clipping
        guard let target = try? store.makeEmpty(for: paint.id), let command = makeCommand() else { return }
        compositor.renderImage(image, photo: photo, into: target, command: command)
        command.commit()
        updateDocument(removed: [id: photo]) { $0.layers[index] = paint }
        activeLayerID = paint.id
    }

    func clearLayer(_ id: UUID) {
        guard layer(id)?.kind == .paint else { return }
        editPixels(of: id) { command, target in
            if let selection {
                ops.paintMask(selection, selection: stamper.whiteMask, color: RGBAColor(red: 0, green: 0, blue: 0), blend: .erase, into: target, command: command)
            } else {
                GPU.fill(target, command: command)
            }
        }
    }

    func flipLayer(_ id: UUID, horizontal: Bool) {
        guard let layer = layer(id) else { return }
        if layer.kind == .image {
            updateDocument { document in
                guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
                if horizontal { document.layers[index].transform.flipX.toggle() } else { document.layers[index].transform.flipY.toggle() }
            }
            return
        }
        guard let copy = GPU.makeTexture(device, width: store.width, height: store.height) else { return }
        editPixels(of: id) { command, target in
            GPU.copy(target, to: copy, command: command)
            let corners: [SIMD2<Float>] = horizontal
                ? [[1, 1], [-1, 1], [1, -1], [-1, -1]]
                : [[-1, -1], [1, -1], [-1, 1], [1, 1]]
            compositor.draw(copy, into: target, blend: .none, corners: corners, clearFirst: true, command: command)
        }
    }
}
