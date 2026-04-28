import SwiftUI

struct LlmParametersSection: View {
    @EnvironmentObject var vm: PhoneViewModel
    @Binding var isDirty: Bool

    private func bind<V>(_ kp: WritableKeyPath<ApiSettings, V>) -> Binding<V> {
        Binding(
            get: { vm.settingsStore.settings[keyPath: kp] },
            set: { vm.settingsStore.settings[keyPath: kp] = $0; isDirty = true }
        )
    }

    var body: some View {
        Section("LLM Parameters") {
            VStack(alignment: .leading) {
                HStack {
                    Text("Temperature")
                    Spacer()
                    Text(String(format: "%.2f", vm.settingsStore.settings.temperature))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: bind(\.temperature), in: 0...2, step: 0.05)
            }

            VStack(alignment: .leading) {
                HStack {
                    Text("Max Tokens")
                    Spacer()
                    Text("\(vm.settingsStore.settings.maxTokens)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { Double(vm.settingsStore.settings.maxTokens) },
                        set: { vm.settingsStore.settings.maxTokens = Int($0); isDirty = true }
                    ),
                    in: 256...8192, step: 256
                )
            }

            VStack(alignment: .leading) {
                HStack {
                    Text("Top P")
                    Spacer()
                    Text(String(format: "%.2f", vm.settingsStore.settings.topP))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: bind(\.topP), in: 0...1, step: 0.05)
            }

            Toggle("Auto-Analyze Recordings", isOn: bind(\.autoAnalyzeRecordings))
            Toggle("Push Chat to Glasses", isOn: bind(\.pushChatToGlasses))
            Toggle("Push Recordings to Glasses", isOn: bind(\.pushRecordingToGlasses))
        }
    }
}
