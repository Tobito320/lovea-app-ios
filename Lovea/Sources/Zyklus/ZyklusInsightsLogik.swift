import Foundation

/// Reine Auswertung für die Insights. Baut auf `ZyklusLogik` auf, rechnet nichts doppelt.
struct ZyklusInsightsLogik {
    static let arztHinweis = "Das ist kein Ersatz für ärztlichen Rat. Wenn dich etwas beunruhigt, sprich mit deiner Ärztin."
    static let sehrKurz = 21
    static let sehrLang = 35

    enum Regelmaessigkeit: Equatable {
        case zuWenigDaten, sehrRegelmaessig, regelmaessig, wechselhaft

        var titel: String {
            switch self {
            case .zuWenigDaten: "Noch zu früh"
            case .sehrRegelmaessig: "Sehr regelmäßig"
            case .regelmaessig: "Regelmäßig"
            case .wechselhaft: "Wechselhaft"
            }
        }

        var text: String {
            switch self {
            case .zuWenigDaten: "Trag noch ein paar Zyklen ein, dann sehe ich mehr."
            case .sehrRegelmaessig: "Dein Körper hat einen festen Takt."
            case .regelmaessig: "Dein Zyklus schwankt nur ein bisschen."
            case .wechselhaft: "Dein Zyklus ist mal kürzer, mal länger. Das kommt vor."
            }
        }
    }

    enum Art: Equatable { case sehrKurz, sehrLang, ausgeblieben, starkeStreuung }

    struct Auffaelligkeit: Equatable {
        let art: Art
        let text: String
    }

    struct Haeufig<Wert: Hashable>: Equatable where Wert: Equatable {
        let wert: Wert
        let anzahl: Int
    }

    struct TempPunkt: Equatable {
        let zyklusTag: Int
        let grad: Double
    }

    let logik: ZyklusLogik
    private let tage: [ZyklusTag]

    init(tage: [ZyklusTag], einstellung: ZyklusEinstellung = ZyklusEinstellung(), heute: String) {
        self.tage = tage
        logik = ZyklusLogik(tage: tage, einstellung: einstellung, heute: heute)
    }

    // MARK: Längen

    /// Die letzten Zykluslängen, älteste zuerst.
    func zyklusVerlauf(maximal: Int = 8) -> [Int] { Array(logik.zyklusLaengen.suffix(maximal)) }
    func periodenVerlauf(maximal: Int = 8) -> [Int] { Array(logik.periodenLaengen.suffix(maximal)) }

    var mittlereZyklusLaenge: Int { logik.mittlereZyklusLaenge }
    var mittlerePeriodenLaenge: Int { logik.mittlerePeriodenLaenge }
    var streuung: Int { logik.streuung }
    var hatZyklen: Bool { !logik.zyklusLaengen.isEmpty }

    var regelmaessigkeit: Regelmaessigkeit {
        guard logik.zyklusLaengen.count >= 3 else { return .zuWenigDaten }
        switch streuung {
        case ...2: return .sehrRegelmaessig
        case ...7: return .regelmaessig
        default: return .wechselhaft
        }
    }

    // MARK: Phasen

    private func tageJePhase(_ phase: Phase) -> [ZyklusTag] {
        tage.filter { logik.phase(am: $0.id) == phase }
    }

    /// Häufigste Symptome in der Phase, meiste zuerst; bei Gleichstand nach Name.
    func haeufigsteSymptome(in phase: Phase, maximal: Int = 3) -> [Haeufig<Symptom>] {
        rang(tageJePhase(phase).flatMap { $0.symptome }, maximal)
    }

    func haeufigsteStimmung(in phase: Phase, maximal: Int = 3) -> [Haeufig<Stimmung>] {
        rang(tageJePhase(phase).flatMap { $0.stimmung }, maximal)
    }

    private func rang<W: Hashable & RawRepresentable>(_ werte: [W], _ maximal: Int) -> [Haeufig<W>] where W.RawValue == String {
        var zaehler: [W: Int] = [:]
        for w in werte { zaehler[w, default: 0] += 1 }
        let sortiert = zaehler.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.rawValue < $1.key.rawValue }
        return sortiert.prefix(maximal).map { Haeufig(wert: $0.key, anzahl: $0.value) }
    }

    // MARK: Temperatur

    /// Temperaturen des laufenden Zyklus (oder des letzten, wenn heute nichts mehr zuordenbar ist), nach Zyklustag.
    var temperaturKurve: [TempPunkt] {
        guard let start = logik.letzterPeriodenStart else { return [] }
        return tage.compactMap { t -> TempPunkt? in
            guard let grad = t.temperatur, t.id >= start, let nr = logik.zyklusTagNummer(am: t.id) else { return nil }
            return TempPunkt(zyklusTag: nr, grad: grad)
        }.sorted { $0.zyklusTag < $1.zyklusTag }
    }

    // MARK: Auffälligkeiten

    var auffaelligkeiten: [Auffaelligkeit] {
        var liste: [Auffaelligkeit] = []
        let laengen = logik.zyklusLaengen.suffix(ZyklusLogik.maxZyklen)
        if let kurz = laengen.min(), kurz < Self.sehrKurz {
            liste.append(.init(art: .sehrKurz, text: "Ein Zyklus war nur \(kurz) Tage kurz."))
        }
        if let lang = laengen.max(), lang > Self.sehrLang {
            liste.append(.init(art: .sehrLang, text: "Ein Zyklus dauerte \(lang) Tage."))
        }
        if let d = logik.verspaetung, d >= 7 {
            liste.append(.init(art: .ausgeblieben, text: "Deine Periode ist seit \(d) Tagen überfällig."))
        }
        if laengen.count >= 3, streuung > 7 {
            liste.append(.init(art: .starkeStreuung, text: "Deine Zyklen unterscheiden sich um \(streuung) Tage."))
        }
        return liste
    }
}
