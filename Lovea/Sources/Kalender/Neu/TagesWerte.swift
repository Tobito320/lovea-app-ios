import Foundation

/// Ein Zeitfenster eines Tages in Minuten seit Mitternacht.
struct TagesFenster: Equatable {
    let von: Int
    let bis: Int
}

/// Welche Marken ein Tag im Monatsraster trägt: Punkt je Person (Termin) und Herz (Treffen).
struct TagesMarken: Equatable {
    var ahmed = false
    var annika = false
    var treffen = false
}

enum BalkenArt: Equatable { case alltag, termin, treffen, frei }

/// Ein Stück eines Tagesbalkens, geklemmt auf 8 bis 22 Uhr.
struct BalkenSegment: Equatable {
    let von: Int
    let bis: Int
    let art: BalkenArt
}

/// Reine Werte für den neuen Kalender (Variante C). Keine Oberfläche, kein Modell: alles nimmt
/// `Block`/`KalenderDaten` und gibt Zahlen oder Text zurück, damit es ohne SwiftUI testbar bleibt.
enum TagesWerte {
    static let fensterVon = 8 * 60
    static let fensterBis = 22 * 60
    /// Ein Treffen mit Uhrzeit belegt diese Zeit; die alte Tagesansicht zeigt es ebenso.
    static let treffenDauer = 120
    static let mindestFrei = 30

    private static func klemme(_ von: Int, _ bis: Int) -> TagesFenster? {
        let anfang = max(von, fensterVon)
        let ende = min(bis, fensterBis)
        return anfang < ende ? TagesFenster(von: anfang, bis: ende) : nil
    }

    /// Die belegte Zeit eines Blocks. Frei und Urlaub belegen nichts, ein Block ohne Zeit das ganze
    /// Fenster, fehlt nur das Ende, gilt er bis 22 Uhr. Abweichung zur alten Ansicht: ein Treffen
    /// mit Uhrzeit belegt `treffenDauer`, eins ohne Uhrzeit nichts.
    private static func zeitraum(_ block: Block) -> TagesFenster? {
        if block.quelle == "treffen" {
            guard let start = Datum.minuten(block.start) else { return nil }
            return klemme(start, start + treffenDauer)
        }
        guard block.status != "frei", block.status != "urlaub" else { return nil }
        return klemme(Datum.minuten(block.start) ?? fensterVon, Datum.minuten(block.ende) ?? fensterBis)
    }

    // MARK: - Gemeinsam frei

    /// Gemeinsame freie Fenster: 8 bis 22 Uhr minus alle belegten Blöcke beider Personen,
    /// Fenster unter 30 Minuten fallen weg.
    static func freieZeiten(_ bloecke: [Block]) -> [TagesFenster] {
        var frei = [TagesFenster(von: fensterVon, bis: fensterBis)]
        for belegt in bloecke.compactMap({ zeitraum($0) }) {
            frei = frei.flatMap { stueck -> [TagesFenster] in
                guard belegt.von < stueck.bis, belegt.bis > stueck.von else { return [stueck] }
                var teile: [TagesFenster] = []
                if stueck.von < belegt.von { teile.append(TagesFenster(von: stueck.von, bis: belegt.von)) }
                if belegt.bis < stueck.bis { teile.append(TagesFenster(von: belegt.bis, bis: stueck.bis)) }
                return teile
            }
        }
        return frei.filter { $0.bis - $0.von >= mindestFrei }
    }

    static func freiText(_ fenster: [TagesFenster]) -> String {
        guard !fenster.isEmpty else { return "Keine gemeinsame freie Zeit" }
        return "Gemeinsam frei " + fenster.map { "\(Datum.uhrzeit(minuten: $0.von))–\(Datum.uhrzeit(minuten: $0.bis))" }.joined(separator: ", ")
    }

    // MARK: - Monatsraster

    /// Marken je Tag des Monats von `monat` (ein beliebiger Tag `yyyy-MM-dd` oder `yyyy-MM`).
    /// Tage ohne Marke fehlen im Ergebnis.
    static func marken(_ daten: KalenderDaten, monat: String) -> [String: TagesMarken] {
        let praefix = String(monat.prefix(7))
        var ergebnis: [String: TagesMarken] = [:]
        for termin in daten.termine where termin.datum.hasPrefix(praefix) {
            if termin.fuer.contains(Person.ahmed.rawValue) { ergebnis[termin.datum, default: TagesMarken()].ahmed = true }
            if termin.fuer.contains(Person.annika.rawValue) { ergebnis[termin.datum, default: TagesMarken()].annika = true }
        }
        for treffen in daten.treffen where treffen.datum.hasPrefix(praefix) {
            ergebnis[treffen.datum, default: TagesMarken()].treffen = true
        }
        return ergebnis
    }

