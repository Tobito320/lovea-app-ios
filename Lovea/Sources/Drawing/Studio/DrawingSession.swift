import Combine
import UIKit

/// UI model of the studio: tool, brush, colors, active layer. All pixel work goes to `CanvasEngine`.
@MainActor
final class DrawingSession: ObservableObject {
    @Published private(set) var document: ArtworkDocument
    @Published var activeLayerID: UUID {
        didSet { engine?.activeLayerID = activeLayerID }
    }
    @Published var tool: StudioTool = .brush {
        didSet { if oldValue != tool { previousTool = oldValue } }
    }
    @Published var brush: BrushPreset = .pen {
        didSet {
            brushSize = brush.defaultWidth
            brushOpacity = brush.defaultOpacity
            pressureControlsSize = brush.pressureControlsSize
            pressureControlsOpacity = brush.pressureControlsOpacity
            recentBrushes = Array(([brush] + recentBrushes.filter { $0 != brush }).prefix(3))
        }
    }
    @Published var brushSize = BrushPreset.pen.defaultWidth
    @Published var brushOpacity = 1.0
    @Published var color: RGBAColor = .studioBlack
    @Published var drawsWithFinger = false
    @Published var pressureControlsSize = true
    @Published var pressureControlsOpacity = false
    @Published var stabilizer = 3.0
    @Published var fillTolerance = UserDefaults.standard.object(forKey: "fill.tolerance") as? Double ?? 0.12 {
        didSet { UserDefaults.standard.set(fillTolerance, forKey: "fill.tolerance") }
    }
    @Published var fillReference = FillReference(rawValue: UserDefaults.standard.string(forKey: "fill.reference") ?? "") ?? .allVisible {
        didSet { UserDefaults.standard.set(fillReference.rawValue, forKey: "fill.reference") }
    }
    @Published var shapeKind: ShapeKind = .line
    @Published var shapeFilled = false
    @Published var lassoRectangle = false
    @Published var symmetry = false {
        didSet { engine?.mirrorX = symmetry ? Float(canvasSize.width / 2) : nil }
    }
    @Published var showsColorPanel = false
    @Published private(set) var recentBrushes: [BrushPreset] = [.pen, .pencil, .marker]
    @Published private(set) var notice: String?
    @Published private(set) var noticeOffersRasterize = false
    @Published private(set) var isBusy = false
    @Published private(set) var hasSelection = false
    @Published private(set) var selectionOutline: [CGPoint] = []
    @Published private(set) var isTransforming = false
    @Published private(set) var layerThumbnails: [UUID: UIImage] = [:]
    @Published private(set) var memoryFull = false

    let engine: CanvasEngine?
    let library: ArtworkLibrary
    let canvasState = CanvasViewState()
    /// Partner drawing from the shared library: never saved here, the owner's stands are the truth.
    let fremd: Bool
    let live: ZeichnungLive
    /// Called with the color the person just used, so the palette can remember it.
    var onColorUsed: ((RGBAColor) -> Void)?
    private var previousTool: StudioTool = .brush
    private var saveTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var thumbnailTasks: [UUID: Task<Void, Never>] = [:]
    private var opacityGestureStart: ArtworkDocument?

    init(artworkID: UUID, library: ArtworkLibrary, fremd: Bool = false) {
        self.library = library
        self.fremd = fremd
        let loaded = library.document(artworkID) ?? .new(
            name: "Neue Zeichnung", projectID: nil, format: .square, width: 2048, height: 2048, background: .white
        )
        document = loaded
        live = ZeichnungLive(zeichnungId: loaded.id.uuidString, fremd: fremd)
        engine = try? CanvasEngine(document: loaded, library: library)
        activeLayerID = engine?.activeLayerID ?? loaded.layers.last?.id ?? UUID()
        engine?.onChange = { [weak self] in self?.engineChanged() }
        engine?.onAction = { [weak self] in self?.live.aktionGeschehen() }
        live.session = self
    }

    var activeLayer: ArtworkLayer? {
        document.layers.first(where: { $0.id == activeLayerID })
    }

