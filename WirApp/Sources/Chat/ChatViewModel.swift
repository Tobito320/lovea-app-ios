import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage]
    @Published var draft: String

    private let currentUserID: String
    private let repository: ChatRepository
    private let now: @Sendable () -> Date

    init(
        currentUserID: String,
        repository: ChatRepository,
        initialMessages: [ChatMessage] = [],
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.currentUserID = currentUserID
        self.repository = repository
        self.messages = initialMessages
        self.draft = ""
        self.now = now
    }

    func load() async {
        do {
            messages = try await repository.messages()
        } catch {
            messages = []
        }
    }

    func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            return
        }

        let pendingMessage = ChatMessage(
            id: UUID(),
            senderID: currentUserID,
            body: body,
            createdAt: now(),
            deliveryState: .sending
        )
        messages.append(pendingMessage)
        draft = ""

        do {
            let sentMessage = try await repository.send(body: body)
            replaceMessage(withID: pendingMessage.id, with: sentMessage)
        } catch {
            replaceMessage(
                withID: pendingMessage.id,
                with: ChatMessage(
                    id: pendingMessage.id,
                    senderID: pendingMessage.senderID,
                    body: pendingMessage.body,
                    createdAt: pendingMessage.createdAt,
                    deliveryState: .sending
                )
            )
        }
    }

    private func replaceMessage(withID id: UUID, with message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else {
            messages.append(message)
            return
        }

        messages[index] = message
    }
}
