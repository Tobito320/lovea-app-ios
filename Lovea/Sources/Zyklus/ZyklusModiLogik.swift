import Foundation

/// Reine Rechnung für Schwanger, Kinderwunsch und Pille. Alle Tage sind `yyyy-MM-dd`.
enum ZyklusModiLogik {
    // MARK: Schwanger

    static let schwangerschaftsTage = 280

    struct SchwangerStand: Equatable {
        /// Vollendete Wochen seit dem ersten Tag der letzten Periode.
        let woche: Int
        /// Tage in der laufenden Woche, 0 bis 6.
        let tag: Int
        let trimester: Int
        let termin: String
        /// Negativ, wenn der Termin vorbei ist.
        let tageBisTermin: Int
    }

    /// Termin = Start + 280 Tage (Naegele). Ein eigener Termin vom Arzt hat Vorrang: dann zählt er minus 280 Tage als Start.
    static func schwangerStand(start: String, termin: String? = nil, heute: String) -> SchwangerStand {
        let beginn = termin.map { Datum.addTage($0, -schwangerschaftsTage) } ?? start
        let ende = termin ?? Datum.addTage(start, schwangerschaftsTage)
        let tage = max(Datum.tageZwischen(beginn, heute), 0)
        let woche = tage / 7
        return SchwangerStand(woche: woche, tag: tage % 7, trimester: trimester(woche: woche),
                              termin: ende, tageBisTermin: Datum.tageZwischen(heute, ende))
    }

    static func trimester(woche: Int) -> Int {
        woche < 14 ? 1 : (woche < 28 ? 2 : 3)
    }

    private static let groessen: [(ab: Int, name: String)] = [
        (4, "ein Mohnkorn"), (5, "ein Sesamkorn"), (6, "eine Linse"), (7, "eine Blaubeere"),
        (8, "eine Himbeere"), (9, "eine Kirsche"), (10, "eine Erdbeere"), (11, "eine Feige"),
        (12, "eine Limette"), (13, "eine Pfirsichhälfte"), (14, "eine Zitrone"), (15, "ein Apfel"),
        (16, "eine Avocado"), (17, "eine Birne"), (18, "eine Paprika"), (19, "eine Mango"),
        (20, "eine Banane"), (22, "eine Papaya"), (24, "ein Maiskolben"), (26, "ein Salatkopf"),
        (28, "eine Aubergine"), (30, "ein Kohlkopf"), (32, "eine Ananas"), (34, "eine Honigmelone"),
        (36, "ein Romanasalat"), (38, "ein Lauchbund"), (40, "eine kleine Wassermelone")
    ]

    /// Nil vor Woche 4.
    static func groessenVergleich(woche: Int) -> String? {
        groessen.last(where: { $0.ab <= woche })?.name
    }

    static func wochenText(_ stand: SchwangerStand) -> String {
        stand.tag == 0 ? "\(stand.woche). Woche" : "\(stand.woche). Woche, Tag \(stand.tag)"
    }

    // MARK: Kinderwunsch

    struct KinderwunschStand: Equatable {
        enum Lage: Equatable { case fruchtbar, eisprung, bald(tage: Int), vorbei, unbekannt }
        let lage: Lage
        let fenster: ClosedRange<String>?
        let eisprung: String?
        let positiveTests: Int
        let negativeTests: Int
    }

    static func kinderwunschStand(logik: ZyklusLogik, tage: [ZyklusTag], heute: String) -> KinderwunschStand {
        let fenster = logik.fruchtbaresFenster
        let eisprung = logik.eisprungTag
        let lage: KinderwunschStand.Lage
        if let fenster, let eisprung {
            if heute == eisprung { lage = .eisprung }
            else if fenster.contains(heute) { lage = .fruchtbar }
            else if heute < fenster.lowerBound { lage = .bald(tage: Datum.tageZwischen(heute, fenster.lowerBound)) }
            else { lage = .vorbei }
        } else {
            lage = .unbekannt
        }
        let seit = logik.letzterPeriodenStart ?? "0000-00-00"
        let imZyklus = tage.filter { $0.id >= seit && $0.id <= heute }
        return KinderwunschStand(lage: lage, fenster: fenster, eisprung: eisprung,
                                 positiveTests: imZyklus.filter { $0.eisprungTest == .positiv }.count,
                                 negativeTests: imZyklus.filter { $0.eisprungTest == .negativ }.count)
    }

    // MARK: Pille

    enum Packung: String, Codable, CaseIterable, Equatable {
        /// 21 Tage nehmen, 7 Tage Pause.
        case einundzwanzig
        /// 28 Tage nehmen, die letzten 7 sind Platzhalter ohne Wirkstoff.
        case achtundzwanzig

        var titel: String { self == .einundzwanzig ? "21 und 7 Tage Pause" : "28 Tage durchgehend" }
    }

    static let wirkstoffTage = 21
    static let packungsTage = 28

    struct PillenStand: Equatable {
        /// 1 bis 28.
        let tagInPackung: Int
        /// Heute eine Tablette nehmen (bei 28 auch Platzhalter).
        let nehmen: Bool
        /// Heute eine Tablette mit Wirkstoff.
        let wirkstoff: Bool
        /// Pausentag bei 21/7 oder Platzhaltertag bei 28.
        let pause: Bool
        /// Tage bis zum nächsten Pausenbeginn, 0 mitten in der Pause.
        let tageBisPause: Int
        /// Tage bis zum Start der nächsten Packung, 1 am letzten Tag.
        let tageBisNeuePackung: Int
    }

    static func pillenStand(start: String, packung: Packung, heute: String) -> PillenStand? {
        let d = Datum.tageZwischen(start, heute)
        guard d >= 0 else { return nil }
        let tag = d % packungsTage + 1
        let pause = tag > wirkstoffTage
        return PillenStand(tagInPackung: tag,
                           nehmen: !pause || packung == .achtundzwanzig,
                           wirkstoff: !pause,
                           pause: pause,
                           tageBisPause: pause ? 0 : wirkstoffTage + 1 - tag,
                           tageBisNeuePackung: packungsTage + 1 - tag)
    }

    /// Packungsstart: ein gesetzter Wert, sonst erster Periodentag, sonst frühester Pillen-Tag.
    static func pillenStart(gesetzt: String?, logik: ZyklusLogik, tage: [ZyklusTag]) -> String? {
        gesetzt ?? logik.letzterPeriodenStart ?? tage.filter { $0.pille == true }.map(\.id).min()
    }

    static func pilleGenommen(tage: [String: ZyklusTag], heute: String) -> Bool {
        tage[heute]?.pille == true
    }

    /// Tage in Folge bis heute (oder gestern, wenn heute noch offen), an denen die Pille eingetragen ist.
    static func pillenSerie(tage: [String: ZyklusTag], heute: String) -> Int {
        var tag = pilleGenommen(tage: tage, heute: heute) ? heute : Datum.addTage(heute, -1)
        var n = 0
        while tage[tag]?.pille == true { n += 1; tag = Datum.addTage(tag, -1) }
        return n
    }
}
