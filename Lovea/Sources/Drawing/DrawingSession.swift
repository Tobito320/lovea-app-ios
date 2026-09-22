import Combine
import UIKit

@MainActor
final class DrawingSession: ObservableObject {
    private struct MetalHistoryEntry {
        let layerID: UUID
        let before: [MetalPaintStroke]
        let after: [MetalPaintStroke]
    }

    @Published var document: ArtworkDocument
    @Published var activeLayerID: UUID
    @Published var tool: StudioTool = .brush
    @Published var brush: BrushPreset = .pen {
        didSet {
            brushWidth = Double(brush.defaultWidth)
            brushOpacity = Double(brush.defaultOpacity)
            rememberBrush(brush)
        }
    }
    @Published var brushWidth = 7.0
    @Published var brushOpacity = 1.0
    @Published var color: RGBAColor = .studioBlack
    @Published var drawsWithFinger = false
    @Published var rulerActive = false
    @Published var stabilizer = 5.0
    @Published var fillTolerance = 0.12
    @Published private(set) var recentColors: [RGBAColor] = [.studioBlack, .blue, .red, .orange]
    @Published private(set) var recentBrushes: [BrushPreset] = [.pen, .pencil, .marker]
    @Published private(set) var activeMetalStroke: MetalPaintStroke?
    @Published private(set) var metalStrokesByLayer: [UUID: [MetalPaintStroke]] = [:]

    let library: ArtworkLibrary
    private var metalUndoStack: [MetalHistoryEntry] = []
    private var metalRedoStack: [MetalHistoryEntry] = []
    private var previewTask: Task<Void, Never>?

    init(artworkID: UUID, library: ArtworkLibrary) {
        self.library = library
        let loadedDocument = library.document(artworkID) ?? ArtworkDocument.new(
            name: "Neue Zeichnung",
            projectID: nil,
            format: .square,
            width: 2048,
            height: 2048,
            background: .white
        )
        self.document = loadedDocument
        self.activeLayerID = loadedDocument.layers.last(where: { $0.kind == .paint })?.id
            ?? loadedDocument.layers.last?.id
            ?? UUID()
        loadMetalStrokes()
    }

    var activeLayer: ArtworkLayer? {
        document.layers.first(where: { $0.id == activeLayerID })
    }

    var canDraw: Bool {
        guard let layer = activeLayer else { return false }
        return layer.kind == .paint && !layer.isLocked
    }

    var canvasSize: CGSize {
        CGSize(width: CGFloat(document.canvasWidth), height: CGFloat(document.canvasHeight))
    }

    var canUndo: Bool { !metalUndoStack.isEmpty }
    var canRedo: Bool { !metalRedoStack.isEmpty }

    func metalStrokes(for layerID: UUID) -> [MetalPaintStroke] {
        metalStrokesByLayer[layerID] ?? []
    }

    func beginMetalStroke(at point: StrokePoint) {
        guard canDraw, tool == .brush || tool == .eraser else { return }
        activeMetalStroke = MetalPaintStroke(
            points: [point],
            color: color,
            width: min(max(brushWidth, 1), 180),
            opacity: min(max(brushOpacity, 0.05), 1),
            tool: tool == .eraser ? .eraser : .brush,
            brushPreset: brush.rawValue
        )
    }

    func appendMetalStrokePoint(_ point: StrokePoint) {
        activeMetalStroke?.points.append(point)
    }

    func endMetalStroke() {
        guard let stroke = activeMetalStroke, let layer = activeLayer, canDraw else {
            activeMetalStroke = nil
            return
        }
        activeMetalStroke = nil
        let before = metalStrokes(for: layer.id)
        let after = before + [stroke]
        metalUndoStack.append(MetalHistoryEntry(layerID: layer.id, before: before, after: after))
        if metalUndoStack.count > 50 { metalUndoStack.removeFirst() }
        metalRedoStack.removeAll()
        saveMetalStrokes(after, for: layer)
    }

    func cancelMetalStroke() {
        activeMetalStroke = nil
    }

