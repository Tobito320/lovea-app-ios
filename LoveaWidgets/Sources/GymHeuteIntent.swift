import AppIntents
import Foundation
import WidgetKit

/// Hakt Gym für heute ab/wieder weg (Z-28.3) — Gym-Woche und die eigene Spalte im Gym-Duell teilen
/// sich diesen einen Intent, keine Parameter nötig: er wirkt immer auf `eigenePerson` und "heute"
/// (per `WidgetDatum.heute()`, nicht auf einen möglicherweise veralteten Stand vertrauen —
/// Review-Fokus 1). Kein `openAppWhenRun`: bleibt im Widget, öffnet die App nicht.
struct GymHeuteIntent: AppIntent {
    static var title: LocalizedStringResource { "Gym heute" }

    func perform() async throws -> some IntentResult {
        guard var stand = WidgetLesen.standOderNil() else { return .result() }
        let heute = WidgetDatum.heute()
        let person = stand.eigenePerson
        let bisher = stand.gymLetzte7[person]?.first(where: { $0.datum == heute })?.erledigt ?? false
        let neu = !bisher

        var tage = stand.gymLetzte7[person] ?? []
        if let index = tage.firstIndex(where: { $0.datum == heute }) {
            tage[index].erledigt = neu
        } else {
            tage.append(WidgetStand.TagEintrag(datum: heute, erledigt: neu))
        }
        stand.gymLetzte7[person] = tage

        if let url = WidgetGruppe.standURL(), let daten = try? JSONEncoder().encode(stand) {
            try? daten.write(to: url, options: .atomic)
        }

        await WidgetOpPoster.gymHeuteSenden(von: person, datum: heute, wert: neu ? 1 : 0)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
