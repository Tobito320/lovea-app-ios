import Foundation

/// Lesen und Schreiben der `zimmer.*`-Einstellungen. Jede Person schreibt nur ihre eigenen Schlüssel
/// (`EinstellungenModell.setzen`), beide lesen über `werte[person]`. Eigene Schreibvorgänge falten sofort lokal.
@MainActor
enum ZimmerRitualeDaten {
    static let vorhang = "zimmer.vorhang"
    static let tee = "zimmer.tee"
    static let halt = "zimmer.halt"
    static let kuss = "zimmer.kuss"
    static let kussGezaehlt = "zimmer.kussGezaehlt"
    static let keks = "zimmer.keks"
    static let wuensche = "zimmer.wuensche"
    static let erfuellt = "zimmer.erfuellt"

    struct KeksAntwort: Codable, Equatable {
        var tag: String
        var antwort: String
    }

    static var ich: Person { Raum.shared.ich ?? .ahmed }
    static var heute: String { Datum.text(Date()) }

    static func wert(_ schluessel: String, von person: Person) -> JSONValue? {
        EinstellungenModell.shared.werte[person]?[schluessel]
    }

    static func text(_ schluessel: String, von person: Person) -> String? {
        if case .string(let s) = wert(schluessel, von: person) { return s }
        return nil
    }

    static func zahl(_ schluessel: String, von person: Person) -> Double? {
        if case .number(let n) = wert(schluessel, von: person) { return n }
        return nil
    }

    static func datum(_ schluessel: String, von person: Person) -> Date? {
        zahl(schluessel, von: person).map { Date(timeIntervalSince1970: $0) }
    }

    /// Zusammengesetzte Werte liegen als JSON-Text in einem String-Schlüssel (hält `JSONValue` einfach).
    static func lesen<T: Decodable>(_ schluessel: String, von person: Person, als typ: T.Type) -> T? {
        guard let s = text(schluessel, von: person), let d = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }

    static func schreiben<T: Encodable>(_ schluessel: String, _ wert: T) {
        guard let d = try? JSONEncoder().encode(wert), let s = String(data: d, encoding: .utf8) else { return }
        EinstellungenModell.shared.setzen(schluessel, .string(s))
    }

    static func setzen(_ schluessel: String, text: String) { EinstellungenModell.shared.setzen(schluessel, .string(text)) }
    static func setzen(_ schluessel: String, zahl: Double) { EinstellungenModell.shared.setzen(schluessel, .number(zahl)) }

    // MARK: Abgeleitet

    /// Wer hat heute zuerst die Marke unter `schluessel` gesetzt?
    static func erster(_ schluessel: String) -> Person? {
        var marken: [Person: String] = [:]
        for p in Person.allCases { if let t = text(schluessel, von: p) { marken[p] = t } }
        return ZimmerRitualeLogik.erster(marken, tag: heute)
    }

    static func markeHeute(_ schluessel: String, von person: Person) -> Bool {
        ZimmerRitualeLogik.zerlegt(text(schluessel, von: person))?.tag == heute
    }

    static func markeSetzen(_ schluessel: String) {
        setzen(schluessel, text: ZimmerRitualeLogik.marke(tag: heute, zeit: Date()))
    }

    static func kuesse() -> Int {
        Person.allCases.reduce(0) { $0 + Int(zahl(kuss, von: $1) ?? 0) }
    }

    static func keksAntwort(von person: Person) -> String? {
        guard let a = lesen(keks, von: person, als: KeksAntwort.self), a.tag == heute else { return nil }
        return a.antwort
    }

    static func meineWuensche() -> [ZimmerRitualeLogik.Wunsch] {
        lesen(wuensche, von: ich, als: [ZimmerRitualeLogik.Wunsch].self) ?? []
    }

    static func partnerWuensche() -> [ZimmerRitualeLogik.Wunsch] {
        lesen(wuensche, von: ich.partner, als: [ZimmerRitualeLogik.Wunsch].self) ?? []
    }

    /// Ids der Wünsche von `wunschPerson`, die die andere Person heimlich als erfüllt markiert hat.
    static func erfuellteIds(von markierer: Person) -> [String] {
        lesen(erfuellt, von: markierer, als: [String].self) ?? []
    }

    // MARK: Hinweis nur einmal zeigen

    private static func hinweisSchluessel(_ art: String) -> String { "lovea.zimmer.hinweis.\(art).\(heute)" }

    static func hinweisNeu(_ art: String) -> Bool {
        UserDefaults.standard.string(forKey: hinweisSchluessel(art)) == nil
    }

    static func hinweisGesehen(_ art: String) {
        UserDefaults.standard.set("1", forKey: hinweisSchluessel(art))
    }
}
