import Foundation

/// Eine erkannte Zutat einer Mahlzeit. Die Nährwerte stehen pro 100 g, damit sich beim Ändern der
/// Gramm alles sofort neu rechnet, ohne neuen KI-Aufruf.
struct EssenKomponente: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var gramm: Double
    var kcalPro100: Double
    var proteinPro100: Double
    var kohlenhydratePro100: Double
    var fettPro100: Double
    /// "hoch", "mittel" oder "niedrig" (wie sicher sich die KI bei dieser Zutat ist).
    var sicherheit: String

    var kcal: Int { Int((gramm * kcalPro100 / 100).rounded()) }
    var protein: Double { gramm * proteinPro100 / 100 }
    var kohlenhydrate: Double { gramm * kohlenhydratePro100 / 100 }
    var fett: Double { gramm * fettPro100 / 100 }
}

/// Nicht Sichtbares, aber sehr wahrscheinlich Enthaltenes (Bratöl, Soße, Dressing).
struct EssenVersteckt: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var gramm: Double
    var kcal: Int
}

enum MahlzeitArt: String, Codable, CaseIterable, Identifiable, Sendable {
    case fruehstueck, mittag, abend, snack

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .fruehstueck: "Frühstück"
        case .mittag: "Mittagessen"
        case .abend: "Abendessen"
        case .snack: "Snack"
        }
    }

    /// Vorschlag nach Uhrzeit (Berlin), damit man selten umstellen muss.
    static func vorschlag(um zeit: Date = Date()) -> MahlzeitArt {
        switch Datum.kalender.component(.hour, from: zeit) {
        case 5..<10: .fruehstueck
        case 10..<15: .mittag
        case 15..<17: .snack
        case 17..<22: .abend
        default: .snack
        }
    }
}

struct EssenSumme: Equatable, Sendable {
    var kcal = 0
    var protein = 0.0
    var kohlenhydrate = 0.0
    var fett = 0.0
}

struct EssenMahlzeit: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    /// "yyyy-MM-dd" (Berlin), wie überall in der App.
    var tag: String
    var zeit: Date
    var art: MahlzeitArt
    var komponenten: [EssenKomponente]
    var versteckt: [EssenVersteckt] = []
    var versteckteZaehlen = true
    var hinweis = ""

    var versteckteKcal: Int { versteckt.reduce(0) { $0 + $1.kcal } }
    var kcal: Int {
        let zutaten = komponenten.reduce(0) { $0 + $1.kcal }
        return zutaten + (versteckteZaehlen ? versteckteKcal : 0)
    }
    var protein: Double { komponenten.reduce(0.0) { $0 + $1.protein } }
    var kohlenhydrate: Double { komponenten.reduce(0.0) { $0 + $1.kohlenhydrate } }
    /// Versteckte Kalorien sind meist Öl oder Butter, also rechnen wir sie als Fett (9 kcal pro g).
    var versteckteFett: Double { versteckt.reduce(0.0) { $0 + Double($1.kcal) / 9 } }
    var fett: Double { komponenten.reduce(0.0) { $0 + $1.fett } + (versteckteZaehlen ? versteckteFett : 0) }

    /// Kurzer Titel für Listen: die ersten zwei Zutaten.
    var titel: String {
        let namen = komponenten.prefix(2).map(\.name).joined(separator: ", ")
        if namen.isEmpty { return art.titel }
        return komponenten.count > 2 ? namen + " …" : namen
    }
}

/// Persönliche Tagesziele. `kcal` hat nach unten eine feste Grenze (siehe Server und Coach).
struct EssenZiele: Codable, Equatable, Sendable {
    /// "cut", "halten" oder "aufbauen".
    var ziel = "cut"
    var kcal = 2000
    var protein = 140

    static let mindestKcal = 1200

    static func titel(_ ziel: String) -> String {
        switch ziel {
        case "cut": "Abnehmen (Cut)"
        case "aufbauen": "Muskelaufbau"
        default: "Gewicht halten"
        }
    }
}

/// Antwort von `POST /ki/essen`.
struct EssenAnalyse: Decodable, Sendable {
    struct Komponente: Decodable, Sendable {
        let name: String
        let gramm: Double
        let kcalPro100: Double
        let proteinPro100: Double
        let kohlenhydratePro100: Double
        let fettPro100: Double
        let sicherheit: String

        enum CodingKeys: String, CodingKey {
            case name, gramm, sicherheit
            case kcalPro100 = "kcal_pro_100g"
            case proteinPro100 = "protein_pro_100g"
            case kohlenhydratePro100 = "kohlenhydrate_pro_100g"
            case fettPro100 = "fett_pro_100g"
        }
    }

    struct Versteckt: Decodable, Sendable {
        let name: String
        let gramm: Double
        let kcal: Int
    }

    struct Gesamt: Decodable, Sendable {
        let kcal: Int
        let kcalMin: Int
        let kcalMax: Int

        enum CodingKeys: String, CodingKey {
            case kcal
            case kcalMin = "kcal_min"
            case kcalMax = "kcal_max"
        }
    }

    let istEssen: Bool
    let items: [Komponente]
    let versteckt: [Versteckt]
    let gesamt: Gesamt
    let frage: String?
    let bemerkung: String

    enum CodingKeys: String, CodingKey {
        case items, versteckt, gesamt, frage, bemerkung
        case istEssen = "ist_essen"
    }

    var komponenten: [EssenKomponente] {
        items.map {
            EssenKomponente(
                name: $0.name, gramm: $0.gramm, kcalPro100: $0.kcalPro100, proteinPro100: $0.proteinPro100,
                kohlenhydratePro100: $0.kohlenhydratePro100, fettPro100: $0.fettPro100, sicherheit: $0.sicherheit
            )
        }
    }

    var versteckteListe: [EssenVersteckt] {
        versteckt.map { EssenVersteckt(name: $0.name, gramm: $0.gramm, kcal: $0.kcal) }
    }
}

struct KiBericht: Codable, Equatable, Sendable {
    let titel: String
    let kurzfassung: String
    let wasGut: [String]
    let wasBesser: [String]
    let morgen: [String]

    enum CodingKeys: String, CodingKey {
        case titel, kurzfassung, morgen
        case wasGut = "was_gut"
        case wasBesser = "was_besser"
    }
}
