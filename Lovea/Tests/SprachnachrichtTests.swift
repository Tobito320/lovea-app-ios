import XCTest
@testable import Lovea

/// Voice round: recording state machine, speed values, autoplay rule (pure logic).
@MainActor
final class SprachnachrichtTests: XCTestCase {
    private let alle: [SprachPhase] = [.bereit, .nimmtAuf, .pruefen, .sendet]

    func testAblaufAufnehmenPausierenPruefenSenden() {
        var phase = SprachPhase.bereit
        phase = SprachAblauf.weiter(phase, .aufnehmen)
        XCTAssertEqual(phase, .nimmtAuf)
        phase = SprachAblauf.weiter(phase, .pausieren)
        XCTAssertEqual(phase, .pruefen)
        phase = SprachAblauf.weiter(phase, .aufnehmen)
        XCTAssertEqual(phase, .nimmtAuf, "weiter aufnehmen hängt an")
        phase = SprachAblauf.weiter(phase, .pausieren)
        phase = SprachAblauf.weiter(phase, .senden)
        XCTAssertEqual(phase, .sendet)
        XCTAssertEqual(SprachAblauf.weiter(phase, .gesendet), .bereit)
    }

    func testUnterbrechungPausiertNurUndSendetNie() {
        XCTAssertEqual(SprachAblauf.weiter(.nimmtAuf, .unterbrechung), .pruefen)

        // Nur `.senden` führt nach `.sendet`.
        for phase in alle where phase != .sendet {
            for ereignis in [SprachEreignis.aufnehmen, .pausieren, .unterbrechung, .verwerfen, .gesendet] {
                XCTAssertNotEqual(SprachAblauf.weiter(phase, ereignis), .sendet, "\(phase) + \(ereignis)")
            }
        }
    }

    func testVerwerfenUndLeeresSendenAusBereit() {
        XCTAssertEqual(SprachAblauf.weiter(.pruefen, .verwerfen), .bereit)
        XCTAssertEqual(SprachAblauf.weiter(.nimmtAuf, .verwerfen), .bereit)
        XCTAssertEqual(SprachAblauf.weiter(.bereit, .senden), .bereit, "ohne Aufnahme nichts senden")
    }

    func testGeschwindigkeiten() {
        XCTAssertEqual(SprachSpieler.naechsteGeschwindigkeit(1), 1.5)
        XCTAssertEqual(SprachSpieler.naechsteGeschwindigkeit(1.5), 2)
        XCTAssertEqual(SprachSpieler.naechsteGeschwindigkeit(2), 1)
        XCTAssertEqual([Float(1), 1.5, 2].map { SprachTempo.text($0) }, ["1×", "1,5×", "2×"])
    }

    // MARK: Autoplay

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func sprache(_ id: String, von: Person, _ s: TimeInterval) -> ChatModell.Nachricht {
        ChatModell.Nachricht(
            id: id, von: von, zeit: t0.addingTimeInterval(s),
            medien: [ChatModell.MedienEintrag(id: "m-\(id)", typ: "sprache", breite: 0, hoehe: 0, dauer: 3, pegel: nil)]
        )
    }

    private func text(_ id: String, von: Person, _ s: TimeInterval) -> ChatModell.Nachricht {
        ChatModell.Nachricht(id: id, von: von, zeit: t0.addingTimeInterval(s), text: "hi")
    }

    func testAutoplayGleicherAbsenderDirektDanach() {
        let verlauf = [sprache("a", von: .annika, 0), sprache("b", von: .annika, 5), sprache("c", von: .annika, 9)]
        XCTAssertEqual(SprachFolge.naechste(nach: "m-a", in: verlauf, ich: .ahmed)?.nachricht.id, "b")
        XCTAssertEqual(SprachFolge.naechste(nach: "m-b", in: verlauf, ich: .ahmed)?.medium.id, "m-c")
        XCTAssertNil(SprachFolge.naechste(nach: "m-c", in: verlauf, ich: .ahmed), "letzte Nachricht")
    }

    func testAutoplayStopptBeiAllemDazwischen() {
        let andererAbsender = [sprache("a", von: .annika, 0), sprache("b", von: .ahmed, 5)]
        XCTAssertNil(SprachFolge.naechste(nach: "m-a", in: andererAbsender, ich: .ahmed))

        let textDazwischen = [sprache("a", von: .annika, 0), text("t", von: .annika, 3), sprache("b", von: .annika, 5)]
        XCTAssertNil(SprachFolge.naechste(nach: "m-a", in: textDazwischen, ich: .ahmed))

        let eigeneDazwischen = [sprache("a", von: .annika, 0), text("t", von: .ahmed, 3), sprache("b", von: .annika, 5)]
        XCTAssertNil(SprachFolge.naechste(nach: "m-a", in: eigeneDazwischen, ich: .ahmed))
    }

    func testEigeneSprachnachrichtSpieltNieWeiter() {
        let verlauf = [sprache("a", von: .ahmed, 0), sprache("b", von: .ahmed, 5)]
        XCTAssertNil(SprachFolge.naechste(nach: "m-a", in: verlauf, ich: .ahmed))
        XCTAssertEqual(SprachFolge.naechste(nach: "m-a", in: verlauf, ich: .annika)?.nachricht.id, "b")
    }
}
