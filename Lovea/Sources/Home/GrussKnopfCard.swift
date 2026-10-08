import Foundation

/// Wann welcher Gruß-Knopf zu sehen ist (Berliner Stunde): "Guten Morgen" 4–9 Uhr einmal am Tag,
/// "Gute Nacht" ab 20 Uhr bis 4 Uhr, mehrmals, aber frühestens 5 Minuten nach dem letzten. Sonst keiner.
/// Die Knöpfe sitzen nicht mehr auf Home: Gute Nacht am Lichtschalter (p60), Guten Morgen am Wecker (p64).
enum GrussFenster {
    static let abstand: TimeInterval = 5 * 60

    static func knopf(stunde: Int, jetzt: Date, letzteNacht: Date?, morgenGesendetHeute: Bool) -> String? {
        if (4..<9).contains(stunde) { return morgenGesendetHeute ? nil : "morgen" }
        guard stunde >= 20 || stunde < 4 else { return nil }
        if let letzteNacht, jetzt.timeIntervalSince(letzteNacht) < abstand { return nil }
        return "nacht"
    }
}
