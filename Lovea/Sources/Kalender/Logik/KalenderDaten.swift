import Foundation

// Diese Typen spiegeln die `d`-Felder der Kalender-Ops aus schnittstellen.md 1:1, damit
// `JSONDecoder` den rohen Op-Body direkt hinein dekodieren kann. `Person` bleibt hier ein
// String ("ahmed"/"annika"), damit dieser Block unabhängig von Sync/Op.swift bleibt.

struct Muster: Codable, Hashable {
    var id: String
    var person: String
    var typ: String // "schule" | "arbeit" | "fahrschule" | "sonstiges"
    var titel: String
    var wochentage: [Int] // 1 = Montag … 7 = Sonntag
    var wochen: String // "alle" | "A" | "B"
    var start: String?
    var ende: String?
    var ab: String // yyyy-MM-dd
}

struct Ausnahme: Codable, Hashable {
    var person: String
    var datum: String
    var musterId: String?
    var status: String // "krank" | "urlaub" | "frei" | "verschoben"
    var bisDatum: String?
    var start: String?
    var ende: String?
}

struct Termin: Codable, Hashable {
    var id: String
    var fuer: [String]
    var titel: String
    var typ: String
    var datum: String
    var start: String?
    var ende: String?
}

struct Treffen: Codable, Hashable {
    var datum: String
    var uhrzeit: String?
    var wasMachenWir: String?
}

/// Der aktuelle Stand aller Kalender-Ops, gefaltet. Andere Blöcke bauen das aus Ops auf
/// (gelöschte Einträge sind hier bereits entfernt); dieser Block liest daraus nur.
struct KalenderDaten {
    var muster: [Muster] = []
    var ausnahmen: [Ausnahme] = []
    var termine: [Termin] = []
    var treffen: [Treffen] = []

    init(muster: [Muster] = [], ausnahmen: [Ausnahme] = [], termine: [Termin] = [], treffen: [Treffen] = []) {
        self.muster = muster
        self.ausnahmen = ausnahmen
        self.termine = termine
        self.treffen = treffen
    }
}

/// Ein Eintrag im Wochenplan eines Tages für eine Person.
struct Block: Equatable {
    var titel: String
    var typ: String
    var start: String?
    var ende: String?
    var status: String // "normal" | "krank" | "urlaub" | "frei" | "verschoben"
    var quelle: String // "muster" | "termin" | "treffen"
}
