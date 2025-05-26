import SwiftUI
import FirebaseStorage
import PhotosUI
import Combine

@MainActor
class ImagePickerViewModel: ObservableObject {
    @Published var selectedItems: [PhotosPickerItem] = [] {
        didSet {
            print("📸 selectedItems updated: \(selectedItems.count)")
            Task {
                await loadImages()
            }
        }
    }
    @Published var images: [UIImage] = []
    @Published var isUploading: Bool = false

    var onImagesLoaded: (() -> Void)?

    func loadImages() async {
        print("🖼 Starting to load \(selectedItems.count) selected item(s)")
        images.removeAll()

        for (index, item) in selectedItems.prefix(3).enumerated() {
            print("🔄 Processing item \(index + 1)")
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
        print("✅ Finished loading images. Total loaded: \(images.count)")
        onImagesLoaded?()
    }

    func clearSelection() {
        selectedItems = []
        images = []
    }
    
    func uploadImages(userId: String, itemId: String) async -> [String] {
        print("[ImagePickerViewModel] Uploading images with userId: \(userId)")
        print("[ImagePickerViewModel] Starting upload for \(images.count) image(s)")
        isUploading = true
        defer { isUploading = false }

        var uploadedUrls: [String] = []

        for (index, image) in images.prefix(3).enumerated() {
            print("⬆️ Uploading image \(index + 1)")
            if let url = await uploadImageToStorage(image: image, userId: userId, itemId: itemId) {
                uploadedUrls.append(url)
                print("✅ Uploaded image URL: \(url)")
                print("📦 Current uploadedUrls: \(uploadedUrls)")
            }
        }

        print("[ImagePickerViewModel] Finished upload. Final URLs: \(uploadedUrls)")
        return uploadedUrls
    }

    private func uploadImageToStorage(image: UIImage, userId: String, itemId: String) async -> String? {
        guard !userId.isEmpty else {
            print("❌ Missing userId")
            return nil
        }

        let imageData = image.jpegData(compressionQuality: 0.8)
        guard let data = imageData else {
            print("❌ Failed to compress image")
            return nil
        }

        let uniqueId = UUID().uuidString
        let path = "users/\(userId)/item-images/\(itemId)/\(uniqueId).jpg"
        let storageRef = Storage.storage().reference().child(path)

        print("📤 Starting upload to path: \(path)")
        print("🔍 Data size: \(data.count) bytes")

        do {
            try await storageRef.putDataAsync(data)
            let url = try await storageRef.downloadURL()
            print("✅ Upload completed. Download URL: \(url.absoluteString)")
            return url.absoluteString
        } catch {
            print("❌ Upload failed at path \(path): \(error.localizedDescription)")
            return nil
        }
    }
}
