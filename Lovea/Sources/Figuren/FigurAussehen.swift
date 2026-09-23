import SwiftUI

/// Looks of one figure, synced as `figur.aussehen`. Every field is an index into the lists below.
/// v1 fields keep their meaning and their lists only grow at the end, so stored ops keep drawing the same.
/// v2 fields decode with defaults when missing (see `init(from:)`), and older builds ignore them.
struct FigurAussehen: Codable, Equatable, Sendable {
    // v1
    var haut = 0, frisur = 0, haarfarbe = 0, augen = 0, brille = 0, bart = 0, oberteil = 0, oberteilfarbe = 0
    // v2: Gesicht
    var gesichtsform = 0, augenform = 0, brauen = 0, nase = 0, mund = 0
    var wimpern = false, sommersprossen = false, muttermal = false, rouge = false
    // v2: Accessoires
    var ohrringe = 0, kopfbedeckung = 0, muetzenfarbe = 3
    // v2: Kleidung und Körper (Farben sind Indizes in `farben`)
    var jacke = 0, jackenfarbe = 3, hose = 1, hosenfarbe = 3, schuhe = 0, schuhfarbe = 2
    var koerperform = 1, groesse = 1

    enum CodingKeys: String, CodingKey {
        case haut, frisur, haarfarbe, augen, brille, bart, oberteil, oberteilfarbe
        case gesichtsform, augenform, brauen, nase, mund, wimpern, sommersprossen, muttermal, rouge
        case ohrringe, kopfbedeckung, muetzenfarbe
        case jacke, jackenfarbe, hose, hosenfarbe, schuhe, schuhfarbe, koerperform, groesse
    }

    static func standard(for person: Person) -> FigurAussehen {
        var a = FigurAussehen()
        switch person {
        case .ahmed:
            a.haut = 3
            a.frisur = 12        // Wuschelig
            a.haarfarbe = 0      // Schwarz
            a.augen = 0
            a.augenform = 1      // Mandel
            a.brauen = 2         // Dick
            a.bart = 3           // Kinnbart mit Schnurrbart
            a.oberteil = 1       // Hoodie
            a.oberteilfarbe = 4  // Grau
            a.hose = 1           // Jeans dunkel
            a.schuhe = 0
            a.schuhfarbe = 2     // Weiß
        case .annika:
            a.haut = 1
            a.frisur = 7         // Lang glatt
            a.haarfarbe = 1      // Dunkelbraun
            a.augen = 4          // Blau
            a.augenform = 1
            a.wimpern = true
            a.mund = 3           // Volle Lippen
            a.rouge = true
            a.ohrringe = 1
            a.oberteil = 4       // Top
            a.oberteilfarbe = 12 // Hellrosa
            a.jacke = 1          // Lederjacke
            a.jackenfarbe = 3    // Schwarz
            a.hose = 2           // Weite Jeans
            a.schuhe = 1         // High-Top
            a.schuhfarbe = 3     // Schwarz
        }
        return a
    }

    static let hautToene: [(name: String, farbe: FigurFarbe)] = [
        ("Porzellan", FigurFarbe(0xFFE3D3)), ("Hell", FigurFarbe(0xF9D3B8)),
        ("Pfirsich", FigurFarbe(0xEFC09B)), ("Honig", FigurFarbe(0xD9A273)),
        ("Karamell", FigurFarbe(0xC68A5B)), ("Zimt", FigurFarbe(0xA96F45)),
        ("Kakao", FigurFarbe(0x7F4F2F)), ("Espresso", FigurFarbe(0x5A3620)),
        ("Rosig", FigurFarbe(0xF3C6B0)), ("Oliv", FigurFarbe(0xC7A07A)),
        ("Bronze", FigurFarbe(0x8E5B3A)), ("Ebenholz", FigurFarbe(0x3E2518)),
    ]

    static let gesichtsformen = ["Oval", "Rund", "Herz", "Eckig", "Länglich", "Diamant"]

