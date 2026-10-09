import Foundation

/// What a weekday is in a plan. Nothing stays silently unplanned: `offen` asks to be decided.
enum TagArt: Equatable, Sendable {
    case training(TrainingsTag), ruhe, offen
}

/// One hint under the week. `tausch` = the two weekdays that swap on "Übernehmen".
struct PlanHinweis: Identifiable, Equatable, Sendable {
    var id: String
    var text: String
    var tausch: [Int]? = nil
}

/// Rest-day rules from the research (docs/superpowers/plans/2026-09-25-training-ruhetage.md): 1 to 3
/// rest days a week, at least 3 training days so every muscle gets about 2 sessions a week, the same
/// main muscles not on two days in a row, not more than 3 training days in a row when the rest days
/// could be spread. The app only speaks when a rule fails, and about placement only when one swap of
/// two weekdays really helps.
enum RuhetagLogik {
    static func art(_ plan: TrainingsPlan, _ w: Int) -> TagArt {
        if let t = plan.tage.first(where: { $0.wochentage.contains(w) }) { return .training(t) }
        return (plan.ruhetage ?? []).contains(w) ? .ruhe : .offen
    }

    /// Weekday `w` becomes training day `tag` (an id), or a rest day when `tag` is nil.
    static func setzen(_ plan: TrainingsPlan, _ w: Int, tag: String?) -> TrainingsPlan {
        var p = plan
        for i in p.tage.indices {
            p.tage[i].wochentage.removeAll { $0 == w }
            if p.tage[i].id == tag { p.tage[i].wochentage = (p.tage[i].wochentage + [w]).sorted() }
        }
        var ruhe = (p.ruhetage ?? []).filter { $0 != w }
        if tag == nil { ruhe = (ruhe + [w]).sorted() }
        p.ruhetage = ruhe
        return p
    }

    /// Swaps what two weekdays are.
    static func tauschen(_ plan: TrainingsPlan, _ a: Int, _ b: Int) -> TrainingsPlan {
        let artA = art(plan, a), artB = art(plan, b)
        return zuweisen(zuweisen(plan, a, artB), b, artA)
    }

    private static func zuweisen(_ plan: TrainingsPlan, _ w: Int, _ art: TagArt) -> TrainingsPlan {
        switch art {
        case .training(let t):
            return setzen(plan, w, tag: t.id)
        case .ruhe:
            return setzen(plan, w, tag: nil)
        case .offen:
            var p = setzen(plan, w, tag: nil)
            p.ruhetage = (p.ruhetage ?? []).filter { $0 != w }
            return p
        }
    }

    /// Main muscles of a day: target muscles of at least two of its exercises (all of them on a day
    /// with one or two). Cardio ("Herz-Kreislauf") and own exercises don't count.
    static func schwerpunkt(_ tag: TrainingsTag) -> Set<String> {
        let muskeln = tag.uebungen.compactMap { $0.katalog?.muskel }.filter { $0 != "Herz-Kreislauf" }
        guard muskeln.count > 2 else { return Set(muskeln) }
        var zahl: [String: Int] = [:]
        for m in muskeln { zahl[m, default: 0] += 1 }
        return Set(zahl.filter { $0.value >= 2 }.keys)
    }

    private static func istTraining(_ plan: TrainingsPlan, _ w: Int) -> Bool {
        if case .training = art(plan, w) { return true }
        return false
    }

    /// Longest run of training days, across the week's end too (7 when every day is training).
    static func laengsteSerie(_ plan: TrainingsPlan) -> Int {
        let training = (1...7).map { istTraining(plan, $0) }
        if !training.contains(false) { return 7 }
        var beste = 0, lauf = 0
        for i in 0..<14 {
            lauf = training[i % 7] ? lauf + 1 : 0
            beste = max(beste, lauf)
        }
        return beste
    }

