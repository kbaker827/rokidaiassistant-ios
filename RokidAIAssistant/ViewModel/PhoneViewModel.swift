import Foundation
import SwiftData
import Combine
import AVFoundation

@MainActor
final class PhoneViewModel: ObservableObject {
    // MARK: Published state

    @Published var conversations: [ConversationItem] = []
    @Published var processingStatus: String? = nil
    @Published var showApiKeyWarning = false
    @Published var isRecording = false
    @Published var recordingDurationMs: Int64 = 0

    // MARK: Sub-managers

    let settingsStore: SettingsStore
    let glassesManager: GlassesConnectionManager
    let photoRepo: PhotoRepository
    let nativeStt: NativeSttService

    private var aiService: AiServiceProtocol
    private var sttService: SttServiceProtocol?

    // Recording
    private var audioRecorder: AVAudioRecorder?
    private var recordingStartTime: Date?
    private var recordingTimer: Timer?
    private var currentRecordingUrl: URL?

    // Photo transfer (reassemble binary chunks from glasses)
    private var photoBuffer = Data()
    private var receivingPhoto = false

    // SwiftData model context (injected by App)
    var modelContext: ModelContext?

    // MARK: Init

    init() {
        self.settingsStore = SettingsStore()
        self.glassesManager = GlassesConnectionManager()
        self.photoRepo = PhotoRepository()
        self.nativeStt = NativeSttService()
        self.aiService = AiServiceFactory.create(settings: settingsStore.settings)
        self.sttService = nil

        setupGlassesCallbacks()
        rebuildAiService()
    }

    // MARK: Settings

    func applySettings() {
        settingsStore.save()
        rebuildAiService()
    }

    private func rebuildAiService() {
        let settings = settingsStore.settings
        aiService = AiServiceFactory.create(settings: settings)
        sttService = SttServiceFactory.create(settings: settings, aiService: aiService)
        if !settings.isCurrentProviderConfigured() && !settings.hasAnyApiKeyConfigured() {
            showApiKeyWarning = true
        }
    }

    // MARK: Glasses connection (Wi-Fi)

    func startGlassesServer() {
        glassesManager.startListening()
    }

    func disconnectGlasses() {
        glassesManager.disconnect()
    }

    private func setupGlassesCallbacks() {
        glassesManager.onMessage = { [weak self] message in
            Task { @MainActor in
                self?.handleGlassesMessage(message)
            }
        }
    }

    private func handleGlassesMessage(_ msg: Message) {
        switch msg.type {
        case .voiceStart:
            photoBuffer = Data()

        case .voiceData:
            // Accumulate voice chunks
            if let audio = msg.binaryData {
                photoBuffer.append(audio)
            }

        case .voiceEnd:
            let audioData = photoBuffer
            photoBuffer = Data()
            guard !audioData.isEmpty else { return }
            Task { await self.processVoiceData(audioData) }

        case .voiceCancel:
            photoBuffer = Data()

        case .photoStart:
            photoBuffer = Data()
            receivingPhoto = true

        case .photoData:
            if let chunk = msg.binaryData { photoBuffer.append(chunk) }
            glassesManager.send(Message.photoAck())

        case .photoEnd:
            let imageData = photoBuffer
            photoBuffer = Data()
            receivingPhoto = false
            guard !imageData.isEmpty else { return }
            Task { await self.processPhoto(imageData) }

        case .systemStatus:
            if let payload = msg.payload { processingStatus = payload }

        default: break
        }
    }

    // MARK: Voice processing

    private func processVoiceData(_ audioData: Data) async {
        processingStatus = "Transcribing..."

        let settings = settingsStore.settings
        let language = settings.speechLanguage
        let mimeType = "audio/wav"

        let sttResult: SpeechResult
        if let sttSvc = sttService {
            sttResult = await sttSvc.transcribe(audioData: audioData, mimeType: mimeType, language: language)
        } else {
            // Use Gemini STT from the AI service if it supports audio
            sttResult = await aiService.transcribeAudioFile(audioData: audioData, mimeType: mimeType, languageCode: language)
        }

        switch sttResult {
        case .success(let transcript):
            addConversation(role: "user", content: transcript)
            if settings.pushChatToGlasses {
                glassesManager.send(Message.displayText("You: \(transcript)"))
            }
            await processChat(userMessage: transcript)
        case .error(let error):
            processingStatus = "Speech recognition failed: \(error)"
        }
    }

