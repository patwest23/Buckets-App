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
    @Published var profileImageData: Data? // Stores the profile image data

    init() {
        checkIfUserIsAuthenticated()
    }

    // Check user authentication status
    func checkIfUserIsAuthenticated() {
        isAuthenticated = Auth.auth().currentUser != nil
    }

    // Sign in
    func signIn() async {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            print("User signed in successfully.")
        } catch let error as NSError {
            handleFirebaseError(error)
        }
    }

    // Sign out
    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            clearState()
            print("User signed out successfully.")
        } catch let error as NSError {
            handleFirebaseError(error)
        }
    }

    // Create a new user
    func createUser() async {
        do {
            try await Auth.auth().createUser(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            print("User created successfully.")
        } catch let error as NSError {
            handleFirebaseError(error)
        }
    }

    // Reset password
    func resetPassword(for email: String) async -> Result<String, Error> {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return .success("A link to reset your password has been sent to \(email).")
        } catch let error as NSError {
            return .failure(formatFirebaseError(error))
        }
    }

    // Update email
    func updateEmail(newEmail: String) async -> Result<String, Error> {
        guard let currentUser = Auth.auth().currentUser else {
            return .failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user is signed in."]))
        }

        do {
            try await currentUser.updateEmail(to: newEmail)
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

    // Reauthenticate the user
    private func reauthenticateUser(currentPassword: String) async -> Result<Void, Error> {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            return .failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found."]))
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        do {
            try await user.reauthenticate(with: credential)
            return .success(())
        } catch let error as NSError {
            return .failure(formatFirebaseError(error))
        }
    }

    // Handle Firebase errors
    private func handleFirebaseError(_ error: NSError) {
        errorMessage = formatFirebaseError(error).localizedDescription
        showErrorAlert = true
        print("Error: \(error.localizedDescription)")
    }

    // Format Firebase errors into user-friendly messages
    private func formatFirebaseError(_ error: NSError) -> NSError {
        let message: String
        switch error.code {
        case AuthErrorCode.invalidEmail.rawValue:
            message = "The email address is invalid."
        case AuthErrorCode.userNotFound.rawValue:
            message = "No user found with this email."
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            message = "This email is already in use by another account."
        case AuthErrorCode.weakPassword.rawValue:
            message = "The password is too weak. Please choose a stronger password."
        case AuthErrorCode.wrongPassword.rawValue:
            message = "The current password is incorrect."
        default:
            message = error.localizedDescription
        }
        return NSError(domain: "", code: error.code, userInfo: [NSLocalizedDescriptionKey: message])
    }

    // Clear all user data on sign-out
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
