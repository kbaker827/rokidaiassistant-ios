import SwiftUI

struct SystemPromptSection: View {
    @EnvironmentObject var vm: PhoneViewModel
    @Binding var isDirty: Bool

    var body: some View {
        Section("System Prompt") {
            TextEditor(
                text: Binding(
                    get: { vm.settingsStore.settings.systemPrompt },
                    set: { vm.settingsStore.settings.systemPrompt = $0; isDirty = true }
                )
            )
            .frame(minHeight: 100)
            .font(.body)
        }
    }
}
