import Foundation

final class GeminiService: BaseAiService, AiServiceProtocol {
    let provider: AiProvider = .gemini

    private let baseUrl = "https://generativelanguage.googleapis.com/v1beta/models"

    private var generateUrl: URL {
        URL(string: "\(baseUrl)/\(modelId):generateContent?key=\(apiKey)")!
    }

    // MARK: Transcribe PCM audio

    func transcribe(pcmAudioData: Data, languageCode: String) async -> SpeechResult {
        guard !apiKey.isEmpty else { return .error("Gemini API key not configured") }
        guard pcmAudioData.count >= 1000 else { return .error("Audio too short") }

        let wavData = pcmToWav(pcmAudioData)
        return await transcribeData(wavData, mimeType: "audio/wav", languageCode: languageCode)
    }

    func transcribeAudioFile(audioData: Data, mimeType: String, languageCode: String) async -> SpeechResult {
        guard !apiKey.isEmpty else { return .error("Gemini API key not configured") }
        guard audioData.count >= 1000 else { return .error("Audio too short") }
        return await transcribeData(audioData, mimeType: mimeType, languageCode: languageCode)
    }

    private func transcribeData(_ data: Data, mimeType: String, languageCode: String) async -> SpeechResult {
        let b64 = data.base64EncodedString()
        let langName = languageDisplayName(languageCode)
        let transcribePrompt = """
        Transcribe the speech in this audio to text. The speaker is speaking \(langName).
        Output the transcription in the original language spoken.
        Rules:
        1. Only output the actual spoken words, nothing else
        2. If the audio contains no clear speech, only noise or silence, respond with exactly: Unable to recognize
        3. Do not output timestamps or add any explanation
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["inline_data": ["mime_type": mimeType, "data": b64]],
                    ["text": transcribePrompt]
                ]
            ]],
            "generationConfig": ["temperature": 0.1, "maxOutputTokens": 500]
        ]

        let result = await withRetry { [self] _ in
            let text = try await self.postJSON(url: self.generateUrl, body: body)
            return self.isValidTranscription(text) ? text : nil
        }

        return result.map { .success($0) } ?? .error("Unable to recognize speech")
    }

    // MARK: Chat

    func chat(userMessage: String) async -> String {
        guard !apiKey.isEmpty else { return "Gemini API key not configured. Please set up an API key in Settings." }

        var contents: [[String: Any]] = conversationHistory.takeLast(6).map { pair in
            let role = pair.role == "user" ? "user" : "model"
            return ["role": role, "parts": [["text": pair.content]]]
        }
        contents.append(["role": "user", "parts": [["text": userMessage]]])

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": getFullSystemPrompt()]]],
            "contents": contents,
            "generationConfig": [
                "temperature": Double(temperature),
                "maxOutputTokens": maxTokens,
                "topP": Double(topP)
            ]
        ]

        let result = await withRetry { [self] _ in
            try await self.postJSON(url: self.generateUrl, body: body)
        }

        if let text = result {
            addToHistory(user: userMessage, assistant: text)
            return text
        }
        return "Sorry, AI service is temporarily unavailable. Please try again later."
    }

    // MARK: Image analysis

    func analyzeImage(imageData: Data, prompt: String) async -> String {
        guard !apiKey.isEmpty else { return "Gemini API key not configured." }
        let b64 = imageData.base64EncodedString()

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["inline_data": ["mime_type": "image/jpeg", "data": b64]],
                    ["text": prompt]
                ]
            ]],
            "generationConfig": [
                "temperature": Double(temperature),
                "maxOutputTokens": min(maxTokens, 4096)
            ]
        ]

        let result = await withRetry { [self] _ in
            try await self.postJSON(url: self.generateUrl, body: body)
        }
        return result ?? "Sorry, unable to analyze this image."
    }

    // MARK: HTTP helper

    private func postJSON(url: URL, body: [String: Any]) async throws -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array {
    func takeLast(_ n: Int) -> Array { Array(suffix(n)) }
}
