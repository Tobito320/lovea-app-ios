import Foundation

/// Confirmed ops, one JSON line each, at `Application Support/Lovea/sync/ops.jsonl`.
/// Loaded lazily on first use so creating an `OpLog` never touches disk on the main thread.
actor OpLog {
    private let fileURL: URL
    private let cursorURL: URL
    /// Sorted by `seq`. I-6: without the drawing ops a newer stand already contains.
    private var ops: [Op] = []
    /// Every id ever logged, pruned ones included, so a repeated echo is never written twice.
    private var ids: Set<String> = []
    /// Highest stand `basis` per drawing (`zeichnung.stand`).
    private var standBasis: [String: Int] = [:]
    private var geladen = false
    private var vollstaendigBisSeqWert: Int?

    private static let zeichenOpArten: Set<String> = ["zeichnung.op", "zeichnung.rueckgaengig"]

    init(rootURL: URL? = nil) {
        let basis = rootURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lovea/sync", isDirectory: true)
        fileURL = basis.appendingPathComponent("ops.jsonl")
        cursorURL = basis.appendingPathComponent("nachholt-bis.txt")
    }

    /// The last `seq` confirmed complete by an actual paging response (server's `seite:true`) —
    /// never by a live broadcast landing in between, and never just "max seq ever logged". Used
    /// by `Raum.start()` as the `seit` to reconnect with, so a restart resumes paging from
    /// exactly where it left off instead of skipping ops that only a live op's high seq made it
    /// look like we already had.
    func vollstaendigBisSeq() -> Int {
        ladenCursor()
        return vollstaendigBisSeqWert ?? 0
    }

    func vollstaendigBisSeqSetzen(_ seq: Int) {
        vollstaendigBisSeqWert = seq
        try? String(seq).write(to: cursorURL, atomically: true, encoding: .utf8)
    }

    private func ladenCursor() {
        guard vollstaendigBisSeqWert == nil else { return }
        if let text = try? String(contentsOf: cursorURL, encoding: .utf8), let seq = Int(text) {
            vollstaendigBisSeqWert = seq
        } else {
            vollstaendigBisSeqWert = 0
        }
    }

    /// Appends confirmed ops. A duplicate `id` (a repeated echo) is silently skipped —
    /// the server already deduplicates by id, this just makes the client idempotent too.
    func anhaengen(_ neue: [Op]) {
        laden()
        let encoder = JSONEncoder()
        var zeilen = ""
        var standNeu = false
        for op in neue {
            guard !ids.contains(op.id) else { continue }
            guard let daten = try? encoder.encode(op), let zeile = String(data: daten, encoding: .utf8) else { continue }
            ids.insert(op.id)
            zeilen += zeile + "\n"
            if standMerken(op) { standNeu = true }
            einsortieren(op)
        }
        guard !zeilen.isEmpty else { return }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(zeilen.utf8))
        } else {
            try? Data(zeilen.utf8).write(to: fileURL)
        }
        if standNeu { ops.removeAll { ueberholt($0) } }
    }

    func alle(arten: Set<String> = []) -> [Op] {
        laden()
        return arten.isEmpty ? ops : ops.filter { arten.contains($0.art) }
    }

    var letzteSeq: Int {
        laden()
        return ops.compactMap(\.seq).max() ?? 0
    }

    /// I-6: echoes arrive almost always in `seq` order, so this is an append; otherwise a binary
    /// search instead of re-sorting the whole log per echo.
    private func einsortieren(_ op: Op) {
        guard !ueberholt(op) else { return }
        let schluessel = op.seq ?? .max
        guard let letzte = ops.last, (letzte.seq ?? .max) > schluessel else {
            ops.append(op)
            return
        }
        var unten = 0
        var oben = ops.count
        while unten < oben {
            let mitte = (unten + oben) / 2
            if (ops[mitte].seq ?? .max) <= schluessel { unten = mitte + 1 } else { oben = mitte }
        }
        ops.insert(op, at: unten)
    }

    private struct ZeichnungKopf: Decodable {
        let zeichnungId: String
        let basis: Int?
    }

    /// Remembers a stand's `basis`; true if it moved up.
    private func standMerken(_ op: Op) -> Bool {
        guard op.art == "zeichnung.stand", let kopf = op.daten(ZeichnungKopf.self), let basis = kopf.basis,
              basis > standBasis[kopf.zeichnungId] ?? 0 else { return false }
        standBasis[kopf.zeichnungId] = basis
        return true
    }

    /// I-6: a stroke or undo a newer stand already contains. `TeilenStand` drops these the same way,
    /// so nobody reads them; keeping them only grew memory with every stroke.
    private func ueberholt(_ op: Op) -> Bool {
        guard Self.zeichenOpArten.contains(op.art), let seq = op.seq,
              let kopf = op.daten(ZeichnungKopf.self), let basis = standBasis[kopf.zeichnungId] else { return false }
        return seq <= basis
    }

    // ponytail: ops.jsonl itself still grows with every stroke and is decoded whole at start
    // (memory-mapped, pruned right after). Compact the file (rewrite without `ueberholt` lines) if
    // starts get slow or memory-heavy.
    private func laden() {
        guard !geladen else { return }
        geladen = true
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let daten = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else { return }
        let decoder = JSONDecoder()
        var geladeneOps: [Op] = []
        for zeile in daten.split(separator: UInt8(ascii: "\n")) {
            guard let op = try? decoder.decode(Op.self, from: Data(zeile)), !ids.contains(op.id) else { continue }
            ids.insert(op.id)
            _ = standMerken(op)
            geladeneOps.append(op)
        }
        ops = geladeneOps.filter { !ueberholt($0) }.sorted { ($0.seq ?? .max) < ($1.seq ?? .max) }
    }
}
