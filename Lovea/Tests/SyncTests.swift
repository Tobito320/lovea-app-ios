import XCTest
@testable import Lovea

@MainActor
final class SyncTests: XCTestCase {

    // MARK: - Op (Z-2.1)

    func testOpRoundTripsIncludingPayload() {
        struct Payload: Codable, Equatable { let text: String; let zahl: Int }
        let payload = Payload(text: "hallo", zahl: 7)
        var op = Op.neu("nachricht.neu", payload, von: .ahmed)
        op.seq = 42

        let encoded = try! JSONEncoder().encode(op)
        let decoded = try! JSONDecoder().decode(Op.self, from: encoded)

        XCTAssertEqual(decoded.id, op.id)
        XCTAssertEqual(decoded.seq, 42)
        XCTAssertEqual(decoded.art, "nachricht.neu")
        XCTAssertEqual(decoded.von, .ahmed)
        XCTAssertEqual(decoded.daten(Payload.self), payload)
        XCTAssertEqual(decoded.zeit.timeIntervalSince1970, op.zeit.timeIntervalSince1970, accuracy: 0.001)
    }

    func testOpDecodesServerMessageWithFractionalSeconds() {
        let json = """
        {"seq":42,"id":"abc","art":"nachricht.neu","von":"annika","zeit":"2026-09-23T14:02:11.123Z","d":{"text":"hi"}}
        """
        let op = try! JSONDecoder().decode(Op.self, from: Data(json.utf8))
        struct Payload: Decodable { let text: String }

        XCTAssertEqual(op.seq, 42)
        XCTAssertEqual(op.von, .annika)
        XCTAssertEqual(op.daten(Payload.self)?.text, "hi")
    }

    // MARK: - OpLog (Z-2.1)

    func testOpLogOrdersBySeqAndDedupesAcrossReload() async {
        let dir = makeTempDirectory()
        let ops = [testOp(seq: 3), testOp(seq: 1), testOp(seq: 2)]
        let log = OpLog(rootURL: dir)
        await log.anhaengen(ops)

        let loaded = await log.alle(arten: [])
        XCTAssertEqual(loaded.map(\.seq), [1, 2, 3])

        // Fresh instance, same directory: reload plus a duplicate must not double-write.
        let reloadedLog = OpLog(rootURL: dir)
        await reloadedLog.anhaengen([ops[0]])
        let afterDuplicate = await reloadedLog.alle(arten: [])

        XCTAssertEqual(afterDuplicate.count, 3)
        let latestSeq = await reloadedLog.letzteSeq
        XCTAssertEqual(latestSeq, 3)
    }

    // MARK: - Warteschlange + Raum: offline, restart, echo (Z-2.3, Review-Fokus 1)

    func testOfflineQueueSurvivesRestartAndDuplicateEchoIsIdempotent() async {
        let dir = makeTempDirectory()
        let server = URL(string: "https://sync.example.com")!

        // Offline: three sends while the transport was never asked to connect.
        let offlineTransport = FakeTransport()
        let offlineRaum = Raum(
            transport: offlineTransport,
            log: OpLog(rootURL: dir),
            warteschlange: Warteschlange(rootURL: dir),
            server: server,
            schluessel: "schluessel"
        )
        offlineRaum.ich = .ahmed
        offlineRaum.senden("nachricht.neu", ["text": "eins"])
        offlineRaum.senden("nachricht.neu", ["text": "zwei"])
        offlineRaum.senden("nachricht.neu", ["text": "drei"])
        await offlineRaum.leer()
        XCTAssertEqual(offlineTransport.sent.count, 0, "nothing should be sent while never connected")
        XCTAssertEqual(offlineRaum.wartet, 3, "the status line needs this to show \"Wartet auf Netz (3)\"")

        // "Restart": a fresh queue instance over the same directory still has all three.
        let reopenedQueue = Warteschlange(rootURL: dir)
        let queuedAfterRestart = await reopenedQueue.offen
        XCTAssertEqual(queuedAfterRestart.count, 3)

        // Reconnect: the queued ops go out immediately.
        let onlineTransport = FakeTransport()
        let log = OpLog(rootURL: dir)
        let onlineRaum = Raum(
            transport: onlineTransport,
            log: log,
            warteschlange: reopenedQueue,
            server: server,
            schluessel: "schluessel"
        )
        onlineRaum.ich = .ahmed
        onlineRaum.start()
        await onlineRaum.leer()
        XCTAssertEqual(onlineRaum.wartet, 3, "status line must still show 3 right after reconnecting, before any echo")

        let sentOpMessages = onlineTransport.sent.filter { $0.contains("\"t\":\"op\"") }
        XCTAssertEqual(sentOpMessages.count, 3)

        // Server confirms all three in one batch.
        let confirmed = zip(queuedAfterRestart.map(\.id), [1, 2, 3]).map { (id: $0, seq: $1) }
        let echo = makeOpsMessage(ops: confirmed, mehr: false)
        await onlineTransport.receive(echo)

        let queueAfterEcho = await reopenedQueue.offen
        XCTAssertTrue(queueAfterEcho.isEmpty)
        let logAfterEcho = await log.alle(arten: [])
        XCTAssertEqual(logAfterEcho.count, 3)
        XCTAssertEqual(onlineRaum.wartet, 0, "status line must clear once all three are confirmed")

        // A duplicate echo (repeated after a bad connection) changes nothing.
        await onlineTransport.receive(echo)
        let queueAfterDuplicate = await reopenedQueue.offen
        XCTAssertTrue(queueAfterDuplicate.isEmpty)
        let logAfterDuplicate = await log.alle(arten: [])
        XCTAssertEqual(logAfterDuplicate.count, 3)
    }

