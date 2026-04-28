import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: PhoneViewModel

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }

            PhotoGalleryView()
                .tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .onAppear { vm.startGlassesServer() }
        .alert("API Key Required", isPresented: $vm.showApiKeyWarning) {
            Button("Open Settings") { vm.showApiKeyWarning = false }
            Button("Dismiss") { vm.showApiKeyWarning = false }
        } message: {
            Text("Please configure an AI provider API key in Settings to use the AI assistant.")
        }
    }
}
