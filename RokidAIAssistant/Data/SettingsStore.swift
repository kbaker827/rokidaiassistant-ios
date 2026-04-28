import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: ApiSettings = ApiSettings()

    private let key = "rokidai_settings_v2"

    init() {
        load()
        if settings.speechLanguage.isEmpty {
            settings.speechLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        }
        if settings.systemPrompt.isEmpty {
            settings.systemPrompt = defaultSystemPrompt()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ApiSettings.self, from: data)
        else { return }
        settings = decoded
    }

    private func defaultSystemPrompt() -> String {
        let lang = Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? "English"
        return "You are a helpful AI assistant. Always respond in \(lang). Provide complete, conversational, and well-formed sentences."
    }
}
