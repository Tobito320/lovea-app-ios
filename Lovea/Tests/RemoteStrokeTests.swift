import XCTest
@testable import Lovea

/// Block 12: partner strokes (Z-12.3) and the sharing fold (Z-12.1, Z-12.2).
@MainActor
final class RemoteStrokeTests: XCTestCase {
    // MARK: Z-12.3

    func testRemoteStrokeFromThreePacketsMatchesLocalStroke() async throws {
        var settings = TestGPU.settings(.pencil, size: 14)
        settings.pressureSize = true
        settings.pressureOpacity = true
        settings.stabilizer = 4
        let inputs = TestGPU.line(from: CGPoint(x: 6, y: 10), to: CGPoint(x: 58, y: 50), steps: 30).enumerated().map { index, point in
            StrokeInput(location: point, pressure: 0.3 + Double(index % 7) / 10, altitude: 0.6 + Double(index % 5) / 10)
        }
        let document = TestGPU.document()
        let local = try await TestGPU.engine(document)
        let remote = try await TestGPU.engine(document)
        let layerID = local.activeLayerID
        XCTAssertEqual(layerID, remote.activeLayerID)

        local.beginStroke(inputs[0], settings: settings, layerID: layerID)
        local.continueStroke(Array(inputs.dropFirst()), predicted: [])
        local.endStroke()

        let chunks = [Array(inputs[0..<9]), Array(inputs[9..<20]), Array(inputs[20...])]
        for (index, chunk) in chunks.enumerated() {
            let packet = LiveStrich(
                zeichnungId: document.id.uuidString, strichId: "s1", ebene: layerID, settings: settings, punkte: chunk,
                spiegel: nil, auswahl: false, anfang: index == 0, ende: index == chunks.count - 1
            )
            let received = try JSONDecoder().decode(LiveStrich.self, from: JSONEncoder().encode(packet))
            received.anwenden(auf: remote, autor: "annika")
        }

        let expected = await TestGPU.bytes(local, layerID)
        let actual = await TestGPU.bytes(remote, layerID)
        XCTAssertTrue(expected.contains { $0 != 0 }, "the stroke painted something")
        XCTAssertEqual(actual, expected)
        XCTAssertFalse(remote.hasRemoteStroke("s1"))
        XCTAssertFalse(remote.undo.canUndo, "a partner stroke is no own undo step")
        XCTAssertTrue(local.undo.canUndo)
    }

    func testOwnUndoSkipsPartnerStroke() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        let id = engine.activeLayerID
        let empty = await TestGPU.bytes(engine, id)
        TestGPU.stroke(engine, TestGPU.line(from: CGPoint(x: 4, y: 4), to: CGPoint(x: 30, y: 4)), settings: TestGPU.settings())
        let points = TestGPU.line(from: CGPoint(x: 4, y: 40), to: CGPoint(x: 60, y: 40)).map { StrokeInput(location: $0) }
        engine.remoteBegin(id: "p", layerID: id, settings: TestGPU.settings(color: RGBAColor(red: 0, green: 0, blue: 1)), first: points[0], autor: "annika")
        engine.remoteContinue(id: "p", Array(points.dropFirst()))
        engine.remoteEnd(id: "p")
        engine.performUndo()
        let bytes = await TestGPU.bytes(engine, id)
        XCTAssertEqual(TestGPU.pixel(bytes, width: 64, x: 20, y: 4), TestGPU.pixel(empty, width: 64, x: 20, y: 4), "own stroke undone")
        XCTAssertGreaterThan(TestGPU.pixel(bytes, width: 64, x: 40, y: 40)[3], 0, "partner stroke stays")
        XCTAssertFalse(engine.undo.canUndo)
    }

    func testHex8RoundTrip() {
        let color = RGBAColor(red: 1, green: 0, blue: 0.2, alpha: 0.6)
        let back = RGBAColor(hex8: color.hex8)
        XCTAssertEqual(color.hex8, "#FF003399")
        XCTAssertEqual(back?.blue ?? 0, 0.2, accuracy: 0.5 / 255)
        XCTAssertEqual(back?.alpha ?? 0, 0.6, accuracy: 0.5 / 255)
    }

    // MARK: Fold

    private func op(_ art: String, _ d: some Encodable, von: Person = .ahmed, seq: Int?, id: String = UUID().uuidString) -> Op {
        let neu = Op.neu(art, d, von: von)
        return Op(id: id, seq: seq, art: art, von: von, zeit: neu.zeit, d: neu.d)
    }

    func testProjectLevelKeepsNewestAcrossEcho() {
        var stand = TeilenStand()
        let teilen = op("projekt.teilen", ProjektTeilen(projektId: "p", name: "Urlaub", stufe: .ansehen), seq: nil, id: "a")
        let aus = op("projekt.teilen", ProjektTeilen(projektId: "p", name: "Urlaub", stufe: .aus), seq: nil, id: "b")
        stand.anwenden(teilen)
        stand.anwenden(aus)
        var echo = teilen
        echo.seq = 10
        stand.anwenden(echo)
        XCTAssertEqual(stand.stufe(projekt: "p"), .aus, "late echo of the older op doesn't win")
        var echoAus = aus
        echoAus.seq = 11
        stand.anwenden(echoAus)
        stand.anwenden(op("projekt.teilen", ProjektTeilen(projektId: "p", name: "Urlaub", stufe: .bearbeiten), seq: 12))
        XCTAssertEqual(stand.stufe(projekt: "p"), .bearbeiten)
        XCTAssertEqual(stand.geteilteProjekte(von: .ahmed).map(\.projektId), ["p"])
        XCTAssertTrue(stand.geteilteProjekte(von: .annika).isEmpty)
    }

    func testStandAndOpsAfterBasis() {
        var stand = TeilenStand()
        let fill = ZeichnungAktion.fuellen(x: 1, y: 2, farbe: "#FF0000FF", toleranz: 0.1, alleEbenen: false, ebene: "e")
        stand.anwenden(op("zeichnung.op", ZeichnungOp(zeichnungId: "z", basis: 0, aktion: fill), seq: 5))
        stand.anwenden(op("zeichnung.op", ZeichnungOp(zeichnungId: "z", basis: 5, aktion: .anderes), seq: 8))
        XCTAssertEqual(stand.letzteOpSeq["z"], 8)
        stand.anwenden(op("zeichnung.stand", ZeichnungStand(zeichnungId: "z", medienId: "m", basis: 5, ebenen: [], projektId: "p"), seq: 9))
        XCTAssertEqual(stand.ops(nach: 5, zeichnungId: "z").map(\.seq), [8])
        XCTAssertFalse(stand.sichtbar(stand.staende["z"]!.wert), "project not shared")
        stand.anwenden(op("zeichnung.einladung", ZeichnungEinladung(zeichnungId: "z", name: "Katze"), seq: 10))
        XCTAssertEqual(stand.geteilteStaende(von: .ahmed).map(\.zeichnungId), ["z"])
        let decoded = stand.ops(nach: 0, zeichnungId: "z").first?.daten(ZeichnungOp.self)
        XCTAssertEqual(decoded?.aktion, .anderes)
    }
}
