import SwiftUI
import SwiftData

struct ChatView: View {
    @EnvironmentObject var vm: PhoneViewModel
    @Query(sort: \ConversationEntry.timestamp) private var history: [ConversationEntry]

    @State private var inputText = ""
    @State private var showHistory = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current session messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if vm.conversations.isEmpty {
                                emptyState
                            } else {
                                ForEach(vm.conversations) { item in
                                    ConversationBubble(item: item)
                                        .padding(.horizontal)
                                        .id(item.id)
                                }
                            }

                            if let status = vm.processingStatus {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text(status)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("status")
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: vm.conversations.count) { _, _ in
                        if let last = vm.conversations.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: vm.processingStatus) { _, s in
                        if s != nil { withAnimation { proxy.scrollTo("status", anchor: .bottom) } }
                    }
                }

                Divider()

                // Input bar
                HStack(spacing: 10) {
                    TextField("Type a message…", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...5)
                        .focused($inputFocused)

                    Button {
                        let msg = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !msg.isEmpty else { return }
                        inputText = ""
                        vm.sendTextMessage(msg)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .blue)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.regularMaterial)
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("History") { showHistory = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { vm.clearConversations() }
                        .disabled(vm.conversations.isEmpty)
                }
            }
            .sheet(isPresented: $showHistory) {
                ConversationHistoryView(history: history)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No messages yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Type a message or speak to your Rokid glasses to start a conversation.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }
}

// MARK: - History sheet

private struct ConversationHistoryView: View {
    let history: [ConversationEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                if history.isEmpty {
                    ContentUnavailableView("No History", systemImage: "clock",
                        description: Text("Past conversations will appear here."))
                } else {
                    ForEach(history) { entry in
                        VStack(alignment: entry.role == "user" ? .trailing : .leading, spacing: 4) {
                            HStack {
                                if entry.role == "user" { Spacer() }
                                Text(entry.role == "user" ? "You" : "Assistant")
                                    .font(.caption).bold()
                                    .foregroundStyle(entry.role == "user" ? .blue : .secondary)
                                if entry.role != "user" { Spacer() }
                            }
                            HStack {
                                if entry.role == "user" { Spacer() }
                                Text(entry.content)
                                    .font(.subheadline)
                                    .padding(10)
                                    .background(entry.role == "user" ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground),
                                                in: RoundedRectangle(cornerRadius: 12))
                                if entry.role != "user" { Spacer() }
                            }
                            Text(entry.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
