import XCTest
@testable import Lovea

@MainActor
final class ChatModellTests: XCTestCase {

    // MARK: - nachricht.neu (Z-4.1)

    func testNeueNachrichtWirdAngezeigtUndIstIdempotentByMessageID() {
        let modell = ChatModell(registrieren: false)
        let nachrichtID = UUID().uuidString
        let optimistisch = neuOp(nachrichtID, text: "hallo", seq: nil)
        let bestaetigt = Op(id: optimistisch.id, seq: 7, art: optimistisch.art, von: optimistisch.von, zeit: optimistisch.zeit, d: optimistisch.d)

        modell.anwenden([optimistisch])
        XCTAssertEqual(modell.nachrichten.count, 1)
        XCTAssertEqual(modell.nachrichten[0].seq, nil)

        modell.anwenden([bestaetigt])
        XCTAssertEqual(modell.nachrichten.count, 1, "die zweite Zustellung (Echo) darf keine zweite Nachricht erzeugen")
        XCTAssertEqual(modell.nachrichten[0].seq, 7)
        XCTAssertEqual(modell.nachrichten[0].text, "hallo")
        XCTAssertEqual(modell.nachrichten[0].id, nachrichtID)
    }

    func testSortierungNachSeqDannZeit() {
        let modell = ChatModell(registrieren: false)
        let jetzt = Date()
        let a = op("nachricht.neu", ["id": "a", "text": "eins"], von: .ahmed, zeit: jetzt, seq: 5)
        let b = op("nachricht.neu", ["id": "b", "text": "zwei"], von: .annika, zeit: jetzt.addingTimeInterval(1), seq: 2)
        let c = op("nachricht.neu", ["id": "c", "text": "drei"], von: .ahmed, zeit: jetzt.addingTimeInterval(2), seq: nil)

        modell.anwenden([a, b, c])

        XCTAssertEqual(modell.nachrichten.map(\.id), ["b", "a", "c"], "seq 2 vor seq 5 vor unbestätigt (Int.max)")
    }

    // MARK: - zeichnung.einladung (Block 13)

    func testEinladungWirdEineLokaleZeileAuchNachEcho() {
        let modell = ChatModell(registrieren: false)
        let optimistisch = op("zeichnung.einladung", ["zeichnungId": "z1", "name": "Katze"], von: .annika)
        let echo = Op(id: optimistisch.id, seq: 9, art: optimistisch.art, von: .annika, zeit: optimistisch.zeit, d: optimistisch.d)
        modell.anwenden([optimistisch])
        modell.anwenden([echo])
        XCTAssertEqual(modell.nachrichten.count, 1)
        XCTAssertEqual(modell.nachrichten[0].einladung, ChatModell.EinladungInfo(zeichnungId: "z1", name: "Katze"))
        XCTAssertEqual(modell.nachrichten[0].seq, 9)
    }

    // MARK: - nachricht.bearbeitet

    func testBearbeitenErsetztTextUndSetztFlag() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([neuOp("m1", text: "original", seq: 1)])
        modell.anwenden([op("nachricht.bearbeitet", ["id": "m1", "text": "geändert"], von: .ahmed)])

