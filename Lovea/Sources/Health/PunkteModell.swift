import Foundation
import Observation

/// Adapts ops (and `ChatModell`/`SpieleModell`) into the plain inputs `PunkteLogik`/`ChallengeLogik`/
/// `BesitzLogik` take, and is the Zielplan's `PunkteLogik.stand(ops, heute, kalender)` surface at the
/// model layer (see the deviation note on `PunkteLogik`). Reuses `HealthModell`'s already-deduped
/// steps/gym/water/goal state instead of re-observing `schritte.setzen`/`habit.setzen`/`einstellung.setzen`
/// a second time.
// ponytail: `stand`/`verlauf`/`wochen`/... still fold on the main thread, but only once per input
// change or day (`gemerkt`, audit #3). Move to a background actor if a profiler ever disagrees.
@MainActor
@Observable
final class PunkteModell {
    static let shared = PunkteModell()

    /// Every `spiel.ergebnis` by op id (Minor 4: wins are derived from all of them, see `spieleSiege`).
    private var spielStaende: [String: PunkteLogik.SpielStand] = [:]
    private var spieleSiege: [PunkteLogik.SpielSieg] { PunkteLogik.spieleSiege(Array(spielStaende.values)) }
    /// Keyed by the OUTER op id, not `d.id` — a purchase op is delivered twice (optimistic `seq ==
    /// nil`, then confirmed): overwriting on every delivery (instead of a one-shot `angewendeteOps`
    /// guard) is what lets `seq` actually update once confirmed. Without this, an own purchase would
    /// keep `seq == nil` forever on THIS device, so on "two devices buy at once" (Review-Fokus 3)
    /// each device would sort its OWN purchase last and the two devices could disagree on which one
    /// wins — `BesitzLogik` already dedups by id, so re-storing the same id is always safe.
    private var kaeufeNachId: [String: BesitzLogik.Kauf] = [:]
    private var kaeufe: [BesitzLogik.Kauf] { Array(kaeufeNachId.values) }

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
        gemerkt("stand") {
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
    }

    /// Z-22.2 "Wofür?": `PunkteLogik.verlauf` allein (Tage + Gym-Wochenziel) erklärt nicht die volle
    /// `stand`-Summe — die Challenge-Boni aus `ChallengeLogik.punkteBonus` fehlen dort, weil die reine
    /// Logik keine Vorstellung von "Woche"/"Monat" als Anzeige-Einheit hat. Hier zusammengeführt, damit
    /// die Historie und der Punktestand-Chip (Z-22.2) auf dieselbe Summe kommen.
    /// Brief I.2: angenommene Käufe (Shop-Kauf und Geschenk) als negative Zeilen, Datum aus `Kauf.zeit`
    /// (`Op.zeit`) — abgelehnte Käufe (Review-Fokus 3) tauchen bewusst nicht auf, sie kosten nichts.
    var verlauf: [PunkteLogik.Eintrag] { gemerkt("verlauf") { verlaufBerechnen() } }

    private func verlaufBerechnen() -> [PunkteLogik.Eintrag] {
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
        let preis: (String) -> Int? = { ShopKatalog.artikel($0)?.preis }
        let urteil = besitzErgebnis(stand: stand, preis: preis)
        for kauf in kaeufe where !urteil.abgelehnt.contains(kauf.id) {
            guard let preisWert = preis(kauf.artikel) else { continue }
            let name = ShopKatalog.artikel(kauf.artikel)?.name ?? kauf.artikel
            let grund = kauf.fuer == kauf.von ? "Kauf: \(name)" : "Geschenk: \(name)"
            eintraege.append(PunkteLogik.Eintrag(datum: Datum.text(kauf.zeit), von: kauf.von, grund: grund, punkte: -preisWert))
        }
        return eintraege.sorted { ($0.datum, $0.von.rawValue) < ($1.datum, $1.von.rawValue) }
    }

    // MARK: - Challenges

    private var wochen: [ChallengeLogik.WochenErgebnis] {
        gemerkt("wochen") {
            ChallengeLogik.wochen(heute: heute, schritte: schritteEintraege, zielGemeinsamWocheAenderungen: HealthModell.shared.zielGemeinsamWocheAenderungen)
        }
    }

    private var monate: [ChallengeLogik.MonatsErgebnis] {
        gemerkt("monate") { ChallengeLogik.monate(heute: heute, schritte: schritteEintraege) }
    }

    private var serien: [ChallengeLogik.SerienBonus] {
        gemerkt("serien") {
            ChallengeLogik.serienBoni(heute: heute, schritte: schritteEintraege, zielSchritte: HealthModell.shared.zielSchritteAenderungen)
        }
    }

    // MARK: - Cache (audit #3)

    /// Bumped the moment any input a cached fold read is about to change. Every cached read touches
    /// it, so SwiftUI and `WidgetStandSchreiber` still notice a change on a cache hit.
    private var version = 0
    @ObservationIgnored private var cache: [String: Any] = [:]
    @ObservationIgnored private var cacheVersion = -1
    @ObservationIgnored private var cacheTag = ""

    /// Runs `berechnen` once per input change (or new day). Its `@Observable` reads (Health, Chat,
    /// own ops) are tracked; the first change to any of them empties the whole cache.
    private func gemerkt<T>(_ schluessel: String, _ berechnen: () -> T) -> T {
        let tag = heute
        if cacheVersion != version || cacheTag != tag {
            cache = [:]
            cacheVersion = version
            cacheTag = tag
        }
        if let wert = cache[schluessel] as? T { return wert }
        let wert = withObservationTracking {
            berechnen()
        } onChange: { [weak self] in
            // Fires synchronously in `willSet` of a main-actor model, before the new value lands.
            MainActor.assumeIsolated { self?.version += 1 }
        }
        cache[schluessel] = wert
        return wert
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
        einkaufsStand(preis: preis).verfuegbar[person] ?? 0
    }

