import Foundation

/// Öffnungsfenster eines Tages in Minuten seit Mitternacht. `bis == nil`: bis Mitternacht offen oder Ende unbekannt.
struct Oeffnungsfenster: Equatable, Sendable {
    let von: Int
    let bis: Int?
}

/// Ein geplanter Slot, der nicht ins Öffnungsfenster passt.
struct OeffnungsWarnung: Equatable, Sendable {
    enum Grund: Equatable, Sendable { case vorOeffnung(von: Int), nachSchluss(bis: Int) }
    let wochentag: Int
    let grund: Grund
}

/// Öffnungszeiten je Studio als Daten, dazu die reine Prüflogik. Wochentag 1 = Mo … 7 = So (`Datum.wochentag`).
enum GymOeffnung {
    /// FitX: 24/7. Absolut Fit and Dance: Mo-Fr 08-22, Sa/So 09-18 laut Studio-Seite und Verzeichnissen
    /// (Recherche 04.10.2026). UNSICHER: eine Quelle nennt Sa/So ab 10:00, Zeiten nicht am Studio bestätigt.
    static func fenster(_ studio: GymStudio, wochentag: Int) -> Oeffnungsfenster {
        switch studio {
        case .fitxHagenMitte: Oeffnungsfenster(von: 0, bis: nil)
        case .absolutFit: wochentag >= 6 ? Oeffnungsfenster(von: 9 * 60, bis: 18 * 60) : Oeffnungsfenster(von: 8 * 60, bis: 22 * 60)
        }
    }

    /// `minute` = Minuten seit Mitternacht. Beginn zählt als offen, Ende nicht.
    static func istOffen(_ studio: GymStudio, wochentag: Int, minute: Int) -> Bool {
        let f = fenster(studio, wochentag: wochentag)
        return minute >= f.von && (f.bis.map { minute < $0 } ?? true)
    }

    /// Slot von `start` bis `start + dauer`: ganz im Fenster ist ok, auch bündig an Anfang und Ende.
    static func warnung(_ studio: GymStudio, wochentag: Int, start: Int, dauer: Int) -> OeffnungsWarnung? {
        let f = fenster(studio, wochentag: wochentag)
        if start < f.von { return OeffnungsWarnung(wochentag: wochentag, grund: .vorOeffnung(von: f.von)) }
        if let bis = f.bis, start + dauer > bis { return OeffnungsWarnung(wochentag: wochentag, grund: .nachSchluss(bis: bis)) }
        return nil
    }

    /// Eine Warnung je Trainingstag der Woche, der nicht passt, nach Wochentag sortiert. Bei FitX immer leer.
    static func warnungen(_ studio: GymStudio, wochentage: [Int], start: Int?, dauer: Int) -> [OeffnungsWarnung] {
        guard let start else { return [] }
        return Set(wochentage).filter { (1...7).contains($0) }.sorted()
            .compactMap { warnung(studio, wochentag: $0, start: start, dauer: dauer) }
    }

    /// "Mo, Di: öffnet erst um 08:00" – gleiche Gründe zusammengefasst, nach erstem Wochentag sortiert.
    static func zeilen(_ warnungen: [OeffnungsWarnung]) -> [String] {
        var gruppen: [(grund: OeffnungsWarnung.Grund, tage: [Int])] = []
        for w in warnungen {
            if let i = gruppen.firstIndex(where: { $0.grund == w.grund }) { gruppen[i].tage.append(w.wochentag) }
            else { gruppen.append((w.grund, [w.wochentag])) }
        }
        return gruppen.map { g in
            let tage = TrainingLogik.wochentageText(g.tage)
            switch g.grund {
            case .vorOeffnung(let von): return "\(tage): öffnet erst um \(Datum.uhrzeit(minuten: von))"
            case .nachSchluss(let bis): return "\(tage): schließt um \(Datum.uhrzeit(minuten: bis))"
            }
        }
    }

    /// Eine Zeile für die Studio-Zeile.
    static func kurztext(_ studio: GymStudio) -> String {
        switch studio {
        case .fitxHagenMitte: "24/7 geöffnet"
        case .absolutFit: "Mo–Fr ab 08:00, Sa/So ab 09:00 (unsicher)"
        }
    }
}
