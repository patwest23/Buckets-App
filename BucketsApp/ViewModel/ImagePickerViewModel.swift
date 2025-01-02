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
    // MARK: - Published Properties
    @Published var uiImages: [UIImage] = []      // Holds the final selected images (max 3)
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

    // MARK: - Firebase References
    private let storage = Storage.storage()
    private let db = Firestore.firestore()

    // MARK: - Initialization
    init() {
        // Enable Firestore’s offline caching via cacheSettings
        let settings = FirestoreSettings()
        let persistentCache = PersistentCacheSettings()
        // persistentCache.sizeBytes = 10485760 // (Optional) e.g. 10MB cache
        settings.cacheSettings = persistentCache
        db.settings = settings
    }

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
        uiImages = Array(loadedImages.prefix(maxImages))
        await uploadImagesToFirestore()
    }

    // MARK: - Upload Images

    /// Uploads selected images to Firebase Storage and updates Firestore with their URLs.
    private func uploadImagesToFirestore() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let storageRef = storage.reference().child("users/\(userId)/images")
        var uploadedImageUrls: [String] = []

        // 1) Upload each image to Storage
        for (index, image) in uiImages.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
            let imageRef = storageRef.child("image\(index + 1).jpg")
            do {
                // If recognized as async:
                try await imageRef.putDataAsync(imageData)
                
                // If recognized as async:
                let downloadUrl = try await imageRef.downloadURL()
                uploadedImageUrls.append(downloadUrl.absoluteString)
            } catch {
                print("Error uploading image: \(error.localizedDescription)")
            }
        }

        // 2) Update Firestore with the new image URLs
        // If `setData` is recognized as async, you can do:
        // try await db.collection("users")
        //    .document(userId)
        //    .setData(["images": uploadedImageUrls], merge: true)
        // Otherwise, use the bridging approach:
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                db.collection("users")
                    .document(userId)
                    .setData(["images": uploadedImageUrls], merge: true) { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
            }
            print("Firestore updated with image URLs.")
        } catch {
            print("Error updating Firestore: \(error.localizedDescription)")
        }
    }

    // MARK: - Resetting & Clearing Images

    /// Resets the selected images to an empty array, then clears them in Firestore/Storage.
    func resetImages() {
        uiImages = []
        imageSelections = [] // Clear the PhotosPicker selection
        Task {
            await clearImagesInFirestore()
        }
    }

    /// Clears all images for the user from Firebase Storage and Firestore.
    private func clearImagesInFirestore() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let storageRef = storage.reference().child("users/\(userId)/images")

        do {
            // If recognized as async:
            let result = try await storageRef.listAll()
            for item in result.items {
                try await item.delete() // concurrency-based call if recognized
            }

            // Remove the image array field from Firestore
            // If `updateData` is recognized as async:
            // try await db.collection("users").document(userId).updateData(["images": FieldValue.delete()])
            // Otherwise bridging:
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                db.collection("users")
                    .document(userId)
                    .updateData(["images": FieldValue.delete()]) { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
            }
            print("Images cleared from Firestore and Storage.")
        } catch {
            print("Error clearing images: \(error.localizedDescription)")
        }
    }

    // MARK: - Local Loading & Conversion

    /// Loads existing UIImages from raw image `Data`.
    func loadExistingImages(from imageDataArray: [Data]) {
        uiImages = Array(imageDataArray.compactMap { UIImage(data: $0) }.prefix(maxImages))
    }

    /// Converts the current UIImages to `Data` array for local storage or other usage.
    func getImagesAsData() -> [Data] {
        Array(uiImages.prefix(maxImages)).compactMap {
            $0.jpegData(compressionQuality: 1.0)
        }
    }
}





