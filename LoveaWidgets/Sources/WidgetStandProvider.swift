import Foundation
import UIKit
import WidgetKit

/// Ein Eintrag für alle sieben Widgets (Z-28.3) — sie zeigen alle denselben `WidgetStand`, nur
/// unterschiedlich angeordnet, ein gemeinsamer `TimelineProvider` spart sieben fast identische.
struct WidgetStandEntry: TimelineEntry, Sendable {
    let date: Date
    let stand: WidgetStand
    let partnerFigur: UIImage?
    let partnerFoto: UIImage?
}

struct WidgetStandProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetStandEntry {
        WidgetStandEntry(date: Date(), stand: WidgetStand(eigenePerson: "ahmed"), partnerFigur: nil, partnerFoto: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetStandEntry) -> Void) {
        completion(Self.aktuellerEintrag())
    }

    /// Policy `.after(nächste Berlin-Mitternacht)`: WidgetKit lädt danach mindestens einmal neu,
    /// selbst wenn die App zwischenzeitlich nicht schreibt — sonst bliebe "heute" im Widget über
    /// Mitternacht hinaus auf dem alten Tag stehen (Review-Fokus 1).
    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetStandEntry>) -> Void) {
        let eintrag = Self.aktuellerEintrag()
        completion(Timeline(entries: [eintrag], policy: .after(WidgetDatum.naechsteMitternacht())))
    }

    private static func aktuellerEintrag() -> WidgetStandEntry {
        let stand = WidgetLesen.stand()
        return WidgetStandEntry(
            date: Date(),
            stand: stand,
            partnerFigur: stand.partnerFigurVorhanden ? WidgetLesen.bild(WidgetGruppe.partnerFigurURL()) : nil,
            partnerFoto: stand.partnerFotoVorhanden ? WidgetLesen.bild(WidgetGruppe.partnerFotoURL()) : nil
        )
    }
}
