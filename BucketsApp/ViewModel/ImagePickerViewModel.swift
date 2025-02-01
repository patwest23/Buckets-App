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
    // MARK: - Published Properties
    @Published var uiImages: [UIImage] = []  // Holds the final selected images (max 3)
    @Published var imageSelections: [PhotosPickerItem] = [] {
        didSet {
            guard !imageSelections.isEmpty else { return }
            Task {
                await loadImages(from: imageSelections)
            }
        }
    }
    
    // MARK: - Constants
    private let maxImages: Int = 3 // Maximum allowed images
    
    // MARK: - Load Images from Selections
    /// Asynchronously loads images from the selected `PhotosPickerItem`.
    /// Ensures the number of images does not exceed `maxImages`.
    private func loadImages(from selections: [PhotosPickerItem]) async {
        var loadedImages: [UIImage] = []
        
        for selection in selections {
            do {
                if let data = try await selection.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loadedImages.append(image)
                }
            } catch {
                print("Error loading image: \(error.localizedDescription)")
            }
        }
        // Limit the uiImages to maxImages
        uiImages = Array(loadedImages.prefix(maxImages))
    }
    
    // MARK: - Local Loading & Conversion
    /// Loads existing UIImages from raw image `Data` (purely local usage).
    func loadExistingImages(from imageDataArray: [Data]) {
        uiImages = Array(imageDataArray.compactMap { UIImage(data: $0) }
                                    .prefix(maxImages))
    }
    
    /// Converts the current UIImages to a `[Data]` array (for local storage or other usage).
    func getImagesAsData() -> [Data] {
        uiImages.prefix(maxImages).compactMap {
            $0.jpegData(compressionQuality: 1.0)
        }
    }
}




