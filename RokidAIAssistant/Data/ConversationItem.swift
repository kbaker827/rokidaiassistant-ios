import Foundation
import SwiftData

struct ConversationItem: Identifiable {
    let id: UUID
    let role: String   // "user" or "assistant"
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    var isUser: Bool { role == "user" }
}

@Model
final class ConversationEntry {
    var id: UUID
    var role: String
    var content: String
    var timestamp: Date
    var sessionId: String

    init(role: String, content: String, sessionId: String = "default") {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.sessionId = sessionId
    }

    var asItem: ConversationItem {
        ConversationItem(id: id, role: role, content: content, timestamp: timestamp)
    }
}

@Model
final class RecordingEntry {
    var id: UUID
    var filePath: String
    var transcription: String?
    var aiAnalysis: String?
    var durationMs: Int64
    var createdAt: Date
    var source: String   // "phone" or "glasses"

    init(filePath: String, durationMs: Int64 = 0, source: String = "phone") {
        self.id = UUID()
        self.filePath = filePath
        self.durationMs = durationMs
        self.source = source
        self.createdAt = Date()
    }
}
