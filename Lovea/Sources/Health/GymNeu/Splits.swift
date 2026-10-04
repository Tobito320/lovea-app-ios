import Foundation

/// Ein fertiger Split aus `splits.json` (gebaut von `tools/splits-bauen.mjs`). Jede `uebung` ist eine
/// Katalog-id (`SplitsTests` prüft das). Wählen schreibt einen ganz normalen `TrainingsPlan`.
struct SplitVorlage: Codable, Identifiable, Equatable, Sendable {
    struct Zeile: Codable, Equatable, Sendable {
        var uebung: String
        var saetze: Int
        var von: Int
        var bis: Int
        /// Cardio: Dauer in Minuten statt Sätzen (Stairmaster, Laufband). Fehlt bei Kraftübungen.
        var minuten: Int? = nil
        /// true = Supersatz mit der nächsten Zeile (`PlanUebung.supersatz`). Nur die 45-Minuten-Pläne setzen es.
        var supersatz: Bool? = nil
    }

    struct Einheit: Codable, Equatable, Sendable {
        var name: String
        /// 1 = Mo … 7 = So, wie `TrainingsTag.wochentage`.
        var wochentage: [Int]
        var uebungen: [Zeile]
    }

    var id: String
    var name: String
    /// "m" oder "w": Ahmed und Annika sehen verschiedene Splits.
    var gruppe: String
    /// "einsteiger", "mittel", "fortgeschritten".
    var level: String
    /// "muskeln", "kraft", "definieren", "fit".
    var ziel: String
    /// "studio", "kurzhantel", "zuhause".
    var geraet: String
    var tage: Int
    var einheiten: [Einheit]
}

/// Akku: `alle` lädt erst beim ersten Zugriff, also wenn die Bibliothek aufgeht, nie beim App-Start.
enum SplitKatalog {
    static let alle: [SplitVorlage] = laden(.main)

    static func laden(_ bundle: Bundle) -> [SplitVorlage] {
        guard let url = bundle.url(forResource: "splits", withExtension: "json")
                ?? bundle.url(forResource: "splits", withExtension: "json", subdirectory: "Health/GymNeu"),
              let daten = try? Data(contentsOf: url),
              let liste = try? JSONDecoder().decode([SplitVorlage].self, from: daten) else { return [] }
        return liste
    }
}

enum SplitLogik {
    static let tageWahl = [2, 3, 4, 5, 6]
    static let ziele: [(id: String, text: String)] = [("muskeln", "Muskeln aufbauen"), ("kraft", "Stärker werden"), ("definieren", "Definieren"), ("fit", "Fit bleiben")]
    static let geraete: [(id: String, text: String)] = [("studio", "Ganzes Studio"), ("kurzhantel", "Nur Kurzhanteln"), ("zuhause", "Zuhause ohne Geräte")]

    static func gruppe(_ p: Person) -> String { p == .annika ? "w" : "m" }

    /// Die Splits für `p`, optional nur die mit `tage` Trainingstagen pro Woche. Reihenfolge wie in der Datei.
    static func fuer(_ p: Person, tage: Int? = nil, in liste: [SplitVorlage] = SplitKatalog.alle) -> [SplitVorlage] {
        liste.filter { $0.gruppe == gruppe(p) && (tage == nil || $0.tage == tage) }
    }

    /// Kurzfilter über der Liste: "Für dich" = Ahmeds eigene Splits, sonst ein Ziel.
    static let artWahl: [(id: String, text: String)] = [("fuerdich", "Für dich"), (kurzArt, "45 Minuten"), ("muskeln", "Aufbauen"), ("kraft", "Kraft"), ("definieren", "Definieren"), ("fit", "Fit")]

    /// Ahmeds 15 Splits aus dem Vault (`tools/splits-bauen.mjs`, ids `m-ahmed01` …).
    static func istEigen(_ v: SplitVorlage) -> Bool { v.id.hasPrefix("m-ahmed") }

    /// Kurzpläne für ein Studio-Zeitfenster (ids `m-kurz45-1` …, `Zeit/ZeitSchaetzung`): Filter "45 Minuten".
    static let kurzArt = "kurz45"
    static func istKurzplan(_ v: SplitVorlage) -> Bool { v.id.contains("-kurz45-") }

    /// Wonach die Suche schaut: Name, Level, Ziel, Tage, Einheiten, Übungen mit Muskel und Körperteil.
    static func suchtext(_ v: SplitVorlage) -> String {
        let uebungen = v.einheiten.flatMap(\.uebungen).compactMap { UebungsKatalog.nachId[$0.uebung] }.flatMap { [$0.name, $0.muskel, $0.koerper] }
        let ziel = ziele.first { $0.id == v.ziel }?.text ?? v.ziel
        return ([v.name, levelText(v), ziel, "\(v.tage) Tage"] + v.einheiten.map(\.name) + uebungen).joined(separator: " ")
    }

    /// Bibliothek: Art ("fuerdich" oder ein Ziel), Tage, dann muss jedes Wort der Suche vorkommen
    /// (Groß/Klein und Akzente egal). Reihenfolge wie in der Datei, die Empfehlungen bleiben oben.
    static func treffer(_ liste: [SplitVorlage], art: String?, tage: Int?, suche: String) -> [SplitVorlage] {
        let woerter = suche.split(whereSeparator: \.isWhitespace).map(String.init)
        return liste.filter { v in
            guard art == nil || (art == "fuerdich" ? istEigen(v) : art == kurzArt ? istKurzplan(v) : v.ziel == art), tage == nil || v.tage == tage else { return false }
            if woerter.isEmpty { return true }
            let text = suchtext(v)
            return woerter.allSatisfy { text.localizedStandardContains($0) }
        }
    }

