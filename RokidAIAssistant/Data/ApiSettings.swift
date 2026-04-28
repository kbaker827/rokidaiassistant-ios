import Foundation

struct ApiSettings: Codable {
    // AI provider selection
    var aiProvider: AiProvider = .gemini
    var aiModelId: String = "gemini-2.5-flash"

    // API keys
    var geminiApiKey: String = ""
    var openaiApiKey: String = ""
    var anthropicApiKey: String = ""
    var deepseekApiKey: String = ""
    var groqApiKey: String = ""
    var xaiApiKey: String = ""
    var alibabaApiKey: String = ""
    var zhipuApiKey: String = ""
    var perplexityApiKey: String = ""
    var moonshotApiKey: String = ""
    var customApiKey: String = ""
    var customBaseUrl: String = "http://localhost:11434/v1/"
    var customModelName: String = "llama4"

    // STT
    var sttProvider: SttProvider = .native
    var deepgramApiKey: String = ""
    var assemblyaiApiKey: String = ""
    var speechLanguage: String = ""   // empty = device locale

    // LLM parameters
    var temperature: Float = 0.7
    var maxTokens: Int = 2048
    var topP: Float = 1.0

    // System prompt
    var systemPrompt: String = ""

    // Glasses push
    var pushChatToGlasses: Bool = true
    var pushRecordingToGlasses: Bool = true

    // Auto-analyze recordings
    var autoAnalyzeRecordings: Bool = true

    func getCurrentApiKey() -> String {
        switch aiProvider {
        case .gemini:     return geminiApiKey
        case .openai:     return openaiApiKey
        case .anthropic:  return anthropicApiKey
        case .deepseek:   return deepseekApiKey
        case .groq:       return groqApiKey
        case .xai:        return xaiApiKey
        case .alibaba:    return alibabaApiKey
        case .zhipu:      return zhipuApiKey
        case .perplexity: return perplexityApiKey
        case .moonshot:   return moonshotApiKey
        case .custom:     return customApiKey
        }
    }

    func getCurrentBaseUrl() -> String {
        if aiProvider == .custom { return customBaseUrl.isEmpty ? AiProvider.custom.defaultBaseUrl : customBaseUrl }
        return aiProvider.defaultBaseUrl
    }

    func getCurrentModelId() -> String {
        if aiProvider == .custom { return customModelName.isEmpty ? aiModelId : customModelName }
        return aiModelId
    }

    func isCurrentProviderConfigured() -> Bool {
        if aiProvider == .custom { return !customBaseUrl.isEmpty }
        return !getCurrentApiKey().isEmpty
    }

    func hasAnyApiKeyConfigured() -> Bool {
        !geminiApiKey.isEmpty || !openaiApiKey.isEmpty || !anthropicApiKey.isEmpty ||
        !deepseekApiKey.isEmpty || !groqApiKey.isEmpty || !xaiApiKey.isEmpty ||
        !alibabaApiKey.isEmpty || !zhipuApiKey.isEmpty || !perplexityApiKey.isEmpty ||
        !moonshotApiKey.isEmpty || !customApiKey.isEmpty || !customBaseUrl.isEmpty
    }
}
