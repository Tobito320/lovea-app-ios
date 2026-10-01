import Foundation

/// Launch-/Aktivierungs-Protokoll (Ahmed, 01.10., Absturzverdacht Build 76): schreibt synchron in
/// UserDefaults, damit ein Absturz direkt danach noch erkennbar bleibt. Bewusst `nonisolated` ohne
/// eigenen Zustand im Speicher — nur UserDefaults, kein `static var` -- und `synchronize()` nach jeder
/// Markierung, weil der Prozess direkt danach sterben kann.
enum StartProtokoll {
    private static let schluessel = "start.stufe"

    static func marke(_ stufe: String) {
        UserDefaults.standard.set(stufe, forKey: schluessel)
        UserDefaults.standard.synchronize()
    }

    /// Letzte Stufe VOR dieser Markierung durch `fertig()` ersetzen.
    static func fertig() {
        marke("fertig")
    }

    /// Stand des Schlüssels, bevor diese Sitzung selbst etwas schreibt: nil, wenn der letzte Start
    /// sauber mit `fertig()` endete oder noch nie geschrieben wurde. Der Aufrufer muss das VOR der
    /// ersten eigenen `marke`/`fertig` lesen (siehe `LoveaApp.init`), sonst überschreibt die eigene
    /// erste Markierung den Wert, den diese Funktion lesen soll.
    static func letzterAbbruch() -> String? {
        guard let voriger = UserDefaults.standard.string(forKey: schluessel), !voriger.isEmpty, voriger != "fertig" else { return nil }
        return voriger
    }
}
