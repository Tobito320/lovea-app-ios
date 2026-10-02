import Foundation

// Treffen mit Ablauf: Typen, Op-Körper und reine Funktionen. Kein `Raum`, kein UI.
// Überraschung: Der Partner bekommt nur `PlatzhalterD` (Id, Zeit, sichtbarAb). Der Inhalt geht als
// `GeheimHuelle` über `entwurf.setzen`, das der Server nur an die eigenen Geräte gibt.

struct PunktOrt: Codable, Hashable, Sendable {
    var name: String
    var lat: Double
    var lon: Double
    var adresse: String?
}

struct FreigabeWahl: Codable, Hashable, Sendable {
    enum Art: String, Codable, Hashable, Sendable { case tage, amTag, stunden }
    var art: Art
    var n: Int
}

struct TreffenPunkt: Identifiable, Hashable, Sendable {
    var id: String
    var datum: String
    var von: Person
    var start: String?
    var ende: String?
    var titel: String? // nil bei Platzhalter
    var notiz: String?
    var ort: PunktOrt?
    var versteckt: Bool
    var sichtbarAb: Date?
    var hatInhalt: Bool { titel != nil }
}

struct PunktEntwurf {
    var id: String?
    var datum: String
    var start: String?
    var ende: String?
    var titel: String
    var notiz: String
    var ort: PunktOrt?
    var ueberraschung: FreigabeWahl?
}

enum PunktAnsicht: Equatable {
    case voll
    case versteckt(ab: Date, gleich: Bool)
}

/// Der Inhalt eines versteckten Punkts, wie ihn nur der Ersteller kennt.
struct GeheimPunkt: Identifiable, Hashable, Sendable {
    var id: String
    var datum: String
    var start: String?
    var ende: String?
    var titel: String
    var notiz: String?
    var ort: PunktOrt?
    var sichtbarAb: Date
    var freigabe: FreigabeWahl
    /// Grabstein, auch für „nicht mehr offen" (schon öffentlich): bleibt gesetzt.
    var geloescht: Bool
    /// Zeit der Op, nach der `TreffenGeheimModell` die Fassungen ordnet.
    var zeit: Date
}

// MARK: - Op-Körper (`d`)

/// `treffen.punkt.setzen`: voller Inhalt, öffentlich.
struct PunktSetzenD: Codable, Equatable {
    var datum: String
    var id: String
    var start: String?
    var ende: String?
    var titel: String
    var notiz: String?
    var ort: PunktOrt?
}

/// `treffen.punkt.platzhalter`: bewusst ein eigener Typ ohne Inhaltsfelder, nicht einmal optionale.
struct PlatzhalterD: Codable, Equatable {
    var datum: String
    var id: String
    var start: String?
    var ende: String?
    /// ISO-8601 UTC ohne Sekundenbruch.
    var sichtbarAb: String

    init(datum: String, id: String, start: String?, ende: String?, sichtbarAb: String) {
        self.datum = datum
        self.id = id
        self.start = start
        self.ende = ende
        self.sichtbarAb = sichtbarAb
    }

    /// Nimmt nur Id, Datum, Zeit und `sichtbarAb` aus `punkt`.
    init(aus punkt: TreffenPunkt, sichtbarAb: Date) {
        self.init(datum: punkt.datum, id: punkt.id, start: punkt.start, ende: punkt.ende, sichtbarAb: TreffenZeit.text(sichtbarAb))
    }
}

/// `treffen.punkt.loeschen`.
struct PunktLoeschenD: Codable, Equatable {
    var datum: String
    var id: String
}

/// Der Inhalt in `entwurf.setzen`, unter dem Schlüssel `treffenGeheim`.
struct GeheimPunktD: Codable, Equatable {
    var datum: String
    var id: String
    var start: String?
    var ende: String?
    var titel: String
    var notiz: String?
    var ort: PunktOrt?
    var sichtbarAb: String
    var freigabe: FreigabeWahl
    var geloescht: Bool?
}

struct GeheimHuelle: Codable, Equatable {
    var treffenGeheim: GeheimPunktD
}

