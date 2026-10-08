import AppIntents
import Foundation
import WidgetKit

/// "Denk an dich" aus dem Widget: `geste herz` an den Partner, Zähler im Widget steigt sofort
/// (wie `GymHeuteIntent`, Op über `WidgetOpPoster`). Push-Abstand gilt serverseitig.
struct DenkAnDichIntent: AppIntent {
    static var title: LocalizedStringResource { "Denk an dich" }

    func perform() async throws -> some IntentResult {
        guard var stand = WidgetLesen.standOderNil() else { return .result() }
        let heute = WidgetDatum.heute()
        let person = stand.eigenePerson
        stand.herzHeute = (stand.herzDatum == heute ? stand.herzHeute ?? 0 : 0) + 1
        stand.herzDatum = heute

        if let url = WidgetGruppe.standURL(), let daten = try? JSONEncoder().encode(stand) {
            try? daten.write(to: url, options: .atomic)
        }

        await WidgetOpPoster.herzSenden(von: person)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