    /// „Herbstferien 17. bis 31. Oktober · Schule entfällt", am Rand „bis 1. September" oder
    /// „ab 23. Dezember". nil ohne Ferien im Monat. // ponytail: nur die erste Ferienzeit; NRW hat
    /// 2026 bis 2028 nie zwei in einem Monat.
    static func ferienZeile(monat: String) -> String? {
        let praefix = String(monat.prefix(7))
        guard let ferien = Ferien.nrw.first(where: { String($0.von.prefix(7)) <= praefix && praefix <= String($0.bis.prefix(7)) })
        else { return nil }
        let monatsname = monatsName(praefix)
        let ab = Int(ferien.von.suffix(2)) ?? 1
        let bis = Int(ferien.bis.suffix(2)) ?? 1
        let tage: String
        switch (ferien.von.hasPrefix(praefix), ferien.bis.hasPrefix(praefix)) {
        case (true, true): tage = ferien.von == ferien.bis ? " \(ab). \(monatsname)" : " \(ab). bis \(bis). \(monatsname)"
        case (true, false): tage = " ab \(ab). \(monatsname)"
        case (false, true): tage = " bis \(bis). \(monatsname)"
        case (false, false): tage = ""
        }
        return "\(ferien.name)\(tage) · Schule entfällt"
    }

    /// „Oktober" für `yyyy-MM`, gleiche Art wie `Datum.anzeige` (FormatStyle, de_DE, Berlin).
    private static func monatsName(_ jahrMonat: String) -> String {
        let stil = Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
        return Datum.datum(jahrMonat + "-01").formatted(stil.month(.wide))
    }

    // MARK: - Texte

    /// „8 Std", „7 Std 30 min", „45 min".
    static func dauerText(_ minuten: Int) -> String {
        let stunden = minuten / 60
        let rest = minuten % 60
        if stunden == 0 { return "\(rest) min" }
        return rest == 0 ? "\(stunden) Std" : "\(stunden) Std \(rest) min"
    }

    /// „Ahmed · Arbeit 08:00–16:30 · netto 8 Std", ein Status wie „krank" hängt hinten an. Bei
    /// krank, Urlaub und frei fällt das Netto weg, die Arbeit findet nicht statt.
    static func alltagZeile(name: String, block: Block) -> String {
        let titel = block.typ == "arbeit" ? "Arbeit" : block.titel
        var teile = [name]
        if let start = block.start, let ende = block.ende {
            teile.append("\(titel) \(start)–\(ende)")
        } else if let start = block.start {
            teile.append("\(titel) ab \(start)")
        } else {
            teile.append(titel)
        }
        let faelltAus = ["krank", "urlaub", "frei"].contains(block.status)
        if let netto = block.arbeitNetto, !faelltAus { teile.append("netto \(dauerText(netto))") }
        if block.status != "normal" { teile.append(block.status) }
        return teile.joined(separator: " · ")
    }

    // MARK: - Balken der Tagesansicht

    /// Balken einer Person: Alltag und Termine, Treffen nicht (die stehen im Balken „zusammen").
    static func personenBalken(_ bloecke: [Block]) -> [BalkenSegment] {
        bloecke.compactMap { block -> BalkenSegment? in
            guard block.quelle != "treffen", let fenster = zeitraum(block) else { return nil }
            return BalkenSegment(von: fenster.von, bis: fenster.bis, art: block.quelle == "termin" ? .termin : .alltag)
        }
        .sorted { $0.von < $1.von }
    }

    /// Balken „zusammen" aus den Blöcken beider Personen: gemeinsam frei (grün) und Treffen
    /// (Rosé). Das Treffen steht in beiden Listen, zählt aber einmal.
    static func zusammenBalken(_ bloecke: [Block]) -> [BalkenSegment] {
        var segmente = freieZeiten(bloecke).map { BalkenSegment(von: $0.von, bis: $0.bis, art: .frei) }
        var gesehen = Set<Int>()
        for block in bloecke where block.quelle == "treffen" {
            guard let fenster = zeitraum(block), gesehen.insert(fenster.von).inserted else { continue }
            segmente.append(BalkenSegment(von: fenster.von, bis: fenster.bis, art: .treffen))
        }
        return segmente.sorted { $0.von < $1.von }
    }
}
