//
//  ImagePickerViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/21/23.
//

import SwiftUI
import PhotosUI

@MainActor
class ImagePickerViewModel: ObservableObject {
    @Published var selectedItem: PhotosPickerItem? = nil
    @Published var pickedImage: UIImage? = nil
    @Published var pickedImageData: Data? = nil

    func loadSelectedImage() async {
        guard let item = selectedItem else { return }

        do {
            let data = try await item.loadTransferable(type: Data.self)
            if let data = data, let image = UIImage(data: data) {
                self.pickedImage = image
                self.pickedImageData = data
                print("✅ Loaded image successfully, size: \(data.count) bytes")
            } else {
                print("⚠️ Unable to decode image data")
            }
        } catch {
            print("❌ Error loading image: \(error.localizedDescription)")
        }
    }

    func clearSelection() {
        selectedItem = nil
        pickedImage = nil
        pickedImageData = nil
    }
}
