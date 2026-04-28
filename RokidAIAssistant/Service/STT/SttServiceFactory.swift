import Foundation

enum SttServiceFactory {
    static func create(settings: ApiSettings, aiService: AiServiceProtocol) -> SttServiceProtocol? {
        switch settings.sttProvider {
        case .native:
            return nil  // NativeSttService is used directly as @StateObject in ViewModel
        case .gemini:
            return GeminiSttAdapter(aiService: aiService)
        case .openaiWhisper:
            return WhisperSttService(apiKey: settings.openaiApiKey,
                                     baseUrl: AiProvider.openai.defaultBaseUrl)
        case .deepgram:
            return DeepgramSttService(apiKey: settings.deepgramApiKey)
        case .assemblyai:
            return AssemblyAiSttService(apiKey: settings.assemblyaiApiKey)
        }
    }
}

// Adapts the AI service's transcribe method to SttServiceProtocol
struct GeminiSttAdapter: SttServiceProtocol {
    let sttProvider: SttProvider = .gemini
    let aiService: AiServiceProtocol

    func transcribe(audioData: Data, mimeType: String, language: String) async -> SpeechResult {
        await aiService.transcribeAudioFile(audioData: audioData, mimeType: mimeType, languageCode: language)
    }
}

struct WhisperSttService: SttServiceProtocol {
    let sttProvider: SttProvider = .openaiWhisper
    let apiKey: String
    let baseUrl: String

    func transcribe(audioData: Data, mimeType: String, language: String) async -> SpeechResult {
        guard !apiKey.isEmpty else { return .error("OpenAI API key not configured") }
        let service = OpenAiCompatibleService(
            provider: .openai, apiKey: apiKey, modelId: "whisper-large-v3", baseUrl: baseUrl,
            systemPrompt: "", temperature: 0, maxTokens: 500, topP: 1)
        return await service.transcribeAudioFile(audioData: audioData, mimeType: mimeType, languageCode: language)
    }
}

struct DeepgramSttService: SttServiceProtocol {
    let sttProvider: SttProvider = .deepgram
    let apiKey: String

    func transcribe(audioData: Data, mimeType: String, language: String) async -> SpeechResult {
        guard !apiKey.isEmpty else { return .error("Deepgram API key not configured") }

        let langParam = language.isEmpty ? "" : "&language=\(language.components(separatedBy: "-").first ?? language)"
        guard let url = URL(string: "https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true\(langParam)") else {
            return .error("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = audioData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return .error("Deepgram API error") }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [String: Any],
               let channels = results["channels"] as? [[String: Any]],
               let alternatives = channels.first?["alternatives"] as? [[String: Any]],
               let transcript = alternatives.first?["transcript"] as? String, !transcript.isEmpty {
                return .success(transcript)
            }
            return .error("Unable to recognize speech")
        } catch {
            return .error(error.localizedDescription)
        }
    }
}

struct AssemblyAiSttService: SttServiceProtocol {
    let sttProvider: SttProvider = .assemblyai
    let apiKey: String

    func transcribe(audioData: Data, mimeType: String, language: String) async -> SpeechResult {
        guard !apiKey.isEmpty else { return .error("AssemblyAI API key not configured") }

        // Step 1: Upload audio
        guard let uploadUrl = URL(string: "https://api.assemblyai.com/v2/upload") else { return .error("Invalid URL") }
        var uploadReq = URLRequest(url: uploadUrl)
        uploadReq.httpMethod = "POST"
        uploadReq.setValue(apiKey, forHTTPHeaderField: "authorization")
        uploadReq.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        uploadReq.httpBody = audioData
        uploadReq.timeoutInterval = 120

        guard let (uploadData, _) = try? await URLSession.shared.data(for: uploadReq),
              let uploadJson = try? JSONSerialization.jsonObject(with: uploadData) as? [String: Any],
              let audioUrl = uploadJson["upload_url"] as? String else {
            return .error("Failed to upload audio to AssemblyAI")
        }

        // Step 2: Request transcription
        var transcriptBody: [String: Any] = ["audio_url": audioUrl]
        if !language.isEmpty { transcriptBody["language_code"] = language.components(separatedBy: "-").first ?? language }

        guard let transcriptUrl = URL(string: "https://api.assemblyai.com/v2/transcript") else { return .error("Invalid URL") }
        var transcriptReq = URLRequest(url: transcriptUrl)
        transcriptReq.httpMethod = "POST"
        transcriptReq.setValue(apiKey, forHTTPHeaderField: "authorization")
        transcriptReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        transcriptReq.httpBody = try? JSONSerialization.data(withJSONObject: transcriptBody)

        guard let (transcriptData, _) = try? await URLSession.shared.data(for: transcriptReq),
              let transcriptJson = try? JSONSerialization.jsonObject(with: transcriptData) as? [String: Any],
              let transcriptId = transcriptJson["id"] as? String else {
            return .error("Failed to start AssemblyAI transcription")
        }

        // Step 3: Poll for result
        for _ in 0..<30 {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let pollUrl = URL(string: "https://api.assemblyai.com/v2/transcript/\(transcriptId)") else { break }
            var pollReq = URLRequest(url: pollUrl)
            pollReq.setValue(apiKey, forHTTPHeaderField: "authorization")

            guard let (pollData, _) = try? await URLSession.shared.data(for: pollReq),
                  let pollJson = try? JSONSerialization.jsonObject(with: pollData) as? [String: Any] else { break }

            let status = pollJson["status"] as? String
            if status == "completed", let text = pollJson["text"] as? String {
                return .success(text)
            } else if status == "error" {
                return .error(pollJson["error"] as? String ?? "AssemblyAI error")
            }
        }
        return .error("AssemblyAI transcription timed out")
    }
}
