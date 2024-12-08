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
    @Published var uiImages: [UIImage] = [] // Holds the final selected images (max 3)
    @Published var imageSelections: [PhotosPickerItem] = [] {
        didSet {
            guard !imageSelections.isEmpty else { return }
            Task {
                await loadImages(from: imageSelections)
            }
        }
    }

    /// Asynchronously loads images from the selected `PhotosPickerItem`.
    /// Ensures the number of images does not exceed the maximum of 3.
    /// - Parameter selections: The selected `PhotosPickerItem` array.
    private func loadImages(from selections: [PhotosPickerItem]) async {
        var loadedImages: [UIImage] = []
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
        // Replace current images with the last selection (max 3)
        uiImages = Array(loadedImages.prefix(3))
    }

    /// Loads existing images from stored `Data`.
    /// Ensures the number of images does not exceed the maximum of 3.
    /// - Parameter imageDataArray: An array of image data.
    func loadExistingImages(from imageDataArray: [Data]) {
        uiImages = Array(imageDataArray.compactMap { UIImage(data: $0) }.prefix(3))
    }

    /// Converts `UIImage` array to `Data` array for storage.
    /// Ensures the number of images does not exceed the maximum of 3.
    /// - Returns: An array of `Data` representations of the images.
    func getImagesAsData() -> [Data] {
        Array(uiImages.prefix(3)).compactMap { $0.jpegData(compressionQuality: 1.0) }
    }

    /// Resets the selected images to an empty array.
    func resetImages() {
        uiImages = []
    }
}