extension GeheimPunkt {
    init?(_ d: GeheimPunktD, zeit: Date) {
        guard let ab = TreffenZeit.datum(d.sichtbarAb) else { return nil }
        self.init(
            id: d.id, datum: d.datum, start: d.start, ende: d.ende, titel: d.titel, notiz: d.notiz, ort: d.ort,
            sichtbarAb: ab, freigabe: d.freigabe, geloescht: d.geloescht ?? false, zeit: zeit
        )
    }

    var wire: GeheimHuelle {
        GeheimHuelle(treffenGeheim: GeheimPunktD(
            datum: datum, id: id, start: start, ende: ende, titel: titel, notiz: notiz, ort: ort,
            sichtbarAb: TreffenZeit.text(sichtbarAb), freigabe: freigabe, geloescht: geloescht ? true : nil
        ))
    }

    var setzenD: PunktSetzenD {
        PunktSetzenD(datum: datum, id: id, start: start, ende: ende, titel: titel, notiz: notiz, ort: ort)
    }
}

enum TreffenZeit {
    // ponytail: gemeinsame Formatierer wie in ChatModell; ISO8601DateFormatter ist thread-safe.
    private nonisolated(unsafe) static let ganz = ISO8601DateFormatter()
    private nonisolated(unsafe) static let bruch: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated static func text(_ datum: Date) -> String { ganz.string(from: datum) }
    nonisolated static func datum(_ text: String) -> Date? { ganz.date(from: text) ?? bruch.date(from: text) }
}

// MARK: - Was gesendet wird

/// Eine Op, noch ohne Absender. `speichern` und `loeschen` sind rein: so prüfen Tests, was der
/// Partner zu sehen bekommt (alles außer `.geheim`).
enum TreffenSendung {
    case setzen(PunktSetzenD)
    case platzhalter(PlatzhalterD)
    case loeschen(PunktLoeschenD)
    case geheim(GeheimHuelle)

    var art: String {
        switch self {
        case .setzen: "treffen.punkt.setzen"
        case .platzhalter: "treffen.punkt.platzhalter"
        case .loeschen: "treffen.punkt.loeschen"
        case .geheim: "entwurf.setzen"
        }
    }

    /// Nur `.geheim` bleibt auf den eigenen Geräten (Server-Filter für `entwurf.setzen`).
    var gehtAnPartner: Bool {
        if case .geheim = self { return false }
        return true
    }

    func op(von: Person) -> Op {
        switch self {
        case .setzen(let d): Op.neu(art, d, von: von)
        case .platzhalter(let d): Op.neu(art, d, von: von)
        case .loeschen(let d): Op.neu(art, d, von: von)
        case .geheim(let d): Op.neu(art, d, von: von)
        }
    }
}

enum TreffenOps {
    /// Leere Zeit wird nil, `ende` nie vor `start`.
    nonisolated static func zeiten(start: String?, ende: String?) -> (start: String?, ende: String?) {
        let s = (start?.isEmpty ?? true) ? nil : start
        var e = (ende?.isEmpty ?? true) ? nil : ende
        if let ms = Datum.minuten(s), let me = Datum.minuten(e), me < ms { e = s }
        return (s, e)
    }

