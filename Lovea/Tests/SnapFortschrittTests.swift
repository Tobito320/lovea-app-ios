import XCTest
@testable import Lovea

/// Zustandsmaschine hinter der Fortschrittsanzeige (Senden und Empfangen). Reine Logik.
final class SnapFortschrittTests: XCTestCase {
    private func senden(_ ereignisse: MedienFortschritt.Ereignis...) -> MedienFortschritt {
        var stand = MedienFortschritt(rolle: .senden)
        for e in ereignisse { stand.anwenden(e) }
        return stand
    }

    private func empfangen(_ ereignisse: MedienFortschritt.Ereignis...) -> MedienFortschritt {
        var stand = MedienFortschritt(rolle: .empfangen)
        for e in ereignisse { stand.anwenden(e) }
        return stand
    }

    // MARK: Senden

    func testSendenStartetBeimVorbereiten() {
        let stand = MedienFortschritt(rolle: .senden)
        XCTAssertEqual(stand.phase, .vorbereiten)
        XCTAssertNil(stand.anteil)
        XCTAssertEqual(stand.text, "Wird vorbereitet")
    }

    func testVollerSendeweg() {
        var stand = senden(.vorbereitet(gesamt: 1000))
        XCTAssertEqual(stand.phase, .hochladen)
        XCTAssertEqual(stand.prozent, 0)
        stand.anwenden(.hochgeladen(bytes: 250))
        XCTAssertEqual(stand.prozent, 25)
        XCTAssertEqual(stand.text, "Hochladen 25 %")
        stand.anwenden(.hochgeladen(bytes: 750))
        stand.anwenden(.uploadFertig)
        XCTAssertEqual(stand.phase, .zustellen)
        XCTAssertEqual(stand.text, "Wird zugestellt")
        stand.anwenden(.bestaetigt)
        XCTAssertEqual(stand.phase, .zugestellt)
        XCTAssertTrue(stand.fertig)
        XCTAssertEqual(stand.anteil, 1)
    }

    func testBestaetigungVorUploadEndeSpringtDirektAufZugestellt() {
        let stand = senden(.vorbereitet(gesamt: 100), .bestaetigt, .hochgeladen(bytes: 40), .uploadFertig)
        XCTAssertEqual(stand.phase, .zugestellt)
    }

    func testBestaetigungVorDemUploadAendertDiePhaseNicht() {
        let stand = senden(.vorbereitet(gesamt: 100), .bestaetigt)
        XCTAssertEqual(stand.phase, .hochladen)
        XCTAssertTrue(stand.bestaetigt)
    }

    func testBytesUeberGesamtWerdenGekappt() {
        let stand = senden(.vorbereitet(gesamt: 100), .hochgeladen(bytes: 80), .hochgeladen(bytes: 80))
        XCTAssertEqual(stand.prozent, 100)
        XCTAssertEqual(stand.uebertragen, 100)
    }

    func testUnbekannteGroesseGibtKeineProzent() {
        let stand = senden(.vorbereitet(gesamt: 0), .hochgeladen(bytes: 500))
        XCTAssertNil(stand.anteil)
        XCTAssertNil(stand.prozent)
        XCTAssertEqual(stand.text, "Hochladen")
    }

    func testNegativeUndNullBytesWerdenIgnoriert() {
        let stand = senden(.vorbereitet(gesamt: 100), .hochgeladen(bytes: -5), .hochgeladen(bytes: 0))
        XCTAssertEqual(stand.uebertragen, 0)
    }

    func testEreignisseInFalscherPhaseWerdenIgnoriert() {
        // Upload-Ende ohne Vorbereitung, Bytes beim Vorbereiten, Download-Ereignis beim Senden.
        let a = senden(.uploadFertig, .hochgeladen(bytes: 10), .erhalten(bytes: 5, gesamt: 10), .heruntergeladen)
        XCTAssertEqual(a.phase, .vorbereiten)
        XCTAssertEqual(a.uebertragen, 0)
    }

    func testNachFertigDreintTeilNichtsZurueck() {
        var stand = senden(.vorbereitet(gesamt: 100), .uploadFertig, .bestaetigt)
        stand.anwenden(.hochgeladen(bytes: 10))
        stand.anwenden(.vorbereitet(gesamt: 5))
        stand.anwenden(.fehler)
        XCTAssertEqual(stand.phase, .zugestellt)
        XCTAssertEqual(stand.uebertragen, 100)
    }

    func testUploadFertigSetztAufGesamt() {
        let stand = senden(.vorbereitet(gesamt: 100), .hochgeladen(bytes: 30), .uploadFertig)
        XCTAssertEqual(stand.uebertragen, 100)
    }

    func testFehlerBeimHochladenUndNeuerVersuchKehrtZurueck() {
        var stand = senden(.vorbereitet(gesamt: 100), .hochgeladen(bytes: 40), .fehler)
        XCTAssertEqual(stand.phase, .fehlgeschlagen)
        XCTAssertNil(stand.anteil)
        XCTAssertEqual(stand.text, "Senden steht aus, wird wiederholt")
        stand.anwenden(.neuerVersuch)
        XCTAssertEqual(stand.phase, .hochladen)
        XCTAssertEqual(stand.uebertragen, 0) // der neue Lauf meldet schon oben liegende Teile erneut
    }

    func testFehlerBeimVorbereitenKehrtZumVorbereitenZurueck() {
        var stand = senden(.fehler)
        XCTAssertEqual(stand.phase, .fehlgeschlagen)
        stand.anwenden(.neuerVersuch)
        XCTAssertEqual(stand.phase, .vorbereiten)
    }

