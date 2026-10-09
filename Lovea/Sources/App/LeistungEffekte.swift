import Foundation

/// Schalter "Aufwendige Effekte" (Einstellungen > Erweitert > Leistung, Standard an). Aus: der
/// Partikel-Hintergrund im Chat steht still, die Wellen und der Dampf der Tagesformen stehen still,
/// die Figuren zeichnen mit hoechstens `figurBildrate` Bildern pro Sekunde. Nichts davon aendert Daten.
/// Gleiches Muster wie `Haptik.an`: lokal auf dem Geraet, kein Op.
enum LeistungEffekte {
    static let schluessel = "lovea.leistung.effekte"
    static let figurBildrate = 10.0

    static func an(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: schluessel) as? Bool ?? true
    }

    /// Bildrate einer lebenden Figur: die normale, bei ausgeschalteten Effekten gedeckelt.
    static func bildrate(normal: Double, effekte: Bool) -> Double {
        effekte ? normal : min(normal, figurBildrate)
    }
}
