import Foundation

final class AnthropicService: BaseAiService, AiServiceProtocol {
    let provider: AiProvider = .anthropic

    private let baseUrl = "https://api.anthropic.com/v1/"
    private let anthropicVersion = "2023-06-01"

    func transcribe(pcmAudioData: Data, languageCode: String) async -> SpeechResult {
        .error("Anthropic does not support speech recognition. Please select Gemini or OpenAI Whisper as STT provider.")
    }

    func chat(userMessage: String) async -> String {
        guard !apiKey.isEmpty else { return "Anthropic API key not configured. Please set up an API key in Settings." }

        var messages: [[String: String]] = conversationHistory.suffix(6).map {
            ["role": $0.role, "content": $0.content]
        }
        messages.append(["role": "user", "content": userMessage])

        let body: [String: Any] = [
            "model": modelId,
            "system": getFullSystemPrompt(),
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": Double(temperature)
        ]

        let result = await withRetry { [self] _ in
            try await self.messagesRequest(body: body)
        }

        if let text = result {
            addToHistory(user: userMessage, assistant: text)
            return text
        }
        return "Sorry, AI service is temporarily unavailable. Please try again later."
    }

    func analyzeImage(imageData: Data, prompt: String) async -> String {
        guard !apiKey.isEmpty else { return "Anthropic API key not configured." }
        let b64 = imageData.base64EncodedString()
        let content: [[String: Any]] = [
            ["type": "image", "source": [
                "type": "base64",
                "media_type": "image/jpeg",
                "data": b64
            ]],
            ["type": "text", "text": prompt]
        ]

        let body: [String: Any] = [
            "model": modelId,
            "system": getFullSystemPrompt(),
            "messages": [["role": "user", "content": content]],
            "max_tokens": min(maxTokens, 4096)
        ]

        let result = await withRetry { [self] _ in
            try await self.messagesRequest(body: body)
        }
        return result ?? "Sorry, unable to analyze this image."
    }

    private func messagesRequest(body: [String: Any]) async throws -> String? {
        let url = URL(string: "\(baseUrl)messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            if code == 429 || code == 529 { throw URLError(.timedOut) }
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
