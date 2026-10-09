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
        Raum.shared.beobachten([DankLogik.art]) { [weak self] op in self?.dankAnwenden(op) }
        Raum.shared.beobachten([KatzeLogik.art]) { [weak self] op in self?.katzeAnwenden(op) }
        Raum.shared.beobachten([StraussGeschenkLogik.art]) { [weak self] op in self?.straussAnwenden(op) }
        Raum.shared.beobachten([KatzePflege.art]) { [weak self] op in self?.futterAnwenden(op) }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            self?.dankSendenFallsFehlt()
        }
    }

    private var dankNachId: [String: Person] = [:]
    private var dankEintraege: [PunkteLogik.Eintrag] { DankLogik.eintraege(dankNachId.map { (id: $0.key, fuer: $0.value) }) }

    /// p61: the cat's strokes by op id, one per day and person (see `KatzeLogik`).
    private var katzeNachId: [String: (tag: String, von: Person)] = [:]
    private var katzeEintraege: [PunkteLogik.Eintrag] { KatzeLogik.eintraege(katzeNachId.map { (id: $0.key, tag: $0.value.tag, von: $0.value.von) }) }

    /// p70 (44): the cat's meals by op id, one per day and person (see `KatzePflege`).
    private var futterNachId: [String: (tag: String, von: Person)] = [:]
    private var futterEintraege: [PunkteLogik.Eintrag] { KatzePflege.eintraege(futterNachId.map { (id: $0.key, tag: $0.value.tag, von: $0.value.von) }) }

    /// p70: bouquet gifts by op ID, one per day and giver (see `StraussGeschenkLogik`).
    private var straussNachId: [String: StraussGeschenkLogik.Geschenk] = [:]

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
        for e in dankEintraege + katzeEintraege + futterEintraege + StraussGeschenkLogik.eintraege(Array(straussNachId.values)) { summe[e.von, default: 0] += e.punkte }
        return summe
    }

    /// Z-22.2 "Wofür?": `PunkteLogik.verlauf` allein (Tage + Gym-Wochenziel) erklärt nicht die volle
    /// `stand`-Summe — die Challenge-Boni aus `ChallengeLogik.punkteBonus` fehlen dort, weil die reine
    /// Logik keine Vorstellung von "Woche"/"Monat" als Anzeige-Einheit hat. Hier zusammengeführt, damit
    /// die Historie und der Punktestand-Chip (Z-22.2) auf dieselbe Summe kommen.
    /// Brief I.2: angenommene Käufe (Shop-Kauf und Geschenk) als negative Zeilen, Datum aus `Kauf.zeit`
    /// (`Op.zeit`) — abgelehnte Käufe (Review-Fokus 3) tauchen bewusst nicht auf, sie kosten nichts.
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
        eintraege += dankEintraege + katzeEintraege + futterEintraege + StraussGeschenkLogik.eintraege(Array(straussNachId.values))
        let preis: (String) -> Int? = { ShopKatalog.artikel($0)?.preis }
        let urteil = besitzErgebnis(stand: stand, preis: preis)
        for kauf in kaeufe where !urteil.abgelehnt.contains(kauf.id) {
            guard let preisWert = preis(kauf.artikel) else { continue }
            let name = ShopKatalog.artikel(kauf.artikel)?.name ?? kauf.artikel
            let grund = kauf.fuer == kauf.von ? "Kauf: \(name)" : "Geschenk: \(name)"
            eintraege.append(PunkteLogik.Eintrag(datum: Datum.text(kauf.zeit), von: kauf.von, grund: grund, punkte: -preisWert))
        }
        for e in ShopErstattung.erstattungen(kaeufe, verdient: stand, katalogPreis: preis) { eintraege += [e.kauf, e.rueckgabe] }
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

    private func dankAnwenden(_ op: Op) {
        guard let d = op.daten(DankLogik.D.self) else { return }
        dankNachId[op.id] = d.fuer
    }

    private func katzeAnwenden(_ op: Op) {
        guard let d = op.daten(KatzeLogik.D.self) else { return }
        katzeNachId[op.id] = (d.tag, op.von)
    }

    private func futterAnwenden(_ op: Op) {
        guard let d = op.daten(KatzePflege.D.self) else { return }
        futterNachId[op.id] = (d.tag, op.von)
    }

    private func straussAnwenden(_ op: Op) {
        guard let d = op.daten(StraussGeschenkLogik.D.self), let g = StraussGeschenkLogik.geschenk(id: op.id, von: op.von, d: d) else { return }
        straussNachId[op.id] = g
    }

    /// p70: has `person` given a bouquet today?
    func straussVerschenkt(_ person: Person) -> Bool { straussNachId[StraussGeschenkLogik.opId(tag: heute, von: person)] != nil }

    /// p70: gives a bouquet to the other one. `StraussGeschenkLogik.punkte` the first time today, 0 afterwards.
    @discardableResult
    func straussSchenken(_ art: StraussArt, text: String?) -> Int {
        guard let ich = Raum.shared.ich, !straussVerschenkt(ich) else { return 0 }
        Raum.shared.einreihen(StraussGeschenkLogik.op(tag: heute, von: ich, strauss: art, text: text))
        return StraussGeschenkLogik.punkte
    }

    /// p70: the gift the other one left for `ich` that is not in the vase yet.
    func straussGeschenkOffen(fuer ich: Person, angenommen: String?) -> StraussGeschenkLogik.Geschenk? {
        StraussGeschenkLogik.offen(Array(straussNachId.values), fuer: ich, angenommen: angenommen)
    }

    /// p61: has `person` stroked the cat today? (A stroke by the other one does not count.)
    func katzeGestreichelt(_ person: Person) -> Bool { katzeNachId[KatzeLogik.opId(tag: heute, von: person)] != nil }

    /// p61: strokes the cat. Gives `KatzeLogik.punkte` the first time today, 0 afterwards. The op id
    /// carries day and person, so a second phone or a replay counts once as well.
    @discardableResult
    func katzeStreicheln() -> Int {
        guard let ich = Raum.shared.ich, !katzeGestreichelt(ich) else { return 0 }
        Raum.shared.einreihen(KatzeLogik.op(tag: heute, von: ich))
        return KatzeLogik.punkte
    }

    /// p70 (44): was the cat fed today, by `person` or by anyone (`person` nil)?
    func katzeGefuettert(_ person: Person? = nil) -> Bool {
        (person.map { [$0] } ?? Person.allCases).contains { futterNachId[KatzePflege.opId(tag: heute, von: $0)] != nil }
    }

    /// p70 (44): feeds the cat. `KatzePflege.punkte` the first time today, 0 when the two fed it already.
    @discardableResult
    func katzeFuettern() -> Int {
        guard let ich = Raum.shared.ich, !katzeGefuettert() else { return 0 }
        Raum.shared.einreihen(KatzePflege.op(tag: heute, von: ich))
        return KatzePflege.punkte
    }

    /// p70 (44): how the cat feels today: fed and stroked by anyone of the two.
    func katzeStimmung() -> KatzePflege.Stimmung {
        KatzePflege.stimmung(gefuettert: katzeGefuettert(), gestreichelt: Person.allCases.contains { katzeGestreichelt($0) })
    }

    /// Läuft einmal nach dem Log-Replay; was schon im Log steht (anderes Gerät, Neuinstallation), wird nicht neu gesendet.
    private func dankSendenFallsFehlt() {
        guard let ich = Raum.shared.ich else { return }
        let gebucht = Set(dankEintraege.map(\.von))
        for person in DankLogik.fehlende(gebucht: gebucht) { Raum.shared.einreihen(DankLogik.op(fuer: person, von: ich)) }
    }

    private func kaufAnwenden(_ op: Op) {
        guard let d = op.daten(ShopKaufD.self) else { return }
        kaeufeNachId[op.id] = BesitzLogik.Kauf(seq: op.seq, id: op.id, von: op.von, artikel: d.artikel, fuer: d.fuer, zeit: op.zeit, verdient: d.verdient)
    }
}

/// `verdient` (I-1) is an optional extension of schnittstellen.md's `shop.kauf {id, artikel, fuer}`.
private struct ShopKaufD: Codable { var id: String; var artikel: String; var fuer: Person; var verdient: Int? }