        let nachricht = modell.nachrichten.first { $0.id == "m1" }
        XCTAssertEqual(nachricht?.text, "geändert")
        XCTAssertEqual(nachricht?.bearbeitet, true)
    }

    // Z-33.3: the version history, once per op even when the echo comes back.
    func testFassungenAusAllenBearbeitungenOhneDoppelteDurchsEcho() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([neuOp("m1", text: "A", seq: 1)])
        let zuB = op("nachricht.bearbeitet", ["id": "m1", "text": "B"], von: .ahmed)
        let zuA = op("nachricht.bearbeitet", ["id": "m1", "text": "A"], von: .ahmed)
        modell.anwenden([zuB])
        modell.anwenden([zuA])
        modell.anwenden([Op(id: zuB.id, seq: 2, art: zuB.art, von: zuB.von, zeit: zuB.zeit, d: zuB.d)])

        let nachricht = modell.nachricht("m1")
        XCTAssertEqual(nachricht?.text, "A")
        XCTAssertEqual(nachricht?.fassungen, ["A", "B"], "das Echo von A→B darf weder Text noch Verlauf zurückdrehen")
    }

    // Z-33.2: `effekt` rides along; unknown values from a newer build are ignored.
    func testEffektWirdGefaltetUnbekannterIgnoriert() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([op("nachricht.neu", ["id": "e1", "text": "gute Nacht", "effekt": "sterne"], von: .annika, seq: 1)])
        modell.anwenden([op("nachricht.neu", ["id": "e2", "text": "hi", "effekt": "feuerwerk"], von: .annika, seq: 2)])

        XCTAssertEqual(modell.nachricht("e1")?.effekt, .sterne)
        XCTAssertNil(modell.nachricht("e2")?.effekt)
        XCTAssertEqual(modell.nachricht("e2")?.text, "hi")
    }

    // Block 18 search, now a pure model function.
    func testSucheFindetTextOhneGeloeschte() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([neuOp("m1", text: "Pizza heute?", seq: 1), neuOp("m2", text: "pizza!", seq: 2), neuOp("m3", text: "Pasta", seq: 3)])
        modell.anwenden([op("nachricht.geloescht", ["id": "m2"], von: .ahmed)])

        XCTAssertEqual(modell.suchen("PIZZA"), ["m1"])
        XCTAssertEqual(modell.suchen("  "), [])
    }

    // MARK: - nachricht.geloescht

    func testLoeschenEntferntFuerBeide() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([neuOp("m1", text: "weg damit", seq: 1)])
        modell.anwenden([op("nachricht.geloescht", ["id": "m1"], von: .annika)])

        XCTAssertEqual(modell.nachrichten.first { $0.id == "m1" }?.geloescht, true)
    }

    // MARK: - nachricht.reaktion (eine je Person)

    func testReaktionEinePerPersonUndKannEntferntWerden() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([neuOp("m1", text: "hi", seq: 1)])

        modell.anwenden([op("nachricht.reaktion", ["id": "m1", "emoji": "❤️"], von: .annika)])
        modell.anwenden([op("nachricht.reaktion", ["id": "m1", "emoji": "😂"], von: .annika)])
        XCTAssertEqual(modell.nachrichten.first { $0.id == "m1" }?.reaktionen[.annika], "😂", "die zweite Reaktion ersetzt die erste")

        modell.anwenden([op("nachricht.reaktion", ["id": "m1", "emoji": nil], von: .annika)])
        XCTAssertNil(modell.nachrichten.first { $0.id == "m1" }?.reaktionen[.annika])
    }

    // MARK: - nachricht.gelesen (bis Zeitpunkt)

    func testGelesenSpeichertNeuestenZeitpunktJePerson() {
        let modell = ChatModell(registrieren: false)
        let frueh = Date(timeIntervalSince1970: 1_000)
        let spaet = Date(timeIntervalSince1970: 2_000)

        modell.anwenden([op("nachricht.gelesen", ["bis": .string(iso(spaet))], von: .annika)])
        modell.anwenden([op("nachricht.gelesen", ["bis": .string(iso(frueh))], von: .annika)])

        let gespeichert = modell.gelesenBis[.annika]!
        XCTAssertEqual(gespeichert.timeIntervalSince1970, spaet.timeIntervalSince1970, accuracy: 0.001, "ein älterer Stand darf den neueren nicht zurückdrehen")
    }

    // MARK: - nachricht.angeheftet mit bis

    func testAnheftenMitBisUndLosloesen() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([neuOp("m1", text: "wichtig", seq: 1)])

        let morgen = Date().addingTimeInterval(86_400)
        modell.anwenden([op("nachricht.angeheftet", ["id": "m1", "bis": .string(iso(morgen))], von: .ahmed)])
        var nachricht = modell.nachrichten.first { $0.id == "m1" }
        XCTAssertEqual(nachricht?.angeheftet, true)
        XCTAssertEqual(nachricht!.angeheftetBis!.timeIntervalSince1970, morgen.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertEqual(modell.angeheftete.map(\.id), ["m1"])

        modell.anwenden([op("nachricht.losgeloest", ["id": "m1"], von: .ahmed)])
        nachricht = modell.nachrichten.first { $0.id == "m1" }
        XCTAssertEqual(nachricht?.angeheftet, false)
        XCTAssertNil(nachricht?.angeheftetBis)
        XCTAssertTrue(modell.angeheftete.isEmpty)
    }

    func testAnheftenOhneBisIstFuerImmerUndBleibtInDerLeiste() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([neuOp("m1", text: "für immer", seq: 1)])
        modell.anwenden([op("nachricht.angeheftet", ["id": "m1", "bis": nil], von: .ahmed)])

        XCTAssertNil(modell.nachrichten.first { $0.id == "m1" }?.angeheftetBis)
        XCTAssertEqual(modell.angeheftete.map(\.id), ["m1"])
    }

    // MARK: - stern (nur die eigenen)

    func testSterneSindProPersonGetrennt() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([neuOp("m1", text: "stern?", seq: 1)])

        modell.anwenden([op("stern", ["id": "m1", "an": true], von: .ahmed)])
        XCTAssertEqual(modell.meineSterne(.ahmed).map(\.id), ["m1"])
        XCTAssertTrue(modell.meineSterne(.annika).isEmpty, "Annikas Filter zeigt nicht Ahmeds Stern")

        modell.anwenden([op("stern", ["id": "m1", "an": false], von: .ahmed)])
        XCTAssertTrue(modell.meineSterne(.ahmed).isEmpty)
    }

    // MARK: - ungelesen (Z-4.6 Badge-Grundlage)

    func testUngeleseneZaehltNurNeuerePartnerNachrichten() {
        let modell = ChatModell(registrieren: false)
        let alt = Date(timeIntervalSince1970: 1_000)
        let neu = Date(timeIntervalSince1970: 3_000)

        modell.anwenden([op("nachricht.neu", ["id": "alt", "text": "alt"], von: .annika, zeit: alt, seq: 1)])
        modell.anwenden([op("nachricht.neu", ["id": "neu", "text": "neu"], von: .annika, zeit: neu, seq: 2)])
        modell.anwenden([op("nachricht.gelesen", ["bis": .string(iso(Date(timeIntervalSince1970: 2_000)))], von: .ahmed)])

        XCTAssertEqual(modell.ungelesen(fuer: .ahmed), 1)
        XCTAssertEqual(modell.ungelesen(fuer: .annika), 0, "eigene Nachrichten zählen nie als ungelesen")
    }

    // MARK: - snap.angesehen / snap.gespeichert (Z-6.3)

    func testSnapAngesehenSetztFlaggenAufDieSnapNachricht() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([op("nachricht.neu", ["id": "s1"], von: .ahmed, seq: 1)])
        modell.anwenden([op("snap.angesehen", ["id": "s1", "lange": true], von: .annika)])

        let nachricht = modell.nachrichten.first { $0.id == "s1" }
        XCTAssertEqual(nachricht?.snapAngesehen, true)
        XCTAssertEqual(nachricht?.snapLange, true)
    }

    func testSnapGespeichertSetztFlag() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([op("nachricht.neu", ["id": "s1"], von: .ahmed, seq: 1)])
        modell.anwenden([op("snap.gespeichert", ["id": "s1"], von: .annika)])

        XCTAssertEqual(modell.nachrichten.first { $0.id == "s1" }?.snapGespeichert, true)
    }

    // MARK: - snap.aufnahme (Z-6.4; Review-Fokus #1: dieselbe Operation kommt zweimal)

    func testSnapAufnahmeWirdZurSystemzeileUndIstIdempotentByOpID() {
        let modell = ChatModell(registrieren: false)
        let optimistisch = op("snap.aufnahme", ["id": "s1", "art": "screenshot"], von: .annika)
        let bestaetigt = Op(id: optimistisch.id, seq: 7, art: optimistisch.art, von: optimistisch.von, zeit: optimistisch.zeit, d: optimistisch.d)

        modell.anwenden([optimistisch])
        XCTAssertEqual(modell.nachrichten.count, 1)
        XCTAssertEqual(modell.nachrichten[0].system, "Annika hat einen Screenshot gemacht")
        XCTAssertEqual(modell.nachrichten[0].seq, nil)

        modell.anwenden([bestaetigt])
        XCTAssertEqual(modell.nachrichten.count, 1, "das Echo (gleiche op.id) darf keine zweite Zeile erzeugen")
        XCTAssertEqual(modell.nachrichten[0].seq, 7)
    }

    func testSnapAufnahmeBildschirmaufnahmeText() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([op("snap.aufnahme", ["id": "s1", "art": "bildschirmaufnahme"], von: .ahmed)])

        XCTAssertEqual(modell.nachrichten.first?.system, "Ahmed hat den Bildschirm aufgenommen")
    }

    // MARK: - Helpers

    private func neuOp(_ id: String, text: String, seq: Int?, von: Person = .ahmed) -> Op {
        op("nachricht.neu", ["id": .string(id), "text": .string(text)], von: von, seq: seq)
    }

    private func op(_ art: String, _ d: [String: AnyEncodableForTests], von: Person, zeit: Date = Date(), seq: Int? = nil) -> Op {
        let neu = Op.neu(art, d, von: von)
        return Op(id: neu.id, seq: seq, art: art, von: von, zeit: zeit, d: neu.d)
    }

    private func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }
}

/// Lets the test helper build small ad-hoc JSON payloads (`["id": "m1", "bis": nil]`, …)
/// without a bespoke Codable struct per op kind.
private enum AnyEncodableForTests: Encodable, ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByNilLiteral {
    case string(String)
    case bool(Bool)
    case null

    init(stringLiteral value: String) { self = .string(value) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
    init(nilLiteral: ()) { self = .null }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        }
    }
}