    /// Überraschung, noch nicht öffentlich, `sichtbarAb` in der Zukunft: Platzhalter für den Partner, Inhalt
    /// nur als `.geheim`. Sonst geht der volle Inhalt öffentlich raus (schon öffentlich bleibt öffentlich).
    nonisolated static func speichern(_ p: PunktEntwurf, id: String, jetzt: Date, schonOeffentlich: Bool) -> [TreffenSendung] {
        let z = zeiten(start: p.start, ende: p.ende)
        let notiz = p.notiz.isEmpty ? nil : p.notiz
        guard let wahl = p.ueberraschung, !schonOeffentlich else {
            return [.setzen(PunktSetzenD(datum: p.datum, id: id, start: z.start, ende: z.ende, titel: p.titel, notiz: notiz, ort: p.ort))]
        }
        let ab = TreffenLogik.freigabeZeit(wahl, datum: p.datum, start: z.start)
        if ab <= jetzt {
            return [.setzen(PunktSetzenD(datum: p.datum, id: id, start: z.start, ende: z.ende, titel: p.titel, notiz: notiz, ort: p.ort))]
        }
        let geheim = GeheimPunktD(
            datum: p.datum, id: id, start: z.start, ende: z.ende, titel: p.titel, notiz: notiz, ort: p.ort,
            sichtbarAb: TreffenZeit.text(ab), freigabe: wahl, geloescht: nil
        )
        let platzhalter = PlatzhalterD(datum: p.datum, id: id, start: z.start, ende: z.ende, sichtbarAb: geheim.sichtbarAb)
        return [.platzhalter(platzhalter), .geheim(GeheimHuelle(treffenGeheim: geheim))]
    }

    /// Löschen geht an beide; ein vorhandener Inhalt bekommt den Grabstein auf den eigenen Geräten.
    nonisolated static func loeschen(datum: String, id: String, geheim: GeheimPunkt?) -> [TreffenSendung] {
        var aus: [TreffenSendung] = [.loeschen(PunktLoeschenD(datum: datum, id: id))]
        if var g = geheim {
            g.geloescht = true
            aus.append(.geheim(g.wire))
        }
        return aus
    }

    /// Freigabe: der volle Inhalt, öffentlich, mit derselben Id.
    nonisolated static func freigeben(_ g: GeheimPunkt) -> TreffenSendung { .setzen(g.setzenD) }
}

// MARK: - Reine Funktionen

enum TreffenLogik {
    /// `von` = `treffen.uhrzeit`, sonst kleinster Start; `bis` = `treffen.bis`, sonst größtes Ende.
    nonisolated static func zeitraum(treffen: Treffen, punkte: [TreffenPunkt]) -> (von: String?, bis: String?) {
        let von = treffen.uhrzeit ?? punkte.compactMap(\.start).min { (Datum.minuten($0) ?? 0) < (Datum.minuten($1) ?? 0) }
        let bis = treffen.bis ?? punkte.compactMap(\.ende).max { (Datum.minuten($0) ?? 0) < (Datum.minuten($1) ?? 0) }
        return (von, bis)
    }

    nonisolated static func zeitText(von: String?, bis: String?) -> String? {
        switch (von, bis) {
        case let (v?, b?): "\(v)–\(b)"
        case let (v?, nil): "ab \(v)"
        case let (nil, b?): "bis \(b)"
        case (nil, nil): nil
        }
    }

    /// Nach Start (ohne Zeit ans Ende), dann Ende, dann Id: stabil.
    nonisolated static func sortiert(_ punkte: [TreffenPunkt]) -> [TreffenPunkt] {
        func schluessel(_ p: TreffenPunkt) -> (Int, Int, String) {
            (Datum.minuten(p.start) ?? Int.max, Datum.minuten(p.ende) ?? Int.max, p.id)
        }
        return punkte.sorted { schluessel($0) < schluessel($1) }
    }

    /// Voll nur, wenn der Inhalt da ist und der Punkt mir gehört oder öffentlich ist. Alles andere
    /// ist versteckt, auch ein eigener Platzhalter, dessen Inhalt noch fehlt.
    nonisolated static func ansicht(_ punkt: TreffenPunkt, ich: Person, jetzt: Date) -> PunktAnsicht {
        if punkt.hatInhalt, punkt.von == ich || !punkt.versteckt { return .voll }
        let ab = punkt.sichtbarAb ?? jetzt
        return .versteckt(ab: ab, gleich: jetzt >= ab)
    }

    /// Beginn des Treffens am `datum` (ohne `start`: 12:00), Zone `Datum.kalender`.
    nonisolated static func beginn(datum: String, start: String?) -> Date {
        zeitpunkt(datum, minuten: Datum.minuten(start) ?? 12 * 60)
    }

