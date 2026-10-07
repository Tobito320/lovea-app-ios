import XCTest
@testable import Lovea

@MainActor
final class ChatPerfTests: XCTestCase {

    private func trace(_ a: Double, _ b: Double, _ c: Double, n: Int = 10, ok: Bool = true) -> ChatPerfTrace {
        ChatPerfTrace(traceId: UUID().uuidString, conversationId: "paar", zeitpunkt: Date(),
                      tapToRequestStartMs: a, requestToResponseMs: b, responseToRenderMs: c,
                      totalSendToVisibleMs: a + b + c, tapToLocalVisibleMs: nil, success: ok,
                      errorCategory: ok ? nil : "timeout", loadedMessageCount: n, attachmentCount: 0)
    }

    func testPerzentile() {
        let w = (1...100).map(Double.init)
        XCTAssertEqual(ChatPerfStatistik.perzentil(w, 50), 50)
        XCTAssertEqual(ChatPerfStatistik.perzentil(w, 95), 95)
        XCTAssertEqual(ChatPerfStatistik.perzentil([7], 95), 7)
        XCTAssertEqual(ChatPerfStatistik.perzentil([], 50), 0)
    }

    func testSpeicherBegrenzt() {
        var s = ChatPerfSpeicher(limit: 100)
        for i in 0..<130 { s.hinzufuegen(trace(Double(i), 1, 1)) }
        XCTAssertEqual(s.traces.count, 100)
        XCTAssertEqual(s.traces.first?.tapToRequestStartMs, 30)
    }

    func testStatistikMittelwerteUndFehlerIgnoriert() {
        let st = ChatPerfStatistik.berechnen([trace(10, 100, 20), trace(30, 300, 40), trace(0, 9999, 0, ok: false)])
        XCTAssertEqual(st.anzahl, 2)
        XCTAssertEqual(st.durchschnittTapZuRequestMs, 20)
        XCTAssertEqual(st.durchschnittRequestZuAntwortMs, 200)
        XCTAssertEqual(st.durchschnittAntwortZuRenderMs, 30)
        XCTAssertEqual(st.letzteGesamtMs, 370)
    }

    func testEngpassKlassifikation() {
        XCTAssertEqual(ChatPerfEngpass.klassifizieren([trace(1, 1, 1)]), .insufficientData)
        XCTAssertEqual(ChatPerfEngpass.klassifizieren(Array(repeating: trace(400, 50, 50), count: 6)), .clientScheduling)
        XCTAssertEqual(ChatPerfEngpass.klassifizieren(Array(repeating: trace(20, 900, 30), count: 6)), .networkOrBackend)
        XCTAssertEqual(ChatPerfEngpass.klassifizieren(Array(repeating: trace(20, 30, 700), count: 6)), .rendering)
        XCTAssertEqual(ChatPerfEngpass.klassifizieren(Array(repeating: trace(100, 100, 100), count: 6)), .mixed)
        let wachsend = (0..<10).map { trace(10, Double($0 * 30), 10, n: $0 * 100) }
        XCTAssertEqual(ChatPerfEngpass.klassifizieren(wachsend), .scalingWithMessageCount)
    }

    // Fake monotone Uhr: jeder Aufruf springt zu einem vorgegebenen Wert (ms).
    private final class Uhr: @unchecked Sendable {
        var ms: UInt64 = 0
        func jetzt() -> UInt64 { ms * 1_000_000 }
    }

    func testTraceWirdNurEinmalAbgeschlossenUndZeitenStimmen() {
        let uhr = Uhr()
        let perf = ChatPerf(limit: 100, uhr: { uhr.jetzt() })
        uhr.ms = 1000; perf.tippen()
        uhr.ms = 1010; perf.beginn(opId: "op1", messageId: "m1", geladen: 42)
        uhr.ms = 1030; perf.anfrageGestartet(opId: "op1")
        uhr.ms = 1130; perf.antwortErhalten(opId: "op1")
        perf.antwortErhalten(opId: "op1") // Redelivery darf nichts ändern
        uhr.ms = 1150; perf.gerendert()
        uhr.ms = 1200; perf.gerendert() // zweiter Aufruf: kein zweiter Trace
        XCTAssertEqual(perf.traces.count, 1)
        let t = perf.traces[0]
        XCTAssertEqual(t.tapToRequestStartMs, 30)
        XCTAssertEqual(t.requestToResponseMs, 100)
        XCTAssertEqual(t.responseToRenderMs, 20)
        XCTAssertEqual(t.totalSendToVisibleMs, 150)
        XCTAssertEqual(t.loadedMessageCount, 42)
        XCTAssertTrue(t.success)
    }

    func testOhneAntwortKeinTraceUndTimeoutAlsFehler() {
        let uhr = Uhr()
        let perf = ChatPerf(limit: 100, uhr: { uhr.jetzt() })
        uhr.ms = 0; perf.beginn(opId: "a", messageId: "ma", geladen: 1)
        perf.gerendert()
        XCTAssertTrue(perf.traces.isEmpty)
        uhr.ms = 31_000; perf.beginn(opId: "b", messageId: "mb", geladen: 1)
        XCTAssertEqual(perf.traces.count, 1)
        XCTAssertEqual(perf.traces[0].errorCategory, "timeout")
        XCTAssertFalse(perf.traces[0].success)
    }

    func testTraceCodableEnthaeltKeinenText() throws {
        let data = try JSONEncoder().encode(trace(1, 2, 3))
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("text"))
        XCTAssertEqual(try JSONDecoder().decode(ChatPerfTrace.self, from: data).totalSendToVisibleMs, 6)
    }
}
