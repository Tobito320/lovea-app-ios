import Foundation

/// I-1: collects the ops of a "higher `seq` wins" fold (Kalender, Wir) so both phones end up equal,
/// whatever order the ops arrive in. Own ops come in twice: optimistic without `seq`, then as the
/// echo with `seq`. `aufnehmen` says whether the new ops can simply be applied on top, or whether
/// the fold has to be rebuilt from `sortiert`.
struct SeqFaltung: Sendable {
    /// In arrival order; `sortiert` has them by `seq`.
    private(set) var ops: [Op] = []
    private var index: [String: Int] = [:]
    private var hoechsteSeq = 0
    /// Applied ops still without `seq`. While there is one, any confirmed op must refold, because
    /// the unconfirmed one will get a higher `seq` and has to stay on top.
    private var offen = 0

    /// Returns the ops to apply on top of the current fold, or nil when the caller must refold `sortiert`.
    mutating func aufnehmen(_ batch: [Op]) -> [Op]? {
        var neu: [Op] = []
        var neuFalten = false
        for op in batch {
            if let i = index[op.id] {
                // The echo of an own op: now it has its real place in the order.
                if ops[i].seq == nil, let seq = op.seq {
                    ops[i].seq = seq
                    offen -= 1
                    hoechsteSeq = max(hoechsteSeq, seq)
                    neuFalten = true
                }
                continue
            }
            index[op.id] = ops.count
            ops.append(op)
            neu.append(op)
            if let seq = op.seq {
                if seq < hoechsteSeq || offen > 0 { neuFalten = true }
                hoechsteSeq = max(hoechsteSeq, seq)
            } else {
                offen += 1
            }
        }
        return neuFalten ? nil : neu
    }

    /// By `seq`, unconfirmed ops last in the order they were made.
    var sortiert: [Op] {
        ops.enumerated()
            .sorted { ($0.element.seq ?? Int.max, $0.offset) < ($1.element.seq ?? Int.max, $1.offset) }
            .map { $0.element }
    }
}