    var canvasSize: CGSize {
        CGSize(width: document.canvasWidth, height: document.canvasHeight)
    }

    /// Partner drawing without the right to edit (live, so revoking takes effect at once).
    var nurAnsehen: Bool { live.nurAnsehen }

    var canUndo: Bool { live.verlauf.map(\.kannRueckgaengig) ?? engine?.undo.canUndo ?? false }
    var canRedo: Bool { live.verlauf.map(\.kannWiederholen) ?? engine?.undo.canRedo ?? false }

    var brushSettings: BrushSettings {
        BrushSettings(
            preset: brush,
            size: min(max(brushSize, 1), 300),
            opacity: min(max(brushOpacity, 0.01), 1),
            // Shared drawing: the color as the op carries it (8 bit), so replays match the own pixels exactly.
            color: live.verlauf == nil ? color : RGBAColor(hex8: color.hex8) ?? color,
            pressureSize: pressureControlsSize,
            pressureOpacity: pressureControlsOpacity,
            stabilizer: Int(stabilizer.rounded()),
            isEraser: tool == .eraser
        )
    }

    func requestRedraw() {
        canvasState.canvas?.setNeedsDisplay()
    }

    private func engineChanged() {
        guard let engine else { return }
        if document != engine.document { document = engine.document }
        if activeLayerID != engine.activeLayerID { activeLayerID = engine.activeLayerID }
        hasSelection = engine.selection != nil
        isTransforming = engine.transformState != nil
        objectWillChange.send()
        requestRedraw()
        scheduleSave()
        scheduleLayerThumbnails()
    }

    // MARK: Saving

