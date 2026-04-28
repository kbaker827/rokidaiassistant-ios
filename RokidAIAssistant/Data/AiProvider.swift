import Foundation

enum AiProvider: String, CaseIterable, Identifiable, Codable {
    case gemini
    case openai
    case anthropic
    case deepseek
    case groq
    case xai
    case alibaba
    case zhipu
    case perplexity
    case moonshot
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini:     return "Gemini"
        case .openai:     return "OpenAI"
        case .anthropic:  return "Anthropic"
        case .deepseek:   return "DeepSeek"
        case .groq:       return "Groq"
        case .xai:        return "xAI (Grok)"
        case .alibaba:    return "Alibaba (Qwen)"
        case .zhipu:      return "Zhipu (GLM)"
        case .perplexity: return "Perplexity"
        case .moonshot:   return "Moonshot (Kimi)"
        case .custom:     return "Custom (OpenAI-compatible)"
        }
    }

    var defaultBaseUrl: String {
        switch self {
        case .gemini:     return "https://generativelanguage.googleapis.com/v1beta/"
        case .openai:     return "https://api.openai.com/v1/"
        case .anthropic:  return "https://api.anthropic.com/v1/"
        case .deepseek:   return "https://api.deepseek.com/"
        case .groq:       return "https://api.groq.com/openai/v1/"
        case .xai:        return "https://api.x.ai/v1/"
        case .alibaba:    return "https://dashscope.aliyuncs.com/compatible-mode/v1/"
        case .zhipu:      return "https://api.z.ai/api/paas/v4/"
        case .perplexity: return "https://api.perplexity.ai/"
        case .moonshot:   return "https://api.moonshot.ai/v1/"
        case .custom:     return "http://localhost:11434/v1/"
        }
    }

    var isOpenAiCompatible: Bool {
        switch self {
        case .gemini, .anthropic: return false
        default: return true
        }
    }

    var supportsVision: Bool {
        switch self {
        case .gemini, .openai, .anthropic, .groq, .alibaba, .moonshot: return true
        default: return false
        }
    }
}

struct ModelOption: Identifiable {
    let id: String
    let displayName: String
    let provider: AiProvider
    let supportsAudio: Bool
    let supportsVision: Bool
    let isPreview: Bool
    let description: String

    init(id: String, displayName: String, provider: AiProvider,
         supportsAudio: Bool = false, supportsVision: Bool = false,
         isPreview: Bool = false, description: String = "") {
        self.id = id
        self.displayName = displayName
        self.provider = provider
        self.supportsAudio = supportsAudio
        self.supportsVision = supportsVision
        self.isPreview = isPreview
        self.description = description
    }
}

