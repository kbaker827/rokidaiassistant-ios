import SwiftUI

struct SttSection: View {
    @EnvironmentObject var vm: PhoneViewModel
    @Binding var isDirty: Bool

    private func bind<V>(_ kp: WritableKeyPath<ApiSettings, V>) -> Binding<V> {
        Binding(
            get: { vm.settingsStore.settings[keyPath: kp] },
            set: { vm.settingsStore.settings[keyPath: kp] = $0; isDirty = true }
        )
    }

    var body: some View {
        Section {
            Picker("STT Provider", selection: bind(\.sttProvider)) {
                ForEach(SttProvider.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }

            LabeledContent("Speech Language") {
                TextField("e.g. en-US, zh-TW", text: bind(\.speechLanguage))
                    .autocapitalization(.none)
                    .multilineTextAlignment(.trailing)
            }

            switch vm.settingsStore.settings.sttProvider {
            case .deepgram:
                apiKeyRow("Deepgram API Key", kp: \.deepgramApiKey)
            case .assemblyai:
                apiKeyRow("AssemblyAI API Key", kp: \.assemblyaiApiKey)
            case .openaiWhisper:
                Text("Uses OpenAI API Key from the API Keys section.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .gemini:
                Text("Uses Gemini API Key from the API Keys section.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .native:
                Text("iOS built-in speech recognition — no API key needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Speech Recognition (STT)")
        }
    }

    @ViewBuilder
    private func apiKeyRow(_ label: String, kp: WritableKeyPath<ApiSettings, String>) -> some View {
        LabeledContent(label) {
            SecureField("API Key", text: bind(kp))
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
        }
    }
}
