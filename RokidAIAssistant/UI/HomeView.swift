import SwiftUI

struct HomeView: View {
    @EnvironmentObject var vm: PhoneViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Welcome header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rokid AI Assistant")
                            .font(.largeTitle).bold()
                        Text("AI-powered voice and vision for Rokid AR glasses")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Status cards row
                    HStack(spacing: 12) {
                        StatusCard(
                            icon: glassesIcon,
                            iconColor: glassesColor,
                            title: "Glasses",
                            value: glassesStatus
                        )
                        StatusCard(
                            icon: "brain.filled.head.profile",
                            iconColor: .blue,
                            title: "AI Model",
                            value: vm.settingsStore.settings.aiModelId
                        )
                    }
                    .padding(.horizontal)

                    // Glasses connection card
                    GlassesConnectionCard()

                    // Recording control card
                    RecordingControlCard()

                    // Recent conversations
                    if !vm.conversations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Current Session")
                                    .font(.headline)
                                Spacer()
                                NavigationLink("View All") {
                                    ChatView().environmentObject(vm)
                                }
                                .font(.subheadline)
                            }
                            .padding(.horizontal)

                            ForEach(vm.conversations.suffix(4)) { item in
                                ConversationBubble(item: item)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    // Status footer
                    if let status = vm.processingStatus {
                        Label(status, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var glassesIcon: String {
        switch vm.glassesManager.connectionState {
        case .connected:    return "glasses"
        case .connecting, .reconnecting: return "antenna.radiowaves.left.and.right"
        default:            return "glasses"
        }
    }

    private var glassesColor: Color {
        switch vm.glassesManager.connectionState {
        case .connected:    return .green
        case .connecting, .reconnecting: return .orange
        case .error:        return .red
        default:            return .secondary
        }
    }

    private var glassesStatus: String {
        switch vm.glassesManager.connectionState {
        case .connected:    return vm.glassesManager.connectedDeviceName ?? "Connected"
        case .connecting, .reconnecting: return "Waiting..."
        case .error:        return "Error"
        default:            return "Disconnected"
        }
    }
}

// MARK: - Sub-components

private struct StatusCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline).bold()
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct GlassesConnectionCard: View {
    @EnvironmentObject var vm: PhoneViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Glasses Connection (Wi-Fi)", systemImage: "wifi")
                .font(.headline)

            if vm.glassesManager.connectionState == .connected {
                Label("Connected: \(vm.glassesManager.connectedDeviceName ?? "Rokid Glasses")",
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Disconnect", role: .destructive) { vm.disconnectGlasses() }
                    .buttonStyle(.bordered)
            } else {
                let ip = vm.glassesManager.localIPAddress ?? "unknown"
                Text("Set glasses app to connect to \(ip):8081 (Wi-Fi debug mode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Start Server") { vm.startGlassesServer() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

private struct RecordingControlCard: View {
    @EnvironmentObject var vm: PhoneViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recording", systemImage: "mic.fill")
                .font(.headline)

            if vm.isRecording {
                let mins = vm.recordingDurationMs / 60000
                let secs = (vm.recordingDurationMs / 1000) % 60
                Label(String(format: "%02d:%02d • Phone", mins, secs),
                      systemImage: "record.circle")
                    .foregroundStyle(.red)
                Button("Stop & Transcribe", role: .destructive) { vm.stopPhoneRecording() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            } else {
                HStack {
                    Button {
                        vm.startPhoneRecording()
                    } label: {
                        Label("Phone Mic", systemImage: "iphone")
                    }
                    .buttonStyle(.borderedProminent)

                    if vm.glassesManager.isConnected {
                        Button {
                            vm.glassesManager.send(Message(type: .remoteRecordStart))
                        } label: {
                            Label("Glasses Mic", systemImage: "glasses")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