    private nonisolated static func zeitpunkt(_ datum: String, minuten m: Int) -> Date {
        let tag = Datum.datum(datum)
        return Datum.kalender.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: tag) ?? tag
    }

    /// tage: Beginn minus n·24 h; amTag: 08:00 am Tag, höchstens der Beginn; stunden: Beginn minus n h.
    /// Nie nach dem Beginn.
    nonisolated static func freigabeZeit(_ w: FreigabeWahl, datum: String, start: String?) -> Date {
        let anfang = beginn(datum: datum, start: start)
        let n = max(0, w.n)
        let ab: Date
        switch w.art {
        case .tage: ab = anfang.addingTimeInterval(-Double(n) * 24 * 3600)
        case .amTag: ab = min(zeitpunkt(datum, minuten: 8 * 60), anfang)
        case .stunden: ab = anfang.addingTimeInterval(-Double(n) * 3600)
        }
        return min(ab, anfang)
    }

    private nonisolated static func istOeffentlich(_ id: String, _ oeffentlich: [TreffenPunkt]) -> Bool {
        oeffentlich.contains { $0.id == id && $0.hatInhalt }
    }

    /// Offene Überraschungen: nicht gelöscht, nicht schon öffentlich mit Inhalt, jede Id einmal.
    nonisolated static func offene(_ geheim: [GeheimPunkt], _ oeffentlich: [TreffenPunkt], _ geloescht: Set<String>) -> [GeheimPunkt] {
        var gesehen: Set<String> = []
        return geheim.filter {
            !$0.geloescht && !geloescht.contains($0.id) && !istOeffentlich($0.id, oeffentlich) && gesehen.insert($0.id).inserted
        }
    }

    /// Fällig = `sichtbarAb <= jetzt`. Zwei Geräte oder doppelte Einträge ergeben eine Freigabe je Id.
    nonisolated static func faelligeFreigaben(geheim: [GeheimPunkt], oeffentlich: [TreffenPunkt], geloescht: Set<String>, jetzt: Date) -> [GeheimPunkt] {
        offene(geheim, oeffentlich, geloescht)
            .filter { $0.sichtbarAb <= jetzt }
            .sorted { ($0.sichtbarAb, $0.id) < ($1.sichtbarAb, $1.id) }
    }

    /// Die nächste Freigabe in der Zukunft, für den Schlaf-Timer. nil: nichts offen.
    nonisolated static func naechsteFaelligkeit(geheim: [GeheimPunkt], oeffentlich: [TreffenPunkt], geloescht: Set<String>, jetzt: Date) -> Date? {
        offene(geheim, oeffentlich, geloescht).map(\.sichtbarAb).filter { $0 > jetzt }.min()
    }

    /// Füllt eigene Platzhalter mit dem Inhalt; sie bleiben `versteckt`.
    nonisolated static func zusammengefuehrt(oeffentlich: [TreffenPunkt], geheim: [String: GeheimPunkt], ich: Person) -> [TreffenPunkt] {
        oeffentlich.map { p in
            guard p.von == ich, !p.hatInhalt, let g = geheim[p.id], !g.geloescht else { return p }
            var voll = p
            voll.titel = g.titel
            voll.notiz = g.notiz
            voll.ort = g.ort
            return voll
        }
    }

    /// „heute 09:00", „morgen 09:00", sonst „Sa. 3. Okt., 09:00".
    nonisolated static func freigabeText(ab: Date, jetzt: Date) -> String {
        let tag = Datum.text(ab)
        let uhr = Datum.uhrzeit(ab)
        switch Datum.tageZwischen(Datum.text(jetzt), tag) {
        case 0: return "heute \(uhr)"
        case 1: return "morgen \(uhr)"
        default:
            let wochentage = ["Mo.", "Di.", "Mi.", "Do.", "Fr.", "Sa.", "So."]
            let monate = ["Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sept.", "Okt.", "Nov.", "Dez."]
            let teile = Datum.kalender.dateComponents([.day, .month], from: ab)
            return "\(wochentage[Datum.wochentag(tag) - 1]) \(teile.day ?? 1). \(monate[(teile.month ?? 1) - 1]), \(uhr)"
        }
    }
}
