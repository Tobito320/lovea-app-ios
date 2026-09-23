import Foundation

/// Pure challenge logic (Z-22.1, Spec 4.2). Same deviation as `PunkteLogik`: takes plain, already-
/// `seq`-aware entry lists instead of raw `Op`s so it stays unit-testable without `Raum`.
enum ChallengeLogik {
    // MARK: - Duell der Woche + Gemeinsam Woche

    struct WochenErgebnis: Sendable, Equatable {
        var montag: String
        var sonntag: String
        var abgeschlossen: Bool
        /// Fair comparison for the Duell: only days where BOTH people have a recorded value (Review-
        /// Fokus 4 — a day one person has no Health data for must never count as a 0 against them).
        var schritteDuell: [Person: Int]
        var duellSieger: Person?
        /// Full sum (missing days simply contribute 0 from that person — "gemeinsam" only ever adds).
        var schritteGesamt: Int
        var gemeinsamZiel: Int
        /// The day the combined total first reached `gemeinsamZiel`, nil if not (yet) reached.
        var gemeinsamErreichtAm: String?
    }

    static func wochen(heute: String, schritte: [TagesEintrag<Int>], zielGemeinsamWoche: Int) -> [WochenErgebnis] {
        let proTag = HealthFaltung.gefaltet(schritte)
        var montage = Set(proTag.values.flatMap { $0.keys.map(Datum.montagDerWoche) })
        montage.insert(Datum.montagDerWoche(heute))
        return montage.sorted().map { montag in
            let sonntag = Datum.addTage(montag, 6)
            let abgeschlossen = heute > sonntag
            let letzterSichtbarerTag = min(sonntag, heute)
            let tage = (0..<7).map { Datum.addTage(montag, $0) }.filter { $0 <= letzterSichtbarerTag }

            let sharedTage = tage.filter { tag in proTag[.ahmed]?[tag] != nil && proTag[.annika]?[tag] != nil }
            let duell = Person.allCases.reduce(into: [Person: Int]()) { dict, person in
                dict[person] = sharedTage.reduce(0) { $0 + (proTag[person]?[$1]?.wert ?? 0) }
            }
            let sieger: Person? = abgeschlossen && !sharedTage.isEmpty && duell[.ahmed] != duell[.annika]
                ? (duell[.ahmed]! > duell[.annika]! ? .ahmed : .annika) : nil

            var laufsumme = 0
            var erreichtAm: String?
            for tag in tage {
                laufsumme += (proTag[.ahmed]?[tag]?.wert ?? 0) + (proTag[.annika]?[tag]?.wert ?? 0)
                if erreichtAm == nil, laufsumme >= zielGemeinsamWoche { erreichtAm = tag }
            }

            return WochenErgebnis(
                montag: montag, sonntag: sonntag, abgeschlossen: abgeschlossen,
                schritteDuell: duell, duellSieger: sieger,
                schritteGesamt: laufsumme, gemeinsamZiel: zielGemeinsamWoche, gemeinsamErreichtAm: erreichtAm
            )
        }
    }

    // MARK: - Gemeinsam Monat

    static let zielGemeinsamMonat = 600_000

    struct MonatsErgebnis: Sendable, Equatable {
        var monat: String // yyyy-MM
        var schritteGesamt: Int
        var gemeinsamErreichtAm: String?
    }

    static func monate(heute: String, schritte: [TagesEintrag<Int>]) -> [MonatsErgebnis] {
        let proTag = HealthFaltung.gefaltet(schritte)
        var monate = Set(proTag.values.flatMap { $0.keys.map { String($0.prefix(7)) } })
        monate.insert(String(heute.prefix(7)))
        return monate.sorted().map { monat in
            let erster = monat + "-01"
            let tageImMonat = Datum.kalender.range(of: .day, in: .month, for: Datum.datum(erster))?.count ?? 30
            let letzterTag = Datum.addTage(erster, tageImMonat - 1)
            let tage = (0..<tageImMonat).map { Datum.addTage(erster, $0) }.filter { $0 <= min(letzterTag, heute) }
            var laufsumme = 0
            var erreichtAm: String?
            for tag in tage {
                laufsumme += (proTag[.ahmed]?[tag]?.wert ?? 0) + (proTag[.annika]?[tag]?.wert ?? 0)
                if erreichtAm == nil, laufsumme >= zielGemeinsamMonat { erreichtAm = tag }
            }
            return MonatsErgebnis(monat: monat, schritteGesamt: laufsumme, gemeinsamErreichtAm: erreichtAm)
        }
    }

    // MARK: - Serien (Tagesziel Schritte, 3/7/14/30 Tage am Stück)

    struct SerienBonus: Sendable, Equatable { var von: Person; var datum: String; var laenge: Int; var punkte: Int }

    private static let meilensteine: [(laenge: Int, punkte: Int)] = [(3, 30), (7, 100), (14, 250), (30, 600)]

    /// Every milestone a consecutive-days run crosses, once per run — a run that breaks and starts
    /// over can earn the same milestone again (e.g. two separate 3-day runs both give +30).
    static func serienBoni(heute: String, schritte: [TagesEintrag<Int>], zielSchritte: [Person: [ZielAenderung]]) -> [SerienBonus] {
        let proTag = HealthFaltung.gefaltet(schritte)
        var ergebnis: [SerienBonus] = []
        for person in Person.allCases {
            guard let ersterTag = (proTag[person] ?? [:]).keys.filter({ $0 <= heute }).min() else { continue }
            var lauf = 0
            var tag = ersterTag
            while tag <= heute {
                let ziel = HealthLogik.zielAmTag(tag, zielSchritte[person] ?? [], standard: 10_000)
                if let wert = proTag[person]?[tag]?.wert, wert >= ziel {
                    lauf += 1
                    if let meilenstein = meilensteine.first(where: { $0.laenge == lauf }) {
                        ergebnis.append(SerienBonus(von: person, datum: tag, laenge: lauf, punkte: meilenstein.punkte))
                    }
                } else {
                    lauf = 0
                }
                tag = Datum.addTage(tag, 1)
            }
        }
        return ergebnis
    }

    // MARK: - Punkte-Summe aus abgeschlossenen/erreichten Challenges

    static func punkteBonus(wochen: [WochenErgebnis], monate: [MonatsErgebnis], serien: [SerienBonus]) -> [Person: Int] {
        var summe: [Person: Int] = [:]
        for woche in wochen {
            if woche.abgeschlossen, let sieger = woche.duellSieger { summe[sieger, default: 0] += 150 }
            if woche.gemeinsamErreichtAm != nil { for p in Person.allCases { summe[p, default: 0] += 150 } }
        }
        for monat in monate where monat.gemeinsamErreichtAm != nil {
            for p in Person.allCases { summe[p, default: 0] += 500 }
        }
        for bonus in serien { summe[bonus.von, default: 0] += bonus.punkte }
        return summe
    }
}
