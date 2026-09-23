import Foundation
import Observation

/// Adapts ops (and `ChatModell`/`SpieleModell`) into the plain inputs `PunkteLogik`/`ChallengeLogik`/
/// `BesitzLogik` take, and is the Zielplan's `PunkteLogik.stand(ops, heute, kalender)` surface at the
/// model layer (see the deviation note on `PunkteLogik`). Reuses `HealthModell`'s already-deduped
/// steps/gym/water/goal state instead of re-observing `schritte.setzen`/`habit.setzen`/`einstellung.setzen`
/// a second time.
@MainActor
@Observable
final class PunkteModell {
    static let shared = PunkteModell()

    private(set) var spieleSiege: [PunkteLogik.SpielSieg] = []
    private(set) var kaeufe: [BesitzLogik.Kauf] = []

    private var angewendeteOps: Set<String> = []
    /// Last seen cumulative `punkte` per game id, to turn `spiel.ergebnis`'s running tally into
    /// "who won THIS round" (a positive delta on exactly one side).
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

    var verlauf: [PunkteLogik.Eintrag] {
        PunkteLogik.verlauf(
            heute: heute, schritte: schritteEintraege, gym: gymEintraege, wasser: wasserEintraege,
            zielSchritte: HealthModell.shared.zielSchritteAenderungen, zielWasser: HealthModell.shared.zielWasserAenderungen,
            zielGym: HealthModell.shared.zielGymAenderungen, chatStreakTage: chatStreakTage, spieleSiege: spieleSiege
        )
    }

    // MARK: - Challenges

    private var wochen: [ChallengeLogik.WochenErgebnis] {
        ChallengeLogik.wochen(heute: heute, schritte: schritteEintraege, zielGemeinsamWoche: HealthModell.shared.zielGemeinsamWoche)
    }

    private var monate: [ChallengeLogik.MonatsErgebnis] {
        ChallengeLogik.monate(heute: heute, schritte: schritteEintraege)
    }

    private var serien: [ChallengeLogik.SerienBonus] {
        ChallengeLogik.serienBoni(heute: heute, schritte: schritteEintraege, zielSchritte: HealthModell.shared.zielSchritteAenderungen)
    }

    /// Für die Health-Tab-Anzeige (Block 21/Z-22.2): laufende Woche/Monat mit Fortschritt.
    var aktuelleWoche: ChallengeLogik.WochenErgebnis? { wochen.first { $0.montag == Datum.montagDerWoche(heute) } }
    var aktuellerMonat: ChallengeLogik.MonatsErgebnis? { monate.first { $0.monat == String(heute.prefix(7)) } }

    // MARK: - Shop / Besitz (BesitzLogik aus Z-23.1)

    /// `preis`: noch nicht verdrahtet — künftig `ShopKatalog.artikel(id)?.preis` (Katalog kommt aus
    /// einem anderen Block, siehe Bericht). `nil` heißt "kein solcher Artikel".
    func besitzt(_ artikel: String, _ person: Person, preis: (String) -> Int?) -> Bool {
        BesitzLogik.auswerten(kaeufe, verdient: stand, preis: preis).besitzt(artikel, person)
    }

    /// Prüft den Stand VOR dem Senden (sofortige "Nicht genug Punkte"-Rückmeldung); die Faltung über
    /// `shop.kauf` bleibt die eigentliche Wahrheit (Review-Fokus 3, gleichzeitige Käufe).
    @discardableResult
    func kaufen(artikel: String, fuer: Person, preis: (String) -> Int?) -> Bool {
        guard let ich = Raum.shared.ich, let preisWert = preis(artikel) else { return false }
        let ergebnis = BesitzLogik.auswerten(kaeufe, verdient: stand, preis: preis)
        let verfuegbar = (stand[ich] ?? 0) - (ergebnis.ausgegeben[ich] ?? 0)
        guard verfuegbar >= preisWert else { return false }
        Raum.shared.senden("shop.kauf", ShopKaufD(id: UUID().uuidString, artikel: artikel, fuer: fuer))
        return true
    }

    // MARK: - Ops falten

    private func spielErgebnisAnwenden(_ op: Op) {
        guard angewendeteOps.insert(op.id).inserted, let d = op.daten(SpielErgebnisD.self) else { return }
        let vorher = letztesSpielErgebnis[d.id]?.punkte ?? SpielPunkte()
        letztesSpielErgebnis[d.id] = d
        let deltaAhmed = d.punkte.ahmed - vorher.ahmed
        let deltaAnnika = d.punkte.annika - vorher.annika
        guard deltaAhmed != deltaAnnika else { return } // unentschieden/keine Änderung: kein Sieg
        let sieger: Person = deltaAhmed > deltaAnnika ? .ahmed : .annika
        spieleSiege.append(PunkteLogik.SpielSieg(von: sieger, datum: Datum.text(op.zeit)))
    }

    private func kaufAnwenden(_ op: Op) {
        guard angewendeteOps.insert(op.id).inserted, let d = op.daten(ShopKaufD.self) else { return }
        kaeufe.append(BesitzLogik.Kauf(seq: op.seq, id: op.id, von: op.von, artikel: d.artikel, fuer: d.fuer))
    }
}

private struct ShopKaufD: Codable { var id: String; var artikel: String; var fuer: Person }
