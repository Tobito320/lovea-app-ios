import Foundation

enum FigurZustand: String, Codable, Sendable, CaseIterable {
    // App
    case imChat, tippt, kamera, sprache, liest, schautBild, schautVideo, zeichnet, karte, spielt
    // Gerät
    case akkuLeer, laedt, offline, schlaeft, nichtStoeren
    // Bewegung
    case laeuft, rennt, rad, faehrt
    // Ort
    case zuhause, gym, schule, arbeit, fahrschule, supermarkt
    // Tageszeit
    case morgen, abend
    // Stimmung und Brauche
    case gut, mittel, schlecht, naehe, worte, ruhe
    // Geste
    case anstupsen, kuss, herz, lacht, anstossen, pokal
    // Ruhe
    case ruhig
    // Mimik (Runde 3): als Geste sendbar (`FigurGesten`), Reaktionen im Chat
    case zwinkert, verliebt, sauer, schmollt, verlegen, muede, ueberrascht, lachtTraenen, weint, denkt, feiert, schockiert, daumen, tanzt
    // Schlaf (Brief G fix 2): after "Gute Nacht" and 3 quiet minutes, sits up in bed yawning
    case sitztImBett

    /// The Runde-3 expressions, in picker order.
    static let mimik: [FigurZustand] = [
        .zwinkert, .verliebt, .lachtTraenen, .daumen, .feiert, .tanzt, .denkt,
        .ueberrascht, .schockiert, .verlegen, .schmollt, .sauer, .weint, .muede,
    ]

    var titel: String {
        switch self {
        case .imChat: "ist im Chat"
        case .tippt: "tippt"
        case .kamera: "macht ein Foto"
        case .sprache: "spricht eine Nachricht"
        case .liest: "liest"
        case .schautBild: "schaut ein Bild an"
        case .schautVideo: "schaut ein Video"
        case .zeichnet: "zeichnet"
        case .karte: "schaut auf die Karte"
        case .spielt: "spielt"
        case .akkuLeer: "Akku fast leer"
        case .laedt: "lädt"
        case .offline: "offline"
        case .schlaeft: "schläft"
        case .nichtStoeren: "nicht stören"
        case .laeuft: "läuft"
        case .rennt: "rennt"
        case .rad: "fährt Rad"
        case .faehrt: "fährt"
        case .zuhause: "zu Hause"
        case .gym: "im Gym"
        case .schule: "in der Schule"
        case .arbeit: "bei der Arbeit"
        case .fahrschule: "in der Fahrschule"
        case .supermarkt: "beim Einkaufen"
        case .morgen: "guten Morgen"
        case .abend: "Abend"
        case .gut: "gut drauf"
        case .mittel: "geht so"
        case .schlecht: "nicht so gut"
        case .naehe: "braucht Nähe"
        case .worte: "braucht Worte"
        case .ruhe: "braucht Ruhe"
        case .anstupsen: "stupst dich an"
        case .kuss: "schickt einen Kuss"
        case .herz: "denkt an dich"
        case .lacht: "lacht"
        case .anstossen: "stößt an"
        case .pokal: "hat gewonnen"
        case .ruhig: "entspannt"
        case .zwinkert: "zwinkert"
        case .verliebt: "ist verliebt"
        case .sauer: "ist sauer"
        case .schmollt: "schmollt"
        case .verlegen: "ist verlegen"
        case .muede: "ist müde"
        case .ueberrascht: "ist überrascht"
        case .lachtTraenen: "lacht Tränen"
        case .weint: "weint"
        case .denkt: "denkt nach"
        case .feiert: "feiert"
        case .schockiert: "ist schockiert"
        case .daumen: "Daumen hoch"
        case .tanzt: "tanzt"
        case .sitztImBett: "wird müde"
        }
    }

    private static let berlin: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return c
    }()

    /// Priority: Geste > offline > App > Ort > Bewegung > Gerät > Tageszeit > Brauche > Stimmung > ruhig.
    /// Abzeichen: "partyhut", "herzaugen", "outfit", "uhrwerk", "schnecke", "krone".
    static func bestimmen(_ e: FigurEingabe) -> (haupt: FigurZustand, abzeichen: [String]) {
        let heute = berlin.dateComponents([.month, .day, .hour], from: e.jetzt)
        var abzeichen: [String] = []
        let geburtstag = e.person == .ahmed ? (monat: 2, tag: 27) : (monat: 6, tag: 6)
        if heute.month == geburtstag.monat && heute.day == geburtstag.tag { abzeichen.append("partyhut") }
        if let jahrestag = e.jahrestag {
            let j = berlin.dateComponents([.month, .day], from: jahrestag)
            if j.month == heute.month && j.day == heute.day { abzeichen.append("herzaugen") }
        }
        if e.dateHeute { abzeichen.append("outfit") }
        if e.puenktlich == "uhrwerk" { abzeichen.append("uhrwerk") }
        if e.puenktlich == "troedel" { abzeichen.append("schnecke") }
        if e.monatsKrone { abzeichen.append("krone") }
        return (haupt(e, stunde: heute.hour ?? 12), abzeichen)
    }

    private static func haupt(_ e: FigurEingabe, stunde: Int) -> FigurZustand {
        if let geste = e.geste { return geste }
        // ponytail: offline sits above App and Ort (brief test "Offline schlägt Ort"); the spec lists Gerät below Ort.
        if !e.online { return .offline }
        if let app = e.app { return app }
        // Schlägt "zu Hause"; unterwegs oder an einem anderen Ort nie schlafend, dann nur "nicht stören".
        // Ohne gespeichertes Zuhause gilt man als zu Hause. Gerade in Bewegung zählt als Bewegung jetzt.
        let schlaf = SchlafLogik.zustand(
            guteNachtSeit: SchlafLogik.guteNachtSeit(nacht: e.guteNacht, morgen: e.gutenMorgen, jetzt: e.jetzt),
            fokusSchlafen: e.fokus == "schlafen", zuhause: !e.zuhauseBekannt || e.ort == .zuhause,
            letzteBewegung: e.bewegung != nil ? e.jetzt : e.letzteBewegung, jetzt: e.jetzt
        )
        switch schlaf {
        case .schlaeft: return .schlaeft
        case .sitzt: return .sitztImBett
        case .wach: break
        }
        if let ort = e.ort { return ort }
        if let bewegung = e.bewegung { return bewegung }
        if e.fokus != nil { return .nichtStoeren }
        if e.laedt { return .laedt }
        if let akku = e.akku, akku < 0.15 { return .akkuLeer }
        if e.morgenGeoeffnet && (5..<11).contains(stunde) { return .morgen }
        if stunde >= 21 || stunde < 5 { return .abend }
        if let brauche = e.brauche, let z = FigurZustand(rawValue: brauche) { return z }
        if let stimmung = e.stimmung, let z = FigurZustand(rawValue: stimmung) { return z }
        return .ruhig
    }
}

