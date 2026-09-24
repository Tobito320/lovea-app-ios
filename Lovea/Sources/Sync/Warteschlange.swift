import Foundation

/// Ops sent but not yet confirmed by the server, persisted at
/// `Application Support/Lovea/sync/warteschlange.json` so they survive a restart.
/// Loaded lazily on first use, same reasoning as `OpLog`.
actor Warteschlange {
    private let fileURL: URL
    private var ops: [Op] = []
    private var geladen = false
    private var ungesichert = false
    private var schreibAuftrag: Task<Void, Never>?

    init(rootURL: URL? = nil) {
        let basis = rootURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lovea/sync", isDirectory: true)
        fileURL = basis.appendingPathComponent("warteschlange.json")
    }

    var offen: [Op] {
        laden()
        return ops
    }

    func rein(_ op: Op) {
        laden()
        guard !ops.contains(where: { $0.id == op.id }) else { return }
        ops.append(op)
        persist()
    }

    /// No-op (and no write) when `id` isn't queued — a duplicate echo must not touch the disk.
    func raus(id: String) {
        laden()
        let vorher = ops.count
        ops.removeAll { $0.id == id }
        guard ops.count != vorher else { return }
        persist()
    }

    /// Audit #7: a burst (chat, offline strokes, a page of echoes) rewrites the file once, 0.3 s
    /// after its first change, instead of once per op. `Raum.leer()` and leaving the foreground
    /// call `sichern()`, so "leer() means on disk" still holds.
    // ponytail: a crash inside those 0.3 s loses the newest queued ops; append-only journal if that ever matters.
    private func persist() {
        ungesichert = true
        guard schreibAuftrag == nil else { return }
        schreibAuftrag = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self.sichern()
        }
    }

    /// Writes pending changes now (no-op when there are none).
    func sichern() {
        schreibAuftrag?.cancel()
        schreibAuftrag = nil
        guard ungesichert else { return }
        ungesichert = false
        if let daten = try? JSONEncoder().encode(ops) {
            try? daten.write(to: fileURL, options: .atomic)
        }
    }

    private func laden() {
        guard !geladen else { return }
        geladen = true
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let daten = try? Data(contentsOf: fileURL) else { return }
        ops = (try? JSONDecoder().decode([Op].self, from: daten)) ?? []
    }
}
