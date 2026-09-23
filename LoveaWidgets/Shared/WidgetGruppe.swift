import Foundation

/// Pfade in der App Group `group.com.onlyus.lovea` (Z-28.2) — geteilt zwischen App und
/// `LoveaWidgets`. `containerURL` liefert `nil` in unsignierten Umgebungen (CI-Simulator-Tests ohne
/// Entitlements, Unit-Tests) — jeder Aufrufer muss das aushalten statt zu erzwingen.
enum WidgetGruppe {
    static let kennung = "group.com.onlyus.lovea"

    static func container() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kennung)
    }

    static func standURL() -> URL? { container()?.appendingPathComponent("widget-stand.json") }
    static func partnerFigurURL() -> URL? { container()?.appendingPathComponent("widget-partner-figur.png") }
    static func partnerFotoURL() -> URL? { container()?.appendingPathComponent("widget-partner-foto.jpg") }

    /// Eine Datei pro wartender Op (`<opId>.json`, `WidgetPendingOp`) — vom Widget-Intent geschrieben,
    /// von der App beim nächsten Start/Vordergrund abgeholt und sofort gelöscht (Z-28.3, Idempotenz
    /// über die App Group hinweg: der Dateiname/die Op-`id` ist eindeutig, ein doppeltes Lesen vor dem
    /// Löschen richtet dank `Raum`s eigener Dedup-Logik keinen Schaden an).
    static func pendingOrdner() -> URL? {
        guard let ordner = container()?.appendingPathComponent("pending", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        return ordner
    }
}