    func undo() {
        guard let entry = metalUndoStack.popLast(),
              let layer = document.layers.first(where: { $0.id == entry.layerID }) else { return }
        activeMetalStroke = nil
        metalRedoStack.append(entry)
        saveMetalStrokes(entry.before, for: layer)
    }

    func redo() {
        guard let entry = metalRedoStack.popLast(),
              let layer = document.layers.first(where: { $0.id == entry.layerID }) else { return }
        activeMetalStroke = nil
        metalUndoStack.append(entry)
        saveMetalStrokes(entry.after, for: layer)
    }

    func selectLayer(_ id: UUID) {
        guard document.layers.contains(where: { $0.id == id }) else { return }
        activeMetalStroke = nil
        activeLayerID = id
        if activeLayer?.kind == .image {
            tool = .brush
        }
    }

    func addPaintLayer(name: String? = nil) {
        let number = document.layers.filter { $0.kind == .paint }.count + 1
        let layer = ArtworkLayer.paint(name: name ?? "Ebene \(number)")
        document.layers.append(layer)
        metalStrokesByLayer[layer.id] = []
        library.saveMetalStrokes([], for: layer, artworkID: document.id)
        activeLayerID = layer.id
        touchDocument()
    }

    func addImageLayer(data: Data, name: String = "Bild", asTemplate: Bool = false) {
        guard let image = UIImage(data: data), let png = image.pngData() else { return }
        var layer = ArtworkLayer.image(name: asTemplate ? "Schablone" : name)
        if asTemplate {
            layer.opacity = 0.35
            layer.isLocked = true
            document.layers.insert(layer, at: 0)
        } else {
            document.layers.append(layer)
        }
        library.saveLayerData(png, layer: layer, artworkID: document.id)

        if asTemplate {
            let paint = ArtworkLayer.paint(name: "Zeichnen")
            document.layers.append(paint)
            metalStrokesByLayer[paint.id] = []
            library.saveMetalStrokes([], for: paint, artworkID: document.id)
            activeLayerID = paint.id
        } else {
            activeLayerID = layer.id
        }
        touchDocument()
    }

    func addGeneratedLayer(_ image: UIImage, name: String, select: Bool = true) {
        guard let data = image.pngData() else { return }
        let layer = ArtworkLayer.image(name: name)
        let insertionIndex: Int
        if let currentIndex = document.layers.firstIndex(where: { $0.id == activeLayerID }) {
            insertionIndex = min(currentIndex + 1, document.layers.count)
        } else {
            insertionIndex = document.layers.count
        }
        document.layers.insert(layer, at: insertionIndex)
        library.saveLayerData(data, layer: layer, artworkID: document.id)
        if select { activeLayerID = layer.id }
        touchDocument()
    }

    func handleCanvasTap(_ point: CGPoint) {
        switch tool {
        case .eyedropper:
            let composed = exportImage()
            if let sampled = RasterTools.sampleColor(in: composed, at: point) {
                setColor(sampled)
            }
        case .fill:
            let composed = exportImage()
            if let fill = RasterTools.floodFillLayer(
                source: composed,
                start: point,
                color: color,
                tolerance: fillTolerance
            ) {
                let previous = activeLayerID
                addGeneratedLayer(fill, name: "Füllung", select: false)
                activeLayerID = previous
            }
        default:
            break
        }
    }

    func addShape(_ kind: ShapeKind, filled: Bool) {
        let image = RasterTools.shapeLayer(
            canvasSize: canvasSize,
            kind: kind,
            color: color,
            lineWidth: CGFloat(max(brushWidth, 1)),
            filled: filled
        )
        addGeneratedLayer(image, name: kind.title)
    }

