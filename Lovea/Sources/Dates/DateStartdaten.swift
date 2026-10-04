import Foundation

/// Startdaten aus der gemeinsamen Date-Notiz von Ahmed und Annika (Bauplan 04.10.2026).
///
/// Feste ID `start-<slug>` aus dem Titel und fester Zeitstempel `stempel`: zwei Handys, die beide
/// die Startdaten senden, erzeugen dieselben Objekte (kein Duplikat), und jede echte Änderung
/// (neuerer Zeitstempel) gewinnt immer gegen eine spät eintreffende Startfassung.
///
/// Zuordnung der Orte aus der Notiz (Entscheidung D2):
/// - Nordpark Düsseldorf: eigene, schon erledigte Idee "Nordpark / Japanischer Garten". Der Haken in der Notiz
///   gehört genau zu diesem Ausflug. An "Spazieren" gehängt würde eine offene Idee einen erledigten Ort tragen.
/// - Wildpark (Düsseldorf): an "Tierpark", dort ist der Wildpark gemeint. "Spazieren" bleibt ohne Ort.
/// - Café Classic Remise (Düsseldorf): an "Frühstücken zusammen".
/// - Eiffelturm bei Nacht (Paris): an "Reisen".
/// - 7th Space Köln: an "Ungewöhnliche Dates" (Kategorie Besonders).
/// Koordinate nur beim Eiffelturm (sicher bekannt). Die anderen tragen lat/lon 0, also nur den Namen,
/// bis jemand den Ort über die Suche setzt (`DateLogik.hatKoordinate`).
enum DateStartdaten {
    /// 2026-10-04 00:00 UTC.
    static let stempel = Date(timeIntervalSince1970: 1_791_072_000)
    static let schluessel = "lovea.dates.startGesendet"

    static func id(_ titel: String) -> String { "start-" + DateLogik.slug(titel) }

    private static func nurName(_ name: String, adresse: String? = nil) -> PunktOrt {
        PunktOrt(name: name, lat: 0, lon: 0, adresse: adresse)
    }

    private static let orte: [String: PunktOrt] = [
        "Nordpark / Japanischer Garten": nurName("Nordpark Düsseldorf", adresse: "Düsseldorf"),
        "Tierpark": nurName("Wildpark Düsseldorf", adresse: "Düsseldorf"),
        "Frühstücken zusammen": nurName("Café Classic Remise", adresse: "Düsseldorf"),
        "Reisen": PunktOrt(name: "Eiffelturm bei Nacht", lat: 48.8584, lon: 2.2945, adresse: "Paris"),
        "Ungewöhnliche Dates": nurName("7th Space Köln", adresse: "Köln"),
    ]

    private static let notizen: [String: String] = [
        "Ikea": "Wohnung, Einrichtung",
        "Quiz": "App, Fragen stellen",
    ]

    private static let tabelle: [(DateKategorie, [String])] = [
        (.essen, [
            "Acai Bowls", "All you can eat", "Eis essen", "Essen gehen", "Frühstücken zusammen", "Katzencafé",
            "Kopfrechnen plus Essen",
        ]),
        (.aktivitaet, [
            "Autodate", "Arcade", "Bowling", "Escape Room", "Eislaufen", "Fitnessstudio zusammen", "Freizeitpark",
            "Jahrmarkt", "Kino", "Lasertag", "Minigolf", "Neon Minigolf", "Seilbahn fahren", "Shoppen",
            "Tischtennis", "Trampolinpark", "Wasserpark", "Workout machen",
        ]),
        (.draussen, [
            "Abendspaziergang", "Alpaka Wanderung", "Blumen pflücken", "Erdbeeren pflücken", "Maislabyrinth",
            "Nordpark / Japanischer Garten", "Outdoor Kino", "Picknick", "Sonnenuntergang oder Sonnenaufgang anschauen",
            "Spazieren", "Tag am See", "Tierpark", "Zoo",
        ]),
        (.reisen, ["Autoreise übers Wochenende", "Reisen", "Urlaub planen"]),
        (.kreativ, [
            "Acrylbilder malen", "Fotoalben zusammen", "Fotos machen", "Leinwände bemalen", "Malen", "Zeichnen",
        ]),
        (.zuhause, [
            "Backen", "Brettspielabend", "Filmabend", "Ikea", "Lego bauen", "Movie-Marathon", "Puzzeln", "Quiz",
            "Spieleabend",
        ]),
        (.besonders, [
            "Krimi-Dinner", "Late-Night Drive", "Massage zusammen", "Schmuck gravieren lassen", "Ungewöhnliche Dates",
        ]),
    ]

    /// Nur "Nordpark / Japanischer Garten" ist abgehakt (ohne Datum, die Notiz nennt keins).
    static let erledigt: Set<String> = ["Nordpark / Japanischer Garten"]

    static let ideen: [DateIdee] = tabelle.flatMap { kategorie, titel in
        titel.map { t in
            DateIdee(
                id: id(t), titel: t, kategorie: kategorie, erledigt: erledigt.contains(t), ort: orte[t],
                notiz: notizen[t], geaendert: stempel, von: .ahmed
            )
        }
    }

    /// Startideen, die im Stand noch fehlen. Eine gelöschte Startidee steht noch im Stand und kommt nicht zurück.
    static func fehlende(in vorhandene: [String: DateIdee]) -> [DateIdee] {
        ideen.filter { vorhandene[$0.id] == nil }
    }
}
