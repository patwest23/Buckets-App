//
//  OnBoardingViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/15/23.
//

import Foundation
import FirebaseAuth

@MainActor
final class OnboardingViewModel: ObservableObject {
    // Published properties for UI state
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert: Bool = false
    @Published var profileImageData: Data? // Store the profile image data

    init() {
        checkIfUserIsAuthenticated()
    }

    // Lightweight check for user authentication status
    func checkIfUserIsAuthenticated() {
        isAuthenticated = Auth.auth().currentUser != nil
    }

    // Sign-in functionality
    func signIn() async {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            print("User signed in successfully")
        } catch {
            handleError(error)
        }
    }

    // Sign-out functionality
    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            clearState()
        } catch {
            handleError(error)
        }
    }

    // User creation functionality
    func createUser() async {
        do {
            try await Auth.auth().createUser(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            print("User created successfully")
        } catch {
            handleError(error)
        }
    }

    // Reset password
    func resetPassword(for email: String) async -> Result<String, Error> {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return .success("A link to reset your password has been sent to \(email).")
        } catch {
            return .failure(error)
        }
    }

    // Update email
    func updateEmail(to newEmail: String) async -> Result<String, Error> {
        do {
            try await Auth.auth().currentUser?.updateEmail(to: newEmail)
            self.email = newEmail
            return .success("Your email has been updated to \(newEmail).")
        } catch {
            return .failure(error)
        }
    }

    // Update password
    func updatePassword(currentPassword: String, newPassword: String) async -> Result<String, Error> {
        let reauthResult = await reauthenticateUser(currentPassword: currentPassword)
        switch reauthResult {
        case .success:
            do {
                try await Auth.auth().currentUser?.updatePassword(to: newPassword)
                return .success("Your password has been updated successfully.")
            } catch {
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    // Update profile image
    func updateProfileImage(with data: Data?) {
        profileImageData = data
    }

    // Reauthentication logic
    private func reauthenticateUser(currentPassword: String) async -> Result<Void, Error> {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            return .failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not found."]))
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        do {
            try await user.reauthenticate(with: credential)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    // Handle errors and update UI state
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showErrorAlert = true
        print("Error: \(error.localizedDescription)")
    }

    // Clear the state when signing out
    private func clearState() {
        email = ""
        password = ""
        profileImageData = nil
        clearErrorState()
    }

    // Clear error state
    private func clearErrorState() {
        errorMessage = nil
        showErrorAlert = false
    }
}
