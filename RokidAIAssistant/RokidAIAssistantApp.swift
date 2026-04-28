import SwiftUI
import SwiftData

@main
struct RokidAIAssistantApp: App {
    @StateObject private var viewModel = PhoneViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .modelContainer(for: [ConversationEntry.self, RecordingEntry.self]) { result in
                    if case .success(let container) = result {
                        Task { @MainActor in
                            viewModel.modelContext = container.mainContext
                        }
                    }
                }
        }
    }
}
