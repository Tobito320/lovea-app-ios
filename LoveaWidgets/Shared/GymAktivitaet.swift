import ActivityKit
import Foundation

/// Live Activity einer laufenden Gym-Einheit (Dynamic Island und Sperrbildschirm). App startet,
/// aktualisiert und beendet sie (`GymLive`), das Widget-Ziel zeichnet sie (`GymLiveWidget`).
struct GymAktivitaet: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var uebung: String?
        var fertig: Int
        var gesamt: Int
        /// Der Satz, der dran ist: "Satz 2 von 3" und "32 kg × 12". nil bei Cardio oder wenn alles fertig ist.
        var satz: Int? = nil
        var saetze: Int? = nil
        var zeile: String? = nil
        /// Die laufende Uhr: seit wann der Satz oder die Pause läuft, bei einer Pause mit Ziel auch bis wann.
        var pause: Bool? = nil
        var seit: Date? = nil
        var bis: Date? = nil
    }

    var sessionId: String
    var start: Date
    var tagName: String
}
