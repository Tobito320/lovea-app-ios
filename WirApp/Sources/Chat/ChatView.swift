import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    let currentUserID: String

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.messages) { message in
                        MessageRow(
                            message: message,
                            isOwnMessage: message.senderID == currentUserID
                        )
                    }
                }
                .padding()
            }

            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Nachricht", text: $viewModel.draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    Task {
                        await viewModel.send()
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Nachricht senden")
            }
            .padding()
            .background(.background)
        }
        .task {
            await viewModel.load()
        }
    }
}
