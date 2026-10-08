import Foundation

/// p47: Teile, die aus dem Shop genommen wurden (Uhren, Schmuck, Brillen, Backdrops, Posen und Tänze,
/// dazu der Rest von Mode und Taschen). Wer eines gekauft hat, bekommt den Preis einmal zurück.
///
/// Ohne neue Op: `BesitzLogik` lehnt den Kauf ab, sobald der Katalog das Teil nicht mehr kennt, also
/// zählt sein Preis nicht mehr als ausgegeben und der Kontostand ist wieder voll. Hier kommt nur die
/// sichtbare Zeile im Verlauf dazu. Ihre ID ist aus der Kauf-Op-ID abgeleitet (`erstattung-<Kauf-ID>`),
/// sie wird bei jedem Start aus denselben Ops neu gefaltet und kann darum weder doppelt noch nur auf
/// einem Gerät auftauchen; die Ops kommen bei Neuinstallation aus dem Log zurück.
enum ShopErstattung {
    static let datum = "2026-10-08"

    /// Name und Preis jedes entfernten, käuflichen Teils (Katalogstand vor dem Aufräumen).
    static let entfernt: [String: (name: String, preis: Int)] = [
        "mode.tshirt-logo": ("Logo-Shirt", 300),
        "mode.jordan-shirt": ("Jordan Statement-Shirt", 1000),
        "mode.balenciaga-shirt": ("Balenciaga Shirt", 3200),
        "mode.bomberjacke": ("Bomberjacke", 850),
        "mode.pufferjacke-pelz": ("Pufferjacke mit Pelzkragen", 1800),
        "mode.dior-cape": ("Dior Cape", 4800),
        "mode.anzughose": ("Anzughose", 900),
        "mode.glitzerhose": ("Glitzerhose", 1100),
        "mode.balenciaga-hose": ("Balenciaga Hose", 3400),
        "mode.jordan-sneaker": ("Jordan Sneaker", 1900),
        "mode.gucci-sneaker": ("Gucci Sneaker", 4600),
        "mode.balenciaga-sneaker": ("Balenciaga Sneaker", 5000),
        "brille.sport": ("Sport-Sonnenbrille", 250),
        "brille.pilot-gold": ("Pilotenbrille Gold", 400),
        "brille.cartier-sonnenbrille": ("Cartier Sonnenbrille", 9000),
        "brille.prada-sonnenbrille": ("Prada Sonnenbrille", 3600),
        "brille.rahmenlos": ("Rahmenlose Luxusbrille", 1500),
        "brille.guess": ("Guess Cat-Eye Brille", 950),
        "tasche.stoffbeutel": ("Stoffbeutel", 180),
        "tasche.rucksack": ("Rucksack", 800),
        "tasche.prada-rucksack": ("Prada Rucksack", 5400),
        "tasche.lv-koffer": ("Louis Vuitton Koffer", 12000),
        "uhr.guess": ("Guess Uhr", 1200),
        "uhr.fossil": ("Fossil Uhr", 1400),
        "uhr.rolex": ("Rolex Datejust", 13000),
        "uhr.cartier": ("Cartier Uhr", 10500),
        "uhr.cartier-tank": ("Cartier Tank", 14000),
        "uhr.apple-style": ("Smartwatch", 900),
        "uhr.smart-sport": ("Sport-Smartwatch", 800),
        "schmuck.kette-silber": ("Silberkette", 300),
        "schmuck.kette-gold": ("Goldkette", 380),
        "schmuck.cartier-kette": ("Cartier Kette", 11000),
        "schmuck.perlenkette": ("Perlenkette", 950),
        "schmuck.tiffany-kette": ("Tiffany Kette", 8500),
        "schmuck.gold-kette": ("Statement-Goldkette", 1800),
        "backdrop.stadt-nacht": ("Stadt bei Nacht", 250),
        "backdrop.strand": ("Strand-Sonnenuntergang", 300),
        "backdrop.regen-fenster": ("Regen am Fenster", 220),
        "backdrop.neon": ("Neon-Skyline", 1200),
        "backdrop.konfetti": ("Konfetti-Party", 900),
        "backdrop.wolken-animiert": ("Wolken (animiert)", 3800),
        "backdrop.sternenhimmel-animiert": ("Sternenhimmel (animiert)", 4200),
        "backdrop.herbstwald": ("Herbstwald", 350),
        "pose.tanz1": ("Tanz: Groove", 1200),
        "pose.tanz2": ("Tanz: Welle", 1400),
        "pose.tanz3": ("Tanz: Hüftschwung", 1600),
        "pose.tanz4": ("Tanz: Flying", 1800),
        "pose.model": ("Model-Pose", 2000),
        "mode.gucci-web-shirt": ("Gucci Web-Shirt", 3400),
        "mode.dior-oblique-pulli": ("Dior Oblique-Pulli", 4400),
        "mode.lv-monogramm-hemd": ("Louis Vuitton Monogramm-Hemd", 5200),
        "mode.balenciaga-hoodie": ("Balenciaga Oversize-Hoodie", 3800),
        "mode.moncler-maya": ("Moncler Maya Steppjacke", 5800),
        "mode.chanel-tweed": ("Chanel Tweed-Jacke", 9500),
        "mode.prada-nylon": ("Prada Re-Nylon Jacke", 4600),
        "mode.gucci-ace": ("Gucci Ace Sneaker", 4200),
        "mode.balenciaga-triple-s": ("Balenciaga Triple S", 4800),
        "uhr.rolex-gmt": ("Rolex GMT-Master II", 14500),
        "schmuck.cartier-love": ("Cartier Love Armreif", 12000),
        "schmuck.cartier-love-ring": ("Cartier Love Ring", 8800),
        "schmuck.chanel-ohrringe": ("Chanel CC Ohrringe", 9200),
    ]

