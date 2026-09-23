import Foundation
import UIKit

/// Liest, was `WidgetStandSchreiber` (App-Target) in die App Group geschrieben hat. Alles best
/// effort: fehlt die Datei (App nie gestartet, kein App-Group-Zugriff im unsignierten CI-Build),
/// liefert `stand()` einen leeren Platzhalter statt abzustürzen.
enum WidgetLesen {
    static func stand() -> WidgetStand { standOderNil() ?? WidgetStand(eigenePerson: "ahmed") }

    static func standOderNil() -> WidgetStand? {
        guard let url = WidgetGruppe.standURL(), let daten = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetStand.self, from: daten)
    }

    static func bild(_ url: URL?) -> UIImage? {
        guard let url, let daten = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: daten)
    }
}
