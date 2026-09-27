import ActivityKit
import Foundation

/// Hält die Live Activity passend zur eigenen laufenden Einheit (Ahmed, 27.09.): Einchecken startet
/// sie, eine neue Übung aktualisiert sie, Auschecken beendet sie. Nur auf dem iPhone.
@MainActor
enum GymLive {
    static func abgleichen() {
        let modell = TrainingModell.shared
        let ich = Raum.shared.ich ?? .ahmed
        let aktiv = Activity<GymAktivitaet>.activities
        guard Geraet.wirdGetragen, let s = modell.laufende(ich) else {
            for a in aktiv { Task { await a.end(nil, dismissalPolicy: .immediate) } }
            return
        }
        let tag = modell.tag(ich, id: s.tag)
        let stand = GymAktivitaet.ContentState(
            uebung: s.aktiv.flatMap { a in tag?.uebungen.first { $0.id == a.plan }?.anzeigeName },
            fertig: tag?.uebungen.filter { s.erledigt($0.id) }.count ?? 0,
            gesamt: tag?.uebungen.count ?? 0)
        for a in aktiv where a.attributes.sessionId != s.id { Task { await a.end(nil, dismissalPolicy: .immediate) } }
        if let a = aktiv.first(where: { $0.attributes.sessionId == s.id }) {
            guard a.content.state != stand else { return }
            Task { await a.update(ActivityContent(state: stand, staleDate: nil)) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            // Klappt nur im Vordergrund; sonst holt der nächste Abgleich beim Öffnen es nach.
            _ = try? Activity.request(
                attributes: GymAktivitaet(sessionId: s.id, start: s.start, tagName: tag?.name ?? "Training"),
                content: ActivityContent(state: stand, staleDate: nil))
        }
    }
}
