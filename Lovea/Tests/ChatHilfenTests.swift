import XCTest
@testable import Lovea

/// R7: interactive keyboard dismiss must not fight the list's own re-pin-to-bottom logic.
final class ChatHilfenTests: XCTestCase {
    func testSpringtNurBeiEchterGroessenaenderung() {
        XCTAssertFalse(ListenAutoScroll.sollNachUntenSpringen(sichtbarGeaendert: false, warAmEnde: true, nutzerZiehtGerade: false))
    }

    func testSpringtNurWennAmEnde() {
        XCTAssertFalse(ListenAutoScroll.sollNachUntenSpringen(sichtbarGeaendert: true, warAmEnde: false, nutzerZiehtGerade: false))
    }

    func testSpringtNichtWaehrendDerNutzerZieht() {
        // Interaktives Tastatur-Einklappen aendert die sichtbare Hoehe bei jedem Frame — das darf
        // nicht gegen die eigene Wisch-Geste des Nutzers anspringen.
        XCTAssertFalse(ListenAutoScroll.sollNachUntenSpringen(sichtbarGeaendert: true, warAmEnde: true, nutzerZiehtGerade: true))
    }

    func testSpringtBeiEchterAenderungAmEndeOhneZiehen() {
        // z. B. Antwort-Leiste oder Tastatur oeffnet sich nicht-interaktiv, waehrend man unten war.
        XCTAssertTrue(ListenAutoScroll.sollNachUntenSpringen(sichtbarGeaendert: true, warAmEnde: true, nutzerZiehtGerade: false))
    }
}

/// Chat-Tempo (Test): the "list is moving" flag and the figure frame rate.
final class ChatTempoTests: XCTestCase {
    func testNurRuheIstKeinScrollen() {
        XCTAssertFalse(ChatTempo.scrolltBei(.idle))
        XCTAssertTrue(ChatTempo.scrolltBei(.tracking))
        XCTAssertTrue(ChatTempo.scrolltBei(.interacting))
        XCTAssertTrue(ChatTempo.scrolltBei(.decelerating))
        XCTAssertTrue(ChatTempo.scrolltBei(.animating))
    }

    func testFigurLaeuftImScrollenLangsamer() {
        XCTAssertEqual(ChatTempo.bildrate(normal: 20, an: true, scrollt: true), ChatTempo.bildrateImScrollen)
    }

    func testFigurBleibtInRuheOderBeiAusgeschaltetemSchalterSchnell() {
        XCTAssertEqual(ChatTempo.bildrate(normal: 20, an: true, scrollt: false), 20)
        XCTAssertEqual(ChatTempo.bildrate(normal: 20, an: false, scrollt: true), 20)
    }

    func testEineLangsameFigurWirdNichtSchneller() {
        XCTAssertEqual(ChatTempo.bildrate(normal: 5, an: true, scrollt: true), 5)
    }

    @MainActor
    func testFlagFolgtDerScrollPhase() {
        let tempo = ChatTempo()
        tempo.phase(.tracking)
        XCTAssertTrue(tempo.scrollt)
        tempo.phase(.decelerating)
        XCTAssertTrue(tempo.scrollt)
        tempo.phase(.idle)
        XCTAssertFalse(tempo.scrollt)
    }
}

/// Chat-Tempo (Test): the link check is cached per text, the backdrop compares by id.
@MainActor
final class ChatTempoZwischenspeicherTests: XCTestCase {
    func testLinkWirdGefundenUndMerktSichDasErgebnis() {
        let text = "Schau mal https://example.com/chat-tempo bitte"
        XCTAssertEqual(LinkCache.erster(in: text)?.absoluteString, "https://example.com/chat-tempo")
        XCTAssertEqual(LinkCache.erster(in: text)?.absoluteString, "https://example.com/chat-tempo")
    }

