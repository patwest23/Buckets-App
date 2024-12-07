//
//  ImagePicker.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/21/23.
//

import SwiftUI
import PhotosUI

@MainActor
class ImagePickerViewModel: ObservableObject {
    @Published var uiImages: [UIImage] = [] // Holds the final selected images
    @Published var imageSelections: [PhotosPickerItem] = [] {
        didSet {
            guard !imageSelections.isEmpty else { return }
            Task {
                await loadImages(from: imageSelections)
            }
        }
    }

    /// Asynchronously loads images from the selected `PhotosPickerItem`.
    /// - Parameter selections: The selected `PhotosPickerItem` array.
    private func loadImages(from selections: [PhotosPickerItem]) async {
        var loadedImages: [UIImage] = [] // Temporary storage to avoid UI inconsistency
        for selection in selections {
            do {
                if let data = try await selection.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loadedImages.append(image)
                }
            } catch {
                print("Error loading image: \(error)")
            }
        }
        uiImages = loadedImages // Update all at once to reduce UI updates
    }

    /// Loads existing images from stored `Data`.
    /// - Parameter imageDataArray: An array of image data.
    func loadExistingImages(from imageDataArray: [Data]) {
        uiImages = imageDataArray.compactMap { UIImage(data: $0) }
    }

    /// Converts `UIImage` array to `Data` array for storage.
    /// - Returns: An array of `Data` representations of the images.
    func getImagesAsData() -> [Data] {
        uiImages.compactMap { $0.jpegData(compressionQuality: 1.0) }
    }
}





