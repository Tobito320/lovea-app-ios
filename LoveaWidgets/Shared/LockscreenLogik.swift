import Foundation

/// Reine Rechnung für die Sperrbildschirm-Widgets "Wiedersehen" und "Schlaf". Liegt in `Shared`,
/// damit die Unit-Tests sie ohne Widget-Erweiterung erreichen. Keine App-Typen (siehe `WidgetDatum`).
enum LockscreenLogik {
    /// Tage bis zum Treffen, `nil` ohne Treffen oder wenn es vorbei ist (der Stand kann veraltet sein).
    static func tageBis(treffen: String?, heute: String) -> Int? {
        guard let treffen else { return nil }
        let tage = WidgetDatum.tageZwischen(heute, treffen)
        return tage >= 0 ? tage : nil
    }

    /// "in 12 Tagen", "morgen", "heute".
    static func countdownText(tage: Int) -> String {
        switch tage {
        case 0: return "heute"
        case 1: return "morgen"
        default: return "in \(tage) Tagen"
        }
    }

    /// "18.10." aus "2026-10-18", unabhängig von der Zeitzone des Geräts.
    static func datumKurz(_ tag: String) -> String {
        let teile = tag.split(separator: "-")
        guard teile.count == 3, let monat = Int(teile[1]), let tagZahl = Int(teile[2]) else { return tag }
        return "\(tagZahl).\(monat)."
    }

    /// 432 -> "7:12".
    static func schlafText(minuten: Int) -> String {
        String(format: "%d:%02d", minuten / 60, minuten % 60)
    }

    /// 4210 -> "4,2k", 950 -> "950".
    static func kurzZahl(_ wert: Int) -> String {
        wert >= 1000 ? (Double(wert) / 1000).formatted(.number.precision(.fractionLength(1))) + "k" : "\(wert)"
    }
}
