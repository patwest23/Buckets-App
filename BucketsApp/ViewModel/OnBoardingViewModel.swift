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
    // Published properties
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false
    @Published var profileImageData: Data? // Store the profile image data

    init() {
        // Only check authentication state; avoid heavy Firebase operations
        checkIfUserIsAuthenticated()
    }

    // Lightweight check for user authentication status
    func checkIfUserIsAuthenticated() {
        isAuthenticated = Auth.auth().currentUser != nil
    }

    // Sign-in functionality
    func signIn() async {
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            isAuthenticated = true
            errorMessage = nil
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
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
            isAuthenticated = true
            errorMessage = nil
            print("User created successfully")
        } catch {
            handleError(error)
        }
    }

    // Reset password
    func resetPassword(for email: String, completion: @escaping (Result<String, Error>) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success("A link to reset your password has been sent to \(email)."))
            }
        }
    }

    // Update email
    func updateEmail(newEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
        Auth.auth().currentUser?.updateEmail(to: newEmail) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                self.email = newEmail
                completion(.success("Your email has been updated to \(newEmail)."))
            }
        }
    }

    // Update password
    func updatePassword(currentPassword: String, newPassword: String, completion: @escaping (Result<String, Error>) -> Void) {
        reauthenticateUser(currentPassword: currentPassword) { reauthResult in
            switch reauthResult {
            case .success:
                Auth.auth().currentUser?.updatePassword(to: newPassword) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success("Your password has been updated successfully."))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // Update profile image
    func updateProfileImage(with data: Data?) {
        profileImageData = data
    }

    // Reauthentication logic
    private func reauthenticateUser(currentPassword: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not found."])))
            return
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        user.reauthenticate(with: credential) { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // Handle errors
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showErrorAlert = true
        print("Error: \(error.localizedDescription)")
    }

    // Clear state on sign out
    private func clearState() {
        email = ""
        password = ""
        errorMessage = nil
    }
}
