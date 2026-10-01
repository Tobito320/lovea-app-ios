import ActivityKit
import Foundation

/// Hält die Live Activity passend zur eigenen laufenden Einheit (Ahmed, 27.09.): Einchecken startet
/// sie, eine neue Übung aktualisiert sie, Auschecken beendet sie. Nur auf dem iPhone.
@MainActor
enum GymLive {
    private struct Ziel: Sendable {
        var attribute: GymAktivitaet
        var stand: GymAktivitaet.ContentState
    }

    /// Abgleiche laufen nacheinander: beim Start kommen viele Ops auf einmal, parallel gäbe es doppelte Aktivitäten.
    private static var letzter: Task<Void, Never>?

    static func abgleichen() {
        let ziel = zielJetzt()
        let vorher = letzter
        letzter = Task {
            await vorher?.value
            await anwenden(ziel)
        }
    }

    private static func zielJetzt() -> Ziel? {
        let modell = TrainingModell.shared
        let ich = Raum.shared.ich ?? .ahmed
        guard Geraet.wirdGetragen, let s = modell.laufende(ich) else { return nil }
        let tag = modell.tag(ich, id: s.tag)
        return Ziel(
            attribute: GymAktivitaet(sessionId: s.id, start: s.start, tagName: tag?.name ?? "Training"),
            stand: GymAktivitaet.ContentState(
                uebung: s.aktiv.flatMap { a in tag?.uebungen.first { $0.id == a.plan }?.anzeigeName },
                fertig: tag?.uebungen.filter { s.erledigt($0.id) }.count ?? 0,
                gesamt: tag?.uebungen.count ?? 0))
    }

    /// Nonisolated: die `Activity`-Objekte bleiben in diesem einen Ablauf (Swift 6, nicht Sendable).
    private nonisolated static func anwenden(_ ziel: Ziel?) async {
        for a in Activity<GymAktivitaet>.activities where a.attributes.sessionId != ziel?.attribute.sessionId {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        if let ziel {
            if let a = Activity<GymAktivitaet>.activities.first(where: { $0.attributes.sessionId == ziel.attribute.sessionId }) {
                if a.content.state != ziel.stand { await a.update(ActivityContent(state: ziel.stand, staleDate: nil)) }
            } else if ActivityAuthorizationInfo().areActivitiesEnabled {
                // Klappt nur im Vordergrund; sonst holt der nächste Abgleich beim Öffnen es nach.
                _ = try? Activity.request(attributes: ziel.attribute, content: ActivityContent(state: ziel.stand, staleDate: nil))
            }
        }
        // R10 (Ahmed, 01.10.: "nur Gym, wenn gestartet" in der Dynamic Island) — nach jedem
        // Gym-Abgleich (Start, Update, Ende) auch Essen neu bewerten: `EssenLive.aktion` beendet
        // Essen von selbst, solange eine Gym-Aktivität läuft, und startet es hier wieder, sobald
        // keine mehr läuft. Kein neuer Timer, läuft nur mit, wenn `GymLive.abgleichen()` ohnehin
        // schon lief.
        await EssenLive.abgleichen()
    }
}
