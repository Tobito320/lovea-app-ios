import SwiftUI

struct ChatTab: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Chat", systemImage: "bubble.left.and.bubble.right")
                .navigationTitle("Chat")
        }
    }
}

