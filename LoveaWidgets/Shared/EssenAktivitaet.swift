import ActivityKit
import Foundation

/// Live Activity der heutigen Ernährung (Dynamic Island und Sperrbildschirm). App startet,
/// aktualisiert und beendet sie (`EssenLive`), das Widget-Ziel zeichnet sie (`EssenLiveWidget`).
struct EssenAktivitaet: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var kcal: Int
        var kcalZiel: Int
        var proteinG: Int
        var proteinZiel: Int
        var kohlenhydrateG: Int
        var kohlenhydrateZiel: Int
        var fettG: Int
        var fettZiel: Int
        /// Tag im Tagebuch ("yyyy-MM-dd"), für den dieser Stand gilt — erkennt den Tageswechsel.
        var tag: String
    }

    var name: String
}
