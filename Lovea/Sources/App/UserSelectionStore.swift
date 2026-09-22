import Combine
import Foundation

enum LoveaPerson: String, CaseIterable, Equatable, Sendable {
    case ahmed = "Ahmed"
    case annika = "Annika"

    var partner: LoveaPerson {
        self == .ahmed ? .annika : .ahmed
    }

    var apiID: String {
        switch self {
        case .ahmed: "ahmed"
        case .annika: "annika"
        }
    }
}

@MainActor
final class UserSelectionStore: ObservableObject {
    @Published private(set) var selectedPerson: LoveaPerson?

    func select(_ person: LoveaPerson) {
        selectedPerson = person
    }

    func reset() {
        selectedPerson = nil
    }
}
