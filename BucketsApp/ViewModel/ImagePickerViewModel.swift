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
    @Published var uiImages: [UIImage] = []
    @Published var imageSelections: [PhotosPickerItem] = [] {
        didSet {
            if !imageSelections.isEmpty {
                Task {
                    await loadImages()
                }
            }
        }
    }

    func loadImages() async {
        uiImages.removeAll()
        for selection in imageSelections {
            if let data = try? await selection.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                uiImages.append(image)
            }
        }
    }

    func loadExistingImages(from imageDataArray: [Data]) {
        uiImages = imageDataArray.compactMap { UIImage(data: $0) }
    }
}





