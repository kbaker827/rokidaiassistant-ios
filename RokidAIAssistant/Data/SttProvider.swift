import Foundation

enum SttProvider: String, CaseIterable, Identifiable, Codable {
    case native       // iOS SFSpeechRecognizer — always available, no key needed
    case gemini       // Gemini native audio
    case openaiWhisper
    case deepgram
    case assemblyai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .native:        return "iOS Native (SFSpeechRecognizer)"
        case .gemini:        return "Gemini Audio"
        case .openaiWhisper: return "OpenAI Whisper"
        case .deepgram:      return "Deepgram"
        case .assemblyai:    return "AssemblyAI"
        }
    }

    var requiresApiKey: Bool { self != .native }
}
