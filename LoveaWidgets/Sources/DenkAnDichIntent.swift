import AppIntents
import Foundation
import WidgetKit

/// "Denk an dich" aus dem Widget: schickt `geste herz` an den Partner. Der Zähler im Widget steigt
/// sofort (lokaler Stand), die Op geht direkt an den Server oder wartet als Datei, bis die App sie
/// abholt (`WidgetOpPoster`). Kein `openAppWhenRun`. Der Push-Abstand (10 Minuten) gilt serverseitig,
/// jeder Tipp zählt trotzdem.
struct DenkAnDichIntent: AppIntent {
    static var title: LocalizedStringResource { "Denk an dich" }

    func perform() async throws -> some IntentResult {
        guard var stand = WidgetLesen.standOderNil() else { return .result() }
        let heute = WidgetDatum.heute()
        let person = stand.eigenePerson
        // Zähler eines früheren Tages verwerfen, bevor erhöht wird.
        var herzen = stand.herzDatum == heute ? (stand.herzHeute ?? [:]) : [:]
        herzen[person, default: 0] += 1
        stand.herzHeute = herzen
        stand.herzDatum = heute

        if let url = WidgetGruppe.standURL(), let daten = try? JSONEncoder().encode(stand) {
            try? daten.write(to: url, options: .atomic)
        }

        await WidgetOpPoster.herzSenden(von: person)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
