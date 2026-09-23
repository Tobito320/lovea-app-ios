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

struct Ausnahme: Codable, Hashable, Identifiable {
    var person: String
    var datum: String
    var musterId: String?
    var status: String // "krank" | "urlaub" | "frei" | "verschoben"
    var bisDatum: String?
    var start: String?
    var ende: String?

    /// Der Schlüssel, nach dem `ausnahme.setzen` ersetzt und `ausnahme.loeschen` entfernt.
    var id: String { "\(person)|\(datum)|\(musterId ?? "")" }
}

/// Z-42.2: `d` von `ausnahme.loeschen {person, datum, musterId?}`, genau der Schlüssel, nach dem
/// `ausnahme.setzen` eine bestehende Ausnahme ersetzt.
struct AusnahmeSchluessel: Codable, Equatable {
    var person: String
    var datum: String
    var musterId: String?

    func passt(_ ausnahme: Ausnahme) -> Bool {
        ausnahme.person == person && ausnahme.datum == datum && ausnahme.musterId == musterId
    }
}

extension AusnahmeSchluessel {
    init(_ ausnahme: Ausnahme) {
        self.init(person: ausnahme.person, datum: ausnahme.datum, musterId: ausnahme.musterId)
    }
}

struct Termin: Codable, Hashable, Identifiable {
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

/// `d` von `treffen.setzen {datum, uhrzeit?, wasMachenWir?}`. `uhrzeit` fehlt: die alte bleibt
/// („Machen wir"); `uhrzeit` "": die Uhrzeit wird zurückgenommen (Z-42.2).
struct TreffenD: Codable, Equatable {
    var datum: String
    var uhrzeit: String?
    var wasMachenWir: String?
}

/// Der aktuelle Stand aller Kalender-Ops, gefaltet. Andere Blöcke bauen das aus Ops auf
/// (gelöschte Einträge sind hier bereits entfernt); dieser Block liest daraus nur.
struct KalenderDaten: Equatable {
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
    /// Nur bei `quelle == "termin"`: für „Zum iPhone-Kalender" pro Termin (Z-9.6).
    var terminId: String? = nil
    /// Nur bei `quelle == "muster"`: die Ausnahme, die auf den Block wirkt (Z-42.2: ändern oder
    /// zurücknehmen).
    var ausnahme: Ausnahme? = nil
}
