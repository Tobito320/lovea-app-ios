import Foundation

actor InMemoryChatRepository: ChatRepository {
    private let currentUserID: String
    private let now: @Sendable () -> Date
    private var storedMessages: [ChatMessage]

    init(
        currentUserID: String,
        initialMessages: [ChatMessage] = [],
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.currentUserID = currentUserID
        self.storedMessages = initialMessages
        self.now = now
    }

    func messages() async throws -> [ChatMessage] {
        storedMessages.sorted { $0.createdAt < $1.createdAt }
    }

    func send(body: String) async throws -> ChatMessage {
        let message = ChatMessage(
            id: UUID(),
            senderID: currentUserID,
            body: body,
            createdAt: now(),
            deliveryState: .sent
        )
        storedMessages.append(message)
        return message
    }
}