    static let frisuren = [
        "Kurz", "Raspel", "Seitenscheitel", "Locken", "Tolle", "Glatze",
        "Bob", "Lang glatt", "Lang wellig", "Pferdeschwanz", "Dutt", "Zöpfe",
        "Wuschelig", "Undercut", "Fade", "Mittelscheitel", "Pilzkopf", "Afro",
        "Man Bun", "Twists", "Lang mit Pony", "Lang lockig", "Schulterlang", "Hoher Zopf",
        "Space Buns", "Seitenzopf", "Halboffen", "Pixie", "Bob mit Pony", "Lang Seitenscheitel",
        "Irokese", "Locken mittellang", "Zwei Zöpfe", "Zurückgegelt",
    ]

    static let haarfarben: [(name: String, farbe: FigurFarbe, straehne: FigurFarbe?)] = [
        ("Schwarz", FigurFarbe(0x221C1C), nil), ("Dunkelbraun", FigurFarbe(0x3B2A20), nil),
        ("Braun", FigurFarbe(0x6B4630), nil), ("Hellbraun", FigurFarbe(0x9A6B45), nil),
        ("Dunkelblond", FigurFarbe(0xB88B55), nil), ("Blond", FigurFarbe(0xE3C07A), nil),
        ("Rot", FigurFarbe(0xB5552B), nil), ("Grau", FigurFarbe(0xA8A8A8), nil),
        ("Rosa", FigurFarbe(0xF29BB5), nil), ("Lila", FigurFarbe(0x6E63C9), nil),
        ("Platinblond", FigurFarbe(0xF1E6C8), nil), ("Kupfer", FigurFarbe(0xC7662F), nil),
        ("Blau", FigurFarbe(0x3D6FC2), nil),
        ("Schwarz mit Strähnen", FigurFarbe(0x221C1C), FigurFarbe(0xB88B55)),
        ("Braun mit Karamell", FigurFarbe(0x5A3A26), FigurFarbe(0xD9A26A)),
        ("Blond mit Strähnen", FigurFarbe(0xC89E5E), FigurFarbe(0xF4E3B5)),
    ]

    static let augenfarben: [(name: String, farbe: FigurFarbe)] = [
        ("Dunkelbraun", FigurFarbe(0x3A2418)), ("Braun", FigurFarbe(0x6B4228)),
        ("Haselnuss", FigurFarbe(0x8A6A2E)), ("Grün", FigurFarbe(0x4F7D4A)),
        ("Blau", FigurFarbe(0x3F74B5)), ("Grau", FigurFarbe(0x6D7B86)),
        ("Bernstein", FigurFarbe(0xB07A2A)), ("Hellblau", FigurFarbe(0x7FB0DD)),
    ]

    static let augenformen = ["Rund", "Mandel", "Groß", "Schmal", "Verträumt", "Hängend", "Katzenauge", "Klein"]
    static let augenbrauen = ["Natürlich", "Dünn", "Dick", "Gerade", "Hoch gebogen", "Buschig", "Kantig", "Kurz"]
    static let nasen = ["Klein", "Knopf", "Spitz", "Breit", "Stupsnase", "Lang"]
    static let muender = ["Lächeln", "Zahnlächeln", "Schmunzeln", "Volle Lippen", "Schmal", "Breit", "Lippenstift Rosé", "Lippenstift Rot"]

    static let brillen = [
        "Keine", "Rund", "Eckig", "Sonnenbrille", "Oval", "Cat-Eye", "Nerd", "Randlos",
        "Pilotenbrille", "Herz-Sonnenbrille", "Sport-Sonnenbrille",
    ]
    static let baerte = ["Keiner", "Stoppeln", "Schnurrbart", "Kinnbart", "Vollbart", "Ziegenbart", "Kinnriemen", "Langer Bart", "Koteletten"]
    static let ohrringArten = ["Keine", "Stecker", "Kreolen", "Hänger", "Perlen"]
    static let kopfbedeckungen = ["Keine", "Cap", "Cap rückwärts", "Beanie", "Fischerhut", "Stirnband", "Haarreif"]