    /// "Einsteiger", "Einsteigerin", "Mittel", "Fortgeschritten".
    static func levelText(_ v: SplitVorlage) -> String {
        switch v.level {
        case "einsteiger": return v.gruppe == "w" ? "Einsteigerin" : "Einsteiger"
        case "fortgeschritten": return "Fortgeschritten"
        default: return "Mittel"
        }
    }

    /// "6 Tage · Fortgeschritten".
    static func unterzeile(_ v: SplitVorlage) -> String { "\(v.tage) Tage · \(levelText(v))" }

    /// Mo bis So: an welchen Tagen der Split trainiert.
    static func wochenbild(_ v: SplitVorlage) -> [Bool] {
        let an = Set(v.einheiten.flatMap(\.wochentage))
        return (1...7).map { an.contains($0) }
    }

    /// "3 × 8–12", "5 × 5".
    static func wdhText(_ z: SplitVorlage.Zeile) -> String {
        if let m = z.minuten { return "\(m) min" }
        return z.von == z.bis ? "\(z.saetze) × \(z.von)" : "\(z.saetze) × \(z.von)–\(z.bis)"
    }

    /// Der Split als Plan: frische ids, Sätze mit der unteren Wiederholungszahl (der Plan kennt keinen
    /// Bereich), ohne Gewicht. Tage ohne Training werden Ruhetage.
    static func alsPlan(_ v: SplitVorlage, neueId: () -> String = { UUID().uuidString }) -> TrainingsPlan {
        let tage = v.einheiten.map { e in
            TrainingsTag(id: neueId(), name: e.name, wochentage: e.wochentage.sorted(), uebungen: e.uebungen.map { z in
                PlanUebung(id: neueId(), uebung: z.uebung, name: nil,
                           saetze: z.minuten != nil ? [] : Array(repeating: PlanSatz(wdh: z.von, kg: nil, failure: false), count: z.saetze),
                           minuten: z.minuten, supersatz: z.supersatz)
            })
        }
        let training = Set(v.einheiten.flatMap(\.wochentage))
        return TrainingsPlan(tage: tage, ruhetage: (1...7).filter { !training.contains($0) }, splitName: v.name)
    }

    /// Geführtes Erstellen: das Gerät muss passen, dann zählt die Zahl der Tage, dann das Ziel.
    /// nil nur, wenn es für die Person gar keinen Split mit dem Gerät gibt.
    static func vorschlag(_ p: Person, tage: Int, ziel: String, geraet: String, in liste: [SplitVorlage] = SplitKatalog.alle) -> SplitVorlage? {
        fuer(p, in: liste).filter { $0.geraet == geraet }.min { a, b in
            let da = abs(a.tage - tage), db = abs(b.tage - tage)
            if da != db { return da < db }
            return (a.ziel == ziel ? 0 : 1) < (b.ziel == ziel ? 0 : 1)
        }
    }
}

/// Reine Texte der neuen Gym-Seite.
enum GymStartLogik {
    /// Was eine Person an `datum` gemacht hat oder vorhat: "54 min · 27 Sätze", "gerade im Gym",
    /// "noch nicht", "nicht im Gym", "geplant: Push", "Ruhetag".
    static func status(_ sessions: [GymSession], datum: String, heute: String, geplant: String?, jetzt: Date) -> String {
        if let s = sessions.first(where: { Datum.text($0.start) == datum }) {
            guard let ende = s.ende else { return TrainingLogik.laufend(s, jetzt: jetzt) ? "gerade im Gym" : "war im Gym" }
            let saetze = s.laeufe.reduce(0) { $0 + ($1.saetze?.count ?? 0) }
            let dauer = TrainingLogik.dauerText(ende.timeIntervalSince(s.start))
            return saetze > 0 ? "\(dauer) · \(saetze) \(saetze == 1 ? "Satz" : "Sätze")" : dauer
        }
        if datum > heute { return geplant.map { "geplant: \($0)" } ?? "Ruhetag" }
        return datum == heute ? "noch nicht" : "nicht im Gym"
    }

    /// "Heute · Push", "Mittwoch · Ruhetag".
    static func titel(datum: String, heute: String, tag: TrainingsTag?) -> String {
        let wann = datum == heute ? "Heute" : TrainingLogik.wochentagName[Datum.wochentag(datum) - 1]
        guard let tag else { return "\(wann) · Ruhetag" }
        return "\(wann) · \(tag.name.isEmpty ? "Training" : tag.name)"
    }

    /// "6 Übungen · etwa 60 min": `ZeitSchaetzung` (Sätze, Pausen, Wechsel), auf 5 min gerundet.
    static func umfang(_ tag: TrainingsTag) -> String {
        let rund = max(5, Int((Double(ZeitSchaetzung.minuten(tag)) / 5).rounded()) * 5)
        return "\(tag.uebungen.count) \(tag.uebungen.count == 1 ? "Übung" : "Übungen") · etwa \(rund) min"
    }
}

/// Schalter "Neues Gym" (Einstellungen, Standard an). Aus zeigt den alten Trainingsplan.
enum GymNeu {
    static let schluessel = "lovea.gymNeu"
    static func an(_ defaults: UserDefaults = .standard) -> Bool { defaults.object(forKey: schluessel) as? Bool ?? true }
}
