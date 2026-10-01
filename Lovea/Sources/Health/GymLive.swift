import ActivityKit
import Foundation

/// Hält die Live Activity passend zur eigenen laufenden Einheit (Ahmed, 27.09.): Einchecken startet
/// sie, eine neue Übung aktualisiert sie, Auschecken beendet sie. Nur auf dem iPhone.
///
/// Build 78 (Ahmed, Absturzverdacht): `TrainingModell`s Op-Beobachter ruft `abgleichen()` für JEDEN
/// replizierten Op — beim Start können das hunderte sein. `abgleichen()` queued deshalb bei einem
/// laufenden Durchlauf keinen weiteren Task, sondern markiert nur `AbgleichZustand.laeuftSchmutzig`;
/// `lauf()` wiederholt sich dann selbst noch einmal, statt hunderte ActivityKit-Anfragen zu stapeln.
@MainActor
enum GymLive {
    private struct Ziel: Sendable {
        var attribute: GymAktivitaet
        var stand: GymAktivitaet.ContentState
    }

    private static var zustand: AbgleichZustand = .leer
    private static var laufZaehler = 0

    static func abgleichen() {
        let (starten, neu) = AbgleichZustand.aufruf(zustand)
        zustand = neu
        guard starten else { return }
        Task { await lauf() }
    }

    private static func lauf() async {
        while true {
            // Replay/ausstehende Schreibzugriffe erst fertig, bevor der Zielzustand gelesen wird —
            // sonst läse ein früher Durchlauf z. B. ein Ernährungsziel, das der Fold noch gar nicht
            // angewendet hat (R: "Zielzustand bei der Ausführung berechnen, nicht beim Aufruf").
            await Raum.shared.leer()
            laufZaehler += 1
            await anwenden(zielJetzt(), nummer: laufZaehler)
            let (nochmal, neu) = AbgleichZustand.fertig(zustand)
            zustand = neu
            guard nochmal else { break }
        }
    }

    private static func zielJetzt() -> Ziel? {
        let modell = TrainingModell.shared
        let ich = Raum.shared.ich ?? .ahmed
        guard Geraet.wirdGetragen, let s = modell.laufende(ich) else {
            WorkoutPuls.shared.verwaisteBeenden()
            return nil
        }
        let liste = modell.workout(s.id)
        let dran = WorkoutLogik.dran(liste).map { (uebung: liste[$0.uebung], satz: $0.satz) }
        var stand = GymAktivitaet.ContentState(
            uebung: dran?.uebung.planUebung.anzeigeName,
            fertig: liste.filter(\.fertig).count,
            gesamt: liste.count)
        if let dran, dran.uebung.saetze.indices.contains(dran.satz) {
            stand.satz = dran.satz + 1
            stand.saetze = dran.uebung.saetze.count
            stand.zeile = WorkoutLogik.satzText(dran.uebung.saetze[dran.satz])
        }
        if let uhr = WorkoutUhr.shared.stand, uhr.session == s.id {
            stand.pause = uhr.pause
            stand.seit = uhr.seit
            stand.bis = uhr.pauseEnde
        }
        return Ziel(attribute: GymAktivitaet(sessionId: s.id, start: s.start, tagName: modell.tag(ich, id: s.tag)?.name ?? "Training"), stand: stand)
    }

    /// Nonisolated: die `Activity`-Objekte bleiben in diesem einen Ablauf (Swift 6, nicht Sendable).
    private nonisolated static func anwenden(_ ziel: Ziel?, nummer: Int) async {
        StartProtokoll.marke("gymLive.anwenden.vor #\(nummer)")
        let gymLiefVorher = !Activity<GymAktivitaet>.activities.isEmpty
        for a in Activity<GymAktivitaet>.activities where a.attributes.sessionId != ziel?.attribute.sessionId {
            StartProtokoll.marke("gymLive.anwenden.altBeenden.vor")
            await a.end(nil, dismissalPolicy: .immediate)
            StartProtokoll.marke("gymLive.anwenden.altBeenden.nach")
        }
        if let ziel {
            if let a = Activity<GymAktivitaet>.activities.first(where: { $0.attributes.sessionId == ziel.attribute.sessionId }) {
                if a.content.state != ziel.stand {
                    StartProtokoll.marke("gymLive.anwenden.update.vor")
                    await a.update(ActivityContent(state: ziel.stand, staleDate: nil))
                    StartProtokoll.marke("gymLive.anwenden.update.nach")
                }
            } else if ActivityAuthorizationInfo().areActivitiesEnabled {
                // Klappt nur im Vordergrund; sonst holt der nächste Abgleich beim Öffnen es nach.
                StartProtokoll.marke("gymLive.anwenden.request.vor")
                _ = try? Activity.request(attributes: ziel.attribute, content: ActivityContent(state: ziel.stand, staleDate: nil))
                StartProtokoll.marke("gymLive.anwenden.request.nach")
            }
        }
        let gymLaeuftJetzt = !Activity<GymAktivitaet>.activities.isEmpty
        StartProtokoll.marke("gymLive.anwenden.nach")
        // R10 (Ahmed, 01.10.: "nur Gym, wenn gestartet" in der Dynamic Island) — Essen nur dann neu
        // bewerten, wenn Gym diesen Durchlauf WIRKLICH gestartet oder beendet hat (Übergang), nicht
        // bei jedem Update (sonst feuert ein laufendes Training bei jeder Satz-Änderung zusätzlich
        // einen Essen-Abgleich — Teil desselben Absturzverdachts).
        guard gymLiefVorher != gymLaeuftJetzt else { return }
        await EssenLive.abgleichen()
    }
}
