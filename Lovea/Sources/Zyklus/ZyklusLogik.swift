import Foundation

/// Reine Zyklus-Rechnung. Alle Tage sind `yyyy-MM-dd`-Strings; intern zählen wir ganze Tage.
/// Perioden-Start = erster Tag mit Blutung leicht/mittel/stark (Schmierblutung zählt nicht).
/// Vorhersage = Mittel der letzten bis zu 6 Zyklen, ohne Daten die Einstellung (Standard 28/5).
struct ZyklusLogik {
    static let maxZyklen = 6
    static let lutealTage = 14

    let einstellung: ZyklusEinstellung
    let heute: String
    /// Start-Tage der Perioden, aufsteigend.
    let periodenStarts: [String]
    /// Blutungstage vom Start bis zum letzten Blutungstag, parallel zu `periodenStarts`.
    let periodenLaengen: [Int]

    private let startIdx: [Int]
    private let heuteIdx: Int

    init(tage: [ZyklusTag], einstellung: ZyklusEinstellung = ZyklusEinstellung(), heute: String) {
        self.einstellung = einstellung
        self.heute = heute
        heuteIdx = Self.index(heute)
        let blutTage = Set(tage.filter { $0.blutung != nil && $0.blutung != .schmierblutung }.map { Self.index($0.id) }).sorted()
        var starts: [Int] = []
        var laengen: [Int] = []
        var letzter = 0
        for t in blutTage {
            if let l = starts.last, t - letzter <= 3 {
                laengen[laengen.count - 1] = t - l + 1
            } else {
                starts.append(t)
                laengen.append(1)
            }
            letzter = t
        }
        startIdx = starts
        periodenStarts = starts.map(Self.text)
        periodenLaengen = laengen
    }

    // MARK: Statistik

    /// Abstände zwischen aufeinanderfolgenden Perioden-Starts, älteste zuerst.
    var zyklusLaengen: [Int] {
        zip(startIdx.dropFirst(), startIdx).map { $0 - $1 }
    }

    private var letzteZyklen: [Int] { Array(zyklusLaengen.suffix(Self.maxZyklen)) }

    var mittlereZyklusLaenge: Int {
        let z = letzteZyklen
        guard !z.isEmpty else { return einstellung.zyklusLaenge }
        return Int((Double(z.reduce(0, +)) / Double(z.count)).rounded())
    }

    var mittlerePeriodenLaenge: Int {
        let p = Array(periodenLaengen.suffix(Self.maxZyklen))
        guard !p.isEmpty else { return einstellung.periodenLaenge }
        return max(1, Int((Double(p.reduce(0, +)) / Double(p.count)).rounded()))
    }

    /// Längster minus kürzester der letzten Zyklen in Tagen; 0 bei weniger als 2 Zyklen.
    var streuung: Int {
        let z = letzteZyklen
        guard let lo = z.min(), let hi = z.max() else { return 0 }
        return hi - lo
    }

    /// Unsicher bei weniger als 3 Zyklen oder Streuung über 7 Tage.
    var vorhersageSicher: Bool { letzteZyklen.count >= 3 && streuung <= 7 }

    // MARK: Vorhersage

    var letzterPeriodenStart: String? { startIdx.last.map(Self.text) }

    var naechstePeriode: String? {
        startIdx.last.map { Self.text($0 + mittlereZyklusLaenge) }
    }

    /// Eisprung im laufenden Zyklus: 14 Tage vor der nächsten Periode.
    var eisprungTag: String? {
        startIdx.last.map { Self.text($0 + mittlereZyklusLaenge - Self.lutealTage) }
    }

    /// Eisprung -5 bis +1 Tage.
    var fruchtbaresFenster: ClosedRange<String>? {
        guard let l = startIdx.last else { return nil }
        let e = l + mittlereZyklusLaenge - Self.lutealTage
        return Self.text(e - 5)...Self.text(e + 1)
    }

    /// Tage über dem erwarteten Perioden-Tag, solange keine neue Periode begann.
    var verspaetung: Int? {
        guard let l = startIdx.last else { return nil }
        let d = heuteIdx - (l + mittlereZyklusLaenge)
        return d > 0 ? d : nil
    }

    var verspaetungHinweis: String? {
        guard let d = verspaetung else { return nil }
        let basis = d == 1 ? "Deine Periode ist 1 Tag später als erwartet." : "Deine Periode ist \(d) Tage später als erwartet."
        return d >= 7 ? basis + " Das kann viele Gründe haben. Sprich bei Sorgen mit deiner Ärztin." : basis
    }

    // MARK: Je Datum

    /// 1 = erster Periodentag. Nil vor der ersten Periode und in der Zukunft, wenn die Periode überfällig ist.
    func zyklusTagNummer(am tag: String) -> Int? {
        zyklus(Self.index(tag))?.nummer
    }

    func phase(am tag: String) -> Phase? {
        guard let z = zyklus(Self.index(tag)) else { return nil }
        if z.nummer <= periodenLaenge(startend: z.start) { return .periode }
        let eis = z.laenge - Self.lutealTage + 1
        if z.nummer == eis { return .eisprung }
        if z.nummer >= eis - 5 && z.nummer <= eis + 1 { return .fruchtbar }
        return z.nummer < eis ? .follikel : .luteal
    }

    // MARK: Intern

    private struct Zyklus { let start: Int; let laenge: Int; let nummer: Int }

    /// Echte Länge; läuft die letzte Periode noch (bis gestern oder heute geloggt), gilt mindestens die mittlere.
    private func periodenLaenge(startend start: Int) -> Int {
        guard let i = startIdx.firstIndex(of: start) else { return mittlerePeriodenLaenge }
        let echt = periodenLaengen[i]
        if i == startIdx.count - 1, heuteIdx - (start + echt - 1) <= 1 { return max(echt, mittlerePeriodenLaenge) }
        return echt
    }

    private func zyklus(_ d: Int) -> Zyklus? {
        guard let i = startIdx.lastIndex(where: { $0 <= d }) else { return nil }
        let s = startIdx[i]
        if i < startIdx.count - 1 {
            return Zyklus(start: s, laenge: startIdx[i + 1] - s, nummer: d - s + 1)
        }
        let len = mittlereZyklusLaenge
        if d < s + len { return Zyklus(start: s, laenge: len, nummer: d - s + 1) }
        if s + len <= heuteIdx { // überfällig: bis heute spät-luteal, danach unbekannt
            return d <= heuteIdx ? Zyklus(start: s, laenge: len, nummer: d - s + 1) : nil
        }
        let k = (d - s) / len
        return Zyklus(start: s + k * len, laenge: len, nummer: d - s - k * len + 1)
    }

    private static let referenz = Datum.datum("2000-01-01")

    private static func index(_ tag: String) -> Int {
        Datum.kalender.dateComponents([.day], from: referenz, to: Datum.datum(tag)).day ?? 0
    }

    private static func text(_ index: Int) -> String {
        Datum.text(Datum.kalender.date(byAdding: .day, value: index, to: referenz)!)
    }
}
