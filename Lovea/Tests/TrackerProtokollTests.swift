import XCTest
@testable import Lovea

/// Paket-Codec des iSo-Tech-Trackers. Alle Pakete hier sind synthetisch (aus `paket` und Hand-Bytes
/// gebaut), nicht vom Gerät mitgeschnitten. Belegt am Gerät ist nur das Format selbst (16 Byte,
/// Summe in Byte 15) und die Bedeutung von 0x03 und 0x16, nicht die Schritt-Dekodierung.
final class TrackerProtokollTests: XCTestCase {
    private func bytes(_ daten: Data) -> [UInt8] { [UInt8](daten) }

    func testPaketHatSechzehnByteUndPruefsumme() {
        let akku = bytes(TrackerProtokoll.akkuAnfrage)
        XCTAssertEqual(akku.count, 16)
        XCTAssertEqual(akku[0], 0x03)
        XCTAssertEqual(akku[15], 0x03)
        XCTAssertEqual(Array(bytes(TrackerProtokoll.pulsEinstellungAnfrage)[0...2]), [0x16, 0x01, 0x00])
        XCTAssertEqual(bytes(TrackerProtokoll.pulsEinstellungAnfrage)[15], 0x17)
    }

    func testSchritteAnfrageBytes() {
        XCTAssertEqual(bytes(TrackerProtokoll.schritteHeuteAnfrage),
                       [0x43, 0x00, 0x0F, 0x00, 0x5F, 0x01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xB2])
    }

    func testPruefsummeLaeuftUeberModulo256() {
        XCTAssertEqual(TrackerProtokoll.pruefsumme([0xFF, 0x02]), 0x01)
    }

    func testUngueltigeLaengeOderPruefsummeGibtNil() {
        XCTAssertNil(TrackerProtokoll.lesen(Data([0x03, 0x1B])))
        var kaputt = bytes(TrackerProtokoll.paket(.akku, [27, 0]))
        kaputt[15] = kaputt[15] &+ 1
        XCTAssertNil(TrackerProtokoll.lesen(Data(kaputt)))
        XCTAssertFalse(TrackerProtokoll.istGueltig(Data()))
    }

    func testAkkuAntwort() {
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.akku, [27, 0])),
                       .akku(.init(prozent: 27, laedt: false)))
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.akku, [100, 1])),
                       .akku(.init(prozent: 100, laedt: true)))
    }

    func testPulsEinstellungAntwort() {
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.pulsEinstellung, [1, 1, 10])),
                       .pulsEinstellung(.init(an: true, intervallMinuten: 10)))
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.pulsEinstellung, [1, 2, 30])),
                       .pulsEinstellung(.init(an: false, intervallMinuten: 30)))
    }

    func testSchrittSlotLittleEndian() {
        let daten: [UInt8] = [0x00, 0, 0, 5, 0, 0, 0x2C, 0x01, 0x10, 0x02, 0x34, 0x03]
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.schritte, daten)),
                       .schritte(.init(slot: 5, kcal: 300, schritte: 528, meter: 820)))
    }

    func testSteuerpaketeDerSchrittAntwortSindKeineSlots() {
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.schritte, [0xF0])), .unbekannt(0x43))
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.schritte, [0xFF])), .unbekannt(0x43))
    }

    func testUnbekannterBefehlWirdNichtGedeutet() {
        var roh = [UInt8](repeating: 0, count: 16)
        roh[0] = 0x7F
        roh[15] = TrackerProtokoll.pruefsumme(Array(roh[0..<15]))
        XCTAssertEqual(TrackerProtokoll.lesen(Data(roh)), .unbekannt(0x7F))
    }

    func testKennungenDesTrackers() {
        XCTAssertEqual(TrackerProtokoll.namenspraefix, "H59")
        XCTAssertEqual(TrackerProtokoll.dienst, "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E")
    }
}