enum AvailableModels {
    static let geminiModels: [ModelOption] = [
        ModelOption(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro", provider: .gemini, supportsAudio: true, supportsVision: true, description: "Most capable reasoning model"),
        ModelOption(id: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash", provider: .gemini, supportsAudio: true, supportsVision: true, description: "Best price-performance"),
        ModelOption(id: "gemini-2.5-flash-lite", displayName: "Gemini 2.5 Flash-Lite", provider: .gemini, supportsAudio: true, supportsVision: true, description: "Fastest & cheapest"),
    ]

    static let openaiModels: [ModelOption] = [
        ModelOption(id: "gpt-5.1", displayName: "GPT-5.1", provider: .openai, supportsVision: true, description: "Recommended general-purpose"),
        ModelOption(id: "gpt-5-mini", displayName: "GPT-5 Mini", provider: .openai, supportsVision: true, description: "Cost-effective"),
        ModelOption(id: "gpt-4o", displayName: "GPT-4o", provider: .openai, supportsVision: true, description: "Multimodal flagship"),
        ModelOption(id: "gpt-4o-mini", displayName: "GPT-4o Mini", provider: .openai, supportsVision: true, description: "Fast and affordable"),
    ]

    static let anthropicModels: [ModelOption] = [
        ModelOption(id: "claude-opus-4-6", displayName: "Claude Opus 4.6", provider: .anthropic, supportsVision: true, description: "Most intelligent"),
        ModelOption(id: "claude-sonnet-4-6", displayName: "Claude Sonnet 4.6", provider: .anthropic, supportsVision: true, description: "Best speed + intelligence"),
        ModelOption(id: "claude-haiku-4-5-20251001", displayName: "Claude Haiku 4.5", provider: .anthropic, supportsVision: true, description: "Fastest"),
    ]

    static let deepseekModels: [ModelOption] = [
        ModelOption(id: "deepseek-chat", displayName: "DeepSeek Chat", provider: .deepseek, description: "General chat model"),
        ModelOption(id: "deepseek-reasoner", displayName: "DeepSeek Reasoner", provider: .deepseek, description: "Reasoning model"),
    ]

    static let groqModels: [ModelOption] = [
        ModelOption(id: "meta-llama/llama-4-scout-17b-16e-instruct", displayName: "Llama 4 Scout", provider: .groq, supportsVision: true, description: "Fast vision model"),
        ModelOption(id: "llama-3.3-70b-versatile", displayName: "Llama 3.3 70B", provider: .groq, description: "Reliable and powerful"),
        ModelOption(id: "llama-3.1-8b-instant", displayName: "Llama 3.1 8B", provider: .groq, description: "Fast and cheap"),
    ]

    static let xaiModels: [ModelOption] = [
        ModelOption(id: "grok-4.1-fast", displayName: "Grok 4.1 Fast", provider: .xai, description: "Best value"),
        ModelOption(id: "grok-3", displayName: "Grok 3", provider: .xai, description: "Stable general-purpose"),
    ]

    static let alibabaModels: [ModelOption] = [
        ModelOption(id: "qwen3-max", displayName: "Qwen 3 Max", provider: .alibaba, description: "Most powerful"),
        ModelOption(id: "qwen-plus", displayName: "Qwen Plus", provider: .alibaba, description: "Balanced"),
        ModelOption(id: "qwen2.5-vl-72b", displayName: "Qwen 2.5 VL 72B", provider: .alibaba, supportsVision: true, description: "Vision model"),
    ]

    static let zhipuModels: [ModelOption] = [
        ModelOption(id: "glm-4.7", displayName: "GLM-4.7", provider: .zhipu, description: "Zhipu flagship"),
        ModelOption(id: "glm-4-flash", displayName: "GLM-4 Flash", provider: .zhipu, description: "Free/Low-cost"),
    ]

    static let perplexityModels: [ModelOption] = [
        ModelOption(id: "sonar-pro", displayName: "Sonar Pro", provider: .perplexity, description: "Advanced search"),
        ModelOption(id: "sonar", displayName: "Sonar", provider: .perplexity, description: "Lightweight search"),
    ]

    static let moonshotModels: [ModelOption] = [
        ModelOption(id: "kimi-k2.5", displayName: "Kimi K2.5", provider: .moonshot, supportsVision: true, description: "Multimodal"),
        ModelOption(id: "moonshot-v1-32k", displayName: "Moonshot V1 32K", provider: .moonshot, description: "Balanced"),
    ]

    static let customModels: [ModelOption] = [
        ModelOption(id: "custom", displayName: "Custom Model", provider: .custom, description: "User-defined model name"),
    ]

    static func getModels(for provider: AiProvider) -> [ModelOption] {
        switch provider {
        case .gemini:     return geminiModels
        case .openai:     return openaiModels
        case .anthropic:  return anthropicModels
        case .deepseek:   return deepseekModels
        case .groq:       return groqModels
        case .xai:        return xaiModels
        case .alibaba:    return alibabaModels
        case .zhipu:      return zhipuModels
        case .perplexity: return perplexityModels
        case .moonshot:   return moonshotModels
        case .custom:     return customModels
        }
    }

    static func findModel(_ id: String) -> ModelOption? {
        AiProvider.allCases.flatMap { getModels(for: $0) }.first { $0.id == id }
    }

    static func defaultModel(for provider: AiProvider) -> ModelOption {
        getModels(for: provider).first ?? ModelOption(id: "custom", displayName: "Custom", provider: .custom)
    }
}
