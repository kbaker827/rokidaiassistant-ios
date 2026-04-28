import Foundation

struct Message {
    let id: String
    let type: MessageType
    let timestamp: Int64
    let payload: String?
    let binaryData: Data?

    init(
        id: String = UUID().uuidString,
        type: MessageType,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        payload: String? = nil,
        binaryData: Data? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.payload = payload
        self.binaryData = binaryData
    }

    // MARK: Convenience factories

    static func handshake(deviceName: String) -> Message {
        Message(type: .handshake, payload: deviceName)
    }
    static func heartbeat() -> Message { Message(type: .heartbeat) }
    static func voiceStart() -> Message { Message(type: .voiceStart) }
    static func voiceData(_ audio: Data) -> Message { Message(type: .voiceData, binaryData: audio) }
    static func voiceEnd() -> Message { Message(type: .voiceEnd) }
    static func aiProcessing(_ status: String) -> Message { Message(type: .aiProcessing, payload: status) }
    static func aiResponseText(_ text: String) -> Message { Message(type: .aiResponseText, payload: text) }
    static func aiError(_ error: String) -> Message { Message(type: .aiError, payload: error) }
    static func displayText(_ text: String) -> Message { Message(type: .displayText, payload: text) }
    static func displayClear() -> Message { Message(type: .displayClear) }
    static func capturePhoto() -> Message { Message(type: .capturePhoto) }
    static func photoAck() -> Message { Message(type: .photoAck) }

    // MARK: JSON serialization

    func toJson() -> String {
        var dict: [String: Any] = [
            "id": id,
            "type": type.rawValue,
            "timestamp": timestamp
        ]
        if let payload { dict["payload"] = payload }
        if let binaryData { dict["binaryData"] = binaryData.base64EncodedString() }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    static func fromJson(_ json: String) -> Message? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let typeCode = dict["type"] as? Int,
              let type = MessageType.from(code: typeCode) else { return nil }
        let id = dict["id"] as? String ?? UUID().uuidString
        let timestamp = dict["timestamp"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)
        let payload = dict["payload"] as? String
        var binaryData: Data? = nil
        if let b64 = dict["binaryData"] as? String {
            binaryData = Data(base64Encoded: b64)
        }
        return Message(id: id, type: type, timestamp: timestamp, payload: payload, binaryData: binaryData)
    }

    // MARK: Binary serialization (for audio streaming over Wi-Fi)
    // Format: [4 bytes type code (big-endian)] [4 bytes payload length] [payload bytes]

    func toBytes() -> Data {
        let payloadBytes = binaryData ?? Data()
        var result = Data(capacity: 8 + payloadBytes.count)
        var typeCode = UInt32(type.rawValue).bigEndian
        var length = UInt32(payloadBytes.count).bigEndian
        result.append(contentsOf: withUnsafeBytes(of: &typeCode) { Array($0) })
        result.append(contentsOf: withUnsafeBytes(of: &length) { Array($0) })
        result.append(payloadBytes)
        return result
    }

    static func fromBytes(_ bytes: Data) -> Message? {
        guard bytes.count >= 8 else { return nil }
        let typeCode = bytes.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self).bigEndian }
        let length = bytes.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).bigEndian }
        guard let type = MessageType.from(code: Int(typeCode)) else { return nil }
        var payload: Data? = nil
        if length > 0 && bytes.count >= 8 + Int(length) {
            payload = bytes.subdata(in: 8..<(8 + Int(length)))
        }
        return Message(type: type, binaryData: payload)
    }
}
