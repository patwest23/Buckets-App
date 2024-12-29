//
//  Extensions.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 12/13/24.
//

import FirebaseStorage
import Foundation
import UIKit

extension StorageReference {
    /// Retrieves data from Firebase Storage asynchronously.
    /// - Parameter maxSize: The maximum size of the data in bytes.
    /// - Returns: The retrieved data as `Data`.
    func getDataAsync(maxSize: Int64) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            self.getData(maxSize: maxSize) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "FirebaseStorage",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred."]
                    ))
                }
            }
        }
    }

    /// Uploads data to Firebase Storage asynchronously.
    /// - Parameters:
    ///   - uploadData: The data to upload.
    ///   - metadata: Optional metadata for the upload.
    func putDataAsync(_ uploadData: Data, metadata: StorageMetadata? = nil) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.putData(uploadData, metadata: metadata) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

extension UIImage {
    /// Resizes the image to a specified width while maintaining the aspect ratio.
    /// - Parameter width: The desired width for the resized image.
    /// - Returns: A resized `UIImage` or the original image if resizing fails.
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width / size.width * size.height)))
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}