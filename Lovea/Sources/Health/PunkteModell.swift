import Foundation
import Observation

/// Adapts ops (and `ChatModell`/`SpieleModell`) into the plain inputs `PunkteLogik`/`ChallengeLogik`/
/// `BesitzLogik` take, and is the Zielplan's `PunkteLogik.stand(ops, heute, kalender)` surface at the
/// model layer (see the deviation note on `PunkteLogik`). Reuses `HealthModell`'s already-deduped
/// steps/gym/water/goal state instead of re-observing `schritte.setzen`/`habit.setzen`/`einstellung.setzen`
/// a second time.
// ponytail: `stand`/`verlauf`/`wochen`/... recompute the full fold on the main thread on every
// access (two people, at most a few thousand ops — measured as fine for Runde 1's equivalents).
// Zielplan says "Faltungen im Hintergrund": move to a background actor/cache if a profiler ever
// disagrees, e.g. once the Health tab polls these every frame during a scroll.
@MainActor
@Observable
final class PunkteModell {
    static let shared = PunkteModell()

    private(set) var spieleSiege: [PunkteLogik.SpielSieg] = []
    /// Keyed by the OUTER op id, not `d.id` — a purchase op is delivered twice (optimistic `seq ==
    /// nil`, then confirmed): overwriting on every delivery (instead of a one-shot `angewendeteOps`
    /// guard) is what lets `seq` actually update once confirmed. Without this, an own purchase would
    /// keep `seq == nil` forever on THIS device, so on "two devices buy at once" (Review-Fokus 3)
    /// each device would sort its OWN purchase last and the two devices could disagree on which one
    /// wins — `BesitzLogik` already dedups by id, so re-storing the same id is always safe.
    private var kaeufeNachId: [String: BesitzLogik.Kauf] = [:]
    private var kaeufe: [BesitzLogik.Kauf] { Array(kaeufeNachId.values) }

    private var angewendeteSpielOps: Set<String> = []
    /// Last seen `spiel.ergebnis` per game id, to turn its running tally into "who won THIS round"
    /// (a positive delta on exactly one side) and to reject a stale/out-of-order redelivery.
    private var letztesSpielErgebnis: [String: SpielErgebnisD] = [:]

    private init() {
        Raum.shared.beobachten(["spiel.ergebnis"]) { [weak self] op in self?.spielErgebnisAnwenden(op) }
        Raum.shared.beobachten(["shop.kauf"]) { [weak self] op in self?.kaufAnwenden(op) }
    }

    private var heute: String { Datum.text(Date()) }

    private var schritteEintraege: [TagesEintrag<Int>] { HealthModell.shared.schritte.values.flatMap { $0.values } }
    private var gymEintraege: [TagesEintrag<Int>] { HealthModell.shared.gym.values.flatMap { $0.values } }
    private var wasserEintraege: [TagesEintrag<Int>] { HealthModell.shared.wasser.values.flatMap { $0.values } }

    /// "Beide gesendet" pro Tag, direkt aus `ChatModell.nachrichten` (volle Historie, kein Paging) —
    /// dieselbe Regel wie `Streak.berechnen`, hier aber für JEDEN Tag statt nur die laufende Serie.
    private var chatStreakTage: Set<String> {
        var proTag: [String: Set<Person>] = [:]
        for nachricht in ChatModell.shared.nachrichten where nachricht.snap != nil {
            proTag[Datum.text(nachricht.zeit), default: []].insert(nachricht.von)
        }
        return Set(proTag.filter { $0.value.count >= Person.allCases.count }.keys)
    }

    // MARK: - Punkte

    var stand: [Person: Int] {
        var summe = PunkteLogik.stand(
            heute: heute, schritte: schritteEintraege, gym: gymEintraege, wasser: wasserEintraege,
            zielSchritte: HealthModell.shared.zielSchritteAenderungen, zielWasser: HealthModell.shared.zielWasserAenderungen,
            zielGym: HealthModell.shared.zielGymAenderungen, chatStreakTage: chatStreakTage, spieleSiege: spieleSiege
        )
        for (person, punkte) in ChallengeLogik.punkteBonus(wochen: wochen, monate: monate, serien: serien) {
            summe[person, default: 0] += punkte
        }
        return summe
    }

