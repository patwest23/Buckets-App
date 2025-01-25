//
//  UserViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 12/29/24.
//

import SwiftUI
import FirebaseFirestore

@MainActor
class UserViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var user: UserModel?

    // MARK: - Firestore Reference
    private let db = Firestore.firestore()

    // MARK: - Initializer
    init() {
        // No Firestore settings here if done once elsewhere
    }

    // MARK: - Fetch User Data
    func fetchUserData(userId: String) async {
        do {
            let fetchedUser = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UserModel, Error>) in
                db.collection("users").document(userId).getDocument { snapshot, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let snapshot = snapshot, snapshot.exists else {
                        let noDocumentError = NSError(domain: "NoDocumentFound", code: 404, userInfo: [
                            NSLocalizedDescriptionKey: "No user document found for ID \(userId)."
                        ])
                        continuation.resume(throwing: noDocumentError)
                        return
                    }

                    do {
                        let user = try snapshot.data(as: UserModel.self)
                        continuation.resume(returning: user)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            self.user = fetchedUser
            print("User data fetched successfully: \(fetchedUser)")
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
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                do {
                    try db
                        .collection("users")
                        .document(userId)
                        .setData(from: updatedUser, merge: true) { error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: ())
                            }
                        }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            self.user = updatedUser
            print("User profile updated successfully.")
        } catch {
            print("Error updating user profile: \(error.localizedDescription)")
        }
    }
}
