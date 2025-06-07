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
    @Published var allUsers: [UserModel] = []
    
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
    
    func fetchUser(with userId: String) async throws -> UserModel {
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(userId)
        let snapshot = try await docRef.getDocument()
        return try snapshot.data(as: UserModel.self)
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
                    userInfo: [
                        NSLocalizedDescriptionKey: "No user document found for ID \(userId)."
                    ]
                )
                self.handleError(noDocError, prefix: "startListeningToUserDoc")
                return
            }
            
            do {
                let updatedUser = try snapshot.data(as: UserModel.self)
                self.user = updatedUser
                print("[UserViewModel] user set =>", updatedUser)
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
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                
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
            print("[UserViewModel] updateUserProfile: User doc updated for /users/\(userId). user.id =", updatedUser.id ?? "nil")
            
        } catch {
            handleError(error, prefix: "updateUserProfile")
        }
    }
    
    // MARK: - Update Username for User & All Items
    /// Updates the user's name to `newName` (e.g. "@JaneDoe") and then
    /// batch-updates all item docs in `/users/<userId>/items` to reflect this new `userName`.
    func updateUserName(to newName: String) async {
        // 1) Validate new name
        guard newName.hasPrefix("@") else {
            let err = NSError(domain: "InvalidUsername",
                              code: 400,
                              userInfo: [NSLocalizedDescriptionKey: "Username must start with @"])
            handleError(err, prefix: "updateUserName")
            return
        }
        
        // 2) Ensure user doc ID is known
        guard let userId = user?.id else {
            let err = NSError(domain: "AuthError",
                              code: 401,
                              userInfo: [NSLocalizedDescriptionKey: "No user ID found."])
            handleError(err, prefix: "updateUserName")
            return
        }
        
        // 3) Start a Firestore batch
        let batch = db.batch()
        
        // 4) Update the user doc's "name" field
        let userRef = db.collection("users").document(userId)
        batch.updateData(["name": newName], forDocument: userRef)
        
        // 5) Fetch all item docs in `/users/<userId>/items`
        do {
            let itemsSnapshot = try await db.collection("users")
                .document(userId)
                .collection("items")
                .getDocuments()
            
            // 6) For each item doc, update "userName" to `newName`
            for itemDoc in itemsSnapshot.documents {
                batch.updateData(["userName": newName], forDocument: itemDoc.reference)
            }
            
            // 7) Commit the batch
            try await batch.commit()
            print("[UserViewModel] updateUserName: Batch updated user doc + \(itemsSnapshot.documents.count) item docs.")
            
            // 8) Update local user object
            user?.name = newName
            
        } catch {
            handleError(error, prefix: "updateUserName")
        }
    }
    
    /// Checks if a given username is already taken by any user in the database
    func isUsernameTaken(_ username: String) async -> Bool {
        do {
            let snapshot = try await db.collection("users")
                .whereField("name", isEqualTo: username)
                .getDocuments()
            return !snapshot.documents.isEmpty
        } catch {
            print("[UserViewModel] Error checking username:", error.localizedDescription)
            return true // Assume taken on failure
        }
    }
    
    /// Sets the username if it's not already taken. Returns true if successful.
    func setUsernameIfAvailable(_ username: String) async -> Bool {
        let isTaken = await isUsernameTaken(username)
        guard isTaken == false else { return false }
        await updateUserName(to: username)
        return true
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error, prefix: String) {
        print("[UserViewModel] \(prefix) Error:", error.localizedDescription)
        errorMessage = error.localizedDescription
        showErrorAlert = true
    }
    // MARK: - Computed Properties
    var userId: String? {
        user?.id
    }
    
    var userIsAuthenticated: Bool {
        user?.id?.isEmpty == false
    }

    // MARK: - Fetch Users by ID List
    func fetchUsers(withIDs ids: [String]) async -> [UserModel] {
        var users: [UserModel] = []
        for id in ids {
            do {
                let docRef = db.collection("users").document(id)
                let snapshot = try await docRef.getDocument()
                if let user = try? snapshot.data(as: UserModel.self) {
                    users.append(user)
                }
            } catch {
                print("[UserViewModel] Error fetching user with ID \(id):", error.localizedDescription)
            }
        }
        return users
    }
    
    // MARK: - Fetch All Users (Used in Explore Tab)
    /// Loads all users from Firestore and assigns them to `allUsers`.
    func loadAllUsers() async {
        do {
            let snapshot = try await db.collection("users").getDocuments()
            var users: [UserModel] = []
            for doc in snapshot.documents {
                print("[UserSearchViewModel] Raw user data:", doc.data())
                if let user = try? doc.data(as: UserModel.self) {
                    users.append(user)
                }
            }
            self.allUsers = users
            if self.user?.following == nil {
                self.user?.following = []
            }
            if self.user?.followers == nil {
                self.user?.followers = []
            }
        } catch {
            print("[UserViewModel] loadAllUsers error:", error.localizedDescription)
            self.allUsers = []
        }
    }
}
