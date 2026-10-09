/// Run state of the camera session as a pure value (p66), so the start/stop race is testable
/// without AVFoundation. `SnapKameraSteuerung` keeps one and mirrors `laeuft`/`bildDa` from it.
///
/// Every start gets a number; the callback that says "frames flow" carries the number of its own
/// run. Without it, start -> stop -> start let the first run's late callback set `bildDa` while the
/// second `startRunning` was still in flight.
struct KameraLauf: Equatable {
    private(set) var laeuft = false
    private(set) var bildDa = false
    private(set) var nummer = 0

    /// The number of the new run, or nil when one is already running.
    mutating func starten() -> Int? {
        guard !laeuft else { return nil }
        laeuft = true
        nummer += 1
        return nummer
    }

    /// false when nothing was running.
    @discardableResult
    mutating func stoppen() -> Bool {
        guard laeuft else { return false }
        laeuft = false
        bildDa = false
        return true
    }

    /// true when the callback belongs to the current, still wanted run.
    @discardableResult
    mutating func bildBereit(nummer von: Int) -> Bool {
        guard laeuft, von == nummer else { return false }
        bildDa = true
        return true
    }
}