    /// `preis`: Default `ShopKatalog.artikel(id)?.preis`. `nil` heißt "kein solcher Artikel".
    func besitzt(_ artikel: String, _ person: Person, preis: (String) -> Int? = { ShopKatalog.artikel($0)?.preis }) -> Bool {
        besitzErgebnis(stand: stand, preis: preis).besitzt(artikel, person)
    }

    /// Z-23.2: ein Fold-Durchlauf für den ganzen Shop-Bildschirm statt einem pro Kachel — `stand`
    /// ist der LEBENSZEIT-verdiente Punktestand (für den Profil-Chip), `verfuegbar` zieht bereits
    /// ausgegebene Punkte ab (Review-Fokus 3) und ist, was der Shop gegen den Preis prüft.
    func einkaufsStand(preis: (String) -> Int?) -> (verfuegbar: [Person: Int], besitz: BesitzLogik.Ergebnis) {
        let s = stand
        let ergebnis = besitzErgebnis(stand: s, preis: preis)
        var verfuegbar: [Person: Int] = [:]
        // I-1: an accepted purchase stays owned when points later drop (Gym unticked), so earned
        // minus spent can go below 0 — shown as 0, the next points pay that back first.
        for p in Person.allCases { verfuegbar[p] = max(0, (s[p] ?? 0) - (ergebnis.ausgegeben[p] ?? 0)) }
        return (verfuegbar, ergebnis)
    }

    /// The one place every ownership read goes through: purchases (`BesitzLogik.auswerten`) plus the
    /// exclusive articles "Gemeinsam Monat" hands out to both for free (I-5).
    private func besitzErgebnis(stand: [Person: Int], preis: (String) -> Int?) -> BesitzLogik.Ergebnis {
        var ergebnis = BesitzLogik.auswerten(kaeufe, verdient: stand, preis: preis)
        let frei = BesitzLogik.exklusivFrei(
            erreichteMonate: monate.filter { $0.gemeinsamErreichtAm != nil }.count,
            exklusiv: ShopKatalog.alle.filter(\.exklusiv).map(\.id)
        )
        for p in Person.allCases { ergebnis.besitz[p, default: []].formUnion(frei) }
        return ergebnis
    }

    /// Z-23.2: gifts `person` received (`fuer == person`, `von != person`), confirmed and not
    /// rejected, newest first — for the profile's "gift received" celebration. Only called once on
    /// `onAppear`, not per-tile, so a second full fold here is fine.
    func geschenkeErhalten(_ person: Person, preis: (String) -> Int?) -> [BesitzLogik.Kauf] {
        let ergebnis = besitzErgebnis(stand: stand, preis: preis)
        return kaeufe
            .filter { $0.fuer == person && $0.von != person && $0.seq != nil && !ergebnis.abgelehnt.contains($0.id) }
            .sorted { ($0.seq ?? 0) > ($1.seq ?? 0) }
    }

    /// Prüft den Stand VOR dem Senden (sofortige "Nicht genug Punkte"-Rückmeldung); die Faltung über
    /// `shop.kauf` bleibt die eigentliche Wahrheit (Review-Fokus 3, gleichzeitige Käufe).
    @discardableResult
    func kaufen(artikel: String, fuer: Person, preis: (String) -> Int?) -> Bool {
        guard let ich = Raum.shared.ich, let preisWert = preis(artikel) else { return false }
        let aktuellerStand = stand
        let ergebnis = BesitzLogik.auswerten(kaeufe, verdient: aktuellerStand, preis: preis)
        let verdient = aktuellerStand[ich] ?? 0
        guard verdient - (ergebnis.ausgegeben[ich] ?? 0) >= preisWert else { return false }
        // I-1: the earned total travels with the op, so this purchase's verdict is fixed for good.
        Raum.shared.senden("shop.kauf", ShopKaufD(id: UUID().uuidString, artikel: artikel, fuer: fuer, verdient: verdient))
        return true
    }

    // MARK: - Ops falten

    /// Keyed by op id: the confirmed echo just updates `seq` (idempotent).
    private func spielErgebnisAnwenden(_ op: Op) {
        guard let d = op.daten(SpielErgebnisD.self) else { return }
        spielStaende[op.id] = PunkteLogik.SpielStand(
            spiel: d.id, gespielt: d.gespielt, ahmed: d.punkte.ahmed, annika: d.punkte.annika,
            datum: Datum.text(op.zeit), seq: op.seq ?? spielStaende[op.id]?.seq, opId: op.id
        )
    }

    private func kaufAnwenden(_ op: Op) {
        guard let d = op.daten(ShopKaufD.self) else { return }
        kaeufeNachId[op.id] = BesitzLogik.Kauf(seq: op.seq, id: op.id, von: op.von, artikel: d.artikel, fuer: d.fuer, zeit: op.zeit, verdient: d.verdient)
    }
}

/// `verdient` (I-1) is an optional extension of schnittstellen.md's `shop.kauf {id, artikel, fuer}`.
private struct ShopKaufD: Codable { var id: String; var artikel: String; var fuer: Person; var verdient: Int? }