    func testTextOhneLinkBleibtOhneLinkAuchAusDemSpeicher() {
        XCTAssertNil(LinkCache.erster(in: "Nur ein Gruss ohne Adresse"))
        XCTAssertNil(LinkCache.erster(in: "Nur ein Gruss ohne Adresse"))
    }

    func testBackdropVergleichtNachId() {
        XCTAssertEqual(Backdrops.neutral, Backdrops.neutral)
        XCTAssertNotEqual(Backdrops.alle[0], Backdrops.alle[1])
    }
}

/// Chat-Tempo (Test): a row is only rebuilt when something it draws changed. A stale row is the
/// risk, so every input a row draws must make two rows unequal, and the closures must not.
@MainActor
final class ChatZeileGleichheitTests: XCTestCase {
    private func nachricht(_ aendern: (inout ChatModell.Nachricht) -> Void = { _ in }) -> ChatModell.Nachricht {
        var n = ChatModell.Nachricht(id: "m1", von: .ahmed, zeit: Date(timeIntervalSince1970: 1_000_000), text: "Hallo")
        aendern(&n)
        return n
    }

    private func zeile(
        _ n: ChatModell.Nachricht, stapel: [ChatModell.Nachricht] = [], vorher: ChatModell.Nachricht? = nil,
        gelesenAm: Date? = nil, zustellText: String? = nil, antwortet: @escaping @Sendable () -> Void = {}
    ) -> ChatNachrichtRow {
        ChatNachrichtRow(
            nachricht: n, ich: .ahmed, stapel: stapel,
            layout: ZeilenLayout(vorher: vorher, erste: n, letzte: n, nachher: nil),
            gelesenAm: gelesenAm, zustellText: zustellText,
            aktionen: ChatZeilenAktionen(antworten: { _ in antwortet() }, springen: { _ in }, fokussieren: { _ in })
        )
    }

    func testGleicheEingabenSindGleich() {
        XCTAssertTrue(zeile(nachricht()) == zeile(nachricht()))
    }

    func testAndereAktionenAendernNichts() {
        XCTAssertTrue(zeile(nachricht(), antwortet: {}) == zeile(nachricht(), antwortet: { _ = 1 }))
    }

    func testJederGezeichneteWertMachtDieZeileUngleich() {
        let basis = zeile(nachricht())
        XCTAssertFalse(basis == zeile(nachricht { $0.reaktionen[.annika] = "❤️" }))
        XCTAssertFalse(basis == zeile(nachricht { $0.gemerkt = [.ahmed] }))
        XCTAssertFalse(basis == zeile(nachricht { $0.gesternt = [.ahmed] }))
        XCTAssertFalse(basis == zeile(nachricht { $0.text = "Hallo!" }))
        XCTAssertFalse(basis == zeile(nachricht { $0.bearbeitet = true }))
        XCTAssertFalse(basis == zeile(nachricht { $0.geloescht = true }))
        XCTAssertFalse(basis == zeile(nachricht { $0.snapAngesehen = true }))
        XCTAssertFalse(basis == zeile(nachricht { $0.seq = 7 }))
    }

    func testLesestatusUndZustellungMachenUngleich() {
        let basis = zeile(nachricht())
        XCTAssertFalse(basis == zeile(nachricht(), gelesenAm: Date(timeIntervalSince1970: 1_000_100)))
        XCTAssertFalse(basis == zeile(nachricht(), zustellText: "Zugestellt"))
    }

    func testStapelUndNachbarnMachenUngleich() {
        let n = nachricht()
        let zweite = ChatModell.Nachricht(id: "m2", von: .ahmed, zeit: n.zeit.addingTimeInterval(5))
        XCTAssertFalse(zeile(n) == zeile(n, stapel: [n, zweite]))
        // Mit Vorgaenger faellt der Datumstrenner weg.
        let davor = ChatModell.Nachricht(id: "m0", von: .ahmed, zeit: n.zeit.addingTimeInterval(-5), text: "Davor")
        XCTAssertFalse(zeile(n) == zeile(n, vorher: davor))
    }
}
