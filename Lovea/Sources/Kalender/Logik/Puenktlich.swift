import Foundation

/// Der `d`-Körper einer `puenktlich.setzen`-Op, 1:1 aus `schnittstellen.md`.
struct PuenktlichEintrag: Codable, Hashable {
    var datum: String
    var ueber: Person
    var wert: String // "uhrwerk" | "charmant" | "troedel" | "weg"
}

enum Puenktlich {
    /// Wer im Monat (`"yyyy-MM"`) pünktlicher bewertet wurde: Punkte je Wertung (Uhrwerk 2,
    /// charmant 1, Trödel 0, "weg" zählt nicht), summiert über alle Bewertungen **über** diese
    /// Person. Gleichstand oder keine Bewertungen ergeben `nil` (keine Krone).
    static func monatsKrone(ops: [Op], monat: String) -> Person? {
        var punkte: [Person: Int] = [.ahmed: 0, .annika: 0]
        for op in ops where op.art == "puenktlich.setzen" {
            guard let e = op.daten(PuenktlichEintrag.self), e.datum.hasPrefix(monat), let wert = punktwert(e.wert) else { continue }
            punkte[e.ueber, default: 0] += wert
        }
        guard punkte[.ahmed] != punkte[.annika] else { return nil }
        return (punkte[.ahmed] ?? 0) > (punkte[.annika] ?? 0) ? .ahmed : .annika
    }

    private static func punktwert(_ wert: String) -> Int? {
        switch wert {
        case "uhrwerk": 2
        case "charmant": 1
        case "troedel": 0
        default: nil // "weg" (weggewischt) zählt nicht in die Wertung
        }
    }
}
