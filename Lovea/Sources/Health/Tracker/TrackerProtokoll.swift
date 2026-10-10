import Foundation

/// Paketformat des iSo-Tech-Trackers H59MAX (Colmi-artiges 16-Byte-Protokoll). Reine Rechnung ohne
/// CoreBluetooth, damit sie ohne Gerät testbar ist.
///
/// Am 08.10.2026 gegen das echte Gerät belegt (Firmware 1.00.13): Akku (0x03) und die Lesebefehle
/// 0x16, 0x2C, 0x36, 0x38. Schritte (0x43): Aufbau der Pakete passt zu echten Antworten (Datum als BCD,
/// Zeitindex, kcal, Schritte, Meter); Ahmed hat am 10.10.2026 bestätigt, dass die Schrittzahl stimmt
/// (Tracker 15.000, iPhone 10.000, der Tracker hat recht).
/// Nicht belegt: Schlaf, Pulsverlauf, kcal.
/// Absichtlich nur Lesebefehle, kein freies Senden: Reset und Ausschalten gehören zur selben Familie.
enum TrackerProtokoll {
    static let dienst = "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E"
    static let schreiben = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    static let antwort = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    static let namenspraefix = "H59"

    enum Befehl: UInt8 {
        case akku = 0x03
        case pulsEinstellung = 0x16
        case schritte = 0x43
    }

    /// 16 Byte: Byte 0 Befehl, dann Nutzdaten, Byte 15 Summe der ersten 15 Byte modulo 256.
    static func paket(_ befehl: Befehl, _ daten: [UInt8] = []) -> Data {
        var b = [UInt8](repeating: 0, count: 16)
        b[0] = befehl.rawValue
        for (i, wert) in daten.prefix(14).enumerated() { b[1 + i] = wert }
        b[15] = pruefsumme(Array(b[0..<15]))
        return Data(b)
    }

    static func pruefsumme(_ bytes: [UInt8]) -> UInt8 {
        UInt8(truncatingIfNeeded: bytes.reduce(0) { $0 &+ Int($1) })
    }

    static func istGueltig(_ daten: Data) -> Bool {
        let b = [UInt8](daten)
        return b.count == 16 && pruefsumme(Array(b[0..<15])) == b[15]
    }

    static let akkuAnfrage = paket(.akku)
    /// 0x16 mit Byte 1 = 1 liest die Einstellung (am Gerät belegt: Antwort "an, 10 Minuten").
    static let pulsEinstellungAnfrage = paket(.pulsEinstellung, [1])
    /// Schritte eines Tages: Byte 1 = Tage zurück (0 = heute), dann Zeitindex 0 bis 0x5F (96 Viertelstunden).
    static func schritteAnfrage(tagVersatz: Int) -> Data {
        paket(.schritte, [UInt8(clamping: tagVersatz), 0x0F, 0, 0x5F, 1])
    }
    static let schritteHeuteAnfrage = schritteAnfrage(tagVersatz: 0)

    struct Akku: Equatable {
        var prozent: Int
        var laedt: Bool
    }

    struct PulsEinstellung: Equatable {
        var an: Bool
        var intervallMinuten: Int
    }

    /// Eine Antwortzeile: Datum (BCD in Byte 1 bis 3), Zeitindex in Viertelstunden (0x44 = 17:00), Zeile
    /// `index` von `anzahl` (Byte 5 und 6), dann kcal, Schritte, Meter (Byte 7 bis 12, little endian).
    struct SchrittSlot: Equatable {
        var tag: String
        var slot: Int
        var index: Int
        var anzahl: Int
        var kcal: Int
        var schritte: Int
        var meter: Int

        /// Die letzte Zeile der Antwort: danach kann die nächste Frage gehen.
        var letzte: Bool { index + 1 >= anzahl }
    }

    enum Antwort: Equatable {
        case akku(Akku)
        case pulsEinstellung(PulsEinstellung)
        /// Kopfpaket einer Schritt-Antwort (Byte 1 = 0xF0): Zeilen folgen.
        case schritteKopf
        case schritte(SchrittSlot)
        /// Byte 1 = 0xFF: nichts (mehr) für diese Frage.
        case schritteEnde
        case unbekannt(UInt8)
    }

    /// `nil` bei falscher Länge oder Prüfsumme.
    static func lesen(_ daten: Data) -> Antwort? {
        guard istGueltig(daten) else { return nil }
        let b = [UInt8](daten)
        switch b[0] {
        case Befehl.akku.rawValue:
            return .akku(Akku(prozent: Int(b[1]), laedt: b[2] != 0))
        case Befehl.pulsEinstellung.rawValue:
            return .pulsEinstellung(PulsEinstellung(an: b[2] == 1, intervallMinuten: Int(b[3])))
        case Befehl.schritte.rawValue:
            if b[1] == 0xF0 { return .schritteKopf }
            if b[1] == 0xFF { return .schritteEnde }
            guard let tag = datumText(b[1], b[2], b[3]), b[4] < 96 else { return .unbekannt(b[0]) }
            return .schritte(SchrittSlot(tag: tag, slot: Int(b[4]), index: Int(b[5]), anzahl: Int(b[6]),
                                         kcal: Int(b[7]) | Int(b[8]) << 8,
                                         schritte: Int(b[9]) | Int(b[10]) << 8,
                                         meter: Int(b[11]) | Int(b[12]) << 8))
        default:
            return .unbekannt(b[0])
        }
    }

    /// Zwei BCD-Ziffern (0x26 = 26); `nil` bei einer Nicht-Ziffer.
    private static func bcd(_ byte: UInt8) -> Int? {
        let zehner = Int(byte >> 4), einer = Int(byte & 0x0F)
        return zehner < 10 && einer < 10 ? zehner * 10 + einer : nil
    }

    /// `yyyy-MM-dd` aus Jahr (ab 2000), Monat und Tag als BCD.
    private static func datumText(_ jahr: UInt8, _ monat: UInt8, _ tag: UInt8) -> String? {
        guard let j = bcd(jahr), let m = bcd(monat), let t = bcd(tag), (1...12).contains(m), (1...31).contains(t) else { return nil }
        return String(format: "%04d-%02d-%02d", 2000 + j, m, t)
    }
}
