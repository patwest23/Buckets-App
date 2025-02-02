//
//  OnBoardingViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/15/23.
//

import Foundation
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isAuthenticated: Bool = false
    @Published var profileImageData: Data?
    @Published var user: UserModel?
    
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false
    
    // MARK: - Firebase References
    private let storage = Storage.storage()
    private let firestore = Firestore.firestore()
    private let profileImagePath = "profile_images"
    
    private var userDocListener: ListenerRegistration?
    
    /// Convenience: user doc ID from `UserModel` (should match Auth UID)
    var userId: String? {
        user?.id
    }
    
    // MARK: - Init / Deinit
    init() {
        checkIfUserIsAuthenticated()
    }
    
    deinit {
        userDocListener?.remove()
    }
    
    // MARK: - Check Auth State
    func checkIfUserIsAuthenticated() {
        Task {
            if let currentUser = Auth.auth().currentUser {
                isAuthenticated = true
                print("[OnboardingViewModel] Already signed in with UID:", currentUser.uid)
                
                // Fetch user doc & profile image
                await fetchUserDocument(userId: currentUser.uid)
                await loadProfileImage()
            } else {
                print("[OnboardingViewModel] No authenticated user found.")
                isAuthenticated = false
            }
        }
    }
    
    func validateAuthSession() -> Bool {
        guard Auth.auth().currentUser != nil else {
            self.isAuthenticated = false
            handleError(NSError(
                domain: "AuthError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User session expired."]
            ))
            return false
        }
        return true
    }
    
    // MARK: - Sign In / Sign Out
    func signIn() async {
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            
            print("[OnboardingViewModel] signIn successful. Auth UID:", authResult.user.uid)
            
            await fetchUserDocument(userId: authResult.user.uid)
            await loadProfileImage()
        } catch {
            handleError(error)
        }
    }
    
    func signOut() async {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            userDocListener?.remove()
            clearState()
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Create User
    func createUser() async {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            
            print("[OnboardingViewModel] createUser successful. Auth UID:", authResult.user.uid)
            
            // Create Firestore doc for the new user at /users/<AuthUID>
            await createUserDocument(userId: authResult.user.uid)
            
            // Fetch user doc to populate `user`
            await fetchUserDocument(userId: authResult.user.uid)
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Real-Time User Doc Listener (Optional)
    func startListeningToUserDocument(userId: String) {
        userDocListener?.remove()
        let docRef = firestore.collection("users").document(userId)
        
        userDocListener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("[OnboardingViewModel] Error listening to user doc:", error.localizedDescription)
                self.handleError(error)
                return
            }
            guard let snapshot = snapshot, snapshot.exists else {
                print("[OnboardingViewModel] User doc not found or removed.")
                return
            }
            
            do {
                self.user = try snapshot.data(as: UserModel.self)
                print("[OnboardingViewModel] User doc updated in real-time. ID =", self.user?.id ?? "nil")
            } catch {
                self.handleError(error)
            }
        }
    }
    
    func stopListeningToUserDocument() {
        userDocListener?.remove()
        userDocListener = nil
    }
    
    // MARK: - Password Reset
    func resetPassword(for email: String) async -> Result<String, Error> {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return .success("A link to reset your password has been sent to \(email).")
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Update Email
    func updateEmail(newEmail: String) async -> Result<String, Error> {
        guard let currentUser = Auth.auth().currentUser else {
            return .failure(NSError(domain: "AuthError", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "No user is logged in."]))
        }
        
        do {
            try await currentUser.sendEmailVerification(beforeUpdatingEmail: newEmail)
            
            let userDoc = firestore.collection("users").document(currentUser.uid)
            let dataToUpdate: [String: String] = ["email": newEmail]
            try await withCheckedThrowingContinuation { continuation in
                userDoc.updateData(dataToUpdate) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            
            self.email = newEmail
            return .success("Verification sent to \(newEmail). Once verified, your email will be updated.")
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Update Password
    func updatePassword(currentPassword: String, newPassword: String) async throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "AuthError", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No user is logged in."])
        }
        
        // Re-auth the user
        let credential = EmailAuthProvider.credential(
            withEmail: currentUser.email ?? "",
            password: currentPassword
        )
        try await currentUser.reauthenticate(with: credential)
        
        // Update password
        try await currentUser.updatePassword(to: newPassword)
        return "Password updated successfully."
    }
    
    // MARK: - Profile Image Management
    func updateProfileImage(with data: Data?) async {
        profileImageData = data
        guard let currentUser = Auth.auth().currentUser, let data = data else { return }
        
        let storageRef = storage.reference().child("\(profileImagePath)/\(currentUser.uid).jpg")
        do {
            try await storageRef.putDataAsync(data)
            let downloadURL = try await storageRef.downloadURL()
            
            let updates: [String: String] = ["profileImageUrl": downloadURL.absoluteString]
            try await firestore.collection("users").document(currentUser.uid).updateData(updates)
            
            print("[OnboardingViewModel] Profile image uploaded, Firestore updated.")
        } catch {
            handleError(error)
        }
    }
    
    func loadProfileImage() async {
        guard let currentUser = Auth.auth().currentUser else {
            print("[OnboardingViewModel] No user signed in.")
            return
        }
        
        let storageRef = storage.reference().child("\(profileImagePath)/\(currentUser.uid).jpg")
        do {
            let data = try await storageRef.getDataAsync(maxSize: 5 * 1024 * 1024)
            profileImageData = data
            print("[OnboardingViewModel] Profile image loaded successfully.")
        } catch {
            print("[OnboardingViewModel] Error loading profile image:", error.localizedDescription)
        }
    }
    
    // MARK: - Firestore Integration
    private func createUserDocument(userId: String) async {
        let userDoc = firestore.collection("users").document(userId)
        do {
            try await userDoc.setData([
                "email": email,
                "createdAt": Date()
            ])
            print("[OnboardingViewModel] User document created at /users/\(userId).")
        } catch {
            handleError(error)
        }
    }
    
    func fetchUserDocument(userId: String) async {
        let userDoc = firestore.collection("users").document(userId)
        do {
            let snapshot = try await userDoc.getDocument()
            guard snapshot.exists else {
                print("[OnboardingViewModel] No user document found at /users/\(userId). Creating new...")
                await createUserDocument(userId: userId)
                return
            }
            
            self.user = try snapshot.data(as: UserModel.self)
            print("[OnboardingViewModel] User doc fetched. user?.id =", self.user?.id ?? "nil")
            
            // Debug: Check if matches
            if self.user?.id == userId {
                print("[OnboardingViewModel] User doc ID matches Auth UID:", userId)
            } else {
                print("[OnboardingViewModel] Warning: user doc ID mismatch. docID =", self.user?.id ?? "nil",
                      "AuthUID =", userId)
            }
            
        } catch {
            print("[OnboardingViewModel] Error fetching/decoding user doc:", error.localizedDescription)
            handleError(error)
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showErrorAlert = true
        print("[OnboardingViewModel] Error:", error.localizedDescription)
    }
    
    private func clearErrorState() {
        errorMessage = nil
        showErrorAlert = false
    }
    
    // Clears out fields when user signs out or for a fresh start
    private func clearState() {
        print("[OnboardingViewModel] Clearing state...")
        email = ""
        password = ""
        profileImageData = nil
        user = nil
        errorMessage = nil
        showErrorAlert = false
        isAuthenticated = false
    }
}