    func addText(_ text: String, fontSize: CGFloat, fontIndex: Int) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let names = ["HelveticaNeue", "AvenirNext-Regular", "Georgia", "CourierNewPSMT"]
        let index = min(max(fontIndex, 0), names.count - 1)
        let font = UIFont(name: names[index], size: fontSize) ?? .systemFont(ofSize: fontSize)
        let image = RasterTools.textLayer(
            canvasSize: canvasSize,
            text: clean,
            color: color,
            fontSize: fontSize,
            font: font
        )
        addGeneratedLayer(image, name: "Text")
    }

    func deleteLayer(_ id: UUID) {
        guard document.layers.count > 1,
              let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        let layer = document.layers[index]
        library.removeLayerAsset(fileName: layer.contentFile, artworkID: document.id)
        if layer.kind == .paint {
            library.removeLayerAsset(fileName: library.metalStrokesFile(for: layer), artworkID: document.id)
        }
        if let maskFile = layer.alphaMaskFile {
            library.removeLayerAsset(fileName: maskFile, artworkID: document.id)
        }
        document.layers.remove(at: index)
        metalStrokesByLayer[id] = nil
        metalUndoStack.removeAll { $0.layerID == id }
        metalRedoStack.removeAll { $0.layerID == id }
        if activeLayerID == id {
            activeLayerID = document.layers[min(index, document.layers.count - 1)].id
        }
        touchDocument()
    }

    func duplicateLayer(_ id: UUID) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        let original = document.layers[index]
        var copy = original.kind == .paint
            ? ArtworkLayer.paint(name: "\(original.name) Kopie")
            : ArtworkLayer.image(name: "\(original.name) Kopie")
        copy.isVisible = original.isVisible
        copy.isLocked = original.isLocked
        copy.opacity = original.opacity
        copy.blendMode = original.blendMode
        copy.clipping = original.clipping
        copy.alphaLock = original.alphaLock
        copy.transform = original.transform

        if let data = library.layerData(original, artworkID: document.id) {
            library.saveLayerData(data, layer: copy, artworkID: document.id)
        }
        if original.kind == .paint {
            let strokes = metalStrokes(for: original.id)
            metalStrokesByLayer[copy.id] = strokes
            library.saveMetalStrokes(strokes, for: copy, artworkID: document.id)
        }
        if original.alphaLock,
           let originalMask = original.alphaMaskFile,
           let maskData = library.layerAsset(fileName: originalMask, artworkID: document.id) {
            let copyMask = "alpha-\(copy.id.uuidString).png"
            copy.alphaMaskFile = copyMask
            library.saveLayerAsset(maskData, fileName: copyMask, artworkID: document.id)
        }
        document.layers.insert(copy, at: index + 1)
        activeLayerID = copy.id
        touchDocument()
    }

    func moveLayer(_ id: UUID, by offset: Int) {
        guard let oldIndex = document.layers.firstIndex(where: { $0.id == id }) else { return }
        let newIndex = min(max(oldIndex + offset, 0), document.layers.count - 1)
        guard newIndex != oldIndex else { return }
        let layer = document.layers.remove(at: oldIndex)
        document.layers.insert(layer, at: newIndex)
        touchDocument()
    }

    func renameLayer(_ id: UUID, to name: String) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        document.layers[index].name = String(clean.prefix(50))
        touchDocument()
    }

    func toggleVisibility(_ id: UUID) {
        updateLayer(id) { $0.isVisible.toggle() }
    }

    func toggleLock(_ id: UUID) {
        updateLayer(id) { $0.isLocked.toggle() }
    }

    func setOpacity(_ value: Double, for id: UUID) {
        updateLayer(id) { $0.opacity = min(max(value, 0), 1) }
    }

    func setBlendMode(_ mode: LayerBlendMode, for id: UUID) {
        updateLayer(id) { $0.blendMode = mode }
    }

    func toggleClipping(_ id: UUID) {
        updateLayer(id) { $0.clipping.toggle() }
    }

    func toggleAlphaLock(_ id: UUID) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }),
              document.layers[index].kind == .paint else { return }

        if document.layers[index].alphaLock {
            if let maskFile = document.layers[index].alphaMaskFile {
                library.removeLayerAsset(fileName: maskFile, artworkID: document.id)
            }
            document.layers[index].alphaLock = false
            document.layers[index].alphaMaskFile = nil
            touchDocument()
            return
        }

        var sourceLayer = document.layers[index]
        sourceLayer.alphaLock = false
        sourceLayer.alphaMaskFile = nil
        guard let image = ArtworkRenderer.layerImage(sourceLayer, document: document, library: library),
              let data = image.pngData() else { return }
        let maskFile = "alpha-\(id.uuidString).png"
        library.saveLayerAsset(data, fileName: maskFile, artworkID: document.id)
        document.layers[index].alphaMaskFile = maskFile
        document.layers[index].alphaLock = true
        touchDocument()
    }

    func updateTransform(_ transform: LayerTransform, for id: UUID) {
        updateLayer(id) { $0.transform = transform }
    }

    func flipActive(horizontal: Bool) {
        guard let id = activeLayer?.id else { return }
        updateLayer(id) {
            if horizontal { $0.transform.flipX.toggle() }
            else { $0.transform.flipY.toggle() }
        }
    }

    func mergeActiveDown() {
        guard let upperIndex = document.layers.firstIndex(where: { $0.id == activeLayerID }), upperIndex > 0 else { return }
        let lowerIndex = upperIndex - 1
        let lower = document.layers[lowerIndex]
        let upper = document.layers[upperIndex]
        var temp = document
        temp.background = .transparent
        temp.layers = [lower, upper]
        let image = ArtworkRenderer.render(document: temp, library: library)
        guard let data = image.pngData() else { return }
        var merged = ArtworkLayer.image(name: "\(lower.name) + \(upper.name)")
        merged.opacity = 1
        library.saveLayerData(data, layer: merged, artworkID: document.id)
        document.layers.remove(at: upperIndex)
        document.layers[lowerIndex] = merged
        metalStrokesByLayer[upper.id] = nil
        metalStrokesByLayer[lower.id] = nil
        for layer in [lower, upper] where layer.kind == .paint {
            library.removeLayerAsset(fileName: library.metalStrokesFile(for: layer), artworkID: document.id)
        }
        metalUndoStack.removeAll { $0.layerID == lower.id || $0.layerID == upper.id }
        metalRedoStack.removeAll { $0.layerID == lower.id || $0.layerID == upper.id }
        activeLayerID = merged.id
        touchDocument()
    }

    func setColor(_ newColor: RGBAColor) {
        color = newColor
        recentColors.removeAll { $0 == newColor }
        recentColors.insert(newColor, at: 0)
        recentColors = Array(recentColors.prefix(8))
        tool = .brush
    }

    func exportImage() -> UIImage {
        ArtworkRenderer.render(document: document, library: library)
    }

    func saveNow() {
        previewTask?.cancel()
        library.saveDocument(document)
        let preview = ArtworkRenderer.thumbnail(document: document, library: library)
        library.savePreview(preview, artworkID: document.id)
    }

    private func updateLayer(_ id: UUID, change: (inout ArtworkLayer) -> Void) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        change(&document.layers[index])
        touchDocument()
    }

    private func loadMetalStrokes() {
        for layer in document.layers where layer.kind == .paint {
            metalStrokesByLayer[layer.id] = library.metalStrokes(for: layer, artworkID: document.id)
        }
    }

    private func saveMetalStrokes(_ strokes: [MetalPaintStroke], for layer: ArtworkLayer) {
        metalStrokesByLayer[layer.id] = strokes
        library.saveMetalStrokes(strokes, for: layer, artworkID: document.id)
        touchDocument()
    }

    private func touchDocument() {
        document.updatedAt = Date()
        library.saveDocument(document)
        schedulePreview()
    }

    private func schedulePreview() {
        previewTask?.cancel()
        previewTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled, let self else { return }
            let preview = ArtworkRenderer.thumbnail(document: self.document, library: self.library)
            self.library.savePreview(preview, artworkID: self.document.id)
        }
    }

    private func rememberBrush(_ brush: BrushPreset) {
        recentBrushes.removeAll { $0 == brush }
        recentBrushes.insert(brush, at: 0)
        recentBrushes = Array(recentBrushes.prefix(3))
    }
}
