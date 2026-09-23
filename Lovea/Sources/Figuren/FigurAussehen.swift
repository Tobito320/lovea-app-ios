import SwiftUI

struct FigurAussehen: Codable, Equatable, Sendable {
    var haut, frisur, haarfarbe, augen, brille, bart, oberteil, oberteilfarbe: Int

    static func standard(for person: Person) -> FigurAussehen {
        switch person {
        case .ahmed:
            FigurAussehen(haut: 3, frisur: 0, haarfarbe: 0, augen: 0, brille: 0, bart: 1, oberteil: 1, oberteilfarbe: 0)
        case .annika:
            FigurAussehen(haut: 1, frisur: 7, haarfarbe: 2, augen: 1, brille: 0, bart: 0, oberteil: 4, oberteilfarbe: 1)
        }
    }

    static let hautToene: [(name: String, farbe: FigurFarbe)] = [
        ("Porzellan", FigurFarbe(0xFFE3D3)), ("Hell", FigurFarbe(0xF9D3B8)),
        ("Pfirsich", FigurFarbe(0xEFC09B)), ("Honig", FigurFarbe(0xD9A273)),
        ("Karamell", FigurFarbe(0xC68A5B)), ("Zimt", FigurFarbe(0xA96F45)),
        ("Kakao", FigurFarbe(0x7F4F2F)), ("Espresso", FigurFarbe(0x5A3620)),
    ]

    static let frisuren = [
        "Kurz", "Raspel", "Seitenscheitel", "Locken", "Tolle", "Glatze",
        "Bob", "Lang glatt", "Lang wellig", "Pferdeschwanz", "Dutt", "Zöpfe",
    ]

    static let haarfarben: [(name: String, farbe: FigurFarbe)] = [
        ("Schwarz", FigurFarbe(0x221C1C)), ("Dunkelbraun", FigurFarbe(0x3B2A20)),
        ("Braun", FigurFarbe(0x6B4630)), ("Hellbraun", FigurFarbe(0x9A6B45)),
        ("Dunkelblond", FigurFarbe(0xB88B55)), ("Blond", FigurFarbe(0xE3C07A)),
        ("Rot", FigurFarbe(0xB5552B)), ("Grau", FigurFarbe(0xA8A8A8)),
        ("Rosa", FigurFarbe(0xF29BB5)), ("Lila", FigurFarbe(0x6E63C9)),
    ]

    static let augenfarben: [(name: String, farbe: FigurFarbe)] = [
        ("Dunkelbraun", FigurFarbe(0x3A2418)), ("Braun", FigurFarbe(0x6B4228)),
        ("Haselnuss", FigurFarbe(0x8A6A2E)), ("Grün", FigurFarbe(0x4F7D4A)),
        ("Blau", FigurFarbe(0x3F74B5)), ("Grau", FigurFarbe(0x6D7B86)),
    ]

    static let brillen = ["Keine", "Rund", "Eckig", "Sonnenbrille"]
    static let baerte = ["Keiner", "Stoppeln", "Schnurrbart", "Kinnbart", "Vollbart"]
    static let oberteile = ["T-Shirt", "Hoodie", "Hemd", "Pulli", "Top", "Jacke", "Trägertop", "Ringelshirt"]

    static let oberteilfarben: [(name: String, farbe: FigurFarbe)] = [
        ("Pflaume", FigurFarbe(0x6B2A4A)), ("Rosé", FigurFarbe(0xFF3B5C)),
        ("Weiß", FigurFarbe(0xF4F1EE)), ("Schwarz", FigurFarbe(0x2B2830)),
        ("Grau", FigurFarbe(0x8E8C93)), ("Marine", FigurFarbe(0x2C3E6B)),
        ("Himmelblau", FigurFarbe(0x7FB6E8)), ("Mint", FigurFarbe(0x8ED8BE)),
        ("Grün", FigurFarbe(0x3F7D52)), ("Gelb", FigurFarbe(0xF5CE5A)),
        ("Orange", FigurFarbe(0xF08A4B)), ("Lila", FigurFarbe(0x9B7BD8)),
    ]
}

/// Figure fill color; the outline color is derived from it.
struct FigurFarbe: Equatable, Sendable {
    let r: Double
    let g: Double
    let b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    private init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    var farbe: Color { Color(red: r, green: g, blue: b) }
    var kontur: Color { mal(0.55).farbe }

    func mal(_ f: Double) -> FigurFarbe { FigurFarbe(r: r * f, g: g * f, b: b * f) }

    func mix(_ o: FigurFarbe, _ t: Double) -> FigurFarbe {
        FigurFarbe(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
    }
}
