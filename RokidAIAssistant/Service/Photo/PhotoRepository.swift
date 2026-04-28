import Foundation
import UIKit

struct PhotoEntry: Identifiable {
    let id: UUID
    let url: URL
    let createdAt: Date
    let aiAnalysis: String?

    var image: UIImage? { UIImage(contentsOfFile: url.path) }
}

@MainActor
final class PhotoRepository: ObservableObject {
    @Published var photos: [PhotoEntry] = []

    private let dir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let d = docs.appendingPathComponent("RokidPhotos")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    init() { loadPhotos() }

    func save(imageData: Data, analysis: String? = nil) -> URL? {
        let name = "photo_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        let url = dir.appendingPathComponent(name)
        do {
            try imageData.write(to: url)
            let entry = PhotoEntry(id: UUID(), url: url, createdAt: Date(), aiAnalysis: analysis)
            photos.insert(entry, at: 0)
            return url
        } catch {
            return nil
        }
    }

    func delete(_ entry: PhotoEntry) {
        try? FileManager.default.removeItem(at: entry.url)
        photos.removeAll { $0.id == entry.id }
    }

    private func loadPhotos() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey]) else { return }
        photos = files
            .filter { $0.pathExtension == "jpg" || $0.pathExtension == "jpeg" }
            .compactMap { url -> PhotoEntry? in
                let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
                return PhotoEntry(id: UUID(), url: url, createdAt: date, aiAnalysis: nil)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
