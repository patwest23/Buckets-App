//
//  UserViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 12/29/24.
//

import FirebaseFirestore
import Foundation

@MainActor
class UserViewModel: ObservableObject {
    @Published var user: UserModel?

    private let db = Firestore.firestore()

    // MARK: - Fetch User Data
    func fetchUserData(userId: String) async {
        do {
            let snapshot = try await db.collection("users").document(userId).getDocument()
            // Correctly handle the optional returned by `snapshot.data(as:)`
            self.user = try snapshot.data(as: UserModel.self) // `self.user` will be nil if decoding fails
            if let user = self.user {
                print("User data fetched successfully: \(user)")
            } else {
                print("No user data found for ID \(userId).")
            }
        } catch {
            print("Error fetching user data: \(error.localizedDescription)")
        }
    }

    // MARK: - Update User Profile
    func updateUserProfile(_ updatedUser: UserModel) async {
        guard let userId = updatedUser.id else {
            print("Error: User ID is nil.")
            return
        }

        do {
            try await db.collection("users").document(userId).setData(from: updatedUser)
            DispatchQueue.main.async {
                self.user = updatedUser
            }
            print("User profile updated successfully.")
        } catch {
            print("Error updating user profile: \(error.localizedDescription)")
        }
    }

    // MARK: - Update Bucket List Item
    func updateBucketListItem(_ item: ItemModel) async {
        guard let userId = user?.id else {
            print("Error: No user ID available.")
            return
        }

        let itemRef = db.collection("users").document(userId).collection("bucketList").document(item.id.uuidString)
        do {
            try await itemRef.setData(from: item, merge: true)
            print("Bucket list item \(item.id) updated successfully.")
        } catch {
            print("Error updating bucket list item: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete Bucket List Item
    func deleteBucketListItem(_ item: ItemModel) async {
        guard let userId = user?.id else {
            print("Error: No user ID available.")
            return
        }

        let itemRef = db.collection("users").document(userId).collection("bucketList").document(item.id.uuidString)
        do {
            try await itemRef.delete()
            print("Bucket list item \(item.id) deleted successfully.")
        } catch {
            print("Error deleting bucket list item: \(error.localizedDescription)")
        }
    }
}
