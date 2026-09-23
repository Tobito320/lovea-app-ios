import SwiftUI

/// Brief G: `profil.zimmer` per person, `{bett, wand, boden, deko: [String], rahmen: [{slot, medienId}]}`.
/// A fixed, designed room: one variant per slot, deco toggled on or off, up to 3 photo frames.
/// Reading is tolerant: anything unknown, missing or out of range falls back to the defaults.
struct Zimmer: Equatable, Sendable {
    struct Rahmen: Equatable, Sendable {
        var slot: Int
        var medienId: String
    }

    var bett = 0
    var wand = 0
    var boden = 0
    var deko = Zimmer.standardDeko
    var rahmen: [Rahmen] = []

    static let betten = ["Holz hell", "Holz dunkel", "Samt rosa", "Metall weiß", "Boxspring grau"]
    static let waende = ["Creme", "Rosa Streifen", "Salbei", "Himmelblau", "Lavendel", "Nachtblau"]
    static let boeden = ["Holz hell", "Holz dunkel", "Teppich creme", "Fliesen", "Teppich rosa"]
    static let dekoArten: [(id: String, name: String)] = [
        ("fenster", "Fenster"), ("teppich", "Teppich"), ("lampe", "Lampe"), ("pflanze", "Pflanze"),
        ("regal", "Regal"), ("lichterkette", "Lichterkette"), ("poster", "Poster"),
    ]
    static let standardDeko = ["fenster", "teppich", "lampe", "pflanze"]
    static let rahmenPlaetze = 3

    func hat(_ id: String) -> Bool { deko.contains(id) }

    func medien(_ slot: Int) -> String? { rahmen.first { $0.slot == slot }?.medienId }

    static func lesen(_ wert: JSONValue?) -> Zimmer {
        var z = Zimmer()
        guard case .object(let o)? = wert else { return z }
        func index(_ schluessel: String, _ anzahl: Int) -> Int? {
            guard case .number(let d)? = o[schluessel], d >= 0, d < Double(anzahl) else { return nil }
            return Int(d)
        }
        z.bett = index("bett", betten.count) ?? 0
        z.wand = index("wand", waende.count) ?? 0
        z.boden = index("boden", boeden.count) ?? 0
        if case .array(let liste)? = o["deko"] {
            let bekannt = Set(dekoArten.map(\.id))
            var gesehen = Set<String>()
            z.deko = liste.compactMap { eintrag -> String? in
                guard case .string(let id) = eintrag, bekannt.contains(id), gesehen.insert(id).inserted else { return nil }
                return id
            }
        }
        if case .array(let liste)? = o["rahmen"] {
            var belegt = Set<Int>()
            z.rahmen = liste.compactMap { eintrag -> Rahmen? in
                guard case .object(let r) = eintrag, case .number(let d)? = r["slot"], d >= 0, d < Double(rahmenPlaetze),
                      case .string(let id)? = r["medienId"], !id.isEmpty, belegt.insert(Int(d)).inserted else { return nil }
                return Rahmen(slot: Int(d), medienId: id)
            }
        }
        return z
    }

    var json: JSONValue {
        .object([
            "bett": .number(Double(bett)), "wand": .number(Double(wand)), "boden": .number(Double(boden)),
            "deko": .array(deko.map { .string($0) }),
            "rahmen": .array(rahmen.map { .object(["slot": .number(Double($0.slot)), "medienId": .string($0.medienId)]) }),
        ])
    }
}

@MainActor
extension Zimmer {
    static func von(_ person: Person) -> Zimmer { lesen(EinstellungenModell.shared.werte[person]?["profil.zimmer"]) }

    // ponytail: per person via `werte[person]` (like `profil.hintergrund`), not `geteilt` - that one
    // is last-wins across both, so one room would overwrite the other.
    func sichern() { EinstellungenModell.shared.setzen("profil.zimmer", json) }
}
