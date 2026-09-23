import Foundation

/// Reine Wartezeit-Berechnung für `WidgetStandSchreiber` (Z-28.2: "höchstens 1 Schreibvorgang pro
/// 15 s") — als eigene Funktion, damit sie ohne `Raum`/App Group testbar ist.
enum WidgetThrottle {
    static func wartezeit(zuletzt: Date, jetzt: Date, minAbstand: TimeInterval) -> TimeInterval {
        max(0, minAbstand - jetzt.timeIntervalSince(zuletzt))
    }
}