    private func scheduleSave() {
        guard !fremd else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self else { return }
            self.basisSetzen()
            await self.engine?.saveDirtyLayers()
            self.live.gespeichert()
            self.schedulePreview()
        }
    }

    /// Shared drawing: the saved file says which ops it contains, so nothing is applied twice later.
    private func basisSetzen() {
        guard let verlauf = live.verlauf else { return }
        engine?.setzeBasis(verlauf.basis, offen: verlauf.offeneIDs)
    }

    private func schedulePreview() {
        previewTask?.cancel()
        previewTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            await self.writePreview()
        }
    }

    private func writePreview() async {
        guard let data = await engine?.thumbnailJPEG(maxDimension: 720) else { return }
        library.savePreview(jpeg: data, artworkID: document.id)
    }

    /// Saves right away: leaving the studio or going to the background.
    func saveNow() {
        guard !fremd else { return }
        saveTask?.cancel()
        previewTask?.cancel()
        basisSetzen()
        Task {
            await engine?.saveDirtyLayers()
            await writePreview()
            live.gespeichert()
        }
    }

    private func scheduleLayerThumbnails() {
        guard let engine else { return }
        for id in engine.dirtyLayers.union(Set(document.layers.map(\.id)).subtracting(layerThumbnails.keys)) {
            thumbnailTasks[id]?.cancel()
            thumbnailTasks[id] = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, let self, let image = await self.engine?.layerThumbnail(id) else { return }
                self.layerThumbnails[id] = image
            }
        }
    }

    // MARK: Drawing

    /// True if the active layer takes paint. Otherwise shows a short notice.
    func ensureDrawable() -> Bool {
        guard let layer = activeLayer else { return false }
        if layer.kind == .image {
            show("Bildebene – zum Bemalen rastern", rasterize: true)
            return false
        }
        if layer.isLocked {
            show("Ebene gesperrt")
            return false
        }
        return !fuerMichGesperrt(layer.id)
    }

    /// Z-13.3: the partner locked this layer for me. Shows a notice.
    func fuerMichGesperrt(_ id: UUID) -> Bool {
        guard let sperre = document.layers.first(where: { $0.id == id })?.gesperrtVon,
              sperre != Raum.shared.ich?.rawValue else { return false }
        show("\(Person(rawValue: sperre)?.name ?? "Dein Schatz") hat die Ebene gesperrt")
        return true
    }

    /// Z-13.3: lock or unlock a layer for the partner. Only the one who locked it can unlock it.
    func sperreFuerPartner(_ id: UUID) {
        guard let ich = Raum.shared.ich?.rawValue else { return }
        updateLayer(id) { $0.gesperrtVon = $0.gesperrtVon == nil ? ich : nil }
    }

    func show(_ text: String, rasterize: Bool = false) {
        notice = text
        noticeOffersRasterize = rasterize
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    func setColor(_ newColor: RGBAColor) {
        color = newColor
        if tool == .eyedropper || tool == .eraser { tool = .brush }
    }

    /// Remembers the color in "Zuletzt" once it actually lands on the canvas.
    func markColorUsed() {
        if tool != .eraser { onColorUsed?(color) }
    }

    func toggleEraser() {
        tool = tool == .eraser ? .brush : .eraser
    }

    func switchToPreviousTool() {
        tool = previousTool
    }

    /// `final: false` is a live preview while the eyedropper drags: it updates the color only,
    /// never the tool (that would jump back to the brush mid-drag).
    func tap(at point: CGPoint, final: Bool = true) {
        guard let engine else { return }
        switch tool {
        case .eyedropper:
            Task {
                if let sampled = await engine.sampleColor(at: point), sampled.alpha > 0 {
                    let picked = RGBAColor(red: sampled.red, green: sampled.green, blue: sampled.blue)
                    if final { setColor(picked); Haptik.auswahl() } else { color = picked }
                } else if final, let paper = document.background.paperColor {
                    // Empty paper: pick the paper color when it is solid; transparent paper stays ignored.
                    setColor(paper)
                    Haptik.auswahl()
                }
            }
        case .fill:
            guard ensureDrawable() else { return }
            markColorUsed()
            // Shared drawing without selection: the replayable fill (a selection-clipped one travels as pixels).
            if live.verlauf != nil, !hasSelection {
                live.fuellen(.fuellen(
                    x: Double(point.x), y: Double(point.y), farbe: color.hex8, toleranz: fillTolerance,
                    alleEbenen: fillReference == .allVisible, ebene: activeLayerID.uuidString
                ))
                return
            }
            isBusy = true
            Task {
                await engine.fill(at: point, color: color, tolerance: fillTolerance, reference: fillReference, layerID: activeLayerID)
                isBusy = false
            }
        default:
            break
        }
    }

    func select(polygon: [CGPoint]) {
        guard polygon.count >= 3, let engine else { return }
        selectionOutline = polygon
        Task { await engine.select(polygon: polygon) }
    }

    func drawShape(_ points: [CGPoint]) {
        guard let engine, ensureDrawable() else { return }
        let filled = shapeFilled && shapeKind != .line
        Task {
            await engine.drawShape(points, filled: filled, settings: brushSettings, layerID: activeLayerID)
            // An outline lands like a stroke, without `onAction`.
            if !(filled && points.count >= 3) { live.aktionGeschehen() }
        }
    }

    func selectTopLayer(at point: CGPoint) {
        Task {
            if let id = await engine?.topLayer(at: point) {
                activeLayerID = id
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
    }

    func undo(fromGesture: Bool = false) {
        guard canUndo, !nurAnsehen else { return }
        if live.verlauf != nil {
            engine?.cancelStroke()
            live.rueckgaengig(wieder: false)
        } else {
            engine?.performUndo()
        }
        if fromGesture { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    func redo(fromGesture: Bool = false) {
        guard canRedo, !nurAnsehen else { return }
        if live.verlauf != nil {
            engine?.cancelStroke()
            live.rueckgaengig(wieder: true)
        } else {
            engine?.performRedo()
        }
        if fromGesture { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    // MARK: Selection

    func clearSelection() {
        engine?.clearSelection()
        selectionOutline = []
    }

    func invertSelection() {
        engine?.invertSelection()
        selectionOutline = []
    }

    func deleteSelection() {
        guard ensureDrawable() else { return }
        engine?.deleteSelection(in: activeLayerID)
    }

    func copySelection(cut: Bool) {
        guard activeLayer?.kind == .paint, !cut || !fuerMichGesperrt(activeLayerID) else { return }
        engine?.copySelectionToNewLayer(from: activeLayerID, cut: cut)
    }

    // MARK: Transform

    func beginTransform() {
        guard let layer = activeLayer else { return }
        if layer.isLocked {
            show("Ebene gesperrt")
            return
        }
        guard !fuerMichGesperrt(layer.id) else { return }
        engine?.beginTransform()
    }

    func updateTransform(_ transform: LayerTransform) {
        engine?.updateTransform(transform)
    }

    func commitTransform() {
        engine?.commitTransform()
        selectionOutline = []
        importedLayerPending = nil
        tool = .brush
    }

    func cancelTransform() {
        engine?.cancelTransform()
        if let imported = importedLayerPending {
            importedLayerPending = nil
            engine?.deleteLayer(imported)
        }
        tool = .brush
    }

    func insertText(_ text: String, font: TextFont, size: Double) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let color = color
        Task {
            let pixels = await Task.detached(priority: .userInitiated) {
                Selection.textPixels(clean, font: font, size: CGFloat(size), color: color)
            }.value
            guard let pixels else { return }
            engine?.beginText(pixels)
        }
    }

    // MARK: Photos

    /// Layer created by an import that is still in its first transform. Cancelling removes it.
    @Published private(set) var importedLayerPending: UUID?

    func importPhoto(_ data: Data, asTemplate: Bool) async {
        guard let engine else { return }
        let limit = Int(max(canvasSize.width, canvasSize.height) * 2)
        let decoded = await Task.detached(priority: .userInitiated) { () -> (RasterOps.Pixels, Data)? in
            guard let pixels = RasterOps.decode(data, maxPixelSize: limit), let png = RasterOps.encode(pixels) else { return nil }
            return (pixels, png)
        }.value
        guard let decoded else {
            show("Foto konnte nicht geladen werden")
            return
        }
        let (pixels, png) = decoded
        var image = ArtworkLayer.image(name: asTemplate ? "Schablone" : "Foto")
        do {
            try engine.setImage(pixels, for: image.id)
        } catch {
            memoryFull = true
            return
        }
        library.saveLayerData(png, layer: image, artworkID: document.id)
        if asTemplate {
            image.opacity = 0.35
            image.isLocked = true
            let paint = ArtworkLayer.paint(name: "Zeichnen")
            guard engine.prepareTexture(for: paint) else {
                memoryFull = true
                return
            }
            engine.updateDocument { document in
                document.layers.insert(image, at: 0)
                document.layers.append(paint)
            }
            activeLayerID = paint.id
        } else {
            engine.addLayer(image)
            activeLayerID = image.id
            importedLayerPending = image.id
            tool = .transform
            engine.beginTransform()
        }
    }

    // MARK: Layers

    func selectLayer(_ id: UUID) {
        guard document.layers.contains(where: { $0.id == id }) else { return }
        engine?.cancelStroke()
        activeLayerID = id
    }

    func addPaintLayer() {
        let number = document.layers.filter { $0.kind == .paint }.count + 1
        let index = (document.layers.firstIndex(where: { $0.id == activeLayerID }) ?? document.layers.count - 1) + 1
        if engine?.addLayer(.paint(name: "Ebene \(number)"), at: index) == false { memoryFull = true }
    }

    func duplicateLayer(_ id: UUID) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        let original = document.layers[index]
        var copy = original.kind == .paint ? ArtworkLayer.paint(name: "\(original.name) Kopie") : ArtworkLayer.image(name: "\(original.name) Kopie")
        copy.isVisible = original.isVisible
        copy.isLocked = original.isLocked
        copy.opacity = original.opacity
        copy.blendMode = original.blendMode
        copy.clipping = original.clipping
        copy.alphaLock = original.alphaLock
        copy.transform = original.transform
        if original.kind == .image, let data = library.layerData(original, artworkID: document.id) {
            library.saveLayerData(data, layer: copy, artworkID: document.id)
        }
        if engine?.addLayer(copy, at: index + 1, copying: id) == false { memoryFull = true }
    }

    func deleteLayer(_ id: UUID) {
        guard !fuerMichGesperrt(id) else { return }
        engine?.deleteLayer(id)
    }

    func layerHasContent(_ id: UUID) async -> Bool {
        await engine?.layerHasContent(id) ?? false
    }

    /// `from` and `to` are indices in the list as shown (topmost first), like `onMove`.
    func moveLayer(from source: IndexSet, to destination: Int) {
        engine?.updateDocument { document in
            var shown = Array(document.layers.reversed())
            shown.move(fromOffsets: source, toOffset: destination)
            document.layers = shown.reversed()
        }
    }

    func renameLayer(_ id: UUID, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        updateLayer(id) { $0.name = String(clean.prefix(50)) }
    }

    func toggleVisibility(_ id: UUID) { updateLayer(id) { $0.isVisible.toggle() } }
    func toggleLock(_ id: UUID) { updateLayer(id) { $0.isLocked.toggle() } }
    func setBlendMode(_ mode: LayerBlendMode, for id: UUID) { updateLayer(id) { $0.blendMode = mode } }
    func toggleClipping(_ id: UUID) { updateLayer(id) { $0.clipping.toggle() } }

    func toggleAlphaLock(_ id: UUID) {
        guard document.layers.first(where: { $0.id == id })?.kind == .paint else { return }
        updateLayer(id) {
            $0.alphaLock.toggle()
            $0.alphaMaskFile = nil
        }
    }

    /// Slider: live while dragging, one undo step per gesture.
    func setOpacityLive(_ value: Double, for id: UUID) {
        guard !fuerMichGesperrt(id) else { return }
        if opacityGestureStart == nil { opacityGestureStart = document }
        engine?.updateDocument(undoable: false) { document in
            guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
            document.layers[index].opacity = min(max(value, 0), 1)
        }
    }

    func endOpacityGesture() {
        if let start = opacityGestureStart { engine?.recordDocumentStep(from: start) }
        opacityGestureStart = nil
    }

    func setOpacity(_ value: Double, for id: UUID) {
        updateLayer(id) { $0.opacity = min(max(value, 0), 1) }
    }

    func mergeDown(_ id: UUID) {
        guard !fuerMichGesperrt(id), let index = document.layers.firstIndex(where: { $0.id == id }), index > 0,
              !fuerMichGesperrt(document.layers[index - 1].id) else { return }
        engine?.mergeDown(id)
    }

    func rasterize(_ id: UUID) {
        guard !fuerMichGesperrt(id) else { return }
        engine?.rasterize(id)
    }

    func clearLayer(_ id: UUID) {
        guard !fuerMichGesperrt(id) else { return }
        engine?.clearLayer(id)
    }

    func flipLayer(_ id: UUID, horizontal: Bool) {
        guard !fuerMichGesperrt(id) else { return }
        engine?.flipLayer(id, horizontal: horizontal)
    }

    func dismissMemoryNotice() { memoryFull = false }

    private func updateLayer(_ id: UUID, change: @escaping (inout ArtworkLayer) -> Void) {
        guard !fuerMichGesperrt(id) else { return }
        engine?.updateDocument { document in
            guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
            change(&document.layers[index])
        }
    }

    // MARK: Adjustments

    func previewAdjustment(_ adjustment: Adjustment, amount: Double) {
        guard ensureDrawable() else { return }
        engine?.previewAdjustment(adjustment, amount: amount)
    }

    func commitAdjustment() { engine?.commitAdjustment() }
    func cancelAdjustment() { engine?.cancelAdjustment() }

    // MARK: Export and sharing

    func flattenedImage() async -> UIImage? {
        await engine?.flattenedImage()
    }

    /// Name for the partner's pen icon: the brush preset, else the tool.
    var werkzeugName: String {
        tool == .brush ? brush.rawValue : tool.rawValue
    }

    func alsBildSenden() {
        guard let engine, !isBusy else { return }
        isBusy = true
        Task {
            do {
                try await StandPaket.alsBildSenden(engine)
                show("Im Chat gesendet")
            } catch {
                show("Senden hat nicht geklappt")
            }
            isBusy = false
        }
    }

    func einladen() {
        live.einladen()
        show("Eingeladen – \(Raum.shared.ich?.partner.name ?? "dein Schatz") kann jederzeit einsteigen")
    }
}
