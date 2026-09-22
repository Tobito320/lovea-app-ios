import Combine
import Foundation

@MainActor
final class DrawingStore: ObservableObject {
    private struct HistoryState {
        var document: DrawingDocument
        var activeLayerID: UUID
    }

    @Published private(set) var document: DrawingDocument
    @Published private(set) var activeLayerID: UUID
    @Published var tool: DrawingTool = .brush
    @Published var color: RGBAColor = .ink
    @Published var brushWidth = 9.0
    @Published var opacity = 1.0
    @Published var drawsWithFinger = false

    private(set) var activeStroke: DrawingStroke?
    private var undoStack: [HistoryState] = []
    private var redoStack: [HistoryState] = []
    private var opacityTransaction: (layerID: UUID, before: HistoryState)?
    private let persistence: DrawingPersistence?

    init(document: DrawingDocument = .empty, persistence: DrawingPersistence? = nil) {
        self.document = document
        self.activeLayerID = document.layers.last?.id ?? UUID()
        self.persistence = persistence
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func loadSavedDocument() async {
        guard let persistence, let saved = try? await persistence.load(), !saved.layers.isEmpty else { return }
        document = saved
        activeLayerID = saved.layers.last!.id
        undoStack.removeAll()
        redoStack.removeAll()
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
        guard let stroke = activeStroke,
              let index = document.layers.firstIndex(where: { $0.id == activeLayerID }) else { return }
        activeStroke = nil
        recordUndo()
        document.layers[index].strokes.append(stroke)
        persist()
    }

    func cancelStroke() {
        activeStroke = nil
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(currentState)
        restore(previous)
        persist()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentState)
        restore(next)
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
        let clamped = min(max(value, 0), 1)
        guard document.layers[index].opacity != clamped else { return }
        if opacityTransaction?.layerID != id {
            recordUndo()
        }
        document.layers[index].opacity = clamped
        if opacityTransaction == nil { persist() }
    }

    func beginLayerOpacityEditing(_ id: UUID) {
        guard opacityTransaction == nil,
              document.layers.contains(where: { $0.id == id }) else { return }
        opacityTransaction = (id, currentState)
    }

    func endLayerOpacityEditing(_ id: UUID) {
        guard let transaction = opacityTransaction, transaction.layerID == id else { return }
        opacityTransaction = nil
        guard transaction.before.document != document else { return }
        undoStack.append(transaction.before)
        trimUndoStack()
        redoStack.removeAll()
        persist()
    }

    func renameLayer(_ name: String, id: UUID) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = document.layers.firstIndex(where: { $0.id == id }),
              document.layers[index].name != trimmed else { return }
        recordUndo()
        document.layers[index].name = trimmed
        persist()
    }

    private func recordUndo() {
        undoStack.append(currentState)
        trimUndoStack()
        redoStack.removeAll()
    }

    private var currentState: HistoryState {
        HistoryState(document: document, activeLayerID: activeLayerID)
    }

    private func restore(_ state: HistoryState) {
        document = state.document
        activeLayerID = state.activeLayerID
        repairActiveLayer()
    }

    private func trimUndoStack() {
        if undoStack.count > 50 { undoStack.removeFirst() }
    }

    private func repairActiveLayer() {
        if !document.layers.contains(where: { $0.id == activeLayerID }) {
            activeLayerID = document.layers.last!.id
        }
    }

    private func persist() {
        guard let persistence else { return }
        let snapshot = document
        Task { try? await persistence.save(snapshot) }
    }
}
