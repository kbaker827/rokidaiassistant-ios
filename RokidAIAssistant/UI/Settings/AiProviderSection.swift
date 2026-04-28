import SwiftUI

struct AiProviderSection: View {
    @EnvironmentObject var vm: PhoneViewModel
    @Binding var isDirty: Bool

    private var settings: Binding<ApiSettings> {
        Binding(
            get: { vm.settingsStore.settings },
            set: { vm.settingsStore.settings = $0; isDirty = true }
        )
    }

    private var models: [ModelOption] {
        AvailableModels.getModels(for: vm.settingsStore.settings.aiProvider)
    }

    var body: some View {
        Section("AI Provider") {
            Picker("Provider", selection: settings.aiProvider) {
                ForEach(AiProvider.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }

            Picker("Model", selection: settings.aiModelId) {
                ForEach(models) { m in
                    VStack(alignment: .leading) {
                        Text(m.displayName)
                        if !m.description.isEmpty {
                            Text(m.description).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tag(m.id)
                }
            }

            if vm.settingsStore.settings.aiProvider == .custom {
                LabeledContent("Base URL") {
                    TextField("http://localhost:11434/v1/", text: settings.customBaseUrl)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Model Name") {
                    TextField("llama4", text: settings.customModelName)
                        .autocapitalization(.none)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .onChange(of: vm.settingsStore.settings.aiProvider) { _, newProvider in
            let defaultModel = AvailableModels.defaultModel(for: newProvider)
            vm.settingsStore.settings.aiModelId = defaultModel.id
            isDirty = true
        }
    }
}
