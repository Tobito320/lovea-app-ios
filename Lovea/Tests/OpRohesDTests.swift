import XCTest
@testable import Lovea

/// Audit #1: `d` sliced from the raw line must decode to the same JSON as the old `JSONValue` path.
@MainActor
final class OpRohesDTests: XCTestCase {

    private let zeit = "2026-09-23T14:02:11.123Z"

    private func zeilen() -> [String] {
        [
            #"{"d":{"text":"hi"},"id":"a","art":"x","von":"ahmed","zeit":"\#(zeit)"}"#,
            #"{"id":"b","d":{"d":{"d":1},"x":[1,2,{"d":"}"}]},"art":"x","von":"annika","zeit":"\#(zeit)","seq":5}"#,
            #"{"id":"c","art":"x","von":"ahmed","zeit":"\#(zeit)","d":{"text":"a\"b\\c\/d {x}, [y]","url":"https:\/\/x.de\/a"}}"#,
            #"{"id":"s","art":"x","von":"ahmed","zeit":"\#(zeit)","d":"nur, \"text\" }"}"#,
            #"{"id":"n","art":"x","von":"ahmed","zeit":"\#(zeit)","d":42.5,"seq":1}"#,
            #"{"id":"l","art":"x","von":"ahmed","zeit":"\#(zeit)","d":[1,"a",null,{"d":[]}]}"#,
            #"{"id":"0","art":"x","von":"ahmed","zeit":"\#(zeit)","d":null}"#,
            #"{"id":"e","art":"x","von":"ahmed","zeit":"\#(zeit)","d":{}}"#,
            #"{ "id" : "w", "d" :  { "a" : true }  , "art":"x", "von":"ahmed", "zeit":"\#(zeit)" }"#,
            #"{"art":"d","id":"v","von":"ahmed","zeit":"\#(zeit)","d":{"k":"d"}}"#,
        ]
    }

    private func schnell(_ zeile: String) throws -> Op {
        let daten = Data(zeile.utf8)
        let decoder = JSONDecoder()
        decoder.userInfo[Op.zeileSchluessel] = daten
        return try decoder.decode(Op.self, from: daten)
    }

    private func json(_ daten: Data) -> NSObject? {
        try? JSONSerialization.jsonObject(with: daten, options: .fragmentsAllowed) as? NSObject
    }

    func testRawSliceMatchesTheJSONValuePath() throws {
        for zeile in zeilen() {
            XCTAssertNotNil(Op.rohesD(Data(zeile.utf8)), "fast path not taken for \(zeile)")
            let roh = try schnell(zeile)
            let alt = try JSONDecoder().decode(Op.self, from: Data(zeile.utf8))
            XCTAssertEqual(roh.id, alt.id)
            XCTAssertEqual(roh.seq, alt.seq)
            XCTAssertEqual(roh.art, alt.art)
            XCTAssertEqual(roh.von, alt.von)
            XCTAssertEqual(roh.zeit, alt.zeit)
            XCTAssertNotNil(json(roh.d), "invalid JSON slice for \(zeile)")
            XCTAssertEqual(json(roh.d), json(alt.d), zeile)
        }
    }

    func testNestedDAndEscapesSliceExactly() {
        let zeile = #"{"id":"b","d":{"d":{"d":1},"t":"a\"}"},"art":"x"}"#
        XCTAssertEqual(Op.rohesD(Data(zeile.utf8)).map { String(decoding: $0, as: UTF8.self) }, #"{"d":{"d":1},"t":"a\"}"}"#)
        XCTAssertNil(Op.rohesD(Data(#"{"id":"x","art":"d"}"#.utf8)))
    }

    func testMissingDStillThrows() {
        XCTAssertThrowsError(try schnell(#"{"id":"m","art":"x","von":"ahmed","zeit":"\#(zeit)"}"#))
    }

    func testOpRoundTripsThroughTheFastPath() throws {
        struct Payload: Codable, Equatable { let text: String; let zahl: Int; let liste: [String] }
        let payload = Payload(text: "a/b \"c\"", zahl: 7, liste: ["x", "}"])
        var op = Op.neu("nachricht.neu", payload, von: .annika)
        op.seq = 9
        let erste = try JSONEncoder().encode(op)
        let zurueck = try schnell(String(decoding: erste, as: UTF8.self))
        XCTAssertEqual(zurueck.daten(Payload.self), payload)
        XCTAssertEqual(zurueck.seq, 9)
        XCTAssertEqual(json(try JSONEncoder().encode(zurueck)), json(erste))
    }

    /// Lines the old app wrote (JSONEncoder output: `\/` escapes, `d` nested) still load and decode.
    func testOldOpsJsonlStillLoads() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("lovea-oprohesd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let text = [
            #"{"id":"alt-1","seq":1,"art":"nachricht.neu","von":"ahmed","zeit":"2026-09-01T10:00:00.000Z","d":{"id":"n1","text":"https:\/\/a.de\/b \"zitat\""}}"#,
            #"{"id":"alt-2","seq":2,"art":"nachricht.neu","von":"annika","zeit":"2026-09-01T10:00:01Z","d":{"text":"zwei","id":"n2"}}"#,
        ].joined(separator: "\n") + "\n"
        try Data(text.utf8).write(to: dir.appendingPathComponent("ops.jsonl"))

        struct Payload: Decodable, Equatable { let id: String; let text: String }
        let ops = await OpLog(rootURL: dir).alle()
        XCTAssertEqual(ops.map(\.id), ["alt-1", "alt-2"])
        XCTAssertEqual(ops[0].daten(Payload.self), Payload(id: "n1", text: "https://a.de/b \"zitat\""))
        XCTAssertEqual(ops[1].daten(Payload.self), Payload(id: "n2", text: "zwei"))
    }
}
