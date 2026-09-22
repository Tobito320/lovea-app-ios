import XCTest
@testable import WirApp

@MainActor
final class ChatViewModelTests: XCTestCase {
    func testSendTrimsWhitespaceAndTurnsMessageSentAfterRepositorySuccess() async throws {
        let repository = InMemoryChatRepository(
            currentUserID: "ahmed",
            now: { Date(timeIntervalSince1970: 10) }
        )
        let viewModel = ChatViewModel(
            currentUserID: "ahmed",
            repository: repository,
            now: { Date(timeIntervalSince1970: 5) }
        )

        viewModel.draft = "  Hallo Annika  "

        await viewModel.send()

        XCTAssertEqual(viewModel.draft, "")
        XCTAssertEqual(viewModel.messages, [
            ChatMessage(
                id: viewModel.messages[0].id,
                senderID: "ahmed",
                body: "Hallo Annika",
                createdAt: Date(timeIntervalSince1970: 10),
                deliveryState: .sent
            )
        ])
    }

    func testSendRejectsEmptyDraft() async {
        let repository = InMemoryChatRepository(currentUserID: "ahmed")
        let viewModel = ChatViewModel(currentUserID: "ahmed", repository: repository)

        viewModel.draft = "   "

        await viewModel.send()

        XCTAssertEqual(viewModel.draft, "   ")
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testSendShowsSendingMessageBeforeRepositoryReturns() async {
        let repository = ControlledChatRepository()
        let viewModel = ChatViewModel(
            currentUserID: "ahmed",
            repository: repository,
            now: { Date(timeIntervalSince1970: 20) }
        )

        viewModel.draft = "Hallo"

        let sendTask = Task {
            await viewModel.send()
        }

        await repository.waitForSend()

        XCTAssertEqual(viewModel.messages, [
            ChatMessage(
                id: viewModel.messages[0].id,
                senderID: "ahmed",
                body: "Hallo",
                createdAt: Date(timeIntervalSince1970: 20),
                deliveryState: .sending
            )
        ])

        await repository.succeed(
            with: ChatMessage(
                id: UUID(),
                senderID: "ahmed",
                body: "Hallo",
                createdAt: Date(timeIntervalSince1970: 25),
                deliveryState: .sent
            )
        )
        await sendTask.value

        XCTAssertEqual(viewModel.messages.first?.deliveryState, .sent)
    }
}

private actor ControlledChatRepository: ChatRepository {
    private var sendContinuation: CheckedContinuation<ChatMessage, Error>?
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func messages() async throws -> [ChatMessage] {
        []
    }

    func send(body: String) async throws -> ChatMessage {
        waiters.forEach { $0.resume() }
        waiters.removeAll()

        return try await withCheckedThrowingContinuation { continuation in
            sendContinuation = continuation
        }
    }

    func waitForSend() async {
        if sendContinuation != nil {
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func succeed(with message: ChatMessage) {
        sendContinuation?.resume(returning: message)
        sendContinuation = nil
    }
}
