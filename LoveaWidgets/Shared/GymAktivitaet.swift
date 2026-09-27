import ActivityKit
import Foundation

/// Live Activity einer laufenden Gym-Einheit (Dynamic Island und Sperrbildschirm). App startet,
/// aktualisiert und beendet sie (`GymLive`), das Widget-Ziel zeichnet sie (`GymLiveWidget`).
struct GymAktivitaet: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var uebung: String?
        var fertig: Int
        var gesamt: Int
    }

    var sessionId: String
    var start: Date
    var tagName: String
}