    func testZweiterFehlerUeberschreibtDenMerkerNicht() {
        var stand = senden(.vorbereitet(gesamt: 10), .fehler, .fehler)
        stand.anwenden(.neuerVersuch)
        XCTAssertEqual(stand.phase, .hochladen)
    }

    func testNeuerVersuchOhneFehlerTutNichts() {
        let stand = senden(.vorbereitet(gesamt: 10), .neuerVersuch)
        XCTAssertEqual(stand.phase, .hochladen)
    }

    // MARK: Empfangen

    func testEmpfangenStartetBeimHerunterladen() {
        let stand = MedienFortschritt(rolle: .empfangen)
        XCTAssertEqual(stand.phase, .herunterladen)
        XCTAssertEqual(stand.text, "Herunterladen")
    }

    func testVollerEmpfangsweg() {
        var stand = empfangen(.erhalten(bytes: 250, gesamt: 1000))
        XCTAssertEqual(stand.prozent, 25)
        XCTAssertEqual(stand.text, "Herunterladen 25 %")
        stand.anwenden(.erhalten(bytes: 1000, gesamt: 1000))
        stand.anwenden(.heruntergeladen)
        XCTAssertEqual(stand.phase, .bereit)
        XCTAssertTrue(stand.fertig)
        XCTAssertEqual(stand.text, "Geladen")
    }

    func testDownloadStandGehtNieRueckwaerts() {
        let stand = empfangen(.erhalten(bytes: 600, gesamt: 1000), .erhalten(bytes: 100, gesamt: 1000))
        XCTAssertEqual(stand.prozent, 60)
    }

    func testDownloadMitUnbekannterGroesse() {
        let stand = empfangen(.erhalten(bytes: 600, gesamt: -1))
        XCTAssertNil(stand.prozent)
        XCTAssertEqual(stand.text, "Herunterladen")
    }

    func testFehlerBeimEmpfangWartetAufAbsenderUndHaeltNichtAn() {
        var stand = empfangen(.fehler)
        XCTAssertEqual(stand.phase, .herunterladen)
        XCTAssertEqual(stand.text, "Wartet auf Absender")
        stand.anwenden(.erhalten(bytes: 10, gesamt: 100))
        XCTAssertEqual(stand.text, "Herunterladen 10 %")
    }

    func testSendeEreignisseBeimEmpfangWerdenIgnoriert() {
        var stand = empfangen()
        stand.anwenden(.vorbereitet(gesamt: 10))
        stand.anwenden(.uploadFertig)
        stand.anwenden(.bestaetigt)
        XCTAssertEqual(stand.phase, .herunterladen)
        XCTAssertFalse(stand.bestaetigt)
    }

    // MARK: Anzeige

    func testMitBestaetigungAendertDenOriginalstandNicht() {
        let stand = senden(.vorbereitet(gesamt: 100), .uploadFertig)
        XCTAssertEqual(stand.phase, .zustellen)
        XCTAssertEqual(stand.mitBestaetigung(true).phase, .zugestellt)
        XCTAssertEqual(stand.mitBestaetigung(false).phase, .zustellen)
        XCTAssertEqual(stand.phase, .zustellen)
    }

    func testAnzeigeAndersIgnoriertKleinenZuwachs() {
        let a = empfangen(.erhalten(bytes: 100, gesamt: 100_000))
        let b = empfangen(.erhalten(bytes: 400, gesamt: 100_000))
        let c = empfangen(.erhalten(bytes: 5_000, gesamt: 100_000))
        XCTAssertFalse(b.anzeigeAnders(als: a))
        XCTAssertTrue(c.anzeigeAnders(als: a))
    }

    // MARK: Upload-Teile

    func testTeilBytesLetzterTeilIstKuerzer() {
        XCTAssertEqual(Medien.teilBytes(teil: 0, gesamtBytes: 2_500_000), Medien.teilGroesse)
        XCTAssertEqual(Medien.teilBytes(teil: 2, gesamtBytes: 2_500_000), 2_500_000 - 2 * Medien.teilGroesse)
        XCTAssertEqual(Medien.teilBytes(teil: 5, gesamtBytes: 100), 0)
        XCTAssertEqual(Medien.teilBytes(teil: 0, gesamtBytes: 100), 100)
    }

    // MARK: Stand

    @MainActor
    func testStandBeginntEinmalUndSetztNichtZurueck() {
        let stand = FortschrittsStand()
        stand.beginnen("a", rolle: .senden)
        stand.anwenden(.vorbereitet(gesamt: 100), id: "a")
        stand.beginnen("a", rolle: .senden)
        XCTAssertEqual(stand.stand("a")?.phase, .hochladen)
    }

    @MainActor
    func testStandIgnoriertUnbekannteIdUndVergisst() {
        let stand = FortschrittsStand()
        stand.anwenden(.vorbereitet(gesamt: 1), id: "x")
        XCTAssertNil(stand.stand("x"))
        stand.beginnen("x", rolle: .empfangen)
        stand.vergessen("x")
        XCTAssertNil(stand.stand("x"))
    }

    @MainActor
    func testStandRaeumtBeendeteEintraegeBeiVollerListe() {
        let stand = FortschrittsStand()
        for i in 0..<60 {
            stand.beginnen("fertig\(i)", rolle: .empfangen)
            stand.anwenden(.heruntergeladen, id: "fertig\(i)")
        }
        stand.beginnen("offen", rolle: .senden)
        XCTAssertNotNil(stand.stand("offen"))
        XCTAssertNil(stand.stand("fertig0"))
        XCTAssertLessThanOrEqual(stand.eintraege.count, 60)
    }
}
