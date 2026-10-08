import Foundation

/// p60: das Gefühl, das jemand gerade setzt. Erscheint als Blase über der eigenen Figur im Zimmer.
enum Stimmung: String, Codable, CaseIterable, Sendable {
    case muede, verliebt, gestresst, gluecklich, krank, vermisse

    var name: String {
        switch self {
        case .muede: "müde"
        case .verliebt: "verliebt"
        case .gestresst: "gestresst"
        case .gluecklich: "glücklich"
        case .krank: "krank"
        case .vermisse: "vermisse dich"
        }
    }
}

struct StimmungEintrag: Equatable, Sendable {
    /// `nil`: bewusst gelöscht.
    var art: Stimmung?
    var zeit: Date
    var opId: String
}

/// Ein Geschenkgedanke für den Partner. Liegt nur in der Box des Absenders (`von`).
struct Geschenk: Equatable, Identifiable, Sendable {
    var id: String
    var text: String
    var erledigt: Bool
    var von: Person
    var zeit: Date
    var opId: String
    /// Grabstein: eine ältere `setzen`-Op, die später eintrifft, holt den Eintrag nicht zurück.
    var geloescht = false
}

struct SignaleStand: Equatable, Sendable {
    var stimmung: [Person: StimmungEintrag] = [:]
    var geschenke: [String: Geschenk] = [:]
}

/// Reine Faltung der Paar-Signale, ohne `Raum` und ohne Oberfläche. Reihenfolgeunabhängig und
/// idempotent: je Schlüssel gewinnt die neueste Op (Zeit, dann Op-ID), doppelte Ops schaden nicht.
enum SignaleLogik {
    static let artStimmung = "stimmung.setzen"
    static let artGeschenk = "geschenkbox.setzen"
    static let artGeschenkWeg = "geschenkbox.loeschen"
    static let arten: Set<String> = [artStimmung, artGeschenk, artGeschenkWeg]

    /// Eine Stimmung gilt einen Tag, danach zeigt die Figur wieder keine Blase.
    static let stimmungGueltig: TimeInterval = 24 * 3600
    static let geschenkMaxZeichen = 140

    struct StimmungD: Codable { var art: String? }
    struct GeschenkD: Codable { var id: String; var text: String; var erledigt: Bool? }
    struct GeschenkWegD: Codable { var id: String }

    static func anwenden(_ ops: [Op], auf start: SignaleStand = SignaleStand()) -> SignaleStand {
        var z = start
        for op in ops {
            switch op.art {
            case artStimmung:
                guard let d = op.daten(StimmungD.self) else { continue }
                var art: Stimmung?
                if let roh = d.art, !roh.isEmpty {
                    // Eine Art, die diese App-Version nicht kennt, wird ignoriert statt als Löschen gelesen.
                    guard let bekannt = Stimmung(rawValue: roh) else { continue }
                    art = bekannt
                }
                if let alt = z.stimmung[op.von], !neuer(op.zeit, op.id, alsZeit: alt.zeit, id: alt.opId) { continue }
                z.stimmung[op.von] = StimmungEintrag(art: art, zeit: op.zeit, opId: op.id)
            case artGeschenk:
                guard let d = op.daten(GeschenkD.self) else { continue }
                let neu = Geschenk(id: d.id, text: d.text, erledigt: d.erledigt ?? false, von: op.von, zeit: op.zeit, opId: op.id)
                if let alt = z.geschenke[d.id], !neuer(op.zeit, op.id, alsZeit: alt.zeit, id: alt.opId) { continue }
                z.geschenke[d.id] = neu
            case artGeschenkWeg:
                guard let d = op.daten(GeschenkWegD.self) else { continue }
                if let alt = z.geschenke[d.id], !neuer(op.zeit, op.id, alsZeit: alt.zeit, id: alt.opId) { continue }
                z.geschenke[d.id] = Geschenk(id: d.id, text: "", erledigt: false, von: op.von, zeit: op.zeit, opId: op.id, geloescht: true)
            default:
                break
            }
        }
        return z
    }

    private static func neuer(_ zeit: Date, _ id: String, alsZeit alt: Date, id altId: String) -> Bool {
        zeit != alt ? zeit > alt : id > altId
    }

