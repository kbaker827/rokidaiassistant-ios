import SwiftUI

struct ConversationBubble: View {
    let item: ConversationItem

    var body: some View {
        HStack {
            if item.isUser { Spacer(minLength: 48) }
            Text(item.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(item.isUser ? Color.blue : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(item.isUser ? .white : .primary)
                .font(.body)
            if !item.isUser { Spacer(minLength: 48) }
        }
    }
}