    // MARK: - Paging (Z-2.2, Review-Fokus 3)

    func testPagingDeliversThreeBatchesForTwelveHundredOps() async {
        let dir = makeTempDirectory()
        let transport = FakeTransport()
        let raum = Raum(
            transport: transport,
            log: OpLog(rootURL: dir),
            warteschlange: Warteschlange(rootURL: dir),
            server: URL(string: "https://sync.example.com")!,
            schluessel: "schluessel"
        )
        raum.ich = .ahmed
        var receivedBatches: [[Op]] = []
        raum.beobachtenStapel([]) { receivedBatches.append($0) }

        raum.start()
        await raum.leer()

        await transport.receive(makeOpsMessage(ops: (1...500).map { (id: "op-\($0)", seq: $0) }, mehr: true))
        await transport.receive(makeOpsMessage(ops: (501...1000).map { (id: "op-\($0)", seq: $0) }, mehr: true))
        await transport.receive(makeOpsMessage(ops: (1001...1200).map { (id: "op-\($0)", seq: $0) }, mehr: false))

        XCTAssertEqual(receivedBatches.map(\.count), [500, 500, 200])
        XCTAssertEqual(receivedBatches.flatMap { $0 }.count, 1200)
        let nachholenRequests = transport.sent.filter { $0.contains("\"nachholen\"") }
        XCTAssertEqual(nachholenRequests.count, 2)
    }

    // MARK: - Medien (Z-2.4, Review-Fokus 5)

    func testFehlendePlanKeepsOnlyValidPartsSortedAndDeduped() {
        XCTAssertEqual(Medien.fehlendePlan(gesamt: 5, fehlend: [4, 2, 2, 10, -1]), [2, 4])
        XCTAssertEqual(Medien.fehlendePlan(gesamt: 3, fehlend: []), [])
        XCTAssertEqual(Medien.fehlendePlan(gesamt: 3, fehlend: [0, 1, 2]), [0, 1, 2])
    }

    // MARK: - Helpers

    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lovea-sync-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func testOp(seq: Int) -> Op {
        Op(id: UUID().uuidString, seq: seq, art: "test.art", von: .ahmed, zeit: Date(), d: Data("{}".utf8))
    }

    private func makeOpsMessage(ops: [(id: String, seq: Int)], mehr: Bool) -> String {
        let entries = ops.map {
            "{\"seq\":\($0.seq),\"id\":\"\($0.id)\",\"art\":\"test.art\",\"von\":\"annika\",\"zeit\":\"2026-09-23T12:00:00.000Z\",\"d\":{}}"
        }
        return "{\"t\":\"ops\",\"ops\":[\(entries.joined(separator: ","))],\"mehr\":\(mehr)}"
    }
}

/// Fake `RaumTransport`: records everything sent, and exposes `receive` to simulate a server
/// message by calling the closure `Raum` handed to `verbinden`.
private final class FakeTransport: RaumTransport, @unchecked Sendable {
    private(set) var sent: [String] = []
    private var onMessage: (@Sendable (String) async -> Void)?
    private var onDisconnect: (@Sendable (Error?) async -> Void)?

    func verbinden(
        url: URL,
        headers: [String: String],
        nachricht: @escaping @Sendable (String) async -> Void,
        getrennt: @escaping @Sendable (Error?) async -> Void
    ) {
        onMessage = nachricht
        onDisconnect = getrennt
    }

    func senden(_ text: String) {
        sent.append(text)
    }

    func trennen() {
        onMessage = nil
        onDisconnect = nil
    }

    func receive(_ text: String) async {
        await onMessage?(text)
    }
}
