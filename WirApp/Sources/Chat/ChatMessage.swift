import Foundation

struct ChatMessage: Identifiable, Equatable, Sendable {
    enum DeliveryState: Equatable, Sendable {
        case sending
        case sent
    }

    let id: UUID
    let senderID: String
    let body: String
    let createdAt: Date
    let deliveryState: DeliveryState
}
