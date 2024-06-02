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
    @Published var uiImage: UIImage?
    @Published var imageSelection: PhotosPickerItem? {
        didSet {
            if let imageSelection = imageSelection {
                Task {
                    try await loadImage(from: imageSelection)
                }
            }
        }
    }
    
    func loadImage(from imageSelection: PhotosPickerItem) async throws {
        do {
            if let data = try await imageSelection.loadTransferable(type: Data.self) {
                self.uiImage = UIImage(data: data)
            }
        } catch {
            print(error.localizedDescription)
            self.uiImage = nil
        }
    }
}



