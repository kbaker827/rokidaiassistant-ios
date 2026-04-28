import Foundation

class BaseAiService {
    let apiKey: String
    let modelId: String
    let systemPrompt: String
    let temperature: Float
    let maxTokens: Int
    let topP: Float

    var conversationHistory: [(role: String, content: String)] = []

    init(apiKey: String, modelId: String, systemPrompt: String,
         temperature: Float = 0.7, maxTokens: Int = 2048, topP: Float = 1.0) {
        self.apiKey = apiKey
        self.modelId = modelId
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
    }

    func getFullSystemPrompt() -> String {
        let langName = Locale.current.localizedString(forLanguageCode:
            Locale.current.language.languageCode?.identifier ?? "en") ?? "English"
        let instruction = """
        CRITICAL INSTRUCTIONS:
        1. YOU MUST ALWAYS RESPOND IN \(langName.uppercased()). DO NOT USE ANY OTHER LANGUAGE.
        2. Provide complete, conversational, and well-formed sentences.
        3. NEVER respond with a single word. NEVER truncate your thoughts.
        """
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short)
        return "\(systemPrompt)\n\n\(instruction)\n\nCurrent date/time: \(dateStr)"
    }

    func addToHistory(user: String, assistant: String) {
        conversationHistory.append((role: "user", content: user))
        conversationHistory.append((role: "assistant", content: assistant))
        while conversationHistory.count > 10 { conversationHistory.removeFirst() }
    }

    func clearHistory() { conversationHistory.removeAll() }

    // MARK: PCM → WAV

    func pcmToWav(_ pcm: Data, sampleRate: Int = 16000, channels: Int = 1, bitsPerSample: Int = 16) -> Data {
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = pcm.count
        let totalSize = 36 + dataSize

        var wav = Data()
        func appendStr(_ s: String) { wav.append(contentsOf: s.utf8) }
        func appendLE(_ v: Int, bytes: Int) {
            for i in 0..<bytes { wav.append(UInt8((v >> (8 * i)) & 0xFF)) }
        }

        appendStr("RIFF"); appendLE(totalSize, bytes: 4); appendStr("WAVE")
        appendStr("fmt "); appendLE(16, bytes: 4); appendLE(1, bytes: 2)
        appendLE(channels, bytes: 2); appendLE(sampleRate, bytes: 4)
        appendLE(byteRate, bytes: 4); appendLE(blockAlign, bytes: 2)
        appendLE(bitsPerSample, bytes: 2)
        appendStr("data"); appendLE(dataSize, bytes: 4)
        wav.append(pcm)
        return wav
    }

    // MARK: Retry

    func withRetry<T>(maxAttempts: Int = 3, delay: TimeInterval = 1.0, action: (Int) async throws -> T?) async -> T? {
        var lastError: Error? = nil
        for attempt in 1...maxAttempts {
            do {
                if let result = try await action(attempt) { return result }
            } catch {
                lastError = error
                let isNetworkError = (error as NSError).domain == NSURLErrorDomain
                if isNetworkError && attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(delay * Double(attempt) * 1_000_000_000))
                    continue
                }
                break
            }
        }
        _ = lastError
        return nil
    }

    // MARK: Language helpers

    func languageDisplayName(_ code: String) -> String {
        let lc = code.lowercased()
        if lc.hasPrefix("zh-tw") || lc.hasPrefix("zh-hant") { return "Traditional Chinese (繁體中文)" }
        if lc.hasPrefix("zh")   { return "Simplified Chinese (简体中文)" }
        if lc.hasPrefix("ja")   { return "Japanese (日本語)" }
        if lc.hasPrefix("ko")   { return "Korean (한국어)" }
        if lc.hasPrefix("fr")   { return "French (Français)" }
        if lc.hasPrefix("es")   { return "Spanish (Español)" }
        if lc.hasPrefix("it")   { return "Italian (Italiano)" }
        if lc.hasPrefix("ru")   { return "Russian (Русский)" }
        if lc.hasPrefix("uk")   { return "Ukrainian (Українська)" }
        if lc.hasPrefix("th")   { return "Thai (ไทย)" }
        if lc.hasPrefix("vi")   { return "Vietnamese (Tiếng Việt)" }
        if lc.hasPrefix("ar")   { return "Arabic (العربية)" }
        return "English"
    }

    func isValidTranscription(_ text: String?) -> Bool {
        guard let text, !text.isEmpty else { return false }
        let lower = text.lowercased()
        let errorPhrases = ["i'm sorry", "cannot recognize", "unable to transcribe",
                            "no speech", "only noise", "silence", "unable to recognize"]
        if errorPhrases.contains(where: { lower.contains($0) }) { return false }
        if text.count < 2 { return false }
        return true
    }
}