    /// Die Stimmung, die jetzt über `person` stehen soll, sonst nil (nie gesetzt, gelöscht, abgelaufen).
    static func stimmung(_ stand: SignaleStand, von person: Person, jetzt: Date) -> Stimmung? {
        guard let e = stand.stimmung[person], jetzt.timeIntervalSince(e.zeit) < stimmungGueltig else { return nil }
        return e.art
    }

    /// Die Box von `person`: nur ihre eigenen, nicht gelöschten Einträge, offene zuerst, je älteste zuerst.
    static func geschenke(_ stand: SignaleStand, von person: Person) -> [Geschenk] {
        stand.geschenke.values
            .filter { $0.von == person && !$0.geloescht }
            .sorted { ($0.erledigt ? 1 : 0, $0.zeit, $0.id) < ($1.erledigt ? 1 : 0, $1.zeit, $1.id) }
    }

    /// Kurzer Text ohne Rand, höchstens `n` Zeichen, nil wenn leer (Geschenkidee, Liebesbrief).
    static func kurz(_ eingabe: String, hoechstens n: Int) -> String? {
        let t = eingabe.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : String(t.prefix(n))
    }

    /// Ein Liebesbrief ist ein ganz normaler Brief (`BriefeSpeicher`), nur kurz und ohne "Öffne, wenn".
    static let liebesbriefTitel = "Ein Liebesbrief"
    static let liebesbriefMaxZeichen = 280

    /// Die Lampe: höchstens ein Tipp alle 10 Sekunden, sonst füllt Dauertippen die Leitung.
    static let lampePause: TimeInterval = 10
    static func lampeFrei(zuletzt: Date?, jetzt: Date) -> Bool {
        zuletzt.map { jetzt.timeIntervalSince($0) >= lampePause } ?? true
    }
}

/// Gute Nacht zu zweit: drücken beide, geht im Zimmer das Licht aus. Die Grüße kommen aus
/// `FigurenModell.gruss` (Op `gruss`), die Push dafür gibt es schon (`regeln.js` `grussRegel`).
enum NachtLogik {
    /// Eine Nacht beginnt um 18 Uhr (Berlin) und endet um 11 Uhr am nächsten Morgen.
    static let beginnStunde = 18
    static let dauer: TimeInterval = 17 * 3600

    typealias Gruesse = [Person: (nacht: Date?, morgen: Date?)]

    static func nachtBeginn(jetzt: Date, kalender: Calendar = .berlin) -> Date {
        let heute = kalender.date(bySettingHour: beginnStunde, minute: 0, second: 0, of: jetzt) ?? jetzt
        return heute <= jetzt ? heute : (kalender.date(byAdding: .day, value: -1, to: heute) ?? heute)
    }

    /// Hat `person` in der laufenden Nacht Gute Nacht gesagt?
    static func gedrueckt(_ person: Person, _ gruesse: Gruesse, jetzt: Date, kalender: Calendar = .berlin) -> Bool {
        guard jetzt.timeIntervalSince(nachtBeginn(jetzt: jetzt, kalender: kalender)) < dauer,
              let nacht = gruesse[person]?.nacht else { return false }
        return nacht >= nachtBeginn(jetzt: jetzt, kalender: kalender)
    }

    /// Beide haben gedrückt und keiner hat danach schon Guten Morgen gesagt.
    static func gemeinsamDunkel(_ gruesse: Gruesse, jetzt: Date, kalender: Calendar = .berlin) -> Bool {
        guard Person.allCases.allSatisfy({ gedrueckt($0, gruesse, jetzt: jetzt, kalender: kalender) }) else { return false }
        let spaeteste = Person.allCases.compactMap { gruesse[$0]?.nacht }.max() ?? .distantPast
        return !Person.allCases.contains { (gruesse[$0]?.morgen ?? .distantPast) > spaeteste }
    }

    /// Der Schalter im Zimmer ist ab 20 Uhr bis 4 Uhr da (wie der Knopf auf Home) und danach, solange
    /// in der Nacht schon jemand gedrückt hat, damit man den Stand sieht.
    static func schalterSichtbar(_ gruesse: Gruesse, jetzt: Date, kalender: Calendar = .berlin) -> Bool {
        let stunde = kalender.component(.hour, from: jetzt)
        return stunde >= 20 || stunde < 4 || Person.allCases.contains { gedrueckt($0, gruesse, jetzt: jetzt, kalender: kalender) }
    }
}
