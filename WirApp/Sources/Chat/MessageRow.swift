import SwiftUI

struct MessageRow: View {
    let message: ChatMessage
    let isOwnMessage: Bool

    var body: some View {
        HStack {
            if isOwnMessage {
                Spacer(minLength: 44)
            }

            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
                Text(message.body)
                    .font(.body)

                if message.deliveryState == .sending {
                    Text("Wird gesendet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isOwnMessage ? .white : .primary)
            .background(isOwnMessage ? Color.accentColor : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)

            if !isOwnMessage {
                Spacer(minLength: 44)
            }
        }
    }

    private var accessibilityLabel: String {
        switch message.deliveryState {
        case .sending:
            return "\(message.body), wird gesendet"
        case .sent:
            return message.body
        }
    }
}
