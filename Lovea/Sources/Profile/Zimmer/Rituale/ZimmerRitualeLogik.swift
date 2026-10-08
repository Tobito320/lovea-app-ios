import Foundation

/// Unser Zimmer, Worker D: die reine Rechnung hinter den Paar-Ritualen (Vorhang, Tee, Kussglas, Keks,
/// Wunschglas, Umarmung). Kein Zugriff auf Modelle, darum testbar. Zustand liegt als `zimmer.*`-Einstellung
/// je Person (jede Person schreibt nur ihre eigenen Schlüssel, beide lesen).
enum ZimmerRitualeLogik {
    // MARK: Tagesmarke (Vorhang, Tee)

    /// "yyyy-MM-dd|Sekunden": welcher Tag, und wann genau (wer war zuerst).
    static func marke(tag: String, zeit: Date) -> String { "\(tag)|\(Int(zeit.timeIntervalSince1970))" }

    static func zerlegt(_ marke: String?) -> (tag: String, zeit: Date)? {
        guard let marke else { return nil }
        let teile = marke.split(separator: "|")
        guard teile.count == 2, let sek = TimeInterval(teile[1]) else { return nil }
        return (String(teile[0]), Date(timeIntervalSince1970: sek))
    }

    /// Wer hat heute als Erste(r) gedrückt? `nil`, wenn heute noch niemand.
    static func erster(_ marken: [Person: String], tag: String) -> Person? {
        var beste: (Person, Date)?
        for (person, text) in marken {
            guard let z = zerlegt(text), z.tag == tag else { continue }
            if beste == nil || z.zeit < beste!.1 { beste = (person, z.zeit) }
        }
        return beste?.0
    }

    static func vorhangText(oeffner: Person?, ich: Person) -> String? {
        guard let oeffner else { return nil }
        return oeffner == ich ? "Guten Morgen, die Vorhänge sind auf" : "\(oeffner.name) hat die Vorhänge aufgemacht"
    }

    static func teeText(macher: Person?, ich: Person) -> String? {
        guard let macher else { return nil }
        return macher == ich ? "Tee für \(ich.partner.name) ist fertig" : "\(macher.name) hat dir Tee gemacht"
    }

    /// Die Vorhänge sind morgens zu, bis jemand sie aufmacht; ab Mittag hängen sie offen an der Seite.
    static func vorhangZu(offenHeute: Bool, stunde: Int) -> Bool { !offenHeute && (4..<12).contains(stunde) }

    // MARK: Kussglas

    static let kussFenster: TimeInterval = 10
    static let glasMaximum = 24

    /// Mein Halten zählt als Kuss, wenn die andere Person gerade eben auch gehalten hat und genau dieses Halten
    /// noch nicht gezählt wurde (sonst zählt ein zweites Halten kurz danach doppelt).
    static func kussZaehlt(meinHalt: Date, partnerHalt: Date?, schonGezaehlt: Date?) -> Bool {
        guard let partnerHalt else { return false }
        if let schonGezaehlt, partnerHalt <= schonGezaehlt { return false }
        return abs(meinHalt.timeIntervalSince(partnerHalt)) <= kussFenster
    }

    /// Hält die andere Person das Glas gerade?
    static func haeltGerade(halt: Date?, jetzt: Date) -> Bool {
        guard let halt else { return false }
        let d = jetzt.timeIntervalSince(halt)
        return d >= 0 && d <= kussFenster
    }

    /// Wie viele Herzen sichtbar im Glas liegen (das Glas bleibt endlich, die Zahl steht trotzdem im Label).
    static func glasHerzen(_ kuesse: Int) -> Int { min(max(kuesse, 0), glasMaximum) }

    // MARK: Keks

    /// Jeden Tag eine andere Frage, für beide dieselbe. Nach `anzahl` Tagen beginnt die Liste von vorn.
    static func fragenIndex(tag: String, anzahl: Int) -> Int {
        guard anzahl > 0, let tage = tageSeit1970(tag) else { return 0 }
        return ((tage % anzahl) + anzahl) % anzahl
    }

    static func tageSeit1970(_ tag: String) -> Int? {
        let t = tag.split(separator: "-").compactMap { Int($0) }
        guard t.count == 3 else { return nil }
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        guard let d = kal.date(from: DateComponents(year: t[0], month: t[1], day: t[2], hour: 12)) else { return nil }
        return Int((d.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    static let antwortMaximum = 140

    static func bereinigt(_ eingabe: String, maximal: Int) -> String? {
        let text = eingabe.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : String(text.prefix(maximal))
    }

    /// Antworten bleiben verdeckt, bis beide heute geantwortet haben.
    static func antwortenOffen(meine: String?, partner: String?) -> Bool {
        !(meine ?? "").isEmpty && !(partner ?? "").isEmpty
    }

    // MARK: Wunschglas

    static let wunschMaximum = 80
    static let wuenscheMaximum = 20

    struct Wunsch: Codable, Equatable, Identifiable {
        var id: String
        var text: String
    }

    static func wunschHinzu(_ liste: [Wunsch], text: String, id: String) -> [Wunsch] {
        guard liste.count < wuenscheMaximum, let t = bereinigt(text, maximal: wunschMaximum) else { return liste }
        return liste + [Wunsch(id: id, text: t)]
    }

    /// Heimlich erfüllt oder wieder zurück: schaltet die Wunsch-ID in der Liste um.
    static func umschalten(_ erfuellt: [String], id: String) -> [String] {
        erfuellt.contains(id) ? erfuellt.filter { $0 != id } : erfuellt + [id]
    }

    static func gold(_ wuensche: [Wunsch], erfuellt: [String]) -> Int {
        let ids = Set(erfuellt)
        return wuensche.filter { ids.contains($0.id) }.count
    }

    // MARK: Umarmung

    /// Beide haben das Profil offen: ich bin da, und vom Partner kam in den letzten Sekunden ein Lebenszeichen.
    static func umarmt(ichDa: Bool, partnerBis: Date, jetzt: Date) -> Bool { ichDa && partnerBis > jetzt }
}
