import Foundation

/// Pure Health logic (Z-20.3): day-boundary-safe folding of HealthKit/habit ops, Gym/Wasser
/// levels, and week/month/year grids. No HealthKit, no Raum — `HealthModell` is the only caller
/// that touches either. Days are always `Datum`'s `yyyy-MM-dd` strings (Europe/Berlin, Monday-first,
/// DST-safe — shared with the Kalender block, see `Kalender/Logik/Datum.swift`).

/// One HealthKit/habit value with just enough of its originating `Op` to resolve "same person+day,
/// highest `seq` wins" without needing `Raum`/`OpLog` — `Raum` delivers ops in arrival order, not
/// `seq` order (a live broadcast can land before the catch-up page below it), so per-day folds must
/// compare `seq` explicitly (Review-Fokus 2). `seq == nil` is an own unconfirmed op — the newest
/// information available, so it sorts AFTER any confirmed `seq`, same as `SeqFaltung.sortiert`.
struct TagesEintrag<Wert: Sendable>: Sendable {
    var seq: Int?
    var von: Person
    /// The day this value is FOR (the op's `datum` field).
    var datum: String
    /// The Berlin day the op was actually sent (`Datum.text(op.zeit)`) — needed for the 7-day
    /// Gym-backfill rule (Spec 4.1). Irrelevant for steps/water, always set for uniformity.
    var gesendetAm: String
    var wert: Wert
}

enum HealthFaltung {
    /// Folds one entry into a per-person-per-day map, keeping the higher-`seq` entry on a clash.
    static func aufnehmen<Wert: Sendable>(_ bisher: inout [Person: [String: TagesEintrag<Wert>]], _ neu: TagesEintrag<Wert>) {
        let alt = bisher[neu.von]?[neu.datum]
        guard alt == nil || (neu.seq ?? .max) >= (alt!.seq ?? .max) else { return }
        bisher[neu.von, default: [:]][neu.datum] = neu
    }

    /// Batch version — used by pure-logic tests and anywhere a full recompute is simpler than an
    /// incremental fold (this app is two people; recomputing from all entries is cheap).
    static func gefaltet<Wert: Sendable>(_ eintraege: [TagesEintrag<Wert>]) -> [Person: [String: TagesEintrag<Wert>]] {
        var ergebnis: [Person: [String: TagesEintrag<Wert>]] = [:]
        for eintrag in eintraege { aufnehmen(&ergebnis, eintrag) }
        return ergebnis
    }
}

/// One `einstellung.setzen ziel.*` change: `datum` is the Berlin day it was SENT (not a target
/// day — goals aren't per-day data). Looking up "the goal in effect on day X" needs the whole
/// history, not just the latest value: changing a goal today must not retroactively change how
/// many points a past day earned (Z-21.2 "Ziele ändern" would otherwise rewrite old `PunkteLogik`
/// results, which can even retroactively make an already-accepted `BesitzLogik` purchase invalid).
struct ZielAenderung: Sendable {
    var seq: Int?
    var datum: String
    var wert: Int
}

enum HealthLogik {
    // MARK: - Ziel-Historie

    /// The goal value in effect on `tag`: the latest change (by day, then `seq`) at or before it,
    /// else `standard`.
    static func zielAmTag(_ tag: String, _ aenderungen: [ZielAenderung], standard: Int) -> Int {
        aenderungen
            .filter { $0.datum <= tag }
            .max { ($0.datum, $0.seq ?? .max) < ($1.datum, $1.seq ?? .max) }?
            .wert ?? standard
    }

    // MARK: - Stufen (Z-20.3, Spec 3.2) — 0...3 für Gym und Wasser

    /// 0 nichts, 1 (leicht) heute abgehakt, 2 (mittel) Wochenziel diese Woche auf Kurs, 3 (stark)
    /// Wochenziel schon geschafft. "Auf Kurs" ist eine einfache Pace-Heuristik: mindestens so viele
    /// Tage geschafft, wie bei gleichmäßigem Tempo bis zum heutigen Wochentag fällig wären.
    /// // ponytail: lineares Pacing, kein Blick auf die Restwoche. Upgrade, falls das zu streng wirkt.
    static func gymStufe(heuteAbgehakt: Bool, erledigtInWoche: Int, ziel: Int, wochentag: Int) -> Int {
        let ziel = max(ziel, 1)
        if erledigtInWoche >= ziel { return 3 }
        let faelligPace = Int((Double(ziel) * Double(wochentag) / 7).rounded(.up))
        if erledigtInWoche >= faelligPace { return 2 }
        return heuteAbgehakt ? 1 : 0
    }

