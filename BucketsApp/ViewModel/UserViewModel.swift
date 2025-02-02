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
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false
    
    // MARK: - Firestore
    private let db = Firestore.firestore()
    private var userDocListener: ListenerRegistration?
    
    // MARK: - Initialization
    init() {
        print("[UserViewModel] init.")
    }
    
    deinit {
        userDocListener?.remove()
        print("[UserViewModel] deinit.")
    }
    
    // MARK: - One-Time Fetch
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
                            userInfo: [NSLocalizedDescriptionKey: "No user document found for ID \(userId)."]
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
            print("[UserViewModel] fetchUserData: Successfully fetched user doc for /users/\(userId). user.id =", fetchedUser.id ?? "nil")
            
            // If doc ID doesn't match, log a warning
            if fetchedUser.id != userId {
                print("[UserViewModel] Warning: User doc ID (\(fetchedUser.id ?? "nil")) != Auth UID (\(userId))")
            }
            
        } catch {
            handleError(error, prefix: "fetchUserData")
        }
    }
    
    // MARK: - Real-Time Listener
    func startListeningToUserDoc(for userId: String) {
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
                    userInfo: [NSLocalizedDescriptionKey: "No user document found for ID \(userId)."]
                )
                self.handleError(noDocError, prefix: "startListeningToUserDoc")
                return
            }
            
            do {
                let updatedUser = try snapshot.data(as: UserModel.self)
                self.user = updatedUser
                print("[UserViewModel] Real-time update for /users/\(userId). user.id =", updatedUser.id ?? "nil")
            } catch {
                self.handleError(error, prefix: "startListeningToUserDoc")
            }
        }
    }
    
    func stopListeningToUserDoc() {
        userDocListener?.remove()
        userDocListener = nil
        print("[UserViewModel] Stopped listening to user doc.")
    }
    
    // MARK: - Update User Profile
    func updateUserProfile(_ updatedUser: UserModel) async {
        guard let userId = updatedUser.id else {
            print("[UserViewModel] updateUserProfile: Error: updatedUser.id is nil.")
            return
        }
        
        do {
            // 1) Merge updated fields into /users/<userId>
            try await withCheckedThrowingContinuation { continuation in
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
            
            // 2) Update local user property
            self.user = updatedUser
            print("[UserViewModel] updateUserProfile: User doc updated for /users/\(userId). user.id =", updatedUser.id ?? "nil")
            
        } catch {
            handleError(error, prefix: "updateUserProfile")
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error, prefix: String) {
        print("[UserViewModel] \(prefix) Error:", error.localizedDescription)
        errorMessage = error.localizedDescription
        showErrorAlert = true
    }
}
