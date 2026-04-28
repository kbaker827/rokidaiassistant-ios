import SwiftUI

struct AboutSection: View {
    var body: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0")
            LabeledContent("AI Providers", value: "11 providers")
            LabeledContent("STT Providers", value: "5 providers")
            LabeledContent("Glasses Bridge", value: "Wi-Fi (port 8081)")
            Link("Source: Rokid AI Assistant (Android)",
                 destination: URL(string: "https://github.com/liangtinglin/RokidAIAssistant")!)
        }
    }
}
