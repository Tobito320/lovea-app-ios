import Foundation

/// Paketformat des iSo-Tech-Trackers H59MAX (Colmi-artiges 16-Byte-Protokoll). Reine Rechnung ohne
/// CoreBluetooth, damit sie ohne Gerät testbar ist.
///
/// Am 08.10.2026 gegen das echte Gerät belegt (Firmware 1.00.13): Akku (0x03) und die Lesebefehle
/// 0x16, 0x2C, 0x36, 0x38. Schritte (0x43): Aufbau der Pakete passt zu echten Antworten (Datum als BCD,
/// Zeitindex, kcal, Schritte, Meter), die Zahlen sind aber noch nicht mit QWatch Pro verglichen.
/// Nicht belegt: Schlaf, Pulsverlauf.
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
    /// Schritte von heute: Tag 0, Zeitindex 0 bis 0x5F (96 Viertelstunden).
    static let schritteHeuteAnfrage = paket(.schritte, [0, 0x0F, 0, 0x5F, 1])

    struct Akku: Equatable {
        var prozent: Int
        var laedt: Bool
    }

    struct PulsEinstellung: Equatable {
        var an: Bool
        var intervallMinuten: Int
    }

    /// Eine Antwortzeile: Zeitindex in Viertelstunden (0x44 = 17:00), dann kcal, Schritte, Meter
    /// (Byte 7 bis 12, little endian). Zahlen noch nicht mit QWatch Pro verglichen.
    struct SchrittSlot: Equatable {
        var slot: Int
        var kcal: Int
        var schritte: Int
        var meter: Int
    }

    enum Antwort: Equatable {
        case akku(Akku)
        case pulsEinstellung(PulsEinstellung)
        case schritte(SchrittSlot)
        case unbekannt(UInt8)
    }

    /// `nil` bei falscher Länge oder Prüfsumme. Schritt-Pakete mit Kopfbyte 0xF0 oder 0xFF sind
    /// Steuerpakete der Antwortfolge und keine Slots.
    static func lesen(_ daten: Data) -> Antwort? {
        guard istGueltig(daten) else { return nil }
        let b = [UInt8](daten)
        switch b[0] {
        case Befehl.akku.rawValue:
            return .akku(Akku(prozent: Int(b[1]), laedt: b[2] != 0))
        case Befehl.pulsEinstellung.rawValue:
            return .pulsEinstellung(PulsEinstellung(an: b[2] == 1, intervallMinuten: Int(b[3])))
        case Befehl.schritte.rawValue:
            guard b[1] != 0xF0, b[1] != 0xFF else { return .unbekannt(b[0]) }
            return .schritte(SchrittSlot(slot: Int(b[4]),
                                         kcal: Int(b[7]) | Int(b[8]) << 8,
                                         schritte: Int(b[9]) | Int(b[10]) << 8,
                                         meter: Int(b[11]) | Int(b[12]) << 8))
        default:
            return .unbekannt(b[0])
        }
    }
}
