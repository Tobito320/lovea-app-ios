import SwiftUI

/// Eingebaute Habits. Gespeichert wird alles als `habit.setzen` (`art` = `id`, `wert` Int pro Tag).
/// Gym und Wasser haben ihre eigenen Karten; Koffein, Protein und Gewicht gehören nur zu "Heute".
struct Habit: Sendable, Identifiable {
    let id: String
    /// true: Zähler (0, 1, 2 ...), false: ja/nein.
    let zaehlen: Bool
    let tagesziel: Int?
    let symbol: String
    let farbe: Color

    static let gym = Habit(id: "gym", zaehlen: false, tagesziel: nil, symbol: "dumbbell.fill", farbe: rgb(0x30D158))
    static let wasser = Habit(id: "wasser", zaehlen: true, tagesziel: nil, symbol: "drop.fill", farbe: rgb(0x5AC8FA))
    static let koffein = Habit(id: "koffein", zaehlen: true, tagesziel: nil, symbol: "cup.and.saucer.fill", farbe: rgb(0xD9A066))
    static let protein = Habit(id: "protein", zaehlen: false, tagesziel: nil, symbol: "fork.knife", farbe: rgb(0xE5534B))
    /// Wert = Zehntel-Kilo (784 = 78,4 kg).
    static let gewicht = Habit(id: "gewicht", zaehlen: true, tagesziel: nil, symbol: "scalemass.fill", farbe: rgb(0xAEAEB2))

    static let eingebaut = [gym, wasser, koffein, protein, gewicht]
    static let nurHeute: Set<String> = ["koffein", "protein", "gewicht"]
    /// Die alte Habit-Liste (Gym, Wasser). Neue Habits mit `nurHeute` tauchen dort nicht auf.
    static let sichtbar = eingebaut.filter { !nurHeute.contains($0.id) }

    private static func rgb(_ hex: Int) -> Color {
        Color(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

enum GewichtText {
    /// 784 -> "78,4 kg".
    static func anzeige(_ zehntel: Int) -> String { "\(zehntel / 10),\(zehntel % 10) kg" }

    /// "78,4" oder "78.4" -> 784. Leer, Text, negativ, unendlich -> nil.
    static func zehntel(_ eingabe: String) -> Int? {
        let text = eingabe.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let kilo = Double(text), kilo.isFinite, kilo > 0, kilo < 1000 else { return nil }
        return Int((kilo * 10).rounded())
    }
}
