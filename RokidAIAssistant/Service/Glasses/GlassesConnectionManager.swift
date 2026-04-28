import Foundation
import Network
import UIKit

/// Replaces Android's BluetoothSppManager.
///
/// iOS cannot act as a generic Bluetooth SPP/RFCOMM server — that requires MFi certification.
/// Instead this class runs a TCP server on port 8081 using Network.framework so the Rokid
/// glasses app can connect over local Wi-Fi in the same way as the Android app's debug Wi-Fi
/// mode. The wire protocol is identical (JSON+newline framing).
///
/// The glasses app must have its "Debug Wi-Fi mode" setting pointing at this phone's IP address
/// on port 8081.
@MainActor
final class GlassesConnectionManager: ObservableObject {
    static let port: UInt16 = 8081

    @Published var connectionState: ConnectionState = .disconnected
    @Published var connectedDeviceName: String? = nil

    var onMessage: ((Message) -> Void)?

    private var listener: NWListener?
    private var connection: NWConnection?

    private var receiveBuffer = Data()

    // MARK: Start / Stop server

    func startListening() {
        stopListening()

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        guard let listener = try? NWListener(using: params, on: NWEndpoint.Port(rawValue: Self.port)!) else { return }
        self.listener = listener
        connectionState = .connecting

        listener.newConnectionHandler = { [weak self] newConn in
            Task { @MainActor in
                self?.acceptConnection(newConn)
            }
        }

        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .failed, .cancelled:
                    self?.connectionState = .error
                default: break
                }
            }
        }

        listener.start(queue: .global(qos: .userInitiated))
    }

    func stopListening() {
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
        connectionState = .disconnected
        connectedDeviceName = nil
        receiveBuffer = Data()
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        connectionState = .disconnected
        connectedDeviceName = nil
    }

    // MARK: Connection handling

    private func acceptConnection(_ conn: NWConnection) {
        connection?.cancel()
        connection = conn
        receiveBuffer = Data()

        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.connectionState = .connected
                    self?.receiveNextMessage()
                case .failed, .cancelled:
                    self?.connectionState = .disconnected
                    self?.connectedDeviceName = nil
                    self?.connection = nil
                    // Resume listening for the next glasses connection
                    self?.startListening()
                default: break
                }
            }
        }
        conn.start(queue: .global(qos: .userInitiated))
    }

    private func receiveNextMessage() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let data = content { self.receiveBuffer.append(data) }
                self.processBuffer()
                if error == nil && !isComplete {
                    self.receiveNextMessage()
                } else {
                    self.disconnect()
                }
            }
        }
    }

    private func processBuffer() {
        // Protocol: JSON lines (terminated by \n)
        while let nlRange = receiveBuffer.range(of: Data([0x0A])) {
            let lineData = receiveBuffer.subdata(in: receiveBuffer.startIndex..<nlRange.lowerBound)
            receiveBuffer = receiveBuffer.subdata(in: nlRange.upperBound..<receiveBuffer.endIndex)

            guard let line = String(data: lineData, encoding: .utf8),
                  !line.trimmingCharacters(in: .whitespaces).isEmpty,
                  let msg = Message.fromJson(line) else { continue }

            handleIncomingMessage(msg)
        }
    }

    private func handleIncomingMessage(_ msg: Message) {
        if msg.type == .handshake {
            connectedDeviceName = msg.payload ?? "Rokid Glasses"
            send(Message.handshake(deviceName: UIDevice.current.name))
        } else if msg.type == .heartbeat {
            send(Message(type: .heartbeatAck))
        } else {
            onMessage?(msg)
        }
    }

    // MARK: Send

    func send(_ message: Message) {
        guard let conn = connection, connectionState == .connected else { return }
        let line = message.toJson() + "\n"
        guard let data = line.data(using: .utf8) else { return }
        conn.send(content: data, completion: .idempotent)
    }

    var isConnected: Bool { connectionState == .connected }

    // MARK: Local IP helper

    var localIPAddress: String? {
        var address: String? = nil
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let p = ptr {
            let addr = p.pointee.ifa_addr!
            if addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: p.pointee.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
            ptr = p.pointee.ifa_next
        }
        return address
    }
}

