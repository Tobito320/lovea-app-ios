import Foundation

/// p63: Anlässe, zu denen sich das Zimmer schmückt. Reine Logik, keine Zeichnung: Datum -> Anlässe -> Deko.
/// Die Reihenfolge der Fälle ist die Vorrangfolge: Persönliches vor Feiertagen vor Jahreszeiten.
enum ZimmerAnlass: CaseIterable, Sendable {
    case geburtstagAhmed, geburtstagAnnika, jahrestag, monatstag, valentinstag
    case silvester, neujahr, weihnachten, nikolaus, advent, halloween, ostern
    case herbst, fruehling, sommer, schnee

    /// Alle Anlässe, die am Tag `tag` gelten, in Vorrangfolge. `jahrestag`: der Tag, an dem sie zusammenkamen.
    static func aktive(am tag: Date, jahrestag: Date? = nil) -> [ZimmerAnlass] {
        allCases.filter { $0.gilt(am: tag, jahrestag: jahrestag) }
    }

    private func gilt(am tag: Date, jahrestag: Date?) -> Bool {
        let k = Calendar.berlin
        let heute = k.dateComponents([.year, .month, .day], from: tag)
        let monat = heute.month ?? 1
        switch self {
        case .geburtstagAhmed: return Self.nahe(tag, BesondereTage.geburtstag(.ahmed), davor: 1, danach: 0)
        case .geburtstagAnnika: return Self.nahe(tag, BesondereTage.geburtstag(.annika), davor: 1, danach: 0)
        case .jahrestag:
            guard let jahrestag else { return false }
            let j = k.dateComponents([.year, .month, .day], from: jahrestag)
            return j.month == heute.month && j.day == heute.day && (heute.year ?? 0) > (j.year ?? 0)
        case .monatstag:
            guard let jahrestag, tag > jahrestag else { return false }
            let j = k.dateComponents([.month, .day], from: jahrestag)
            if j.month == heute.month && j.day == heute.day { return false }
            let tageImMonat = k.range(of: .day, in: .month, for: tag)?.count ?? 28
            return heute.day == min(j.day ?? 1, tageImMonat)
        case .valentinstag: return Self.nahe(tag, (2, 14), davor: 1, danach: 0)
        case .silvester: return Self.nahe(tag, (12, 31), davor: 1, danach: 0)
        case .neujahr: return Self.nahe(tag, (1, 1), davor: 0, danach: 1)
        case .weihnachten: return Self.nahe(tag, (12, 24), davor: 0, danach: 2)
        case .nikolaus: return Self.nahe(tag, (12, 6), davor: 1, danach: 0)
        case .advent: return Self.adventskerzen(am: tag) > 0
        case .halloween: return Self.nahe(tag, (10, 31), davor: 6, danach: 0)
        case .ostern:
            let bis = Self.tage(von: tag, bis: Feiertage.osterSonntag(jahr: heute.year ?? 2026))
            return (-1...6).contains(bis)
        case .herbst: return (9...11).contains(monat)
        case .fruehling: return (3...5).contains(monat)
        case .sommer: return (6...8).contains(monat)
        case .schnee: return monat == 12 || monat <= 2
        }
    }

    /// Ganze Tage von `a` bis `b` (positiv: `b` liegt später).
    static func tage(von a: Date, bis b: Date) -> Int {
        let k = Calendar.berlin
        return k.dateComponents([.day], from: k.startOfDay(for: a), to: k.startOfDay(for: b)).day ?? 0
    }

    /// `tag` liegt im Fenster um den Festtag: höchstens `davor` Tage vorher, höchstens `danach` Tage nachher.
    private static func nahe(_ tag: Date, _ fest: (monat: Int, tag: Int), davor: Int, danach: Int) -> Bool {
        let k = Calendar.berlin
        let jahr = k.component(.year, from: tag)
        return (jahr - 1...jahr + 1).contains { j in
            guard let ziel = k.date(from: DateComponents(year: j, month: fest.monat, day: fest.tag)) else { return false }
            return (-danach...davor).contains(tage(von: tag, bis: ziel))
        }
    }

    /// Brennende Kerzen am Adventskranz: 0 vor dem 1. Advent und ab dem 24.12., sonst 1 bis 4.
    static func adventskerzen(am tag: Date) -> Int {
        let k = Calendar.berlin
        let c = k.dateComponents([.year, .month, .day], from: tag)
        guard let jahr = c.year, c.month == 11 || c.month == 12 else { return 0 }
        guard let heiligabend = k.date(from: DateComponents(year: jahr, month: 12, day: 24)),
              let vierter = k.date(byAdding: .day, value: -((k.component(.weekday, from: heiligabend) - 1) % 7), to: heiligabend)
        else { return 0 }
        let seit = tage(von: vierter, bis: tag)
        if seit < -21 || tage(von: tag, bis: heiligabend) <= 0 { return 0 }
        return min(max((seit + 21) / 7 + 1, 1), 4)
    }
}

