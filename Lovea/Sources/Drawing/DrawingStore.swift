import Combine
import Foundation

@MainActor
final class DrawingStore: ObservableObject {
    @Published private(set) var document: DrawingDocument
    @Published private(set) var activeLayerID: UUID
    @Published var tool: DrawingTool = .brush
    @Published var color: RGBAColor = .ink
    @Published var brushWidth = 9.0
    @Published var opacity = 1.0
    @Published var drawsWithFinger = false

    private(set) var activeStroke: DrawingStroke?
    private var undoStack: [DrawingDocument] = []
    private var redoStack: [DrawingDocument] = []
    private let persistence: DrawingPersistence?

    init(document: DrawingDocument = .empty, persistence: DrawingPersistence? = nil) {
        self.document = document
        self.activeLayerID = document.layers.first?.id ?? UUID()
        self.persistence = persistence
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func loadSavedDocument() async {
        guard let persistence, let saved = try? await persistence.load(), !saved.layers.isEmpty else { return }
        document = saved
        activeLayerID = saved.layers[0].id
    }

    func beginStroke(at point: StrokePoint) {
        activeStroke = DrawingStroke(
            points: [point],
            color: color,
            width: brushWidth,
            opacity: opacity,
            tool: tool
        )
    }

    func appendPoint(_ point: StrokePoint) {
        activeStroke?.points.append(point)
    }

    func endStroke() {
        guard let stroke = activeStroke else { return }
        activeStroke = nil
        recordUndo()
        guard let index = document.layers.firstIndex(where: { $0.id == activeLayerID }) else { return }
        document.layers[index].strokes.append(stroke)
        persist()
    }

    func cancelStroke() {
        activeStroke = nil
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(document)
        document = previous
        repairActiveLayer()
        persist()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(document)
        document = next
        repairActiveLayer()
        persist()
    }

    func clear() {
        recordUndo()
        for index in document.layers.indices {
            document.layers[index].strokes.removeAll()
        }
        persist()
    }

    func addLayer() {
        recordUndo()
        let layer = DrawingLayer(name: "Ebene \(document.layers.count + 1)")
        document.layers.append(layer)
        activeLayerID = layer.id
        persist()
    }

    func selectLayer(_ id: UUID) {
        guard document.layers.contains(where: { $0.id == id }) else { return }
        activeLayerID = id
    }

    func toggleLayerVisibility(_ id: UUID) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        recordUndo()
        document.layers[index].isVisible.toggle()
        persist()
    }

    func deleteLayer(_ id: UUID) {
        guard document.layers.count > 1,
              let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        recordUndo()
        document.layers.remove(at: index)
        repairActiveLayer()
        persist()
    }

    func updateLayerOpacity(_ value: Double, id: UUID) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        document.layers[index].opacity = min(max(value, 0), 1)
        persist()
    }

    private func recordUndo() {
        undoStack.append(document)
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func repairActiveLayer() {
        if !document.layers.contains(where: { $0.id == activeLayerID }) {
            activeLayerID = document.layers[0].id
        }
    }

    private func persist() {
        guard let persistence else { return }
        let snapshot = document
        Task { try? await persistence.save(snapshot) }
    }
}
