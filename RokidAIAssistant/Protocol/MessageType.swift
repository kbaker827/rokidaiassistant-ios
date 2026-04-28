import Foundation

enum MessageType: Int, Codable {
    // Connection management
    case handshake          = 0x00
    case handshakeAck       = 0x01
    case heartbeat          = 0x02
    case heartbeatAck       = 0x03
    case disconnect         = 0x0F

    // Voice
    case voiceStart         = 0x10
    case voiceData          = 0x11
    case voiceEnd           = 0x12
    case voiceCancel        = 0x13
    case remoteRecordStart  = 0x14
    case remoteRecordStop   = 0x15

    // AI processing
    case aiProcessing       = 0x20
    case aiResponseText     = 0x21
    case aiResponseTts      = 0x22
    case userTranscript     = 0x23
    case aiError            = 0x2F

    // Display
    case displayText        = 0x30
    case displayClear       = 0x31
    case displayStatus      = 0x32

    // Photo transfer
    case photoStart         = 0x40
    case photoData          = 0x41
    case photoEnd           = 0x42
    case photoAck           = 0x43
    case photoRetry         = 0x44
    case photoCancel        = 0x45
    case photoAnalysisResult = 0x46
    case capturePhoto       = 0x47

    // Live mode
    case liveSessionStart   = 0x50
    case liveSessionEnd     = 0x51
    case liveTranscription  = 0x52
    case videoFrame         = 0x53

    // System
    case systemStatus       = 0xF0
    case systemConfig       = 0xF1
    case systemError        = 0xFF

    static func from(code: Int) -> MessageType? {
        return MessageType(rawValue: code)
    }
}
