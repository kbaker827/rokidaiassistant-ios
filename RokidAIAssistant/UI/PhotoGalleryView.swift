import SwiftUI

struct PhotoGalleryView: View {
    @EnvironmentObject var vm: PhoneViewModel
    @State private var selectedPhoto: PhotoEntry? = nil
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage? = nil

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 2)]

    var body: some View {
        NavigationView {
            Group {
                if vm.photoRepo.photos.isEmpty {
                    ContentUnavailableView(
                        "No Photos",
                        systemImage: "photo.on.rectangle",
                        description: Text("Photos captured from Rokid glasses will appear here. You can also import from your library.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(vm.photoRepo.photos) { photo in
                                photoThumbnail(photo)
                                    .onTapGesture { selectedPhoto = photo }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gallery")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImagePicker = true
                    } label: {
                        Image(systemName: "photo.badge.plus")
                    }
                }
                if vm.glassesManager.isConnected {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            vm.requestCapturePhoto()
                        } label: {
                            Label("Capture", systemImage: "camera")
                        }
                    }
                }
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
                    .environmentObject(vm)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView { image in
                    guard let img = image,
                          let data = img.jpegData(compressionQuality: 0.85) else { return }
                    vm.analyzeImage(data)
                }
            }
        }
    }

    @ViewBuilder
    private func photoThumbnail(_ photo: PhotoEntry) -> some View {
        if let img = photo.image {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipped()
        } else {
            Rectangle()
                .fill(.quaternary)
                .frame(width: 120, height: 120)
                .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
        }
    }
}

// MARK: - Photo detail

private struct PhotoDetailView: View {
    @EnvironmentObject var vm: PhoneViewModel
    let photo: PhotoEntry
    @Environment(\.dismiss) private var dismiss
    @State private var analysis: String = ""
    @State private var isAnalyzing = false
    @State private var customPrompt = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if let img = photo.image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }

                    if !analysis.isEmpty {
                        GroupBox("AI Analysis") {
                            Text(analysis)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                    }

                    VStack(spacing: 8) {
                        TextField("Custom prompt (optional)", text: $customPrompt)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)

                        Button {
                            Task { await runAnalysis() }
                        } label: {
                            Label(isAnalyzing ? "Analyzing…" : "Analyze with AI", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isAnalyzing)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        vm.photoRepo.delete(photo)
                        dismiss()
                    } label: { Image(systemName: "trash") }
                }
            }
            .onAppear {
                analysis = photo.aiAnalysis ?? ""
            }
        }
    }

    private func runAnalysis() async {
        guard let img = photo.image,
              let data = img.jpegData(compressionQuality: 0.85) else { return }
        isAnalyzing = true
        let prompt = customPrompt.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Please describe this image in detail."
            : customPrompt
        let result = await vm.settingsStore.settings.aiProvider == .gemini
            ? (GeminiService(apiKey: vm.settingsStore.settings.geminiApiKey,
                             modelId: vm.settingsStore.settings.aiModelId,
                             systemPrompt: vm.settingsStore.settings.systemPrompt)
                .analyzeImage(imageData: data, prompt: prompt))
            : "Please use the Chat tab to analyze photos with non-Gemini providers."
        analysis = result
        isAnalyzing = false
    }
}

// MARK: - Image picker wrapper

struct ImagePickerView: UIViewControllerRepresentable {
    let onPick: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (UIImage?) -> Void
        init(onPick: @escaping (UIImage?) -> Void) { self.onPick = onPick }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            onPick(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onPick(nil)
        }
    }
}
