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
    /// Positions in `ops` of applied ops still without `seq`, oldest first. While there is one, any
    /// confirmed op from elsewhere must refold, because the unconfirmed one will get a higher `seq`
    /// and has to stay on top.
    private var offene: [Int] = []

    /// Returns the ops to apply on top of the current fold, or nil when the caller must refold `sortiert`.
    mutating func aufnehmen(_ batch: [Op]) -> [Op]? {
        var neu: [Op] = []
        var neuFalten = false
        for op in batch {
            if let i = index[op.id] {
                // The echo of an own op. The fold order is "confirmed by seq, then open ones", so the
                // oldest open op confirming above every known seq keeps its place: nothing to redo.
                if ops[i].seq == nil, let seq = op.seq {
                    ops[i].seq = seq
                    if seq < hoechsteSeq || offene.first != i { neuFalten = true }
                    offene.removeAll { $0 == i }
                    hoechsteSeq = max(hoechsteSeq, seq)
                }
                continue
            }
            index[op.id] = ops.count
            ops.append(op)
            neu.append(op)
            if let seq = op.seq {
                if seq < hoechsteSeq || !offene.isEmpty { neuFalten = true }
                hoechsteSeq = max(hoechsteSeq, seq)
            } else {
                offene.append(ops.count - 1)
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