/// Was im Zimmer hängt und steht. Fünf Plätze, jeder Anlass füllt seine; der wichtigste Anlass gewinnt den Platz.
struct ZimmerDeko: Equatable, Sendable {
    enum Girlande: Sendable { case wimpel, herzen, lichter, blaetter, blumen, eier, fledermaeuse, luftschlangen }
    enum Boden: Sendable { case geschenke, tannenbaum, kuerbisse, gruselkuerbis, osterkorb, blumentopf, stiefel, strandball }
    enum Luft: Sendable { case ballons, herzballons, goldballons }
    enum Streu: Sendable { case konfetti, herzen, schnee, schmetterlinge, blaetter }
    enum Fenster: Sendable { case torte, kerzen, rose, osterhase, tulpen, sonnenblume, laterne, geist, adventskranz, stern, sektglaeser, kleeblatt, schneehaube }

    var girlande: Girlande?
    var boden: Boden?
    var luft: Luft?
    var streu: Streu?
    var fenster: Fenster?
    /// Brennende Kerzen des Adventskranzes.
    var kerzen = 0

    var leer: Bool { girlande == nil && boden == nil && luft == nil && streu == nil && fenster == nil }

    static func fuer(_ anlaesse: [ZimmerAnlass], kerzen: Int = 0) -> ZimmerDeko {
        var d = ZimmerDeko(kerzen: kerzen)
        for a in anlaesse {
            let t = a.teile
            d.girlande = d.girlande ?? t.girlande
            d.boden = d.boden ?? t.boden
            d.luft = d.luft ?? t.luft
            d.streu = d.streu ?? t.streu
            d.fenster = d.fenster ?? t.fenster
        }
        return d
    }

    /// Die Deko für einen Tag.
    static func fuer(tag: Date, jahrestag: Date? = nil) -> ZimmerDeko {
        fuer(ZimmerAnlass.aktive(am: tag, jahrestag: jahrestag), kerzen: ZimmerAnlass.adventskerzen(am: tag))
    }
}

extension ZimmerAnlass {
    /// Was dieser Anlass beisteuert (Reihenfolge: Girlande, Boden, Luft, Streu, Fenster).
    fileprivate var teile: ZimmerDeko {
        switch self {
        case .geburtstagAhmed, .geburtstagAnnika:
            ZimmerDeko(girlande: .wimpel, boden: .geschenke, luft: .ballons, streu: .konfetti, fenster: .torte)
        case .jahrestag:
            ZimmerDeko(girlande: .herzen, boden: .geschenke, luft: .herzballons, streu: .herzen, fenster: .kerzen)
        case .monatstag:
            ZimmerDeko(girlande: .herzen, streu: .herzen, fenster: .rose)
        case .valentinstag:
            ZimmerDeko(girlande: .herzen, boden: .geschenke, luft: .herzballons, streu: .herzen, fenster: .rose)
        case .silvester:
            ZimmerDeko(girlande: .luftschlangen, luft: .goldballons, streu: .konfetti, fenster: .sektglaeser)
        case .neujahr:
            ZimmerDeko(girlande: .luftschlangen, luft: .goldballons, streu: .konfetti, fenster: .kleeblatt)
        case .weihnachten:
            ZimmerDeko(girlande: .lichter, boden: .tannenbaum, streu: .schnee, fenster: .stern)
        case .nikolaus:
            ZimmerDeko(girlande: .lichter, boden: .stiefel, streu: .schnee, fenster: .kerzen)
        case .advent:
            ZimmerDeko(girlande: .lichter, boden: .tannenbaum, streu: .schnee, fenster: .adventskranz)
        case .halloween:
            ZimmerDeko(girlande: .fledermaeuse, boden: .gruselkuerbis, fenster: .geist)
        case .ostern:
            ZimmerDeko(girlande: .eier, boden: .osterkorb, fenster: .osterhase)
        case .herbst:
            ZimmerDeko(girlande: .blaetter, boden: .kuerbisse, streu: .blaetter, fenster: .laterne)
        case .fruehling:
            ZimmerDeko(girlande: .blumen, boden: .blumentopf, streu: .schmetterlinge, fenster: .tulpen)
        case .sommer:
            ZimmerDeko(girlande: .wimpel, boden: .strandball, fenster: .sonnenblume)
        case .schnee:
            ZimmerDeko(girlande: .lichter, streu: .schnee, fenster: .schneehaube)
        }
    }
}
