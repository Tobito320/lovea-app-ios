import Foundation

/// How often a habit is due (Z-35.1). JSON `{typ, anzahl?, tage?}`, `tage` 1 = Mo … 7 = So (`Datum.wochentag`).
enum Haeufigkeit: Codable, Equatable, Sendable {
    case taeglich, proWoche(Int), tage([Int])

    private enum CodingKeys: String, CodingKey { case typ, anzahl, tage }

    /// Unknown `typ` from a newer build falls back to `.taeglich` instead of dropping the habit.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decodeIfPresent(String.self, forKey: .typ) ?? "taeglich" {
        case "proWoche": self = .proWoche(try c.decodeIfPresent(Int.self, forKey: .anzahl) ?? 3)
        case "tage": self = .tage(try c.decodeIfPresent([Int].self, forKey: .tage) ?? [])
        default: self = .taeglich
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .taeglich:
            try c.encode("taeglich", forKey: .typ)
        case .proWoche(let anzahl):
            try c.encode("proWoche", forKey: .typ)
            try c.encode(anzahl, forKey: .anzahl)
        case .tage(let tage):
            try c.encode("tage", forKey: .typ)
            try c.encode(tage, forKey: .tage)
        }
    }
}

/// One habit definition (Z-35.1). `habit.anlegen`/`habit.aendern` carry exactly this JSON without
/// `von`/`ausgeblendet` (the `CodingKeys` leave both out, their defaults fill in on decoding); the
/// fold sets `von` from the op and `ausgeblendet` from `habit.ausblenden`.
struct Habit: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var symbol: String
    /// `HabitFarbe.rawValue`
    var farbe: String
    var zaehlen: Bool
    var tagesziel: Int?
    var haeufigkeit: Haeufigkeit
    /// "ich" | "beide"
    var fuer: String
    var von: String? = nil
    var ausgeblendet: Bool = false

    private enum CodingKeys: String, CodingKey { case id, name, symbol, farbe, zaehlen, tagesziel, haeufigkeit, fuer }

    /// Built in, never deletable, only hideable. Their goals stay `ziel.gym` (per week) and
    /// `ziel.wasser` (per day) — the numbers here are only the defaults.
    static let gym = Habit(id: "gym", name: "Gym", symbol: "dumbbell.fill", farbe: HabitFarbe.mint.rawValue, zaehlen: false, tagesziel: nil, haeufigkeit: .proWoche(3), fuer: "beide")
    static let wasser = Habit(id: "wasser", name: "Wasser", symbol: "drop.fill", farbe: HabitFarbe.himmel.rawValue, zaehlen: true, tagesziel: 8, haeufigkeit: .taeglich, fuer: "beide")
    /// Nur für "Heute" (Tagesformen): nie in der Habit-Liste (`HabitFaltung.sichtbar`).
    static let koffein = Habit(id: "koffein", name: "Koffein", symbol: "cup.and.saucer.fill", farbe: HabitFarbe.amber.rawValue, zaehlen: true, tagesziel: nil, haeufigkeit: .taeglich, fuer: "beide")
    static let protein = Habit(id: "protein", name: "Protein", symbol: "fork.knife", farbe: HabitFarbe.koralle.rawValue, zaehlen: false, tagesziel: nil, haeufigkeit: .taeglich, fuer: "beide")
    /// Wert = Zehntel-Kilo (784 = 78,4 kg), siehe `GewichtText`.
    static let gewicht = Habit(id: "gewicht", name: "Gewicht", symbol: "scalemass.fill", farbe: HabitFarbe.grau.rawValue, zaehlen: true, tagesziel: nil, haeufigkeit: .taeglich, fuer: "beide")
    static let eingebaut = [gym, wasser, koffein, protein, gewicht]
    static let nurHeute: Set<String> = [koffein.id, protein.id, gewicht.id]

    var istEingebaut: Bool { Habit.eingebaut.contains { $0.id == id } }
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

/// The eight HabitLink tints. Colors live with the views (`HealthStil.swift`).
enum HabitFarbe: String, CaseIterable, Sendable {
    case mint, amber, indigo, rose, himmel, limette, koralle, grau
}

/// The 40 SF Symbols the create sheet offers (Spec 3.3), all present since SF Symbols 4.
enum HabitSymbole {
    static let alle = [
        "dumbbell.fill", "drop.fill", "figure.run", "figure.walk", "figure.yoga", "figure.pool.swim",
        "bicycle", "figure.hiking", "figure.mind.and.body", "bed.double.fill", "moon.zzz.fill", "sun.max.fill",
        "book.fill", "books.vertical.fill", "pencil", "graduationcap.fill", "brain.head.profile", "heart.fill",
        "leaf.fill", "carrot.fill", "fork.knife", "cup.and.saucer.fill", "pills.fill", "cross.case.fill",
        "music.note", "guitars.fill", "paintpalette.fill", "camera.fill", "gamecontroller.fill", "house.fill",
        "cart.fill", "eurosign.circle.fill", "phone.fill", "gift.fill", "pawprint.fill", "sparkles",
        "star.fill", "bolt.fill", "alarm.fill", "airplane",
    ]
}