    /// Eine Erstattung als zwei Verlaufszeilen: der alte Kauf (minus, Datum des Kaufs) und die Rückgabe
    /// (plus, Datum der Aufräumaktion). Zusammen null, so passt der Verlauf zum vollen Kontostand.
    struct Erstattung: Equatable, Sendable {
        let id: String
        let kauf: PunkteLogik.Eintrag
        let rueckgabe: PunkteLogik.Eintrag
    }

    static func opId(_ kaufId: String) -> String { "erstattung-\(kaufId)" }

    /// Je angenommenem Kauf eines entfernten Teils genau eine Erstattung an den Zahler (`von`), auch bei
    /// Geschenken. `katalogPreis` ist der Preis im heutigen Katalog. Angenommen heißt: mit dem alten Preis
    /// wäre der Kauf durchgegangen, so wie damals gebucht.
    static func erstattungen(_ kaeufe: [BesitzLogik.Kauf], verdient: [Person: Int], katalogPreis: (String) -> Int?) -> [Erstattung] {
        let urteil = BesitzLogik.auswerten(kaeufe, verdient: verdient, preis: { katalogPreis($0) ?? entfernt[$0]?.preis })
        var gesehen = Set<String>()
        return kaeufe.sorted { $0.id < $1.id }.compactMap { kauf in
            guard let alt = entfernt[kauf.artikel], katalogPreis(kauf.artikel) == nil,
                  !urteil.abgelehnt.contains(kauf.id), gesehen.insert(kauf.id).inserted else { return nil }
            return Erstattung(
                id: opId(kauf.id),
                kauf: PunkteLogik.Eintrag(datum: Datum.text(kauf.zeit), von: kauf.von, grund: "Kauf: \(alt.name)", punkte: -alt.preis),
                rueckgabe: PunkteLogik.Eintrag(datum: datum, von: kauf.von, grund: "Erstattung: \(alt.name)", punkte: alt.preis)
            )
        }
    }
}