    /// 0 nichts getrunken, 1 unter 50 %, 2 ab 50 %, 3 Tagesziel erreicht.
    static func wasserStufe(glaeser: Int, ziel: Int) -> Int {
        guard glaeser > 0 else { return 0 }
        let ziel = max(ziel, 1)
        if glaeser >= ziel { return 3 }
        if glaeser * 2 >= ziel { return 2 }
        return 1
    }

    // MARK: - Ansichten (Z-21.1, hier nur die reine Tage-Erzeugung)

    /// Montag...Sonntag der Woche, die `tag` enthält.
    static func wocheTage(_ tag: String) -> [String] {
        let montag = Datum.montagDerWoche(tag)
        return (0..<7).map { Datum.addTage(montag, $0) }
    }

    /// Kalendergitter für einen Monat, Montag-first, `nil` = Füllzelle außerhalb des Monats.
    /// `monateZurueck` 0 = aktueller Monat; ein negativer Aufruf wird auf 0 geklemmt — es gibt
    /// keinen zukünftigen Monat ("nie in die Zukunft: der letzte Monat ist der aktuelle").
    static func monatsGitter(heute: String, monateZurueck: Int) -> [String?] {
        let zurueck = max(0, monateZurueck)
        let aktuellerErster = String(heute.prefix(7)) + "-01"
        guard let zielErster = Datum.kalender.date(byAdding: .month, value: -zurueck, to: Datum.datum(aktuellerErster))
            .map(Datum.text)
        else { return [] }
        let tageImMonat = Datum.kalender.range(of: .day, in: .month, for: Datum.datum(zielErster))?.count ?? 30
        let vorspann = Datum.wochentag(zielErster) - 1 // 0...6, Montag-first
        var zellen: [String?] = Array(repeating: nil, count: vorspann)
        zellen += (0..<tageImMonat).map { Datum.addTage(zielErster, $0) }
        while zellen.count % 7 != 0 { zellen.append(nil) }
        return zellen
    }

    /// Rollendes Jahr (52 Wochen, Montag-first) bis einschließlich `heute` — endet nie in der
    /// Zukunft, weil einfach bei `heute` abgeschnitten wird statt bis Sonntag der laufenden Woche.
    static func jahresGitter(heute: String) -> [String] {
        let montagDieserWoche = Datum.montagDerWoche(heute)
        let start = Datum.addTage(montagDieserWoche, -7 * 51)
        var tag = start
        var tage: [String] = []
        while tag <= heute {
            tage.append(tag)
            tag = Datum.addTage(tag, 1)
        }
        return tage
    }

    // MARK: - Schlaf (Z-20.1)

    struct SchlafIntervall: Sendable { var von: Date; var bis: Date }

    /// Merges overlapping/adjacent asleep intervals (iPhone AND Watch can both write samples for
    /// the same stretch — a naive sum double-counts) and sums what remains. The night is assigned
    /// to the WAKE date (the last interval's end), per Spec 3.1.
    static func schlafZusammenfassen(_ intervalle: [SchlafIntervall]) -> (minuten: Int, von: Date, bis: Date)? {
        guard !intervalle.isEmpty else { return nil }
        let sortiert = intervalle.sorted { $0.von < $1.von }
        var zusammengefuehrt: [SchlafIntervall] = [sortiert[0]]
        for intervall in sortiert.dropFirst() {
            if intervall.von <= zusammengefuehrt[zusammengefuehrt.count - 1].bis {
                zusammengefuehrt[zusammengefuehrt.count - 1].bis = max(zusammengefuehrt[zusammengefuehrt.count - 1].bis, intervall.bis)
            } else {
                zusammengefuehrt.append(intervall)
            }
        }
        let minuten = zusammengefuehrt.reduce(0) { $0 + Int($1.bis.timeIntervalSince($1.von) / 60) }
        return (minuten, zusammengefuehrt[0].von, zusammengefuehrt[zusammengefuehrt.count - 1].bis)
    }

    // MARK: - Senden nur bei Änderung (Z-20.1)

    /// Gleiche Schwelle wie bisher für Schritte: sofort bei neuem Tag oder Sprung ≥50, sonst
    /// höchstens alle 15 Minuten (Throttle, damit der Partner zeitnah nachzieht, ohne die
    /// Warteschlange mit einer Op pro Schritt zu fluten).
    static func sollSchritteSenden(anzahl: Int, zuletzt: (datum: String, anzahl: Int)?, heutigerTag: String, vergangen: TimeInterval) -> Bool {
        guard let zuletzt, zuletzt.datum == heutigerTag else { return true }
        return abs(anzahl - zuletzt.anzahl) >= 50 || vergangen >= 15 * 60
    }
}
