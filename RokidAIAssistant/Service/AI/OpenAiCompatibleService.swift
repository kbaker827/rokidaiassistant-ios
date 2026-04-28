import Foundation

/// Handles OpenAI and all OpenAI-compatible providers (DeepSeek, Groq, xAI, Alibaba, Zhipu, Perplexity, Moonshot, Custom).
final class OpenAiCompatibleService: BaseAiService, AiServiceProtocol {
    let provider: AiProvider
    private let baseUrl: String

    init(provider: AiProvider, apiKey: String, modelId: String, baseUrl: String,
         systemPrompt: String, temperature: Float, maxTokens: Int, topP: Float) {
        self.provider = provider
        self.baseUrl = baseUrl.hasSuffix("/") ? baseUrl : baseUrl + "/"
        super.init(apiKey: apiKey, modelId: modelId, systemPrompt: systemPrompt,
                   temperature: temperature, maxTokens: maxTokens, topP: topP)
    }

    func transcribe(pcmAudioData: Data, languageCode: String) async -> SpeechResult {
        guard provider == .openai || provider == .groq else {
            return .error("This provider does not support speech recognition. Please use Gemini or OpenAI Whisper.")
        }
        return await whisperTranscribe(data: pcmToWav(pcmAudioData), mimeType: "audio/wav",
                                       filename: "audio.wav", language: languageCode)
    }

    func transcribeAudioFile(audioData: Data, mimeType: String, languageCode: String) async -> SpeechResult {
        guard provider == .openai || provider == .groq else {
            return .error("This provider does not support speech recognition.")
        }
        let ext = mimeType.hasSuffix("mp4") || mimeType.hasSuffix("aac") ? "m4a" :
                  mimeType.hasSuffix("mp3") ? "mp3" : "wav"
        return await whisperTranscribe(data: audioData, mimeType: mimeType,
                                       filename: "audio.\(ext)", language: languageCode)
    }

    private func whisperTranscribe(data: Data, mimeType: String, filename: String, language: String) async -> SpeechResult {
        guard !apiKey.isEmpty else { return .error("API key not configured") }
        let url = URL(string: "\(baseUrl)audio/transcriptions")!

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func append(_ s: String) { if let d = s.data(using: .utf8) { body.append(d) } }

        // model field
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\n")
        append("whisper-large-v3\r\n")

        // language field
        let langCode = language.components(separatedBy: "-").first ?? language
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"language\"\r\n\r\n")
        append("\(langCode)\r\n")

        // file field
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = body

        do {
            let (respData, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return .error("Whisper API error") }
            if let json = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let text = json["text"] as? String, !text.isEmpty {
                return .success(text)
            }
            return .error("Unable to recognize speech")
        } catch {
            return .error(error.localizedDescription)
        }
    }

    // MARK: Chat

    func chat(userMessage: String) async -> String {
        guard !apiKey.isEmpty || provider == .custom else {
            return "API key not configured. Please set up an API key in Settings."
        }

        var messages: [[String: String]] = [["role": "system", "content": getFullSystemPrompt()]]
        for pair in conversationHistory.suffix(6) {
            messages.append(["role": pair.role, "content": pair.content])
        }
        messages.append(["role": "user", "content": userMessage])

        let body: [String: Any] = [
            "model": modelId,
            "messages": messages,
            "temperature": Double(temperature),
            "max_tokens": maxTokens,
            "top_p": Double(topP)
        ]

        let result = await withRetry { [self] _ in
            try await self.chatRequest(body: body)
        }

        if let text = result {
            addToHistory(user: userMessage, assistant: text)
            return text
        }
        return "Sorry, AI service is temporarily unavailable. Please try again later."
    }

    // MARK: Image analysis

    func analyzeImage(imageData: Data, prompt: String) async -> String {
        guard provider.supportsVision else {
            return "This provider does not support image analysis. Please use Gemini, OpenAI, or Anthropic."
        }
        guard !apiKey.isEmpty else { return "API key not configured." }

        let b64 = imageData.base64EncodedString()
        let content: [[String: Any]] = [
            ["type": "text", "text": prompt],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]]
        ]
        let body: [String: Any] = [
            "model": modelId,
            "messages": [
                ["role": "system", "content": getFullSystemPrompt()],
                ["role": "user", "content": content]
            ],
            "max_tokens": min(maxTokens, 4096)
        ]

        let result = await withRetry { [self] _ in
            try await self.chatRequest(body: body)
        }
        return result ?? "Sorry, unable to analyze this image."
    }

    // MARK: HTTP helper

    private func chatRequest(body: [String: Any]) async throws -> String? {
        let url = URL(string: "\(baseUrl)chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            if code == 429 || code == 503 { throw URLError(.timedOut) }
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
