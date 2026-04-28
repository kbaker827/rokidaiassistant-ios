import Foundation

enum AiServiceFactory {
    static func create(settings: ApiSettings) -> AiServiceProtocol {
        let provider = settings.aiProvider
        let apiKey = settings.getCurrentApiKey()
        let modelId = settings.getCurrentModelId()
        let baseUrl = settings.getCurrentBaseUrl()
        let systemPrompt = settings.systemPrompt
        let temp = settings.temperature
        let maxTok = settings.maxTokens
        let topP = settings.topP

        switch provider {
        case .gemini:
            return GeminiService(apiKey: apiKey, modelId: modelId, systemPrompt: systemPrompt,
                                 temperature: temp, maxTokens: maxTok, topP: topP)
        case .anthropic:
            return AnthropicService(apiKey: apiKey, modelId: modelId, systemPrompt: systemPrompt,
                                    temperature: temp, maxTokens: maxTok, topP: topP)
        default:
            return OpenAiCompatibleService(
                provider: provider, apiKey: apiKey, modelId: modelId, baseUrl: baseUrl,
                systemPrompt: systemPrompt, temperature: temp, maxTokens: maxTok, topP: topP)
        }
    }
}
