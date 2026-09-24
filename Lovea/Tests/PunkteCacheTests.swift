import XCTest
@testable import Lovea

/// Audit #3: `PunkteModell` caches its folds, but a change to an observed input (here a chat-streak
/// day in `ChatModell`) must still show up on the very next read.
@MainActor
final class PunkteCacheTests: XCTestCase {

    private func snap(_ von: Person, zeit: String) -> Op {
        let d = #"{"id":"punkte-cache-\#(UUID().uuidString)","snap":{"bleibt":false}}"#
        let datum = ISO8601DateFormatter().date(from: zeit)!
        return Op(id: UUID().uuidString, seq: nil, art: "nachricht.neu", von: von, zeit: datum, d: Data(d.utf8))
    }

    func testCachedStandFollowsAChatStreakDay() {
        let punkte = PunkteModell.shared
        let vorher = punkte.stand
        XCTAssertEqual(punkte.stand, vorher, "a second read without changes must be the same")
        let verlaufVorher = punkte.verlauf.count

        // Both sent a snap on a fixed past day before `chatStreakEnde`: +5 each.
        ChatModell.shared.anwenden([snap(.ahmed, zeit: "2024-02-29T10:00:00Z"), snap(.annika, zeit: "2024-02-29T11:00:00Z")])

        let nachher = punkte.stand
        for person in Person.allCases {
            XCTAssertEqual((nachher[person] ?? 0) - (vorher[person] ?? 0), 5, "\(person)")
        }
        XCTAssertEqual(punkte.verlauf.count, verlaufVorher + Person.allCases.count)
    }
}
