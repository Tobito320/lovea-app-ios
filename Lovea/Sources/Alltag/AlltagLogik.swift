import Foundation

/// p64: der eine Song auf dem Plattenspieler, für beide gleich. Neuer Song ersetzt den alten.
struct PlatteEintrag: Equatable, Sendable {
    /// Spotify-Titel-ID (22 Zeichen); der Link wird daraus gebaut, nie fremder Text.
    var id: String
    var titel: String
    var kuenstler: String?
    var cover: String?
    var von: Person
    var zeit: Date
    var opId: String

    var link: URL? { URL(string: AlltagLogik.spotifyLink(id)) }
}

/// Weckzeit einer Person in Minuten seit Mitternacht. `an == false`: kein Wecker gestellt.
struct WeckerEintrag: Equatable, Sendable {
    var minuten: Int?
    var an: Bool
    var zeit: Date
    var opId: String
}

/// Das Outfit-Foto am Spiegel. `medium == nil`: wieder abgehängt. Hängt nur an seinem Tag (`yyyy-MM-dd`).
struct OutfitEintrag: Equatable, Sendable {
    var medium: String?
    var tag: String
    var zeit: Date
    var opId: String
}

/// Ein Zettel am Kühlschrank, für beide gleich.
struct KuehlZettel: Equatable, Identifiable, Sendable {
    var id: String
    var text: String
    var erledigt: Bool
    /// TikTok- oder Instagram-Link (geprüft), tippen öffnet ihn.
    var link: String?
    var notiz: String?
    /// Medien-ID eines Essensbilds.
    var bild: String?
    var von: Person
    var zeit: Date
    var opId: String
    /// Grabstein: eine ältere `setzen`-Op, die später eintrifft, holt den Zettel nicht zurück.
    var geloescht = false
}

/// Gesendet nur vom Gerät, das die Freigabe in den Zyklus-Einstellungen hat. Kein Zyklus-Wort darin.
struct WaermeEintrag: Equatable, Sendable {
    var tag: String
    var an: Bool
    var zeit: Date
    var opId: String
}

struct AlltagStand: Equatable, Sendable {
    var platte: PlatteEintrag?
    var wecker: [Person: WeckerEintrag] = [:]
    var outfit: [Person: OutfitEintrag] = [:]
    var zettel: [String: KuehlZettel] = [:]
    var waerme: [Person: WaermeEintrag] = [:]
}

/// Reine Faltung des Paar-Alltags, ohne `Raum` und ohne Oberfläche. Wie `SignaleLogik`:
/// reihenfolgeunabhängig und idempotent, je Schlüssel gewinnt die neueste Op (Zeit, dann Op-ID).
enum AlltagLogik {
    static let artPlatte = "platte.setzen"
    static let artWecker = "wecker.setzen"
    static let artSpiegel = "spiegel.setzen"
    static let artZettel = "kuehl.setzen"
    static let artZettelWeg = "kuehl.weg"
    static let artWaerme = "waerme.setzen"
    static let arten: Set<String> = [artPlatte, artWecker, artSpiegel, artZettel, artZettelWeg, artWaerme]

    static let zettelMaxZeichen = 80
    static let notizMaxZeichen = 200
    /// So lange dreht sich die Platte im Zimmer, danach steht sie still (Akku).
    static let drehDauer: TimeInterval = 30

    struct PlatteD: Codable { var id: String; var titel: String; var kuenstler: String?; var cover: String? }
    struct WeckerD: Codable { var min: Int?; var an: Bool }
    struct SpiegelD: Codable { var medium: String?; var tag: String }
    struct ZettelD: Codable { var id: String; var text: String; var erledigt: Bool?; var link: String?; var notiz: String?; var bild: String? }
    struct ZettelWegD: Codable { var id: String }
    struct WaermeD: Codable { var tag: String; var an: Bool }

