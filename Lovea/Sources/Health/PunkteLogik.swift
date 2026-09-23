import Foundation

/// Pure points logic (Z-22.1, Spec 4.1). All numbers from Spec 4.1. Never stores a running total —
/// the balance is always a fold over ops (here: over the already-deduped `TagesEintrag` lists that
/// `PunkteModell` builds from ops), so both devices land on the same number.
///
/// Deviation from `schnittstellen.md`'s sketch `PunkteLogik.stand(ops, heute, kalender)`: this takes
/// plain per-source entry lists (steps/gym/water, each carrying `seq`) instead of raw `Op`, so the
/// "same day set twice, highest `seq` wins" rule (Review-Fokus 2) is directly unit-testable here
/// instead of only through the untested `PunkteModell` adapter. `PunkteModell` does the op → entry
/// adaptation and owns the Zielplan-listed `stand(ops, heute, kalender)` surface at the model layer.
enum PunkteLogik {
    struct Eintrag: Sendable, Equatable { var datum: String; var von: Person; var grund: String; var punkte: Int }

    struct SpielSieg: Sendable { var von: Person; var datum: String }

    /// One day's own components (everything except the weekly Gym bonus, which needs the whole week).
    static func tagesPunkte(schritte: Int?, zielSchritte: Int, gymAbgehakt: Bool, wasser: Int, zielWasser: Int, chatStreakTag: Bool, spieleGewonnen: Int) -> Int {
        var summe = 0
        if let schritte {
            summe += min(schritte / 100, 300)
            if schritte >= zielSchritte { summe += 20 }
            if schritte >= 15_000 { summe += 30 }
        }
        if gymAbgehakt { summe += 40 }
        if zielWasser > 0, wasser >= zielWasser { summe += 10 }
        if chatStreakTag { summe += 5 }
        summe += spieleGewonnen * 10
        return summe
    }

    /// Full breakdown up to (incl.) `heute` — the source `PunkteModell.verlauf` reads and `stand`
    /// sums. `gym` entries older than 7 days past their credited day are dropped entirely here
    /// (Spec 4.1: "sonst keine Punkte") — both for the daily +40 and for the weekly-goal count.
    static func verlauf(
        heute: String,
        schritte: [TagesEintrag<Int>],
        gym: [TagesEintrag<Int>],
        wasser: [TagesEintrag<Int>],
        zielSchritte: [Person: [ZielAenderung]],
        zielWasser: [Person: [ZielAenderung]],
        zielGym: [Person: [ZielAenderung]],
        chatStreakTage: Set<String>,
        spieleSiege: [SpielSieg]
    ) -> [Eintrag] {
        let schritteProTag = HealthFaltung.gefaltet(schritte)
        let gymEintraege = gym.filter { Datum.tageZwischen($0.datum, $0.gesendetAm) <= 7 }
        let gymProTag = HealthFaltung.gefaltet(gymEintraege)
        let wasserProTag = HealthFaltung.gefaltet(wasser)

        var tage = Set(chatStreakTage)
        for proTag in [schritteProTag, wasserProTag] { for tageProPerson in proTag.values { tage.formUnion(tageProPerson.keys) } }
        for tageProPerson in gymProTag.values { tage.formUnion(tageProPerson.keys) }
        tage = Set(tage.filter { $0 <= heute })

        var eintraege: [Eintrag] = []
        for tag in tage.sorted() {
            for person in Person.allCases {
                let schrittWert = schritteProTag[person]?[tag]?.wert
                let zielS = HealthLogik.zielAmTag(tag, zielSchritte[person] ?? [], standard: 10_000)
                let gymAbgehakt = (gymProTag[person]?[tag]?.wert ?? 0) > 0
                let wasserWert = wasserProTag[person]?[tag]?.wert ?? 0
                let zielW = HealthLogik.zielAmTag(tag, zielWasser[person] ?? [], standard: 8)
                let streakHeute = chatStreakTage.contains(tag)
                let siege = spieleSiege.filter { $0.von == person && $0.datum == tag }.count
                let punkte = tagesPunkte(schritte: schrittWert, zielSchritte: zielS, gymAbgehakt: gymAbgehakt, wasser: wasserWert, zielWasser: zielW, chatStreakTag: streakHeute, spieleGewonnen: siege)
                if punkte != 0 { eintraege.append(Eintrag(datum: tag, von: person, grund: "Tag", punkte: punkte)) }
            }
        }
        eintraege += wochenGymBonus(heute: heute, gymProTag: gymProTag, zielGym: zielGym)
        return eintraege.sorted { ($0.datum, $0.von.rawValue) < ($1.datum, $1.von.rawValue) }
    }

    static func stand(
        heute: String,
        schritte: [TagesEintrag<Int>],
        gym: [TagesEintrag<Int>],
        wasser: [TagesEintrag<Int>],
        zielSchritte: [Person: [ZielAenderung]],
        zielWasser: [Person: [ZielAenderung]],
        zielGym: [Person: [ZielAenderung]],
        chatStreakTage: Set<String>,
        spieleSiege: [SpielSieg]
    ) -> [Person: Int] {
        var summe: [Person: Int] = [:]
        for eintrag in verlauf(heute: heute, schritte: schritte, gym: gym, wasser: wasser, zielSchritte: zielSchritte, zielWasser: zielWasser, zielGym: zielGym, chatStreakTage: chatStreakTage, spieleSiege: spieleSiege) {
            summe[eintrag.von, default: 0] += eintrag.punkte
        }
        return summe
    }

    /// +80 once per person and ISO week (Mo...So) once their Gym goal for that week is met —
    /// attributed to the day the Nth qualifying day happened.
    private static func wochenGymBonus(heute: String, gymProTag: [Person: [String: TagesEintrag<Int>]], zielGym: [Person: [ZielAenderung]]) -> [Eintrag] {
        var ergebnis: [Eintrag] = []
        for person in Person.allCases {
            let abgehakteTage = Set((gymProTag[person] ?? [:]).filter { $0.value.wert > 0 }.keys)
            let wochenMontage = Set(abgehakteTage.map(Datum.montagDerWoche)).filter { $0 <= heute }
            for montag in wochenMontage {
                let ziel = max(1, HealthLogik.zielAmTag(montag, zielGym[person] ?? [], standard: 3))
                let wocheSortiert = (0..<7).map { Datum.addTage(montag, $0) }.filter { abgehakteTage.contains($0) }.sorted()
                guard wocheSortiert.count >= ziel else { continue }
                let erreichtAm = wocheSortiert[ziel - 1]
                ergebnis.append(Eintrag(datum: erreichtAm, von: person, grund: "Gym-Wochenziel", punkte: 80))
            }
        }
        return ergebnis
    }
}
