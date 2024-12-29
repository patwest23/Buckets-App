//
//  ImagePicker.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/21/23.
//

import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

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
    
    private let maxImages: Int = 3 // Define a constant for the maximum images allowed
    private let storage = Storage.storage() // Firebase Storage reference
    private let db = Firestore.firestore() // Firestore reference

    /// Asynchronously loads images from the selected `PhotosPickerItem`.
    /// Ensures the number of images does not exceed the maximum limit.
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
                print("Error loading image: \(error.localizedDescription)")
            }
        }
        uiImages = Array(loadedImages.prefix(maxImages)) // Update images locally
        await uploadImagesToFirestore() // Sync with Firestore
    }

    /// Uploads selected images to Firebase Storage and updates Firestore with their URLs.
    private func uploadImagesToFirestore() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let storageRef = storage.reference().child("users/\(userId)/images")
        var uploadedImageUrls: [String] = []

        for (index, image) in uiImages.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
            let imageRef = storageRef.child("image\(index + 1).jpg")
            do {
                _ = try await imageRef.putDataAsync(imageData)
                let downloadUrl = try await imageRef.downloadURL()
                uploadedImageUrls.append(downloadUrl.absoluteString)
            } catch {
                print("Error uploading image: \(error.localizedDescription)")
            }
        }

        // Update Firestore with the new image URLs
        do {
            try await db.collection("users").document(userId).setData(["images": uploadedImageUrls], merge: true)
            print("Firestore updated with image URLs.")
        } catch {
            print("Error updating Firestore: \(error.localizedDescription)")
        }
    }

    /// Loads existing images from stored `Data`.
    /// Ensures the number of images does not exceed the maximum limit.
    /// - Parameter imageDataArray: An array of image data.
    func loadExistingImages(from imageDataArray: [Data]) {
        uiImages = Array(imageDataArray.compactMap { UIImage(data: $0) }.prefix(maxImages))
    }

    /// Converts `UIImage` array to `Data` array for storage.
    /// Ensures the number of images does not exceed the maximum limit.
    /// - Returns: An array of `Data` representations of the images.
    func getImagesAsData() -> [Data] {
        Array(uiImages.prefix(maxImages)).compactMap { $0.jpegData(compressionQuality: 1.0) }
    }

    /// Resets the selected images to an empty array.
    func resetImages() {
        uiImages = []
        imageSelections = [] // Ensure the PhotosPicker state is cleared
        Task {
            await clearImagesInFirestore() // Clear images from Firestore
        }
    }

    /// Clears all images for the user from Firebase Storage and Firestore.
    private func clearImagesInFirestore() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let storageRef = storage.reference().child("users/\(userId)/images")

        do {
            // List and delete all images in the user's storage folder
            let result = try await storageRef.listAll()
            for item in result.items {
                try await item.delete()
            }

            // Remove image URLs from Firestore
            try await db.collection("users").document(userId).updateData(["images": FieldValue.delete()])
            print("Images cleared from Firestore and Storage.")
        } catch {
            print("Error clearing images: \(error.localizedDescription)")
        }
    }
}





