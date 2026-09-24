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
        let zuhause: Bool? = e.zuhauseBekannt ? e.ort == .zuhause : nil
        if schlaeft(fokusSchlafen: e.fokus == "schlafen", guteNacht: e.guteNacht, gutenMorgen: e.gutenMorgen,
                    aktiv: e.aktiv, bewegt: e.bewegung != nil, zuhause: zuhause, jetzt: e.jetzt) { return .schlaeft }
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

    /// The one sleep rule (used here for the own state and by `ProfilSzene` for the partner):
    /// (sleep focus, OR a "Gute Nacht" since the last 20:00 not undone by "Guten Morgen" or by being
    /// active after 09:00) AND not moving AND (at the Home place, OR no Home place known: `nil`).
    static func schlaeft(fokusSchlafen: Bool, guteNacht: Date?, gutenMorgen: Date?, aktiv: Date?, bewegt: Bool, zuhause: Bool?, jetzt: Date) -> Bool {
        guard !bewegt, zuhause != false else { return false }
        return fokusSchlafen || guteNachtGilt(nacht: guteNacht, morgen: gutenMorgen, aktiv: aktiv, jetzt: jetzt)
    }

    static func guteNachtGilt(nacht: Date?, morgen: Date?, aktiv: Date?, jetzt: Date) -> Bool {
        guard let nacht, nacht >= letzte20Uhr(jetzt) else { return false }
        if let morgen, morgen > nacht { return false }
        if let aktiv, aktiv >= neunUhr(nach: nacht) { return false }
        return true
    }

    private static func letzte20Uhr(_ jetzt: Date) -> Date {
        let heute = berlin.date(bySettingHour: 20, minute: 0, second: 0, of: jetzt) ?? jetzt
        return heute <= jetzt ? heute : berlin.date(byAdding: .day, value: -1, to: heute) ?? heute
    }

    private static func neunUhr(nach d: Date) -> Date {
        let neun = berlin.date(bySettingHour: 9, minute: 0, second: 0, of: d) ?? d
        return neun > d ? neun : berlin.date(byAdding: .day, value: 1, to: neun) ?? neun
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
    // Brief G fix: the "Gute Nacht" half of the sleep rule.
    var guteNacht: Date?            // newest "Gute Nacht" gruss
    var gutenMorgen: Date?          // newest "Guten Morgen" gruss
    var aktiv: Date?                // last time the app was in the foreground
    var zuhauseBekannt = true       // a Home place is saved; `false` lets sleep count anywhere
}