    /// Z-22.2 "Wofür?": `PunkteLogik.verlauf` allein (Tage + Gym-Wochenziel) erklärt nicht die volle
    /// `stand`-Summe — die Challenge-Boni aus `ChallengeLogik.punkteBonus` fehlen dort, weil die reine
    /// Logik keine Vorstellung von "Woche"/"Monat" als Anzeige-Einheit hat. Hier zusammengeführt, damit
    /// die Historie und der Punktestand-Chip (Z-22.2) auf dieselbe Summe kommen.
    /// // ponytail: Käufe fehlen noch als negative Einträge (kein `datum` in `BesitzLogik.Kauf`, Shop
    /// ist Block 23 — nachrüsten, sobald Käufe eine Op-Zeit mitführen).
    var verlauf: [PunkteLogik.Eintrag] {
        var eintraege = PunkteLogik.verlauf(
            heute: heute, schritte: schritteEintraege, gym: gymEintraege, wasser: wasserEintraege,
            zielSchritte: HealthModell.shared.zielSchritteAenderungen, zielWasser: HealthModell.shared.zielWasserAenderungen,
            zielGym: HealthModell.shared.zielGymAenderungen, chatStreakTage: chatStreakTage, spieleSiege: spieleSiege
        )
        for woche in wochen {
            if woche.abgeschlossen, let sieger = woche.duellSieger {
                eintraege.append(PunkteLogik.Eintrag(datum: woche.sonntag, von: sieger, grund: "Duell der Woche", punkte: 150))
            }
            if let erreichtAm = woche.gemeinsamErreichtAm {
                for p in Person.allCases { eintraege.append(PunkteLogik.Eintrag(datum: erreichtAm, von: p, grund: "Gemeinsam Woche", punkte: 150)) }
            }
        }
        for monat in monate {
            guard let erreichtAm = monat.gemeinsamErreichtAm else { continue }
            for p in Person.allCases { eintraege.append(PunkteLogik.Eintrag(datum: erreichtAm, von: p, grund: "Gemeinsam Monat", punkte: 500)) }
        }
        for bonus in serien {
            eintraege.append(PunkteLogik.Eintrag(datum: bonus.datum, von: bonus.von, grund: "Serie \(bonus.laenge) Tage", punkte: bonus.punkte))
        }
        return eintraege.sorted { ($0.datum, $0.von.rawValue) < ($1.datum, $1.von.rawValue) }
    }

    // MARK: - Challenges

    private var wochen: [ChallengeLogik.WochenErgebnis] {
        ChallengeLogik.wochen(heute: heute, schritte: schritteEintraege, zielGemeinsamWocheAenderungen: HealthModell.shared.zielGemeinsamWocheAenderungen)
    }

    private var monate: [ChallengeLogik.MonatsErgebnis] {
        ChallengeLogik.monate(heute: heute, schritte: schritteEintraege)
    }

    private var serien: [ChallengeLogik.SerienBonus] {
        ChallengeLogik.serienBoni(heute: heute, schritte: schritteEintraege, zielSchritte: HealthModell.shared.zielSchritteAenderungen)
    }

    /// Für die Health-Tab-Anzeige (Block 21/Z-22.2): laufende Woche/Monat/Serie mit Fortschritt.
    var aktuelleWoche: ChallengeLogik.WochenErgebnis? { wochen.first { $0.montag == Datum.montagDerWoche(heute) } }
    var aktuellerMonat: ChallengeLogik.MonatsErgebnis? { monate.first { $0.monat == String(heute.prefix(7)) } }
    /// Die letzte ABGESCHLOSSENE Woche (für den Duell-Ausgang) — `aktuelleWoche` ist nie
    /// `abgeschlossen`, solange sie noch läuft, deshalb braucht die Konfetti-Prüfung diese getrennt.
    var letzteAbgeschlosseneWoche: ChallengeLogik.WochenErgebnis? {
        wochen.filter(\.abgeschlossen).max { $0.montag < $1.montag }
    }
    var laufendeSerien: [Person: Int] {
        ChallengeLogik.laufendeSerie(heute: heute, schritte: schritteEintraege, zielSchritte: HealthModell.shared.zielSchritteAenderungen)
    }

