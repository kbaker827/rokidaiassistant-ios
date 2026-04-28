# Rokid AI Assistant — iOS

iOS companion app for [RokidAIAssistant](https://github.com/liangtinglin/RokidAIAssistant) — an AI-powered voice and vision assistant for Rokid AR glasses.

This is a faithful iOS port of the Android phone-side app. The glasses-side app still runs on the Rokid glasses hardware (Android); only the phone companion app has been converted.

## Features

| Feature | Description |
|---------|-------------|
| 🤖 Multi-AI Providers | 11 providers: Gemini, OpenAI, Anthropic, DeepSeek, Groq, xAI, Alibaba (Qwen), Zhipu (GLM), Perplexity, Moonshot (Kimi), Custom (OpenAI-compatible) |
| 🎤 Voice Input | iOS native SFSpeechRecognizer, Gemini Audio, OpenAI Whisper, Deepgram, AssemblyAI |
| 📷 Photo Analysis | Capture from glasses or import from library; AI image analysis |
| 📱 Phone Mic Recording | Record from phone microphone with auto-transcription and AI analysis |
| 💬 Conversation History | SwiftData persistence across sessions |
| 🔌 Glasses Bridge | Wi-Fi TCP server (port 8081) — same protocol as Android app |

## Bluetooth / Glasses Connection

The original Android app uses Bluetooth SPP (RFCOMM) for the glasses data channel. RFCOMM is unavailable to third-party iOS apps without MFi certification.

| Mode | iOS status |
|------|-----------|
| Bluetooth SPP/RFCOMM data transport | ❌ Not available without MFi |
| Wi-Fi TCP server (port 8081) | ✅ Fully functional |

**Recommended:** Use the glasses app's **Debug Wi-Fi Mode**. Set the target IP to your iPhone's local IP (shown in Settings → Glasses Connection) on port 8081. The glasses app connects over LAN and the full message protocol works identically.

## Setup in Xcode

1. Open Xcode → File → New → Project → iOS App
2. Set bundle identifier to `com.rokidai.ios`
3. Delete the auto-generated `ContentView.swift`
4. Drag the `RokidAIAssistant/` folder into the Xcode project (check "Copy items if needed")
5. Replace the generated `Info.plist` with `RokidAIAssistant/Info.plist` (or merge the keys)
6. Add these capabilities in Signing & Capabilities:
   - **Background Modes** → check **Audio, AirPlay, and Picture in Picture**
7. Build and run on a physical iPhone (microphone and local network require real hardware)

## Architecture

```
Rokid Glasses (Android)  ←Wi-Fi TCP:8081→  RokidAI iOS  ←HTTPS→  AI Provider APIs
        │                                        │
  Glasses HUD app                       GlassesConnectionManager
  (unchanged Android)                   PhoneViewModel
                                        AiServiceFactory → GeminiService
                                                         → OpenAiCompatibleService
                                                         → AnthropicService
                                        SttServiceFactory → NativeSttService
                                                          → GeminiSttAdapter
                                                          → WhisperSttService
                                                          → DeepgramSttService
                                                          → AssemblyAiSttService
```

### Key source files

| File | Purpose |
|------|---------|
| `Protocol/MessageType.swift` | Message type enum (mirrors Android `MessageType.kt`) |
| `Protocol/Message.swift` | Message struct — JSON+newline framing for Wi-Fi transport |
| `Data/AiProvider.swift` | AI provider enum + model catalog |
| `Data/ApiSettings.swift` | All API keys, provider selection, LLM parameters |
| `Data/ConversationItem.swift` | In-session item + SwiftData `ConversationEntry` model |
| `Service/Glasses/GlassesConnectionManager.swift` | NWListener TCP server on port 8081 |
| `Service/AI/GeminiService.swift` | Gemini REST API (chat, STT, vision) |
| `Service/AI/OpenAiCompatibleService.swift` | OpenAI + all OpenAI-compatible providers |
| `Service/AI/AnthropicService.swift` | Anthropic Claude API |
| `Service/STT/NativeSttService.swift` | iOS SFSpeechRecognizer (live + file) |
| `Service/STT/SttServiceFactory.swift` | Deepgram, AssemblyAI, Whisper adapters |
| `ViewModel/PhoneViewModel.swift` | Central state + orchestration |
| `UI/HomeView.swift` | Home screen with connection status and recording controls |
| `UI/ChatView.swift` | Chat screen with SwiftData history |
| `UI/PhotoGalleryView.swift` | Photo grid + AI analysis |
| `UI/Settings/` | All settings sections |

## Configuration

Open the app → Settings tab:

- **AI Provider**: Select provider and model
- **API Keys**: Enter keys for each provider you want to use (only the active provider's key is required)
- **STT Provider**: Select speech recognition backend
- **Glasses Connection**: Shows your phone's IP; configure the glasses app to connect to `<IP>:8081`

## Protocol Compatibility

The iOS app uses the same JSON wire protocol as the Android glasses app. No changes to the glasses-side Android app are needed.

Message framing: `{JSON}\n` (newline-delimited JSON over TCP).

## License

MIT — same as the original [RokidAIAssistant](https://github.com/liangtinglin/RokidAIAssistant).