    static func anwenden(_ ops: [Op], auf start: AlltagStand = AlltagStand()) -> AlltagStand {
        var z = start
        for op in ops {
            switch op.art {
            case artPlatte:
                guard let d = op.daten(PlatteD.self), spotifyIdGueltig(d.id) else { continue }
                if let alt = z.platte, !SignaleLogik.neuer(op.zeit, op.id, alsZeit: alt.zeit, id: alt.opId) { continue }
                z.platte = PlatteEintrag(id: d.id, titel: d.titel, kuenstler: d.kuenstler, cover: d.cover, von: op.von, zeit: op.zeit, opId: op.id)
            case artWecker:
                guard let d = op.daten(WeckerD.self) else { continue }
                if let alt = z.wecker[op.von], !SignaleLogik.neuer(op.zeit, op.id, alsZeit: alt.zeit, id: alt.opId) { continue }
                z.wecker[op.von] = WeckerEintrag(minuten: d.min.flatMap { (0..<1440).contains($0) ? $0 : nil }, an: d.an, zeit: op.zeit, opId: op.id)
            case artSpiegel:
                guard let d = op.daten(SpiegelD.self) else { continue }
                if let alt = z.outfit[op.von], !SignaleLogik.neuer(op.zeit, op.id, alsZeit: alt.zeit, id: alt.opId) { continue }
                z.outfit[op.von] = OutfitEintrag(medium: d.medium, tag: d.tag, zeit: op.zeit, opId: op.id)
            case artZettel:
                guard let d = op.daten(ZettelD.self) else { continue }
                if let alt = z.zettel[d.id], !SignaleLogik.neuer(op.zeit, op.id, alsZeit: alt.zeit, id: alt.opId) { continue }
                z.zettel[d.id] = KuehlZettel(id: d.id, text: d.text, erledigt: d.erledigt ?? false, link: d.link.flatMap(zettelLink),
                                             notiz: d.notiz, bild: d.bild, von: op.von, zeit: op.zeit, opId: op.id)
            case artZettelWeg:
                guard let d = op.daten(ZettelWegD.self) else { continue }
                if let alt = z.zettel[d.id], !SignaleLogik.neuer(op.zeit, op.id, alsZeit: alt.zeit, id: alt.opId) { continue }
                z.zettel[d.id] = KuehlZettel(id: d.id, text: "", erledigt: false, von: op.von, zeit: op.zeit, opId: op.id, geloescht: true)
            case artWaerme:
                guard let d = op.daten(WaermeD.self) else { continue }
                if let alt = z.waerme[op.von], !SignaleLogik.neuer(op.zeit, op.id, alsZeit: alt.zeit, id: alt.opId) { continue }
                z.waerme[op.von] = WaermeEintrag(tag: d.tag, an: d.an, zeit: op.zeit, opId: op.id)
            default:
                break
            }
        }
        return z
    }

    // MARK: Plattenspieler

    static func spotifyLink(_ id: String) -> String { "https://open.spotify.com/track/" + id }

