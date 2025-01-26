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
    
    /// The user document from Firestore.
    @Published var user: UserModel?
    
    /// If you want to show errors in the UI, you can store them here
    /// and display them in an alert or a text label.
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false
    
    // MARK: - Firestore Reference
    
    private let db = Firestore.firestore()
    private var userDocListener: ListenerRegistration?
    
    // MARK: - Initialization
    
    init() {
        // Nothing special here.
        // If you want, you can automatically call fetch or listen to user doc, e.g.:
        // startListeningToUserDoc(for: someUserID)
    }
    
    deinit {
        // Remove the listener to avoid memory leaks
        userDocListener?.remove()
    }
    
    // MARK: - One-Time Fetch
    
    /// Fetches user data for a given userID (one-time only).
    func fetchUserData(userId: String) async {
        do {
            let fetchedUser: UserModel = try await withCheckedThrowingContinuation { continuation in
                db.collection("users").document(userId).getDocument { snapshot, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let snapshot = snapshot, snapshot.exists else {
                        let noDocError = NSError(
                            domain: "NoDocumentFound",
                            code: 404,
                            userInfo: [
                                NSLocalizedDescriptionKey: "No user document found for ID \(userId)."
                            ]
                        )
                        continuation.resume(throwing: noDocError)
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
            print("[UserViewModel] User data fetched successfully for user \(userId).")
        } catch {
            handleError(error, prefix: "fetchUserData")
        }
    }
    
    // MARK: - Real-Time Listener (Optional)
    
    /// If you want continuous real-time updates to the user doc, call this method instead of `fetchUserData`.
    /// The `user` property will automatically update whenever the Firestore doc changes.
    func startListeningToUserDoc(for userId: String) {
        // Remove old listener if any
        userDocListener?.remove()
        
        let docRef = db.collection("users").document(userId)
        userDocListener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleError(error, prefix: "startListeningToUserDoc")
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                let noDocError = NSError(
                    domain: "NoDocumentFound",
                    code: 404,
                    userInfo: [
                        NSLocalizedDescriptionKey: "No user document found for ID \(userId)."
                    ]
                )
                self.handleError(noDocError, prefix: "startListeningToUserDoc")
                return
            }
            
            do {
                self.user = try snapshot.data(as: UserModel.self)
                print("[UserViewModel] User doc updated in real-time for user \(userId).")
            } catch {
                self.handleError(error, prefix: "startListeningToUserDoc")
            }
        }
    }
    
    /// Stop listening to the user document.
    func stopListeningToUserDoc() {
        userDocListener?.remove()
        userDocListener = nil
        print("[UserViewModel] Stopped listening to user doc.")
    }
    
    // MARK: - Update User Profile
    
    /// Writes a new version of the user doc to Firestore (merging fields).
    func updateUserProfile(_ updatedUser: UserModel) async {
        guard let userId = updatedUser.id else {
            print("[UserViewModel] Error: User ID is nil in `updatedUser`.")
            return
        }
        
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                do {
                    try db.collection("users")
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
            print("[UserViewModel] User profile updated successfully for user \(userId).")
        } catch {
            handleError(error, prefix: "updateUserProfile")
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error, prefix: String) {
        print("[UserViewModel] \(prefix) Error: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
        showErrorAlert = true
    }
}
