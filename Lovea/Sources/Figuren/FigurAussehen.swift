import SwiftUI

/// Z-24.1: `w`/`m` show only for that person, `n` (neutral) shows for both. Fixed per person, no switch (Spec §5).
enum FigurGeschlecht: String, Codable, Sendable { case w, m, n }

extension Person {
    var figurGeschlecht: FigurGeschlecht { self == .ahmed ? .m : .w }
}

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
    // v3 (Z-23.1/Z-24.2): getragene Shop-Teile, String-IDs aus `ShopKatalog`, nil = nichts.
    var tasche: String?, uhr: String?, schmuck: String?, pose: String?, tier: String?
    // v3 (Z-24.1): freie Farbwahl für Haare und Kleidung, Hex "RRGGBB". nil = weiter der Index oben.
    var haarfarbeHex: String?, oberteilfarbeHex: String?, jackenfarbeHex: String?, hosenfarbeHex: String?, schuhfarbeHex: String?
    // v4 (Z-39.3): freier Alltagsschmuck, Indizes in `ketten`/`ringe`/`armbaender`/`uhrenAlltag`, 0 = keiner.
    var kette = 0, ring = 0, armband = 0, uhrAlltag = 0
    // v5 (fix round 3): Kinnbart, combines with any mustache; index into `kinnbaerte`, 0 = none.
    var kinnbart = 0
    // v6 (fix round 4): several small moles on the cheeks, white AirPods in both ears.
    var muttermale = false, airpods = false
    /// Whose figure this is. Not synced (missing from `CodingKeys`): `standard(for:)` and
    /// `FigurenModell.aussehen(_:)` set it, so the drawing can dress Ahmed and Annika differently
    /// in the gym. `nil` = unknown, draws the chosen outfit.
    var person: Person?

    enum CodingKeys: String, CodingKey {
        case haut, frisur, haarfarbe, augen, brille, bart, oberteil, oberteilfarbe
        case gesichtsform, augenform, brauen, nase, mund, wimpern, sommersprossen, muttermal, rouge
        case ohrringe, kopfbedeckung, muetzenfarbe
        case jacke, jackenfarbe, hose, hosenfarbe, schuhe, schuhfarbe, koerperform, groesse
        case tasche, uhr, schmuck, pose, tier
        case haarfarbeHex, oberteilfarbeHex, jackenfarbeHex, hosenfarbeHex, schuhfarbeHex
        case kette, ring, armband, uhrAlltag
        case kinnbart
        case muttermale, airpods
    }

    /// Z-38.4: the looks of Ahmed's and Annika's Bitmojis (`docs/figuren-vorlage/`). Whoever never sent
    /// an own `figur.aussehen` sees these (`FigurenModell.aussehen`), the editor's "Wie mein Bitmoji" sets them.
    static func standard(for person: Person) -> FigurAussehen {
        var a = FigurAussehen()
        a.person = person
        switch person {
        case .ahmed:
            // Fix round 4: his real everyday look, after his photos and the ChatGPT stickers
            // (`design/ki/sticker/wir-ich.png`): long angular face, light warm skin with moles,
            // almost black curly cloud with a heavy fringe over a low taper, thick straight brows,
            // heavy relaxed lids, long nose, full light-pink lips, medium-brown mustache, a trace of
            // chin stubble, AirPods, black tee, grey wide jeans, white low tops.
            a.haut = 12          // Hell warm
            a.gesichtsform = 6   // Kantig lang
            a.frisur = 79        // Mushroom Taper (Locken-Wolke mit Pony)
            a.haarfarbe = 16     // Fast schwarz
            a.augen = 0          // Dunkelbraun
            a.augenform = 4      // Verträumt (schwere, entspannte Lider)
            a.brauen = 8         // Dick gerade
            a.nase = 5           // Lang
            a.mund = 8           // Lippen hellrosa
            a.bart = 14          // Oberlippenbart hellbraun
            a.kinnbart = 1       // Leichter Kinnbart
            a.muttermale = true
            a.airpods = true
            a.koerperform = 3    // Athletisch
            a.oberteil = 32      // Schwarzes Rundhals-Tee
            a.hose = 18          // Hellgraue Baggy-Jeans
            a.schuhe = 15        // Weiße Low-Top-Sneaker
        case .annika:
            a.haut = 1
            a.frisur = 56        // Lang glatt Mittelscheitel
            a.haarfarbe = 1      // Dunkelbraun
            a.augen = 4          // Blau
            a.augenform = 1
            a.wimpern = true
            a.mund = 3           // Volle Lippen
            a.rouge = true
            a.ohrringe = 1
            a.koerperform = 5    // Sportlich
            a.oberteil = 4       // Top
            a.oberteilfarbe = 12 // Hellrosa
            a.jacke = 1          // Lederjacke
            a.jackenfarbe = 3    // Schwarz
            a.hose = 1           // Jeans dunkel
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
        ("Hell warm", FigurFarbe(0xE8C2A6)), // Fix round 4 (Ahmed)
    ]

    static let gesichtsformen = ["Oval", "Rund", "Herz", "Eckig", "Länglich", "Diamant", "Kantig lang"]

    static let frisuren = [
        "Kurz", "Raspel", "Seitenscheitel", "Locken", "Tolle", "Glatze",
        "Bob", "Lang glatt", "Lang wellig", "Pferdeschwanz", "Dutt", "Zöpfe",
        "Wuschelig", "Undercut", "Fade", "Mittelscheitel", "Pilzkopf", "Afro",
        "Man Bun", "Twists", "Lang mit Pony", "Lang lockig", "Schulterlang", "Hoher Zopf",
        "Space Buns", "Seitenzopf", "Halboffen", "Pixie", "Bob mit Pony", "Lang Seitenscheitel",
        "Irokese", "Locken mittellang", "Zwei Zöpfe", "Zurückgegelt",
        // Z-38.3 (Runde 3): 22 für Ahmed (34–55), 22 für Annika (56–77), alle mit Strähnen und Glanzlicht.
        "Bitmoji-Pony", "Pony zerzaust kurz", "Curtains", "Quiff", "French Crop", "Buzz Cut mit Linie",
        "Seitenscheitel Fade", "Pompadour", "Spikes", "Undercut Schwung", "Slick Back", "Bro Flow",
        "Mittelscheitel lang", "Mullet", "Edgar", "Textured Crop", "Faux Hawk", "Waves",
        "Twists kurz", "Cornrows", "Top Knot", "Wuschel glatt",
        "Lang glatt Mittelscheitel", "Lang Stufen", "Curtain Bangs lang", "Beach Waves", "Sleek Pferdeschwanz", "Messy Bun",
        "Tiefer Dutt", "Halboffen mit Schleife", "Lob", "Bob gewellt", "Lang mit geradem Pony", "Seitlicher Fischgrätzopf",
        "Boxer Braids", "Volle Locken", "Hime Cut", "Wolf Cut", "Butterfly Cut", "Seitenscheitel hinters Ohr",
        "Hochsteckfrisur mit Spange", "Hoher Zopf mit Scrunchie", "Afro Puffs", "Lange Box Braids",
        // Fix round 3: Ahmed's own hairstyles from his photos (78–82), all with a taper fade.
        "Locken-Pony übers Auge", "Mushroom Taper", "Welliger Seitenschwung", "Fluffy Locken", "Gym Wet Look",
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
        ("Fast schwarz", FigurFarbe(0x241712), nil), // Fix round 4 (Ahmed)
    ]

    static let augenfarben: [(name: String, farbe: FigurFarbe)] = [
        ("Dunkelbraun", FigurFarbe(0x3A2418)), ("Braun", FigurFarbe(0x6B4228)),
        ("Haselnuss", FigurFarbe(0x8A6A2E)), ("Grün", FigurFarbe(0x4F7D4A)),
        ("Blau", FigurFarbe(0x3F74B5)), ("Grau", FigurFarbe(0x6D7B86)),
        ("Bernstein", FigurFarbe(0xB07A2A)), ("Hellblau", FigurFarbe(0x7FB0DD)),
    ]

    static let augenformen = ["Rund", "Mandel", "Groß", "Schmal", "Verträumt", "Hängend", "Katzenauge", "Klein", "Scharf"]
    static let augenbrauen = ["Natürlich", "Dünn", "Dick", "Gerade", "Hoch gebogen", "Buschig", "Kantig", "Kurz", "Dick gerade"]
    static let nasen = ["Klein", "Knopf", "Spitz", "Breit", "Stupsnase", "Lang"]
    static let muender = ["Lächeln", "Zahnlächeln", "Schmunzeln", "Volle Lippen", "Schmal", "Breit", "Lippenstift Rosé", "Lippenstift Rot", "Lippen hellrosa"]

    static let brillen = [
        "Keine", "Rund", "Eckig", "Sonnenbrille", "Oval", "Cat-Eye", "Nerd", "Randlos",
        "Pilotenbrille", "Herz-Sonnenbrille", "Sport-Sonnenbrille",
        "XL-Sonnenbrille Gold", "Rahmenlose Luxusbrille",
    ]
    static let baerte = [
        "Keiner", "Stoppeln", "Schnurrbart", "Kinnbart", "Vollbart", "Ziegenbart", "Kinnriemen", "Langer Bart", "Koteletten",
        "Fu-Manchu", "Anker-Bart", "Dichter Bart kurz", "Backenbart mit Schnurrbart",
        "Feiner Schnurrbart", "Oberlippenbart hellbraun", "Schnurrbart frisiert",
    ]
    /// Z-24.1: gender filter is fixed per person (Spec §5) — `n` shows for both, `m`/`w` only for that gender.
    /// Index-aligned with `frisuren`/`baerte`; new entries append at the end so stored indices never shift.
    static let frisurenGeschlecht: [FigurGeschlecht] = [
        // Fix round 2: every long style, braid, ponytail, bun and bob is female-only (Ahmed: "diese
        // richtig langen Haare sind weiblich"); only short/medium male-typical and unisex styles stay.
        .n, .n, .n, .n, .n, .m, .w, .w, .w, .w, .w, .w, .n, .m, .m, .n, .n, .n, .m, .n,
        .w, .w, .w, .w, .w, .w, .w, .w, .w, .w, .n, .w, .w, .n,
        .m, .m, .m, .m, .m, .m, .m, .m, .m, .m, .m, .m, .w, .m, .m, .m, .m, .m, .m, .m, .m, .m,
        .w, .w, .w, .w, .w, .w, .w, .w, .w, .w, .w, .w, .w, .w, .w, .w, .w, .w, .w, .w, .w, .w,
        .m, .m, .m, .m, .m,
    ]
    /// Ahmed: no half-bald looks. Styles drawn with `seitenFade` (skin-mixed sides) are hidden in the
    /// editor; a figure already wearing one keeps rendering it.
    static let halbglatze: Set<Int> = [13, 14, 30, 35, 37, 38, 40, 41, 43, 48, 49, 50, 52, 54]
    static let baerteGeschlecht: [FigurGeschlecht] = [.n, .m, .m, .m, .m, .m, .m, .m, .m, .m, .m, .m, .m, .m, .m, .m]
    static let ohrringArten = ["Keine", "Stecker", "Kreolen", "Hänger", "Perlen", "Diamant-Stecker", "Große Kreolen", "Herz-Hänger"]
    static let ohrringeGeschlecht: [FigurGeschlecht] = [.n, .n, .n, .n, .n, .n, .w, .w]
    static let kopfbedeckungen = ["Keine", "Cap", "Cap rückwärts", "Beanie", "Fischerhut", "Stirnband", "Haarreif", "Carhartt Beanie", "Trucker Cap"]

    static let oberteile = [
        "T-Shirt", "Hoodie", "Hemd", "Pulli", "Top", "Jacke", "Trägertop", "Ringelshirt",
        "Kleid", "Polo", "Rollkragen", "Crop-Top", "Trikot", "Karohemd",
        "Logo-Hoodie", "Statement-Shirt", "Seidenbluse",
        // Z-39.1 Alltagsmarken (frei), Z-39.2 Luxus (nur Shop, siehe `oberteileShop`).
        "H&M Basic-Shirt", "Zara Rippstrick-Top", "Nike Tech Fleece", "Nike Trikot", "Puma Shirt", "Stüssy Shirt",
        "Gucci Web-Shirt", "Dior Oblique-Pulli", "Louis Vuitton Monogramm-Hemd", "Balenciaga Oversize-Hoodie",
        // Aus Ahmeds und Annikas Fotos (frei), Zeichnung über `fotoOberteile`.
        "Weißes Kompressions-Longsleeve", "Schwarzes Kompressions-Tee", "Waldgrünes Oversize-Tee", "Weißes Rippen-Tank",
        // Fix round 3 (Ahmed's photos): 31 has its own drawing, 32 via `fotoOberteile`, 33 = bare torso.
        "Rosa Strickpulli mit Grafik", "Schwarzes Rundhals-Tee", "Oben ohne",
        // Fix round 4: Gymshark (own drawing with the logo).
        "Gymshark Tee schwarz", "Gymshark Longsleeve weiß",
    ]
    static let jacken = [
        "Keine", "Lederjacke", "Jeansjacke", "Bomberjacke", "Blazer", "Pufferjacke", "Pelzkragen-Jacke", "Cape",
        "Adidas Trainingsjacke", "The North Face Puffer", "Carhartt Jacke",
        "Moncler Maya", "Chanel Tweed-Jacke", "Prada Re-Nylon Jacke",
    ]
    static let hosen = [
        "Jeans hell", "Jeans dunkel", "Weite Jeans", "Stoffhose", "Jogginghose", "Cargohose", "Shorts", "Rock", "Minirock", "Leggings",
        "Anzughose", "Glitzerhose",
        "Adidas Trainingshose", "Levi's 501", "Nike Tech Fleece Jogger", "Puma Leggings",
        "Schwarze Gym-Shorts", "Hellgraue Wide-Jogger", "Hellgraue Baggy-Jeans",
        "Rosa Weite Jeans",
    ]
    static let schuhArten = [
        "Sneaker", "High-Top", "Laufschuhe", "Stiefel", "Chelsea-Boots", "Sandalen", "Ballerinas", "Slipper", "Logo-Sneaker", "Two-Tone-Sneaker",
        "Nike Air Force 1", "Adidas Samba", "New Balance 550",
        "Gucci Ace", "Balenciaga Triple S",
        "Weiße Low-Top-Sneaker",
    ]
    static let groessen = ["Klein", "Mittel", "Groß"]

    /// Z-38.2: body types in `koerperform` order, names and tags derived below so they never drift.
    /// `breite` scales the half-figure torso and `armHalb` its arms; `s`/`t`/`h` are the full-body
    /// shoulder/waist/hip half widths, `arm`/`bein` the limb thickness there. `muskel` (0…1) adds
    /// shoulder and biceps bulges plus chest lines, `kurve` (0…1) a bust line and an hourglass.
    struct Koerper: Sendable {
        let name: String
        let geschlecht: FigurGeschlecht
        let breite, armHalb, s, t, h, arm, bein, muskel, kurve: CGFloat
    }

    static let koerper: [Koerper] = [
        // Fix round 1: the types differ clearly at a glance (render board `figuren-koerper`); Normal is unchanged.
        Koerper(name: "Schlank", geschlecht: .n, breite: 0.86, armHalb: 0.86, s: 33, t: 24, h: 27, arm: 0.54, bein: 13, muskel: 0, kurve: 0),
        Koerper(name: "Normal", geschlecht: .n, breite: 1, armHalb: 1, s: 41, t: 30, h: 32, arm: 0.66, bein: 17, muskel: 0, kurve: 0),
        Koerper(name: "Kräftig", geschlecht: .m, breite: 1.16, armHalb: 1.14, s: 52, t: 50, h: 46, arm: 0.86, bein: 24, muskel: 0, kurve: 0),
        Koerper(name: "Athletisch", geschlecht: .m, breite: 1.2, armHalb: 1.16, s: 56, t: 29, h: 32, arm: 0.8, bein: 19, muskel: 0.7, kurve: 0),
        Koerper(name: "Muskulös", geschlecht: .n, breite: 1.32, armHalb: 1.4, s: 64, t: 36, h: 37, arm: 1, bein: 23, muskel: 1, kurve: 0),
        Koerper(name: "Sportlich", geschlecht: .w, breite: 0.95, armHalb: 0.96, s: 38, t: 23, h: 30, arm: 0.6, bein: 16, muskel: 0.35, kurve: 0.35),
        Koerper(name: "Kurvig", geschlecht: .w, breite: 1, armHalb: 1, s: 39, t: 25, h: 50, arm: 0.66, bein: 22, muskel: 0, kurve: 1),
    ]
    static let koerperformen = koerper.map(\.name)
    static let koerperformenGeschlecht = koerper.map(\.geschlecht)
    /// "Normal" stays for old looks but is hidden in the editor (Z-38.2).
    static let koerperformenVersteckt: Set<Int> = [1]

    /// Z-39.3: free everyday jewelry, 0 = none. The drawings live next to the names in `Zubehoer/SchmuckZeichner.swift`.
    static let ketten = ["Keine"] + alltagsKetten.map { $0.name }
    static let kettenGeschlecht = [FigurGeschlecht.n] + alltagsKetten.map { $0.geschlecht }
    static let ringe = ["Keiner"] + alltagsRinge.map { $0.name }
    static let ringeGeschlecht = [FigurGeschlecht.n] + alltagsRinge.map { $0.geschlecht }
    static let armbaender = ["Keins"] + alltagsArmbaender.map { $0.name }
    static let armbaenderGeschlecht = [FigurGeschlecht.n] + alltagsArmbaender.map { $0.geschlecht }
    static let uhrenAlltag = ["Keine"] + alltagsUhren.map { $0.name }
    /// Fix round 3: chin hair on its own, so it combines with every mustache (Bart tab, men only).
    static let kinnbaerte = ["Keiner", "Leichter Kinnbart", "Kinnbart"]

    /// Only "Kleid"/"Rock"/"Minirock", the Zara top and the Puma leggings are gender-tagged (Spec §5).
    static let oberteileGeschlecht: [FigurGeschlecht] = [
        .n, .n, .n, .n, .n, .n, .n, .n, .w, .n, .n, .n, .n, .n, .n, .n, .n,
        .n, .w, .n, .n, .n, .n, .n, .n, .n, .n,
        .m, .m, .m, .w,
        .m, .m, .m,
        .n, .n,
    ]
    static let hosenGeschlecht: [FigurGeschlecht] = [.n, .n, .n, .n, .n, .n, .n, .w, .w, .n, .n, .n, .n, .n, .n, .w, .m, .m, .m, .m]
    /// Z-23.1: indices appended for shop "mode"/"brille" items (`shopTeile` below) — hidden from the
    /// free editor and `zufall()` so buying is the only way to wear them.
    static let oberteileShop: Set<Int> = [14, 15, 16, 23, 24, 25, 26]
    static let jackenShop: Set<Int> = [6, 7, 11, 12, 13]
    static let hosenShop: Set<Int> = [10, 11]
    static let schuheShop: Set<Int> = [8, 9, 13, 14]
    static let brillenShop: Set<Int> = [11, 12]

    /// Indices of `liste` allowed for `person`: gender-appropriate (tag missing = always allowed)
    /// and not shop-only. Keeps the original index so a filtered tile still sets the right int.
    static func erlaubt<T>(_ liste: [T], geschlecht: [FigurGeschlecht] = [], shop: Set<Int> = [], fuer person: Person) -> [Int] {
        let g = person.figurGeschlecht
        return liste.indices.filter { i in
            !shop.contains(i) && (i >= geschlecht.count || geschlecht[i] == .n || geschlecht[i] == g)
        }
    }

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
        // Fix round 3: Ahmed's pink and deep black.
        ("Pink", FigurFarbe(0xF2A9BA)), ("Tiefschwarz", FigurFarbe(0x161617)),
        ("Bordeaux", FigurFarbe(0x4A1F24)), // Fix round 4: Ahmed's trucker cap
    ]
}

