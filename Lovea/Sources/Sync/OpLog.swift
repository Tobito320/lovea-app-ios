import Foundation

/// Confirmed ops, one JSON line each, at `Application Support/Lovea/sync/ops.jsonl`.
/// Loaded lazily on first use so creating an `OpLog` never touches disk on the main thread.
actor OpLog {
    private let fileURL: URL
    private var ops: [Op] = []
    private var indexVonId: [String: Int] = [:]
    private var geladen = false

    init(rootURL: URL? = nil) {
        let basis = rootURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lovea/sync", isDirectory: true)
        fileURL = basis.appendingPathComponent("ops.jsonl")
    }

    /// Appends confirmed ops. A duplicate `id` (a repeated echo) is silently skipped —
    /// the server already deduplicates by id, this just makes the client idempotent too.
    func anhaengen(_ neue: [Op]) {
        laden()
        let encoder = JSONEncoder()
        var zeilen = ""
        for op in neue {
            guard indexVonId[op.id] == nil else { continue }
            guard let daten = try? encoder.encode(op), let zeile = String(data: daten, encoding: .utf8) else { continue }
            zeilen += zeile + "\n"
            einfuegen(op)
        }
        guard !zeilen.isEmpty else { return }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(zeilen.utf8))
        } else {
            try? Data(zeilen.utf8).write(to: fileURL)
        }
        ops.sort { ($0.seq ?? .max) < ($1.seq ?? .max) }
        indexVonId.removeAll(keepingCapacity: true)
        for (i, op) in ops.enumerated() { indexVonId[op.id] = i }
    }

    func alle(arten: Set<String> = []) -> [Op] {
        laden()
        return arten.isEmpty ? ops : ops.filter { arten.contains($0.art) }
    }

    var letzteSeq: Int {
        laden()
        return ops.compactMap(\.seq).max() ?? 0
    }

    private func einfuegen(_ op: Op) {
        indexVonId[op.id] = ops.count
        ops.append(op)
    }

    private func laden() {
        guard !geladen else { return }
        geladen = true
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        let decoder = JSONDecoder()
        for zeile in text.split(separator: "\n") {
            guard let op = try? decoder.decode(Op.self, from: Data(zeile.utf8)), indexVonId[op.id] == nil else { continue }
            einfuegen(op)
        }
        ops.sort { ($0.seq ?? .max) < ($1.seq ?? .max) }
        indexVonId.removeAll(keepingCapacity: true)
        for (i, op) in ops.enumerated() { indexVonId[op.id] = i }
    }
}
