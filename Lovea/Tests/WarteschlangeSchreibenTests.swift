import XCTest
@testable import Lovea

/// Audit #7: queue writes are coalesced, but nothing is lost — a flush or the short delay puts
/// every change on disk, in order.
final class WarteschlangeSchreibenTests: XCTestCase {

    private func ordner() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lovea-queue-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func op(_ id: String) -> Op {
        Op(id: id, seq: nil, art: "test.art", von: .ahmed, zeit: Date(), d: Data("{}".utf8))
    }

    func testBurstIsOnDiskAfterSichern() async {
        let dir = ordner()
        let queue = Warteschlange(rootURL: dir)
        for i in 1...20 { await queue.rein(op("op-\(i)")) }
        await queue.raus(id: "op-3")
        await queue.sichern()

        let neu = await Warteschlange(rootURL: dir).offen
        XCTAssertEqual(neu.map(\.id), (1...20).filter { $0 != 3 }.map { "op-\($0)" })
    }

    func testDelayedWriteLandsWithoutSichern() async throws {
        let dir = ordner()
        let queue = Warteschlange(rootURL: dir)
        await queue.rein(op("a"))
        await queue.rein(op("b"))
        try await Task.sleep(for: .seconds(1))

        let neu = await Warteschlange(rootURL: dir).offen
        XCTAssertEqual(neu.map(\.id), ["a", "b"])
    }

    /// A second instance that changed nothing must never overwrite the file with its stale copy.
    func testUnchangedInstanceDoesNotOverwrite() async {
        let dir = ordner()
        let alt = Warteschlange(rootURL: dir)
        _ = await alt.offen
        let queue = Warteschlange(rootURL: dir)
        await queue.rein(op("x"))
        await queue.sichern()
        await alt.sichern()

        let neu = await Warteschlange(rootURL: dir).offen
        XCTAssertEqual(neu.map(\.id), ["x"])
    }
}
