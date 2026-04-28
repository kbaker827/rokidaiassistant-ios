import Foundation

protocol SttServiceProtocol {
    var sttProvider: SttProvider { get }
    func transcribe(audioData: Data, mimeType: String, language: String) async -> SpeechResult
}
