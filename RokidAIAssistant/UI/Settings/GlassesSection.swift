import SwiftUI

struct GlassesSection: View {
    @EnvironmentObject var vm: PhoneViewModel

    var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading) {
                    Text("Connection Mode")
                    Text("Wi-Fi (TCP port 8081)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "wifi")
                    .foregroundStyle(.blue)
            }

            if let ip = vm.glassesManager.localIPAddress {
                LabeledContent("Phone IP Address") {
                    Text(ip)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Port") {
                    Text("\(GlassesConnectionManager.port)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            switch vm.glassesManager.connectionState {
            case .connected:
                Label("Connected: \(vm.glassesManager.connectedDeviceName ?? "Glasses")",
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Disconnect", role: .destructive) { vm.disconnectGlasses() }

            case .connecting, .reconnecting:
                Label("Waiting for glasses to connect…", systemImage: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.orange)
                Button("Stop", role: .destructive) { vm.disconnectGlasses() }

            default:
                Button("Start Wi-Fi Server") { vm.startGlassesServer() }
                    .buttonStyle(.borderedProminent)
            }

            Text("On the Rokid glasses app: enable Debug Wi-Fi Mode and point it at the IP above on port \(GlassesConnectionManager.port).")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Glasses Connection")
        } footer: {
            Text("iOS cannot use Bluetooth SPP (RFCOMM) without MFi certification. Wi-Fi mode is fully functional and uses the same JSON protocol as the Android app.")
        }
    }
}
