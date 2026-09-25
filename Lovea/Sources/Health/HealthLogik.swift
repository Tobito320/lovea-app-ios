import Foundation

/// Pure Health logic (Z-20.3): day-boundary-safe folding of HealthKit/habit ops, goal history, month
/// grids, sleep and the one-time step backfill. No HealthKit, no Raum — `HealthModell` is the only
/// caller that touches either. Days are always `Datum`'s `yyyy-MM-dd` strings (Europe/Berlin,
/// Monday-first, DST-safe — shared with the Kalender block, see `Kalender/Logik/Datum.swift`).

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
    /// The originating `Op.id` (I-2). With a unique default so plain test entries never look
    /// like "the same op".
    var id: String = UUID().uuidString
    /// Z-36.1: steps from the one-time 90-day backfill — shown, but never worth points or challenge
    /// progress. A later unflagged op for the same day wins by `seq` and counts normally.
    var nachgetragen: Bool = false
}

enum HealthFaltung {
    /// Folds one entry into a per-person-per-day map, keeping the higher-`seq` entry on a clash.
    // ponytail: only the winner per day is kept — a confirmed op from elsewhere that lost to a still-
    // unconfirmed own op is gone if that own op later confirms BELOW it (needs a live broadcast to beat
    // a catch-up page); the next launch's seq-ordered replay heals it. Keep all ops per day if it bites.
    static func aufnehmen<Wert: Sendable>(_ bisher: inout [Person: [String: TagesEintrag<Wert>]], _ neu: TagesEintrag<Wert>) {
        gewinner(&bisher[neu.von, default: [:]][neu.datum], neu)
    }

    /// The rule for one slot (a day, a habit definition, a hide switch): the higher `seq` wins,
    /// `nil` (own, unconfirmed) counts as newest. Final-Review I-2: the confirmed echo of an own op
    /// (same `id`) replaces its optimistic copy, so it takes part with its real `seq` from then on —
    /// otherwise it stays `nil` (= newest) forever and a later widget/second-device op could never
    /// beat it. A redelivery without `seq` (the widget merge re-queues an op the log may already have
    /// confirmed) keeps the known `seq`.
    static func gewinner<Wert: Sendable>(_ slot: inout TagesEintrag<Wert>?, _ neu: TagesEintrag<Wert>) {
        var neu = neu
        if let alt = slot {
            if alt.id == neu.id {
                neu.seq = neu.seq ?? alt.seq
            } else if (neu.seq ?? .max) < (alt.seq ?? .max) {
                return
            }
        }
        slot = neu
    }

    /// Batch version — used by pure-logic tests and anywhere a full recompute is simpler than an
    /// incremental fold (this app is two people; recomputing from all entries is cheap).
    static func gefaltet<Wert: Sendable>(_ eintraege: [TagesEintrag<Wert>]) -> [Person: [String: TagesEintrag<Wert>]] {
        var ergebnis: [Person: [String: TagesEintrag<Wert>]] = [:]
        for eintrag in eintraege { aufnehmen(&ergebnis, eintrag) }
        return ergebnis
    }

    /// Z-36.1, Review-Fokus 2: what points and challenges may see. Filtered AFTER folding, so a
    /// backfilled day that later got a real value counts, and a backfilled winner never lets an
    /// older value through.
    static func punktefaehig(_ eintraege: [TagesEintrag<Int>]) -> [Person: [String: TagesEintrag<Int>]] {
        gefaltet(eintraege).mapValues { tage in tage.filter { !$0.value.nachgetragen } }
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
    /// The originating `Op.id` (I-2), unique default for the same reason as `TagesEintrag.id`.
    var id: String = UUID().uuidString
}

enum HealthLogik {
    // MARK: - Ziel-Historie

    /// Final-Review I-2: the confirmed echo of an own change replaces its optimistic copy in place
    /// (so it gets its real `seq`) instead of being appended or dropped.
    static func zielAufnehmen(_ liste: inout [ZielAenderung], _ neu: ZielAenderung) {
        guard let i = liste.firstIndex(where: { $0.id == neu.id }) else { liste.append(neu); return }
        liste[i].seq = neu.seq ?? liste[i].seq
    }

    /// The goal value in effect on `tag`: the latest change (by day, then `seq`) at or before it,
    /// else `standard`. Ties (two still-unconfirmed changes) go to the later-arrived one — `max(by:)`
    /// alone keeps the FIRST of equal elements.
    static func zielAmTag(_ tag: String, _ aenderungen: [ZielAenderung], standard: Int) -> Int {
        aenderungen.enumerated()
            .filter { $0.element.datum <= tag }
            .max { ($0.element.datum, $0.element.seq ?? .max, $0.offset) < ($1.element.datum, $1.element.seq ?? .max, $1.offset) }?
            .element.wert ?? standard
    }

    // MARK: - Ansichten (hier nur die reine Tage-Erzeugung)

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

    // MARK: - Einmaliges Nachtragen (Z-36.1, Review-Fokus 2)

    /// Days the one-time backfill may send: the last 90 days minus the live window (today and the
    /// 7 days before, which `HealthModell` keeps sending unflagged and worth points), and never a day
    /// that already has an own value — a flagged op would otherwise win by `seq` and take its points.
    /// Newest first. Days are stepped by calendar day, so DST (25.10.2026) never skips or doubles one.
    static func nachtragTage(heute: String, vorhanden: Set<String>) -> [String] {
        (8..<90).map { Datum.addTage(heute, -$0) }.filter { !vorhanden.contains($0) }
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

    /// Final-Review I-4: the ONE night that belongs to wake day `tag` (Spec 3.1). Intervals with gaps
    /// up to 3 h (waking up at night) form a block; of the blocks that END on `tag`, the longest one
    /// is the night. So the night before (ends the day before) is never added in, and an afternoon
    /// nap on `tag` neither adds minutes nor moves the wake-up time.
    static func schlafNacht(_ intervalle: [SchlafIntervall], tag: String) -> (minuten: Int, von: Date, bis: Date)? {
        var bloecke: [[SchlafIntervall]] = []
        var blockEnde = Date.distantPast
        for intervall in intervalle.sorted(by: { $0.von < $1.von }) {
            if bloecke.isEmpty || intervall.von.timeIntervalSince(blockEnde) > 3 * 3600 {
                bloecke.append([intervall])
            } else {
                bloecke[bloecke.count - 1].append(intervall)
            }
            blockEnde = max(blockEnde, intervall.bis)
        }
        return bloecke
            .compactMap { schlafZusammenfassen($0) }
            .filter { Datum.text($0.bis) == tag }
            .max { $0.minuten < $1.minuten }
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