extension FigurAussehen {
    /// A look saved before v2 keeps its 8 fields on top of the person's v2 standard (outfit, face details).
    static func ausV1(_ alt: FigurAussehen, fuer person: Person) -> FigurAussehen {
        var a = standard(for: person)
        a.haut = alt.haut
        a.frisur = alt.frisur
        a.haarfarbe = alt.haarfarbe
        a.augen = alt.augen
        a.brille = alt.brille
        a.bart = alt.bart
        a.oberteil = alt.oberteil
        a.oberteilfarbe = alt.oberteilfarbe
        return a
    }

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
        try lies(.tasche, &tasche)
        try lies(.uhr, &uhr)
        try lies(.schmuck, &schmuck)
        try lies(.pose, &pose)
        try lies(.tier, &tier)
        try lies(.haarfarbeHex, &haarfarbeHex)
        try lies(.oberteilfarbeHex, &oberteilfarbeHex)
        try lies(.jackenfarbeHex, &jackenfarbeHex)
        try lies(.hosenfarbeHex, &hosenfarbeHex)
        try lies(.schuhfarbeHex, &schuhfarbeHex)
        try lies(.kette, &kette)
        try lies(.ring, &ring)
        try lies(.armband, &armband)
        try lies(.uhrAlltag, &uhrAlltag)
        try lies(.kinnbart, &kinnbart)
        try lies(.muttermale, &muttermale)
        try lies(.airpods, &airpods)
    }
}

