import XCTest
@testable import Lovea

@MainActor
final class UserSelectionStoreTests: XCTestCase {
    func testStartsWithoutASelectedPerson() {
        let store = UserSelectionStore()

        XCTAssertNil(store.selectedPerson)
    }

    func testSelectingAhmedStartsTheAppAsAhmed() {
        let store = UserSelectionStore()

        store.select(.ahmed)

        XCTAssertEqual(store.selectedPerson, .ahmed)
    }

    func testResetReturnsToPersonSelection() {
        let store = UserSelectionStore()
        store.select(.annika)

        store.reset()

        XCTAssertNil(store.selectedPerson)
    }
}
