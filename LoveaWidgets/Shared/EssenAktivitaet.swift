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

        init(kcal: Int, kcalZiel: Int, proteinG: Int, proteinZiel: Int, kohlenhydrateG: Int,
             kohlenhydrateZiel: Int, fettG: Int, fettZiel: Int, mahlzeitenKcal: [Int], tag: String) {
            self.kcal = kcal; self.kcalZiel = kcalZiel
            self.proteinG = proteinG; self.proteinZiel = proteinZiel
            self.kohlenhydrateG = kohlenhydrateG; self.kohlenhydrateZiel = kohlenhydrateZiel
            self.fettG = fettG; self.fettZiel = fettZiel
            self.mahlzeitenKcal = mahlzeitenKcal; self.tag = tag
        }

        /// R8 (Review, Critical): abwärtskompatibel zu einer Aktivität, die eine ältere App-Version
        /// gestartet hat — vor R8 ganz ohne `mahlzeitenKcal`, vor dem R7-Fix sogar ohne `tag`.
        /// ActivityKit decodiert deren persistiertes JSON weiter gegen diesen Typ; ohne Fallback
        /// würde das crashen. Fehlende Felder bekommen neutrale Defaults, `EssenLive.anwenden`
        /// erkennt die fehlenden Mahlzeitendaten danach (`istVeraltet`) und startet neu.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            kcal = try c.decode(Int.self, forKey: .kcal)
            kcalZiel = try c.decode(Int.self, forKey: .kcalZiel)
            proteinG = try c.decode(Int.self, forKey: .proteinG)
            proteinZiel = try c.decode(Int.self, forKey: .proteinZiel)
            kohlenhydrateG = try c.decode(Int.self, forKey: .kohlenhydrateG)
            kohlenhydrateZiel = try c.decode(Int.self, forKey: .kohlenhydrateZiel)
            fettG = try c.decode(Int.self, forKey: .fettG)
            fettZiel = try c.decode(Int.self, forKey: .fettZiel)
            mahlzeitenKcal = try c.decodeIfPresent([Int].self, forKey: .mahlzeitenKcal) ?? [0, 0, 0, 0]
            tag = try c.decodeIfPresent(String.self, forKey: .tag) ?? ""
        }
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