    // MARK: Chat

    func sendTextMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        addConversation(role: "user", content: trimmed)
        if settingsStore.settings.pushChatToGlasses {
            glassesManager.send(Message.displayText("You: \(trimmed)"))
        }
        Task { await processChat(userMessage: trimmed) }
    }

    private func processChat(userMessage: String) async {
        processingStatus = "Thinking..."
        glassesManager.send(Message.aiProcessing("Processing..."))

        let response = await aiService.chat(userMessage: userMessage)
        processingStatus = nil
        addConversation(role: "assistant", content: response)

        if settingsStore.settings.pushChatToGlasses {
            glassesManager.send(Message.aiResponseText(response))
            glassesManager.send(Message.displayText(response))
        }

        persistConversation(role: "user", content: userMessage)
        persistConversation(role: "assistant", content: response)
    }

    // MARK: Photo processing

    func requestCapturePhoto() {
        glassesManager.send(Message.capturePhoto())
    }

    private func processPhoto(_ imageData: Data) async {
        let url = photoRepo.save(imageData: imageData)
        processingStatus = "Analyzing photo..."
        glassesManager.send(Message.aiProcessing("Analyzing photo..."))

        let prompt = "Please describe this image in detail."
        let analysis = await aiService.analyzeImage(imageData: imageData, prompt: prompt)
        processingStatus = nil

        addConversation(role: "assistant", content: "[Photo] \(analysis)")

        if settingsStore.settings.pushChatToGlasses {
            glassesManager.send(Message.aiResponseText(analysis))
            glassesManager.send(Message.displayText(analysis))
        }

        _ = url
    }

    // MARK: Image analysis (from phone camera / gallery)

    func analyzeImage(_ imageData: Data, prompt: String = "Please describe this image in detail.") {
        Task {
            processingStatus = "Analyzing photo..."
            let analysis = await aiService.analyzeImage(imageData: imageData, prompt: prompt)
            processingStatus = nil
            addConversation(role: "assistant", content: "[Photo] \(analysis)")
            if settingsStore.settings.pushChatToGlasses {
                glassesManager.send(Message.aiResponseText(analysis))
            }
            _ = photoRepo.save(imageData: imageData, analysis: analysis)
        }
    }

    // MARK: Phone recording

    func startPhoneRecording() {
        guard !isRecording else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rec_\(Int(Date().timeIntervalSince1970 * 1000)).m4a")
        currentRecordingUrl = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true)
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordingStartTime = Date()
            recordingDurationMs = 0

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let start = self.recordingStartTime else { return }
                    self.recordingDurationMs = Int64(-start.timeIntervalSinceNow * 1000)
                }
            }
        } catch {
            processingStatus = "Recording failed: \(error.localizedDescription)"
        }
    }

    func stopPhoneRecording() {
        guard isRecording, let recorder = audioRecorder, let url = currentRecordingUrl else { return }

        recorder.stop()
        audioRecorder = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        recordingStartTime = nil

        guard let audioData = try? Data(contentsOf: url) else { return }
        try? FileManager.default.removeItem(at: url)
        currentRecordingUrl = nil

        Task {
            processingStatus = "Transcribing recording..."
            let settings = settingsStore.settings
            let sttResult: SpeechResult
            if let sttSvc = sttService {
                sttResult = await sttSvc.transcribe(audioData: audioData, mimeType: "audio/mp4", language: settings.speechLanguage)
            } else {
                sttResult = await aiService.transcribeAudioFile(audioData: audioData, mimeType: "audio/mp4", languageCode: settings.speechLanguage)
            }

            switch sttResult {
            case .success(let transcript):
                addConversation(role: "user", content: "[Recording] \(transcript)")
                if settings.autoAnalyzeRecordings {
                    await processChat(userMessage: transcript)
                }
            case .error(let err):
                processingStatus = "Transcription failed: \(err)"
            }
        }
    }

    // MARK: Conversation helpers

    func addConversation(role: String, content: String) {
        let item = ConversationItem(role: role, content: content)
        conversations.append(item)
    }

    func clearConversations() {
        conversations.removeAll()
        aiService.clearHistory()
    }

    // MARK: Persistence (SwiftData)

    private func persistConversation(role: String, content: String) {
        guard let ctx = modelContext else { return }
        ctx.insert(ConversationEntry(role: role, content: content))
        try? ctx.save()
    }
}
