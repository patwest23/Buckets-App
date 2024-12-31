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
    // Published properties for UI state
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isAuthenticated: Bool = false
    @Published var profileImageData: Data? // Stores the profile image data
    @Published var user: UserModel? // User object
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false

    private let storage = Storage.storage()
    private let firestore = Firestore.firestore()
    private let profileImagePath = "profile_images"

    init() {
        checkIfUserIsAuthenticated()
    }

    // MARK: - Authentication Functions

    /// Check the current authentication status
    func checkIfUserIsAuthenticated() {
        if let currentUser = Auth.auth().currentUser {
            isAuthenticated = true
            Task {
                await fetchUserDocument(userId: currentUser.uid)
                await loadProfileImage()
            }
        } else {
            isAuthenticated = false
        }
    }

    /// Sign in a user with email and password
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

    /// Create a new user with email and password
    func createUser() async {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            await createUserDocument(userId: authResult.user.uid)
            await fetchUserDocument(userId: authResult.user.uid)
        } catch {
            handleError(error)
        }
    }

    /// Reset the password for a given email
    func resetPassword(for email: String) async -> Result<String, Error> {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return .success("A link to reset your password has been sent to \(email).")
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Profile Image Functions

    /// Update the profile image in Firebase Storage
    func updateProfileImage(with data: Data?) async {
        profileImageData = data
        guard let currentUser = Auth.auth().currentUser, let data = data else { return }
        let storageRef = storage.reference().child("\(profileImagePath)/\(currentUser.uid).jpg")
        do {
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
            let data = try await storageRef.getDataAsync(maxSize: 5 * 1024 * 1024) // Max 5MB
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
            let snapshot = try await userDoc.getDocument()
            if snapshot.exists {
                self.user = try snapshot.data(as: UserModel.self)
                print("User document fetched successfully.")
            } else {
                print("No user document found. Creating a new one...")
                await createUserDocument(userId: userId)
            }
        } catch {
            print("Error fetching user document: \(error.localizedDescription)")
        }
    }

    // MARK: - Error Handling

    /// Handle and display errors
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showErrorAlert = true
        print("Error: \(error.localizedDescription)")
    }

    /// Clear the user's data and error states
    private func clearState() {
        email = ""
        password = ""
        profileImageData = nil
        user = nil
        errorMessage = nil
        showErrorAlert = false
    }

    /// Clear error messages
    private func clearErrorState() {
        errorMessage = nil
        showErrorAlert = false
    }
}
