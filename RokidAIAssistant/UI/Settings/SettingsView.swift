import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: PhoneViewModel
    @State private var isDirty = false

    var body: some View {
        NavigationView {
            Form {
                AiProviderSection(isDirty: $isDirty)
                ApiKeysSection(isDirty: $isDirty)
                SttSection(isDirty: $isDirty)
                LlmParametersSection(isDirty: $isDirty)
                SystemPromptSection(isDirty: $isDirty)
                GlassesSection()
                AboutSection()
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        vm.applySettings()
                        isDirty = false
                    }
                    .bold()
                    .disabled(!isDirty)
                }
            }
        }
    }
}