    static func spotifyIdGueltig(_ id: String) -> Bool {
        id.count == 22 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    /// Die Titel-ID aus eingefügtem Text: Link vom Teilen-Knopf (mit oder ohne `intl-de/`, mit `?si=`),
    /// `spotify:track:...`, auch mitten in einem längeren Text. Alben, Listen und Fremdes: nil.
    static func spotifyId(in text: String) -> String? {
        let klein = text.lowercased()
        guard klein.contains("spotify.com") || klein.contains("spotify:") else { return nil }
        for marke in ["spotify.com/", "spotify:"] {
            var rest = Substring(text)
            while let r = rest.range(of: marke, options: .caseInsensitive) {
                rest = rest[r.upperBound...]
                let teile = rest.prefix { !$0.isWhitespace && $0 != "?" && $0 != "#" }.split(whereSeparator: { $0 == "/" || $0 == ":" })
                // "intl-de" oder ähnliches überspringen, danach muss "track" und die ID kommen.
                let ohneSprache = teile.first?.hasPrefix("intl-") == true ? Array(teile.dropFirst()) : Array(teile)
                if ohneSprache.count >= 2, ohneSprache[0] == "track", spotifyIdGueltig(String(ohneSprache[1])) {
                    return String(ohneSprache[1])
                }
            }
        }
        return nil
    }

    private struct OEmbedD: Decodable { var title: String?; var thumbnail_url: String? }

    /// Titel und Cover aus der oEmbed-Antwort von Spotify (ohne Schlüssel). Cover nur von https.
    static func oembed(_ daten: Data) -> (titel: String, cover: String?)? {
        guard let d = try? JSONDecoder().decode(OEmbedD.self, from: daten),
              let titel = kurz(d.title ?? "", hoechstens: 120) else { return nil }
        return (titel, d.thumbnail_url.flatMap { $0.hasPrefix("https://") ? $0 : nil })
    }

    /// oEmbed liefert keinen Künstler. Der steht im Seitenkopf: `og:description` = "Künstler · Album · Song · Jahr".
    static func kuenstler(ausKopf kopf: String) -> String? {
        guard let marke = kopf.range(of: "og:description\" content=\"") else { return nil }
        let inhalt = kopf[marke.upperBound...].prefix { $0 != "\"" }
        let entschluesselt = inhalt
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
        guard let erster = entschluesselt.components(separatedBy: " · ").first else { return nil }
        return kurz(erster, hoechstens: 80)
    }

    // MARK: Wecker

    /// "6:45"; ohne gestellten Wecker nil.
    static func weckzeit(_ e: WeckerEintrag?) -> String? {
        guard let e, e.an, let m = e.minuten else { return nil }
        return String(format: "%ld:%02ld", m / 60, m % 60)
    }

    /// Wer steht zuerst auf: nur wenn beide einen Wecker haben und er nicht gleich liegt.
    static func fruehAufsteher(_ wecker: [Person: WeckerEintrag]) -> Person? {
        guard let a = wecker[.ahmed], let b = wecker[.annika], a.an, b.an, let ma = a.minuten, let mb = b.minuten, ma != mb else { return nil }
        return ma < mb ? .ahmed : .annika
    }

    static func aufstehSatz(ich: Person, _ wecker: [Person: WeckerEintrag]) -> String {
        guard weckzeit(wecker[.ahmed]) != nil, weckzeit(wecker[.annika]) != nil else { return "Noch nicht beide Wecker gestellt" }
        guard let erster = fruehAufsteher(wecker) else { return "Ihr steht zur gleichen Zeit auf" }
        return erster == ich ? "Du stehst zuerst auf" : "\(erster.name) steht zuerst auf"
    }

    // MARK: Spiegel

    /// Das Outfit von `person`, solange es heute hängt.
    static func outfit(_ stand: AlltagStand, von person: Person, heute: String) -> String? {
        guard let e = stand.outfit[person], e.tag == heute else { return nil }
        return e.medium
    }

    // MARK: Kühlschrank

    /// Offene zuerst, innerhalb davon die ältesten zuerst; Erledigte unten.
    static func zettelListe(_ stand: AlltagStand) -> [KuehlZettel] {
        stand.zettel.values
            .filter { !$0.geloescht }
            .sorted { ($0.erledigt ? 1 : 0, $0.zeit, $0.id) < ($1.erledigt ? 1 : 0, $1.zeit, $1.id) }
    }

    static func offene(_ stand: AlltagStand) -> Int { stand.zettel.values.filter { !$0.geloescht && !$0.erledigt }.count }

    /// Nur Links zu TikTok oder Instagram, nur https. Aus einem längeren Text wird das erste Wort mit https.
    static func zettelLink(_ eingabe: String) -> String? {
        let wort = eingabe.split(whereSeparator: \.isWhitespace).first { $0.lowercased().hasPrefix("https://") }
        guard let wort, let url = URL(string: String(wort)), url.scheme == "https", let host = url.host?.lowercased() else { return nil }
        let erlaubt = ["tiktok.com", "instagram.com", "instagr.am"]
        guard erlaubt.contains(where: { host == $0 || host.hasSuffix("." + $0) }) else { return nil }
        return url.absoluteString
    }

    // MARK: Wärmflasche und Tee

    /// Läuft nur auf dem Gerät mit dem Zyklus. Schwer: starke Blutung oder Krämpfe heute eingetragen,
    /// oder einer der ersten drei Periodentage. Das Ergebnis ist ein Ja oder Nein, mehr verlässt das Gerät nicht.
    static func schwererTag(tage: [ZyklusTag], einstellung: ZyklusEinstellung, heute: String) -> Bool {
        if let t = tage.first(where: { $0.id == heute }), t.blutung == .stark || t.symptome.contains(.kraempfe) { return true }
        let logik = ZyklusLogik(tage: tage, einstellung: einstellung, heute: heute)
        guard logik.phase(am: heute) == .periode, let nummer = logik.zyklusTagNummer(am: heute) else { return false }
        return nummer <= 3
    }

    /// Muss eine Op raus? Nur wenn sich der Stand für heute ändert; ausgeschaltet und nie gesendet: nichts.
    static func waermeSenden(soll: Bool, heute: String, bisher: WaermeEintrag?) -> Bool? {
        let aktuell = bisher.map { $0.tag == heute && $0.an } ?? false
        return soll == aktuell ? nil : soll
    }

    /// Steht heute Süßes und Tee auf dem Tisch? Für `person` = wer es gesendet hat.
    static func waermeAktiv(_ stand: AlltagStand, von person: Person, heute: String) -> Bool {
        stand.waerme[person].map { $0.tag == heute && $0.an } ?? false
    }

    // MARK: Text

    /// Kurzer Text ohne Rand, höchstens `n` Zeichen, nil wenn leer.
    static func kurz(_ eingabe: String, hoechstens n: Int) -> String? {
        SignaleLogik.kurz(eingabe, hoechstens: n)
    }
}