    static let oberteile = [
        "T-Shirt", "Hoodie", "Hemd", "Pulli", "Top", "Jacke", "Trägertop", "Ringelshirt",
        "Kleid", "Polo", "Rollkragen", "Crop-Top", "Trikot", "Karohemd",
    ]
    static let jacken = ["Keine", "Lederjacke", "Jeansjacke", "Bomberjacke", "Blazer", "Pufferjacke"]
    static let hosen = ["Jeans hell", "Jeans dunkel", "Weite Jeans", "Stoffhose", "Jogginghose", "Cargohose", "Shorts", "Rock", "Minirock", "Leggings"]
    static let schuhArten = ["Sneaker", "High-Top", "Laufschuhe", "Stiefel", "Chelsea-Boots", "Sandalen", "Ballerinas", "Slipper"]
    static let koerperformen = ["Schlank", "Normal", "Kräftig"]
    static let groessen = ["Klein", "Mittel", "Groß"]

    /// Shared clothing palette: Oberteil, Jacke, Hose, Schuhe, Kopfbedeckung. The first 12 were the v1 top colors.
    static let farben: [(name: String, farbe: FigurFarbe)] = [
        ("Pflaume", FigurFarbe(0x6B2A4A)), ("Rosé", FigurFarbe(0xFF3B5C)),
        ("Weiß", FigurFarbe(0xF4F1EE)), ("Schwarz", FigurFarbe(0x2B2830)),
        ("Grau", FigurFarbe(0x8E8C93)), ("Marine", FigurFarbe(0x2C3E6B)),
        ("Himmelblau", FigurFarbe(0x7FB6E8)), ("Mint", FigurFarbe(0x8ED8BE)),
        ("Grün", FigurFarbe(0x3F7D52)), ("Gelb", FigurFarbe(0xF5CE5A)),
        ("Orange", FigurFarbe(0xF08A4B)), ("Lila", FigurFarbe(0x9B7BD8)),
        ("Hellrosa", FigurFarbe(0xF7B6C8)), ("Beige", FigurFarbe(0xD8C3A0)),
        ("Braun", FigurFarbe(0x7A5234)), ("Denim", FigurFarbe(0x4B6C98)),
    ]
}

extension FigurAussehen {
    /// Tolerant: every key is optional, so v1 JSON (8 keys) and future JSON both decode.
    init(from decoder: any Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func lies<T: Decodable>(_ k: CodingKeys, _ wert: inout T) throws {
            if let v = try c.decodeIfPresent(T.self, forKey: k) { wert = v }
        }
        try lies(.haut, &haut)
        try lies(.frisur, &frisur)
        try lies(.haarfarbe, &haarfarbe)
        try lies(.augen, &augen)
        try lies(.brille, &brille)
        try lies(.bart, &bart)
        try lies(.oberteil, &oberteil)
        try lies(.oberteilfarbe, &oberteilfarbe)
        try lies(.gesichtsform, &gesichtsform)
        try lies(.augenform, &augenform)
        try lies(.brauen, &brauen)
        try lies(.nase, &nase)
        try lies(.mund, &mund)
        try lies(.wimpern, &wimpern)
        try lies(.sommersprossen, &sommersprossen)
        try lies(.muttermal, &muttermal)
        try lies(.rouge, &rouge)
        try lies(.ohrringe, &ohrringe)
        try lies(.kopfbedeckung, &kopfbedeckung)
        try lies(.muetzenfarbe, &muetzenfarbe)
        try lies(.jacke, &jacke)
        try lies(.jackenfarbe, &jackenfarbe)
        try lies(.hose, &hose)
        try lies(.hosenfarbe, &hosenfarbe)
        try lies(.schuhe, &schuhe)
        try lies(.schuhfarbe, &schuhfarbe)
        try lies(.koerperform, &koerperform)
        try lies(.groesse, &groesse)
    }
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
