import SwiftUI
import PhotosUI
import Combine

@MainActor
class ImagePickerViewModel: ObservableObject {
    @Published var selectedItems: [PhotosPickerItem] = [] {
        didSet {
            Task {
                await loadImages()
            }
        }
    }
    @Published var images: [UIImage] = []
    @Published var isUploading: Bool = false

    func loadImages() async {
        images.removeAll()

        for item in selectedItems.prefix(3) {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                    print("✅ Loaded image of size: \(data.count) bytes")
                } else {
                    print("⚠️ Unable to decode image data.")
                }
            } catch {
                print("❌ Failed to load image: \(error.localizedDescription)")
            }
        }
    }

    func clearSelection() {
        selectedItems = []
        images = []
    }
    
    func uploadImages(userId: String, itemId: String, uploadFunc: @escaping (UIImage) async -> String?) async -> [String] {
        print("[ImagePickerViewModel] Uploading images with userId: \(userId)")
        isUploading = true
        defer { isUploading = false }

        var uploadedUrls: [String] = []
        for image in images.prefix(3) {
            if let url = await uploadFunc(image) {
                uploadedUrls.append(url)
            }
        }
        return uploadedUrls
    }
}
