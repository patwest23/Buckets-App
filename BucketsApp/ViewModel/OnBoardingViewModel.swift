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
    @Published var profileImageData: Data? // Profile image data
    @Published var user: UserModel?        // User object
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false

    // MARK: - Firebase References
    private let storage = Storage.storage()
    private let firestore = Firestore.firestore()
    private let profileImagePath = "profile_images"

    // MARK: - Initializer
    init() {
        // Configure Firestore cache settings (instead of `isPersistenceEnabled`)
        let settings = FirestoreSettings()
        let persistentCache = PersistentCacheSettings()
        // persistentCache.sizeBytes = 10485760 // e.g., 10MB cache, if desired
        settings.cacheSettings = persistentCache
        firestore.settings = settings

        checkIfUserIsAuthenticated()
    }

    // MARK: - Authentication Functions

    /// Check current authentication status
    func checkIfUserIsAuthenticated() {
        guard let currentUser = Auth.auth().currentUser else {
            isAuthenticated = false
            return
        }

        isAuthenticated = true
        Task {
            await fetchUserDocument(userId: currentUser.uid)
            await loadProfileImage()
        }
    }

    /// Sign in with email and password
    func signIn() async {
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            await fetchUserDocument(userId: authResult.user.uid)
            await loadProfileImage()
        } catch {
            handleError(error)
        }
    }

    /// Sign out the current user
    func signOut() async {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            clearState()
        } catch {
            handleError(error)
        }
    }

    /// Create a new user with email/password
    func createUser() async {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()

            // Create Firestore doc for the new user
            await createUserDocument(userId: authResult.user.uid)
            // Fetch user doc to populate `user` property
            await fetchUserDocument(userId: authResult.user.uid)
        } catch {
            handleError(error)
        }
    }

    /// Send a password reset email
    func resetPassword(for email: String) async -> Result<String, Error> {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return .success("A link to reset your password has been sent to \(email).")
        } catch {
            return .failure(error)
        }
    }

    /// Update the authenticated user's email
    func updateEmail(newEmail: String) async -> Result<String, Error> {
        guard let currentUser = Auth.auth().currentUser else {
            return .failure(
                NSError(
                    domain: "AuthError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No user is logged in."]
                )
            )
        }

        do {
            // 1) Send an email verification before updating the email
            try await currentUser.sendEmailVerification(beforeUpdatingEmail: newEmail)
            
            // 2) Update the email field in Firestore
            let userDoc = firestore.collection("users").document(currentUser.uid)
            // NOTE: If `updateData` is recognized as async in your SDK, you can do:
            // try await userDoc.updateData(["email": newEmail])
            // Otherwise, wrap it in a continuation to remove concurrency warnings:
            let dataToUpdate: [String: String] = ["email": newEmail]
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                userDoc.updateData(dataToUpdate) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            
            // 3) Update your local state on the main actor
            //    (already on the main actor, but we do it explicitly for clarity)
            self.email = newEmail
            
            // 4) Inform the user to verify their email
            return .success(
                "Verification sent to \(newEmail). Once verified, your email will be updated."
            )
        } catch {
            return .failure(error)
        }
    }

    /// Update the authenticated user's password
    func updatePassword(currentPassword: String, newPassword: String) async throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(
                domain: "AuthError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No user is logged in."]
            )
        }

        // Re-authenticate with the current password
        let credential = EmailAuthProvider.credential(
            withEmail: currentUser.email ?? "",
            password: currentPassword
        )
        try await currentUser.reauthenticate(with: credential)

        // Update to the new password
        try await currentUser.updatePassword(to: newPassword)

        // Return a success message (or handle however you like)
        return "Password updated successfully."
    }

    // MARK: - Profile Image Functions

    /// Update the profile image in Firebase Storage
    func updateProfileImage(with data: Data?) async {
        profileImageData = data
        guard let currentUser = Auth.auth().currentUser, let data = data else { return }
        let storageRef = storage.reference().child("\(profileImagePath)/\(currentUser.uid).jpg")
        do {
            // Uses concurrency-based `putDataAsync` from newer SDK
            try await storageRef.putDataAsync(data)
            print("Profile image uploaded successfully.")
        } catch {
            handleError(error)
        }
    }

    /// Load the profile image from Firebase Storage
    func loadProfileImage() async {
        guard let currentUser = Auth.auth().currentUser else {
            print("No user signed in.")
            return
        }
        let storageRef = storage.reference().child("\(profileImagePath)/\(currentUser.uid).jpg")
        do {
            let data = try await storageRef.getDataAsync(maxSize: 5 * 1024 * 1024)
            profileImageData = data
            print("Profile image loaded successfully.")
        } catch {
            print("Error loading profile image: \(error.localizedDescription)")
        }
    }

    // MARK: - Firestore Integration

    /// Create a new Firestore document for the user
    private func createUserDocument(userId: String) async {
        let userDoc = firestore.collection("users").document(userId)
        do {
            // If recognized as async, you can call directly:
            try await userDoc.setData([
                "email": email,
                "createdAt": Date()
            ])
            print("User document created successfully.")
        } catch {
            handleError(error)
        }
    }

    /// Fetch the Firestore document for the user using Codable
    private func fetchUserDocument(userId: String) async {
        let userDoc = firestore.collection("users").document(userId)
        do {
            // If recognized as async in your SDK:
            let snapshot = try await userDoc.getDocument()
            if snapshot.exists {
                // Attempt to decode
                self.user = try snapshot.data(as: UserModel.self)
                print("User document fetched successfully.")
            } else {
                print("No user document found. Creating a new one...")
                await createUserDocument(userId: userId)
            }
        } catch {
            print("Error fetching or decoding user document: \(error.localizedDescription)")
        }
    }

    // MARK: - Error Handling

    /// Handle and display errors
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showErrorAlert = true
        print("Error: \(error.localizedDescription)")
    }

    /// Clear all user data and error states
    private func clearState() {
        email = ""
        password = ""
        profileImageData = nil
        user = nil
        errorMessage = nil
        showErrorAlert = false
    }

    /// Clear only error states
    private func clearErrorState() {
        errorMessage = nil
        showErrorAlert = false
    }
}