/// Which int field a "mode"/"brille" shop item sets (see `FigurAussehen.shopTeile`).
/// ponytail: a plain enum instead of a `WritableKeyPath` — key paths carry Swift-6-Sendable risk
/// in a static global table, and CI is the only compiler here, so the simpler type wins.
enum ShopFeld: Sendable { case oberteil, jacke, hose, schuhe, brille }

extension FigurAussehen {
    /// Z-23.1: wears a purchased "mode"/"brille" shop item — those categories have no dedicated
    /// field, they reuse the existing int index (see `oberteileShop` etc.). Unknown ids are ignored.
    /// `tasche`/`uhr`/`schmuck`/`pose`/`tier` need no mapping, the shop id is stored directly.
    mutating func anziehen(_ artikelId: String) {
        guard let e = FigurAussehen.shopTeile[artikelId] else { return }
        // Always assign the hex (even nil): several ids share one (feld, index) with different
        // hex (e.g. `mode.tshirt-logo`/`mode.guess-hoodie`/`mode.nike-hoodie` all set `.oberteil`
        // 14) — leaving a stale hex from a PREVIOUS item would make Z-23.2's "is this worn?" check
        // match the wrong one of them.
        switch e.feld {
        case .oberteil: oberteil = e.index; oberteilfarbeHex = e.hex
        case .jacke: jacke = e.index; jackenfarbeHex = e.hex
        case .hose: hose = e.index; hosenfarbeHex = e.hex
        case .schuhe: schuhe = e.index; schuhfarbeHex = e.hex
        case .brille: brille = e.index // keine freie Farbe für Brillen
        }
    }

