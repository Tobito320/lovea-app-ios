import XCTest
@testable import Lovea

/// Pure fold tests for `EntwurfFaltung` (Z-26.2, Review-Fokus #5 "Entwurf auf zwei Geräten oder
/// nach Neuinstallation"). Exercised through `ChatModell.anwenden`/`entwurf(fuer:)`, same pattern
/// as every other fold in `ChatModellTests`.
@MainActor
final class EntwurfTests: XCTestCase {
    func testNewestConfirmedSeqWinsRegardlessOfArrivalOrder() {
        let modell = ChatModell(registrieren: false)
        let alt = opEntwurf(text: "alt", von: .ahmed, seq: 5, zeit: Date(timeIntervalSince1970: 1_000))
        let neu = opEntwurf(text: "neu", von: .ahmed, seq: 8, zeit: Date(timeIntervalSince1970: 2_000))

        // seq 8 delivered BEFORE seq 5 — the log/catch-up order isn't guaranteed.
        modell.anwenden([neu])
        modell.anwenden([alt])

        XCTAssertEqual(modell.entwurf(fuer: .ahmed).text, "neu")
    }

    func testUnconfirmedLocalEchoDoesNotPermanentlyOutrankALaterConfirmedOp() {
        let modell = ChatModell(registrieren: false)
        let id = UUID().uuidString
        let optimistisch = opEntwurf(text: "eigenes Tippen", von: .ahmed, seq: nil, zeit: Date(timeIntervalSince1970: 1_000), id: id)

        modell.anwenden([optimistisch])
        XCTAssertEqual(modell.entwurf(fuer: .ahmed).text, "eigenes Tippen", "the optimistic send shows immediately")

        // The SAME op, now confirmed (same op.id) — must not need to "win" a comparison against
        // its own still-open entry.
        let bestaetigt = Op(id: id, seq: 3, art: optimistisch.art, von: .ahmed, zeit: optimistisch.zeit, d: optimistisch.d)
        modell.anwenden([bestaetigt])
        XCTAssertEqual(modell.entwurf(fuer: .ahmed).text, "eigenes Tippen", "same content, now confirmed")

        // A genuinely newer draft, already confirmed with a higher seq (e.g. typed on a second
        // device) must still be able to win — the earlier local echo must not have permanently
        // sorted itself above every future confirmed seq.
        let zweitesGeraet = opEntwurf(text: "vom zweiten Gerät", von: .ahmed, seq: 9, zeit: Date(timeIntervalSince1970: 2_000))
        modell.anwenden([zweitesGeraet])
        XCTAssertEqual(modell.entwurf(fuer: .ahmed).text, "vom zweiten Gerät")
    }

    func testClearStaysClearedAgainstALateOlderOp() {
        let modell = ChatModell(registrieren: false)
        let entwurf = opEntwurf(text: "hallo", von: .ahmed, seq: 4, zeit: Date(timeIntervalSince1970: 1_000))
        modell.anwenden([entwurf])
        XCTAssertEqual(modell.entwurf(fuer: .ahmed).text, "hallo")

        let geleert = opEntwurf(text: nil, von: .ahmed, seq: 6, zeit: Date(timeIntervalSince1970: 2_000))
        modell.anwenden([geleert])
        XCTAssertTrue(modell.entwurf(fuer: .ahmed).leer)

        // A stray replay of the older draft (lower seq) must never resurrect it.
        modell.anwenden([entwurf])
        XCTAssertTrue(modell.entwurf(fuer: .ahmed).leer, "a sent draft never taucht wieder auf")
    }

    func testPartnerDraftNeverSurfacesForIch() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([opEntwurf(text: "Annikas Entwurf", von: .annika, seq: 1)])

        XCTAssertTrue(modell.entwurf(fuer: .ahmed).leer)
        XCTAssertEqual(modell.entwurf(fuer: .annika).text, "Annikas Entwurf")
    }

    func testMedienUndSpracheWerdenGefaltet() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([opEntwurf(text: "mit Bild", medien: ["m1", "m2"], sprache: "s1", von: .ahmed, seq: 1)])

        let entwurf = modell.entwurf(fuer: .ahmed)
        XCTAssertEqual(entwurf.medien, ["m1", "m2"])
        XCTAssertEqual(entwurf.sprache, "s1")
        XCTAssertFalse(entwurf.leer)
    }

    // MARK: - Helper

    private func opEntwurf(text: String?, medien: [String]? = nil, sprache: String? = nil, von: Person, seq: Int?, zeit: Date = Date(), id: String = UUID().uuidString) -> Op {
        let neu = Op.neu("entwurf.setzen", EntwurfPayloadForTests(text: text, medien: medien, sprache: sprache), von: von)
        return Op(id: id, seq: seq, art: neu.art, von: von, zeit: zeit, d: neu.d)
    }
}

private struct EntwurfPayloadForTests: Encodable {
    var text: String?
    var medien: [String]?
    var sprache: String?
}
