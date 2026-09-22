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

@MainActor
final class UndoHistory {
    let budgetBytes: Int
    private var undoStack: [UndoEntry] = []
    private var redoStack: [UndoEntry] = []

    init(budgetBytes: Int = 256 << 20) {
        self.budgetBytes = budgetBytes
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var count: Int { undoStack.count }
    var bytesInUse: Int { (undoStack + redoStack).reduce(0) { $0 + $1.bytes } }

    func push(_ entry: UndoEntry) {
        undoStack.append(entry)
        redoStack.removeAll()
        while undoStack.count > 1, bytesInUse > budgetBytes {
            undoStack.removeFirst()
        }
    }

    func popUndo() -> UndoEntry? {
        guard let entry = undoStack.popLast() else { return nil }
        redoStack.append(entry)
        return entry
    }

    func popRedo() -> UndoEntry? {
        guard let entry = redoStack.popLast() else { return nil }
        undoStack.append(entry)
        return entry
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
