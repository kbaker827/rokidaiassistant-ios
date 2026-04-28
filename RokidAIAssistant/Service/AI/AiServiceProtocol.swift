import Foundation

enum SpeechResult {
    case success(String)
    case error(String)
}

protocol AiServiceProtocol {
    var provider: AiProvider { get }

    func transcribe(pcmAudioData: Data, languageCode: String) async -> SpeechResult
    func transcribeAudioFile(audioData: Data, mimeType: String, languageCode: String) async -> SpeechResult
    func chat(userMessage: String) async -> String
    func analyzeImage(imageData: Data, prompt: String) async -> String
    func clearHistory()
}

extension AiServiceProtocol {
    func transcribeAudioFile(audioData: Data, mimeType: String, languageCode: String) async -> SpeechResult {
        await transcribe(pcmAudioData: audioData, languageCode: languageCode)
    }
}
