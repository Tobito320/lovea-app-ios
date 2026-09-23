@preconcurrency import Metal

enum UndoEntry {
    case pixels(layerID: UUID, region: MTLRegion, before: MTLTexture, after: MTLTexture)
    case document(before: ArtworkDocument, after: ArtworkDocument, removedTextures: [UUID: MTLTexture])

    var bytes: Int {
        switch self {
        case let .pixels(_, region, _, _):
            region.size.width * region.size.height * 8
        case let .document(_, _, removed):
            removed.values.reduce(0) { $0 + $1.width * $1.height * 4 }
        }
    }
}

/// Undo steps with their author. `autor == nil` is an own action; foreign entries (partner strokes)
/// are recorded but never undone locally.
@MainActor
final class UndoHistory {
    private struct Item {
        let entry: UndoEntry
        let autor: String?
    }

    let budgetBytes: Int
    private var undoStack: [Item] = []
    private var redoStack: [Item] = []

    /// Shared drawing: every step goes to the shared history (`GemeinsamVerlauf`) instead of this stack.
    var umleiten: ((UndoEntry) -> Void)?

    init(budgetBytes: Int = 256 << 20) {
        self.budgetBytes = budgetBytes
    }

    var canUndo: Bool { undoStack.contains { $0.autor == nil } }
    var canRedo: Bool { !redoStack.isEmpty }
    var count: Int { undoStack.count }
    var bytesInUse: Int { (undoStack + redoStack).reduce(0) { $0 + $1.entry.bytes } }

    func push(_ entry: UndoEntry, autor: String? = nil) {
        if let umleiten {
            umleiten(entry)
            return
        }
        undoStack.append(Item(entry: entry, autor: autor))
        if autor == nil { redoStack.removeAll() }
        while undoStack.count > 1, bytesInUse > budgetBytes {
            undoStack.removeFirst()
        }
    }

    /// Pops the newest own entry. Level 1 only: shared drawings undo through `GemeinsamVerlauf`,
    /// which re-applies the partner's later steps.
    func popUndo() -> UndoEntry? {
        guard let index = undoStack.lastIndex(where: { $0.autor == nil }) else { return nil }
        let item = undoStack.remove(at: index)
        redoStack.append(item)
        return item.entry
    }

    func popRedo() -> UndoEntry? {
        guard let item = redoStack.popLast() else { return nil }
        undoStack.append(item)
        return item.entry
    }

    func removeAll() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// Memory warning: keep only the newer half.
    func dropOldestHalf() {
        undoStack.removeFirst(undoStack.count / 2)
        redoStack.removeAll()
    }
}
