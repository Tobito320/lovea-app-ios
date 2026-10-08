import XCTest
@testable import Lovea

/// Paket-Codec des iSo-Tech-Trackers. `echt` sind Antworten, die am 08.10.2026 um 20:28 vom Gerät
/// mitgeschnitten wurden (Firmware 1.00.13, nur Lesebefehle). Alles andere ist synthetisch, aus
/// `paket` oder Hand-Bytes gebaut. Die Schrittzahlen sind noch nicht mit QWatch Pro verglichen.
final class TrackerProtokollTests: XCTestCase {
    private func daten(hex: String) -> Data {
        var ergebnis = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let ende = hex.index(index, offsetBy: 2)
            ergebnis.append(UInt8(hex[index..<ende], radix: 16)!)
            index = ende
        }
        return ergebnis
    }

    private func bytes(_ daten: Data) -> [UInt8] { [UInt8](daten) }

    // MARK: Echte Pakete vom Gerät

    func testEchteAnfragenStimmenMitDemGeraetFormatUeberein() {
        XCTAssertEqual(TrackerProtokoll.akkuAnfrage, daten(hex: "03000000000000000000000000000003"))
        XCTAssertEqual(TrackerProtokoll.pulsEinstellungAnfrage, daten(hex: "16010000000000000000000000000017"))
        XCTAssertEqual(TrackerProtokoll.schritteHeuteAnfrage, daten(hex: "43000f005f01000000000000000000b2"))
    }

    func testEchteAkkuAntwort() {
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "031b000000000000000000000000001e")),
                       .akku(.init(prozent: 27, laedt: false)))
    }

    func testEchtePulsEinstellung() {
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "1601010a050000000000000000000027")),
                       .pulsEinstellung(.init(an: true, intervallMinuten: 10)))
    }

    func testEchteSchrittAntwortZeilen() {
        // Kopfpaket (Byte 1 = 0xF0, vier Zeilen folgen) ist keine Zeile.
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "43f00401000000000000000000000038")), .unbekannt(0x43))
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "43261008440004cd0180004d00000064")),
                       .schritte(.init(slot: 0x44, kcal: 461, schritte: 128, meter: 77)))
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "432610084c0204b003e1009f00000006")),
                       .schritte(.init(slot: 0x4C, kcal: 944, schritte: 225, meter: 159)))
    }

    func testEchtesSchlussPaketIstKeineZeile() {
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "43ff0000000000000000000000000042")), .unbekannt(0x43))
    }

    // MARK: Synthetisch

    func testPaketHatSechzehnByteUndPruefsumme() {
        let akku = bytes(TrackerProtokoll.akkuAnfrage)
        XCTAssertEqual(akku.count, 16)
        XCTAssertEqual(akku[0], 0x03)
        XCTAssertEqual(akku[15], 0x03)
    }

    func testPruefsummeLaeuftUeberModulo256() {
        XCTAssertEqual(TrackerProtokoll.pruefsumme([0xFF, 0x02]), 0x01)
    }

    func testUngueltigeLaengeOderPruefsummeGibtNil() {
        XCTAssertNil(TrackerProtokoll.lesen(Data([0x03, 0x1B])))
        var kaputt = bytes(daten(hex: "031b000000000000000000000000001e"))
        kaputt[15] = kaputt[15] &+ 1
        XCTAssertNil(TrackerProtokoll.lesen(Data(kaputt)))
        XCTAssertFalse(TrackerProtokoll.istGueltig(Data()))
    }

    func testAkkuLaedt() {
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.akku, [100, 1])),
                       .akku(.init(prozent: 100, laedt: true)))
    }

    func testPulsEinstellungAus() {
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.pulsEinstellung, [1, 2, 30])),
                       .pulsEinstellung(.init(an: false, intervallMinuten: 30)))
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
