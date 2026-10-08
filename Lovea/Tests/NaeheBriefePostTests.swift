import XCTest
@testable import Lovea

@MainActor
final class NaeheBriefePostTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_791_500_000)

    private func op<T: Encodable>(_ art: String, _ d: T, von: Person, id: String = UUID().uuidString, nach s: TimeInterval = 0) -> Op {
        var o = Op.neu(art, d, von: von)
        o = Op(id: id, seq: nil, art: art, von: von, zeit: t0.addingTimeInterval(s), d: o.d)
        return o
    }

    private struct BriefD: Encodable { var id: String; var titel: String; var text: String; var sprache: String? }
    private struct IdD: Encodable { var id: String }
    private struct PostD: Encodable { var id: String; var medienId: String; var dauer: Double; var pegel: [Float] }

    // MARK: - Titel

    func testTitelBautOeffneWennGenauEinmal() {
        XCTAssertEqual(BriefeLogik.titel(fuer: "du mich vermisst"), "Öffne, wenn du mich vermisst")
        XCTAssertEqual(BriefeLogik.titel(fuer: "  Öffne, wenn du traurig bist "), "Öffne, wenn du traurig bist")
        XCTAssertEqual(BriefeLogik.titel(fuer: "öffne wenn du lachst"), "Öffne, wenn du lachst")
        XCTAssertNil(BriefeLogik.titel(fuer: "   "))
        XCTAssertNil(BriefeLogik.titel(fuer: "Öffne, wenn"))
    }

    func testVorschlaegeSindAlleGueltig() {
        XCTAssertEqual(BriefeLogik.vorschlaege.count, 5)
        for v in BriefeLogik.vorschlaege { XCTAssertEqual(BriefeLogik.titel(fuer: v), "Öffne, wenn " + v) }
    }

    // MARK: - Briefe falten

    func testBriefUndOeffnungFaltenUndSindIdempotent() throws {
        let neu = op(BriefeLogik.artNeu, BriefD(id: "b1", titel: "Öffne, wenn du mich vermisst", text: "Ich bin da.", sprache: nil), von: .ahmed, id: "o1")
        let auf = op(BriefeLogik.artGeoeffnet, IdD(id: "b1"), von: .annika, id: "o2", nach: 60)
        let stand = BriefeLogik.anwenden([neu, auf, neu, auf])
        XCTAssertEqual(stand.briefe.count, 1)
        let brief = try XCTUnwrap(stand.briefe["b1"])
        XCTAssertEqual(brief.von, .ahmed)
        XCTAssertEqual(BriefeLogik.geoeffnetAm(brief, stand), t0.addingTimeInterval(60))
        XCTAssertEqual(stand, BriefeLogik.anwenden([auf, neu]), "Reihenfolge egal")
    }

    func testFruehesteOeffnungGewinnt() {
        let neu = op(BriefeLogik.artNeu, BriefD(id: "b1", titel: "t", text: "x", sprache: nil), von: .ahmed)
        let spaet = op(BriefeLogik.artGeoeffnet, IdD(id: "b1"), von: .annika, nach: 500)
        let frueh = op(BriefeLogik.artGeoeffnet, IdD(id: "b1"), von: .annika, nach: 100)
        XCTAssertEqual(BriefeLogik.anwenden([neu, spaet, frueh]).geoeffnet["b1"], t0.addingTimeInterval(100))
    }

    func testErhaltenUngeoeffnetZuerstUndZaehler() {
        let ops = [
            op(BriefeLogik.artNeu, BriefD(id: "alt", titel: "a", text: "x", sprache: nil), von: .ahmed, nach: 0),
            op(BriefeLogik.artNeu, BriefD(id: "neu", titel: "n", text: "x", sprache: nil), von: .ahmed, nach: 10),
            op(BriefeLogik.artNeu, BriefD(id: "mein", titel: "m", text: "x", sprache: nil), von: .annika, nach: 20),
            op(BriefeLogik.artGeoeffnet, IdD(id: "neu"), von: .annika, nach: 30),
        ]
        let stand = BriefeLogik.anwenden(ops)
        XCTAssertEqual(BriefeLogik.erhalten(stand, ich: .annika).map(\.id), ["alt", "neu"])
        XCTAssertEqual(BriefeLogik.ungeoeffnet(stand, ich: .annika), 1)
        XCTAssertEqual(BriefeLogik.geschrieben(stand, ich: .annika).map(\.id), ["mein"])
        XCTAssertEqual(BriefeLogik.ungeoeffnet(stand, ich: .ahmed), 1, "Ahmeds eigene Briefe zählen nicht, ihrer schon")
    }

    func testBriefSpeicherSchreibenOeffnenNurEmpfaengerin() throws {
        final class Ziel { var ops: [Op] = [] }
        let ziel = Ziel()
        var ich = Person.ahmed
        let s = BriefeSpeicher(ich: { ich }, senden: { ziel.ops.append($0) })
        XCTAssertNil(s.schreiben(titel: "du mich vermisst", text: "   "), "ohne Text und ohne Stimme kein Brief")
        XCTAssertNil(s.schreiben(titel: " ", text: "Hallo"))
        let brief = try XCTUnwrap(s.schreiben(titel: "du mich vermisst", text: " Hallo "))
        XCTAssertEqual(brief.titel, "Öffne, wenn du mich vermisst")
        XCTAssertEqual(brief.text, "Hallo")
        XCTAssertEqual(s.ungeoeffnet, 0)
        s.oeffnen(brief)
        XCTAssertEqual(ziel.ops.count, 1, "Absender kann seinen Brief nicht öffnen")

        ich = .annika
        XCTAssertEqual(s.ungeoeffnet, 1)
        s.oeffnen(brief)
        s.oeffnen(brief)
        XCTAssertEqual(ziel.ops.map(\.art), [BriefeLogik.artNeu, BriefeLogik.artGeoeffnet], "zweites Öffnen sendet nichts")
        XCTAssertEqual(s.ungeoeffnet, 0)
    }

    func testBriefNurMitStimmeIstErlaubt() throws {
        let s = BriefeSpeicher(ich: { .ahmed }, senden: { _ in })
        let b = try XCTUnwrap(s.schreiben(titel: "du mich vermisst", text: "", sprache: "m1", dauer: 12, pegel: [0.5]))
        XCTAssertEqual(b.sprache, "m1")
        XCTAssertEqual(b.dauer, 12)
    }

    // MARK: - Sprachpost

    func testSprachpostUngehoertBisAbgespielt() throws {
        let neu = op(SprachpostLogik.artNeu, PostD(id: "p1", medienId: "m1", dauer: 8, pegel: [0.1, 0.9]), von: .ahmed)
        var stand = SprachpostLogik.anwenden([neu])
        XCTAssertEqual(SprachpostLogik.ungehoert(stand, ich: .annika), 1)
        XCTAssertEqual(SprachpostLogik.ungehoert(stand, ich: .ahmed), 0, "eigene Post ist nie ungehört")
        let post = try XCTUnwrap(stand.posten["p1"])
        XCTAssertTrue(SprachpostLogik.istUngehoert(post, stand, ich: .annika))
        stand = SprachpostLogik.anwenden([op(SprachpostLogik.artGehoert, IdD(id: "p1"), von: .annika, nach: 90)], auf: stand)
        XCTAssertFalse(SprachpostLogik.istUngehoert(post, stand, ich: .annika))
        XCTAssertEqual(stand.gehoert["p1"], t0.addingTimeInterval(90))
    }

    func testSprachpostListeNeuesteZuerst() {
        let ops = [
            op(SprachpostLogik.artNeu, PostD(id: "a", medienId: "m", dauer: 3, pegel: []), von: .ahmed, nach: 0),
            op(SprachpostLogik.artNeu, PostD(id: "b", medienId: "m", dauer: 3, pegel: []), von: .ahmed, nach: 50),
        ]
        XCTAssertEqual(SprachpostLogik.liste(SprachpostLogik.anwenden(ops)).map(\.id), ["b", "a"])
    }

    func testSprachpostSpeicherKurzeAufnahmeUndGehoertEinmal() throws {
        final class Ziel { var ops: [Op] = [] }
        let ziel = Ziel()
        var ich = Person.ahmed
        let s = SprachpostSpeicher(ich: { ich }, senden: { ziel.ops.append($0) })
        XCTAssertNil(s.abschicken(medienId: "m", dauer: 0.4, pegel: []), "zu kurz")
        let p = try XCTUnwrap(s.abschicken(medienId: "m", dauer: 5, pegel: [0.3]))
        s.alsGehoert(p)
        XCTAssertEqual(ziel.ops.count, 1, "Absender markiert nichts als gehört")
        ich = .annika
        XCTAssertEqual(s.ungehoert, 1)
        s.alsGehoert(p)
        s.alsGehoert(p)
        XCTAssertEqual(ziel.ops.map(\.art), [SprachpostLogik.artNeu, SprachpostLogik.artGehoert])
        XCTAssertEqual(s.ungehoert, 0)
    }

    func testOpsSurvivenCodableRoundtrip() throws {
        let neu = op(SprachpostLogik.artNeu, PostD(id: "p1", medienId: "m1", dauer: 8, pegel: [0.1]), von: .ahmed)
        let data = try JSONEncoder().encode(neu)
        let zurueck = try JSONDecoder().decode(Op.self, from: data)
        XCTAssertEqual(SprachpostLogik.anwenden([zurueck]).posten["p1"]?.medienId, "m1")
    }
}
