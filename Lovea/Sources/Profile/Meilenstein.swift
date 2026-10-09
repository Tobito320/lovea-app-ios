import Foundation

/// The next "together" milestone since 26.08.2026 (same day as the "Tage zusammen" chip): every month in the
/// first year, then every year. `fortschritt` runs 0...1 from the last milestone to the next one, for the
/// ring around the avatar. Pure, days as `yyyy-MM-dd`.
enum Meilenstein {
    static let start = "2026-08-26"

    struct Stand: Equatable {
        let titel: String
        let tage: Int
        let fortschritt: Double

        var text: String { "noch \(tage) \(tage == 1 ? "Tag" : "Tage") bis \(titel)" }
    }

    static func naechster(heute: String, start: String = start) -> Stand {
        var vorher = 0
        var ziel = 1
        while tag(start, plus: ziel) <= heute {
            vorher = ziel
            ziel = ziel < 12 ? ziel + 1 : ziel + 12
        }
        let von = max(tag(start, plus: vorher), min(heute, start))
        let bis = tag(start, plus: ziel)
        let gesamt = Datum.tageZwischen(von, bis)
        let gelaufen = heute < start ? 0 : Datum.tageZwischen(von, heute)
        let anteil = gesamt > 0 ? Double(gelaufen) / Double(gesamt) : 0
        return Stand(titel: titel(monate: ziel), tage: Datum.tageZwischen(heute, bis), fortschritt: min(max(anteil, 0), 1))
    }

    static func titel(monate: Int) -> String {
        if monate < 12 { return monate == 1 ? "1 Monat" : "\(monate) Monate" }
        let jahre = monate / 12
        return jahre == 1 ? "1 Jahr" : "\(jahre) Jahre"
    }

    private static func tag(_ start: String, plus monate: Int) -> String {
        Datum.text(Datum.kalender.date(byAdding: .month, value: monate, to: Datum.datum(start))!)
    }
}
