import SwiftUI

struct AppRootView: View {
    @StateObject private var viewModel: ChatViewModel

    init() {
        let repository = InMemoryChatRepository(
            currentUserID: "ahmed",
            initialMessages: [
                ChatMessage(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    senderID: "annika",
                    body: "Testchat ist bereit.",
                    createdAt: Date(timeIntervalSince1970: 1),
                    deliveryState: .sent
                )
            ]
        )
        _viewModel = StateObject(
            wrappedValue: ChatViewModel(
                currentUserID: "ahmed",
                repository: repository
            )
        )
    }

    var body: some View {
        NavigationStack {
            ChatView(viewModel: viewModel, currentUserID: "ahmed")
                .navigationTitle(AppConfiguration.title)
        }
    }
}