/// Brief G fix 2: where someone is on the way to sleep. `sitzt` = sits up in bed, yawning.
enum SchlafZustand: Sendable, Equatable {
    case wach, sitzt, schlaeft

    /// From a shared figure state (the partner sends `schlaeft` / `sitztImBett` with presence).
    init(_ z: FigurZustand?) {
        switch z {
        case .schlaeft?: self = .schlaeft
        case .sitztImBett?: self = .sitzt
        default: self = .wach
        }
    }
}

/// The one sleep decision, on the sleeper's own phone (`FigurZustand.bestimmen`); everyone else
/// reads the state it shares.
enum SchlafLogik {
    static let sitzenNach: TimeInterval = 3 * 60
    static let schlafenNach: TimeInterval = 5 * 60
    static let guteNachtHoechstens: TimeInterval = 12 * 3600
    /// Movement this recent still counts as moving for the sleep focus.
    static let ruheNoetig: TimeInterval = 60

    /// Not at Home: never asleep. Sleep focus and resting: asleep. After "Gute Nacht" (at most
    /// 12 h): still for 3 min sits up in bed, still for 5 min asleep; any movement starts over.
    static func zustand(guteNachtSeit: Date?, fokusSchlafen: Bool, zuhause: Bool, letzteBewegung: Date?, jetzt: Date) -> SchlafZustand {
        guard zuhause else { return .wach }
        let ruhe = letzteBewegung.map { jetzt.timeIntervalSince($0) } ?? .infinity
        if fokusSchlafen && ruhe >= ruheNoetig { return .schlaeft }
        guard let seit = guteNachtSeit, jetzt.timeIntervalSince(seit) <= guteNachtHoechstens else { return .wach }
        let still = min(jetzt.timeIntervalSince(seit), ruhe)
        if still >= schlafenNach { return .schlaeft }
        if still >= sitzenNach { return .sitzt }
        return .wach
    }

    /// The "Gute Nacht" that counts: said since the last 20:00 and not followed by "Guten Morgen".
    static func guteNachtSeit(nacht: Date?, morgen: Date?, jetzt: Date) -> Date? {
        guard let nacht, nacht >= letzte20Uhr(jetzt) else { return nil }
        if let morgen, morgen > nacht { return nil }
        return nacht
    }

    private static func letzte20Uhr(_ jetzt: Date) -> Date {
        let heute = Calendar.berlin.date(bySettingHour: 20, minute: 0, second: 0, of: jetzt) ?? jetzt
        return heute <= jetzt ? heute : Calendar.berlin.date(byAdding: .day, value: -1, to: heute) ?? heute
    }
}
/// Everything `bestimmen` looks at. States are passed as the matching `FigurZustand`.
struct FigurEingabe: Sendable {
    var person: Person
    var jetzt = Date()
    var geste: FigurZustand?        // anstupsen, kuss, herz, lacht, anstossen, pokal
    var app: FigurZustand?          // imChat … spielt
    var ort: FigurZustand?          // zuhause … supermarkt
    var bewegung: FigurZustand?     // laeuft, rennt, rad, faehrt
    var akku: Double?               // 0…1
    var laedt = false
    var online = true
    var fokus: String?              // "schlafen" or any other focus name
    var morgenGeoeffnet = false     // first open this morning
    var stimmung: String?           // "gut" | "mittel" | "schlecht"
    var brauche: String?            // "naehe" | "worte" | "ruhe"
    var jahrestag: Date?
    var dateHeute = false
    var puenktlich: String?         // "uhrwerk" | "charmant" | "troedel" | "weg"
    var monatsKrone = false
    // Brief G fix: inputs of `SchlafLogik`.
    var guteNacht: Date?            // newest "Gute Nacht" gruss
    var gutenMorgen: Date?          // newest "Guten Morgen" gruss
    var letzteBewegung: Date?       // last steps or walking/running/cycling
    var zuhauseBekannt = true       // a Home place is saved; `false` counts as at Home
}
