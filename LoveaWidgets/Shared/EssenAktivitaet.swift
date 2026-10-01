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
        /// kcal je Mahlzeit, Reihenfolge wie `EssenMahlzeitAnzeige.allCases`/`Mahlzeit.allCases`
        /// (Frühstück, Mittag, Abend, Snacks). Immer genau 4 Werte.
        var mahlzeitenKcal: [Int]
        /// Tag im Tagebuch ("yyyy-MM-dd"), für den dieser Stand gilt — erkennt den Tageswechsel.
        var tag: String
    }

    var name: String
}

/// Die vier Mahlzeiten fürs Widget-Ziel, das `Lovea/Sources` (und damit den echten `Mahlzeit`-Typ)
/// nicht sieht — siehe `project.yml`, `LoveaWidgets` hat nur `LoveaWidgets/Sources` + `/Shared`.
/// rawValue, Reihenfolge, Name, Symbol und Anteil müssen zu `Mahlzeit` passen.
enum EssenMahlzeitAnzeige: String, CaseIterable, Hashable {
    case fruehstueck, mittag, abend, snack

    var name: String {
        switch self {
        case .fruehstueck: "Frühstück"
        case .mittag: "Mittagessen"
        case .abend: "Abendessen"
        case .snack: "Snacks"
        }
    }

    var symbol: String {
        switch self {
        case .fruehstueck: "sunrise.fill"
        case .mittag: "sun.max.fill"
        case .abend: "moon.stars.fill"
        case .snack: "carrot.fill"
        }
    }

    /// Anteil am Tagesziel, wie `Mahlzeit.anteil`.
    var anteil: Double {
        switch self {
        case .fruehstueck: 0.25
        case .mittag: 0.35
        case .abend: 0.30
        case .snack: 0.10
        }
    }
}
