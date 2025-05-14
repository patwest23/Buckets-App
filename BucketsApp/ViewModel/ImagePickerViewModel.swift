import SwiftUI
import PhotosUI
import Combine

@MainActor
class ImagePickerViewModel: ObservableObject {
    @Published var selectedItems: [PhotosPickerItem] = []
    @Published var images: [UIImage] = []

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
}