    /// ponytail: table-driven so a new "mode"/"brille" `ShopArtikel` needs one line here plus one
    /// new geometry case in `FigurView.swift` (or reuses an existing one with a different hex color).
    static let shopTeile: [String: (feld: ShopFeld, index: Int, hex: String?)] = [
        "mode.tshirt-logo": (.oberteil, 14, nil),
        "mode.guess-hoodie": (.oberteil, 14, "8E8C93"),
        "mode.nike-hoodie": (.oberteil, 14, "2B2830"),
        "mode.jordan-shirt": (.oberteil, 15, "2B2830"),
        "mode.balenciaga-shirt": (.oberteil, 15, nil),
        "mode.seidenbluse": (.oberteil, 16, nil),
        "mode.dior-bluse": (.oberteil, 16, "F4F1EE"),
        "mode.jeansjacke": (.jacke, 2, nil),
        "mode.bomberjacke": (.jacke, 3, nil),
        "mode.moncler-jacke": (.jacke, 6, "2C3E6B"),
        "mode.pufferjacke-pelz": (.jacke, 6, "2B2830"),
        "mode.dior-cape": (.jacke, 7, "F4F1EE"),
        "mode.cargohose": (.hose, 5, nil),
        "mode.anzughose": (.hose, 10, "2B2830"),
        "mode.glitzerhose": (.hose, 11, nil),
        "mode.balenciaga-hose": (.hose, 10, nil),
        "mode.nike-sneaker": (.schuhe, 8, nil),
        "mode.jordan-sneaker": (.schuhe, 8, "C8283F"),
        "mode.gucci-sneaker": (.schuhe, 9, "3F7D52"),
        "mode.balenciaga-sneaker": (.schuhe, 9, nil),
        "brille.sport": (.brille, 10, nil),
        "brille.pilot-gold": (.brille, 8, nil),
        "brille.cartier-sonnenbrille": (.brille, 11, nil),
        "brille.prada-sonnenbrille": (.brille, 11, nil),
        "brille.rahmenlos": (.brille, 12, nil),
        "brille.guess": (.brille, 5, nil),
        // Z-39.2: Luxus, eigene Indizes am Listenende (Zeichnung in `FigurView.swift`).
        "mode.gucci-web-shirt": (.oberteil, 23, "F4F1EE"),
        "mode.dior-oblique-pulli": (.oberteil, 24, "2C3E6B"),
        "mode.lv-monogramm-hemd": (.oberteil, 25, "6B4630"),
        "mode.balenciaga-hoodie": (.oberteil, 26, "2B2830"),
        "mode.moncler-maya": (.jacke, 11, "2C3E6B"),
        "mode.chanel-tweed": (.jacke, 12, "EFE6D6"),
        "mode.prada-nylon": (.jacke, 13, "2B2830"),
        "mode.gucci-ace": (.schuhe, 13, "F4F1EE"),
        "mode.balenciaga-triple-s": (.schuhe, 14, "D8C3A0"),
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

    /// Z-24.1 free color picker: parses "RRGGBB" or "#RRGGBB". `nil` for anything malformed, so a
    /// bad round-trip from `ColorPicker` never crashes rendering — the swatch index is used instead.
    init?(hex: String) {
        var s = Substring(hex)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(v)
    }

    /// "RRGGBB", no leading `#`. Values are clamped so an out-of-gamut round-trip stays a valid hex.
    var hex: String {
        let ziffern = Array("0123456789ABCDEF")
        func kanal(_ x: Double) -> String {
            let v = Swift.max(0, Swift.min(255, Int((x * 255).rounded())))
            return String([ziffern[v / 16], ziffern[v % 16]])
        }
        return kanal(r) + kanal(g) + kanal(b)
    }
}
