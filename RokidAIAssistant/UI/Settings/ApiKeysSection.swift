import SwiftUI

struct ApiKeysSection: View {
    @EnvironmentObject var vm: PhoneViewModel
    @Binding var isDirty: Bool

    private var s: ApiSettings {
        get { vm.settingsStore.settings }
    }

    private func bind<V>(_ kp: WritableKeyPath<ApiSettings, V>) -> Binding<V> {
        Binding(
            get: { vm.settingsStore.settings[keyPath: kp] },
            set: { vm.settingsStore.settings[keyPath: kp] = $0; isDirty = true }
        )
    }

    var body: some View {
        Section("API Keys") {
            apiKeyRow("Gemini", key: bind(\.geminiApiKey))
            apiKeyRow("OpenAI", key: bind(\.openaiApiKey))
            apiKeyRow("Anthropic", key: bind(\.anthropicApiKey))
            apiKeyRow("DeepSeek", key: bind(\.deepseekApiKey))
            apiKeyRow("Groq", key: bind(\.groqApiKey))
            apiKeyRow("xAI (Grok)", key: bind(\.xaiApiKey))
            apiKeyRow("Alibaba (Qwen)", key: bind(\.alibabaApiKey))
            apiKeyRow("Zhipu (GLM)", key: bind(\.zhipuApiKey))
            apiKeyRow("Perplexity", key: bind(\.perplexityApiKey))
            apiKeyRow("Moonshot (Kimi)", key: bind(\.moonshotApiKey))
            apiKeyRow("Custom Provider", key: bind(\.customApiKey))
        }
    }

    @ViewBuilder
    private func apiKeyRow(_ label: String, key: Binding<String>) -> some View {
        LabeledContent(label) {
            SecureField("API Key", text: key)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
        }
    }
}
