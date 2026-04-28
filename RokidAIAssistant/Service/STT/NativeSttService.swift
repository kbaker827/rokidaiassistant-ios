import Foundation
import Speech
import AVFoundation

@MainActor
final class NativeSttService: ObservableObject, SttServiceProtocol {
    let sttProvider: SttProvider = .native

    @Published var isRecognizing = false
    @Published var partialText: String = ""

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?

    var onResult: ((String) -> Void)?
    var onPartial: ((String) -> Void)?

    // Transcribe a recorded audio file (not live)
    func transcribe(audioData: Data, mimeType: String, language: String) async -> SpeechResult {
        // Write to temp file, recognize it
        let ext = mimeType.contains("mp4") || mimeType.contains("aac") ? "m4a" :
                  mimeType.contains("mp3") ? "mp3" : "wav"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("stt_\(UUID().uuidString).\(ext)")
        do {
            try audioData.write(to: url)
        } catch {
            return .error("Failed to write temp file: \(error.localizedDescription)")
        }
        defer { try? FileManager.default.removeItem(at: url) }

        let locale = Locale(identifier: language.isEmpty ? Locale.current.identifier : language)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            return .error("Speech recognition not available for language: \(language)")
        }

        return await withCheckedContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    continuation.resume(returning: .success(result.bestTranscription.formattedString))
                } else if let error {
                    continuation.resume(returning: .error(error.localizedDescription))
                }
            }
        }
    }

    // MARK: Live recording with SFSpeechRecognizer

    func requestPermissions() async -> Bool {
        let status = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        return status == .authorized
    }

    func startListening(language: String = "") {
        stopListening()

        let locale = language.isEmpty ? Locale.current : Locale(identifier: language)
        speechRecognizer = SFSpeechRecognizer(locale: locale)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let node = audioEngine.inputNode
        let fmt = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            self?.recognitionRequest?.append(buf)
        }

        do {
            try audioEngine.start()
        } catch {
            return
        }

        isRecognizing = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.partialText = text
                    self.onPartial?(text)
                    if result.isFinal {
                        self.onResult?(text)
                        self.stopListening()
                    }
                }
            }
            if error != nil { Task { @MainActor in self.stopListening() } }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecognizing = false
        partialText = ""
    }
}