    // MARK: - Shop / Besitz (BesitzLogik aus Z-23.1)

    /// Verfügbarer (ausgebbarer) Punktestand nach Käufen — das, was Anzeigen wie `PunkteChip` zeigen
    /// sollten, nicht `stand` (Summe aller je verdienten Punkte, der Kaufeinsatz für `kaufen`/`besitzt`).
    /// Default-`preis` ist `ShopKatalog` (Block 23); ein eigener Katalog lässt sich weiter durchreichen.
    func verfuegbar(_ person: Person, preis: (String) -> Int? = { ShopKatalog.artikel($0)?.preis }) -> Int {
        let ergebnis = BesitzLogik.auswerten(kaeufe, verdient: stand, preis: preis)
        return (stand[person] ?? 0) - (ergebnis.ausgegeben[person] ?? 0)
    }

    /// `preis`: Default `ShopKatalog.artikel(id)?.preis`. `nil` heißt "kein solcher Artikel".
    func besitzt(_ artikel: String, _ person: Person, preis: (String) -> Int? = { ShopKatalog.artikel($0)?.preis }) -> Bool {
        BesitzLogik.auswerten(kaeufe, verdient: stand, preis: preis).besitzt(artikel, person)
    }

    /// Prüft den Stand VOR dem Senden (sofortige "Nicht genug Punkte"-Rückmeldung); die Faltung über
    /// `shop.kauf` bleibt die eigentliche Wahrheit (Review-Fokus 3, gleichzeitige Käufe).
    @discardableResult
    func kaufen(artikel: String, fuer: Person, preis: (String) -> Int?) -> Bool {
        guard let ich = Raum.shared.ich, let preisWert = preis(artikel) else { return false }
        let aktuellerStand = stand
        let ergebnis = BesitzLogik.auswerten(kaeufe, verdient: aktuellerStand, preis: preis)
        let verfuegbar = (aktuellerStand[ich] ?? 0) - (ergebnis.ausgegeben[ich] ?? 0)
        guard verfuegbar >= preisWert else { return false }
        Raum.shared.senden("shop.kauf", ShopKaufD(id: UUID().uuidString, artikel: artikel, fuer: fuer))
        return true
    }

    // MARK: - Ops falten

    private func spielErgebnisAnwenden(_ op: Op) {
        guard angewendeteSpielOps.insert(op.id).inserted, let d = op.daten(SpielErgebnisD.self) else { return }
        let vorher = letztesSpielErgebnis[d.id] ?? SpielErgebnisD(id: d.id, gespielt: 0, punkte: SpielPunkte())
        // Ops kommen nicht zwingend in `gespielt`-Reihenfolge an (Review-Fokus 2-artig): eine
        // ältere Op NACH einer neueren würde sonst eine negative Differenz liefern und der Person
        // mit weniger Punkten fälschlich einen Sieg gutschreiben.
        guard d.gespielt > vorher.gespielt else { return }
        letztesSpielErgebnis[d.id] = d
        let deltaAhmed = d.punkte.ahmed - vorher.punkte.ahmed
        let deltaAnnika = d.punkte.annika - vorher.punkte.annika
        guard deltaAhmed != deltaAnnika else { return } // unentschieden/keine Änderung: kein Sieg
        let sieger: Person = deltaAhmed > deltaAnnika ? .ahmed : .annika
        spieleSiege.append(PunkteLogik.SpielSieg(von: sieger, datum: Datum.text(op.zeit)))
    }

    private func kaufAnwenden(_ op: Op) {
        guard let d = op.daten(ShopKaufD.self) else { return }
        kaeufeNachId[op.id] = BesitzLogik.Kauf(seq: op.seq, id: op.id, von: op.von, artikel: d.artikel, fuer: d.fuer)
    }
}

private struct ShopKaufD: Codable { var id: String; var artikel: String; var fuer: Person }