    /// Lower is better: 10 per pair of neighbouring days (So→Mo too) sharing main muscles, 3 per
    /// training day beyond 3 in a row.
    static func wertung(_ plan: TrainingsPlan, schwerpunkt: (TrainingsTag) -> Set<String> = schwerpunkt) -> Int {
        var punkte = 0
        for w in 1...7 {
            if case .training(let a) = art(plan, w), case .training(let b) = art(plan, w % 7 + 1),
               !schwerpunkt(a).isDisjoint(with: schwerpunkt(b)) {
                punkte += 10
            }
        }
        return punkte + max(0, laengsteSerie(plan) - 3) * 3
    }

    /// The hints for a plan, empty when everything is fine.
    static func hinweise(_ plan: TrainingsPlan, schwerpunkt: (TrainingsTag) -> Set<String> = schwerpunkt) -> [PlanHinweis] {
        guard !plan.tage.isEmpty else { return [] }
        let offen = (1...7).filter { art(plan, $0) == .offen }
        if !offen.isEmpty {
            return [PlanHinweis(id: "offen", text: "Noch nicht geplant: \(TrainingLogik.wochentageText(offen)). Tipp auf den Tag und leg Training oder Ruhetag fest.")]
        }
        let ruhe = (1...7).filter { art(plan, $0) == .ruhe }.count
        if ruhe == 0 {
            return [PlanHinweis(id: "zuWenig", text: "Kein Ruhetag in der Woche. 1 bis 3 Ruhetage geben deinen Muskeln Zeit, stärker zu werden.")]
        }
        if 7 - ruhe < 3 {
            return [PlanHinweis(id: "zuViel", text: "\(ruhe) Ruhetage sind viel. Mit 3 bis 4 Trainingstagen kommt jede Muskelgruppe 2-mal pro Woche dran, das bringt am meisten.")]
        }
        guard let tausch = besterTausch(plan, schwerpunkt: schwerpunkt) else { return [] }
        let text = "\(problem(plan, schwerpunkt: schwerpunkt)) Vorschlag: \(tauschText(plan, tausch.a, tausch.b))."
        return [PlanHinweis(id: "verteilung", text: text, tausch: [tausch.a, tausch.b])]
    }

    /// The one swap of two weekdays that lowers `wertung` the most; nil when no swap helps.
    static func besterTausch(_ plan: TrainingsPlan, schwerpunkt: (TrainingsTag) -> Set<String>) -> (a: Int, b: Int)? {
        let jetzt = wertung(plan, schwerpunkt: schwerpunkt)
        guard jetzt > 0 else { return nil }
        var beste: (a: Int, b: Int, wert: Int)?
        for a in 1...6 {
            for b in (a + 1)...7 where art(plan, a) != art(plan, b) {
                let wert = wertung(tauschen(plan, a, b), schwerpunkt: schwerpunkt)
                if wert < (beste?.wert ?? jetzt) { beste = (a, b, wert) }
            }
        }
        return beste.map { ($0.a, $0.b) }
    }

    /// The first placement problem, in words.
    static func problem(_ plan: TrainingsPlan, schwerpunkt: (TrainingsTag) -> Set<String>) -> String {
        for w in 1...7 {
            let n = w % 7 + 1
            guard case .training(let a) = art(plan, w), case .training(let b) = art(plan, n) else { continue }
            let gleich = schwerpunkt(a).intersection(schwerpunkt(b)).sorted()
            if !gleich.isEmpty {
                return "\(gleich.joined(separator: " und ")) kommt am \(TrainingLogik.wochentagName[w - 1]) und gleich wieder am \(TrainingLogik.wochentagName[n - 1]) dran, dazwischen braucht der Muskel Erholung."
            }
        }
        return "\(laengsteSerie(plan)) Trainingstage am Stück ohne Pause."
    }

    /// "Ruhetag auf Dienstag, Beine auf Mittwoch".
    static func tauschText(_ plan: TrainingsPlan, _ a: Int, _ b: Int) -> String {
        "\(name(art(plan, b))) auf \(TrainingLogik.wochentagName[a - 1]), \(name(art(plan, a))) auf \(TrainingLogik.wochentagName[b - 1])"
    }

    private static func name(_ art: TagArt) -> String {
        switch art {
        case .training(let t): return t.name.isEmpty ? "Training" : t.name
        case .ruhe: return "Ruhetag"
        case .offen: return "offen"
        }
    }
}
