//
//  MockOnBoardingViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 9/14/24.
//


import SwiftUI

class MockOnboardingViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var email: String = "mockuser@example.com"
    @Published var password: String = "password"
    @Published var profileImageData: Data? = nil
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert: Bool = false

    /// Simulate sign-in process
    func signIn() {
        if email == "mockuser@example.com" && password == "password" {
            isAuthenticated = true
            errorMessage = nil
        } else {
            simulateError("Invalid email or password.")
        }
    }

    /// Simulate sign-out process
    func signOut() {
        isAuthenticated = false
        clearState()
    }

    /// Simulate user creation
    func createUser() {
        if email.isEmpty || password.isEmpty {
            simulateError("Email and password cannot be empty.")
        } else {
            isAuthenticated = true
            errorMessage = nil
        }
    }

    /// Simulate updating the profile image
    func updateProfileImage(with data: Data?) {
        profileImageData = data
    }

    /// Simulate resetting the password
    func resetPassword() {
        if email == "mockuser@example.com" {
            errorMessage = "A password reset link has been sent to \(email)."
            showErrorAlert = true
        } else {
            simulateError("Email not found.")
        }
    }

    /// Simulate updating email
    func updateEmail(newEmail: String) {
        if newEmail.isEmpty {
            simulateError("Email cannot be empty.")
        } else {
            email = newEmail
            errorMessage = "Your email has been updated to \(newEmail)."
            showErrorAlert = true
        }
    }

    /// Simulate updating password
    func updatePassword(newPassword: String) {
        if newPassword.isEmpty {
            simulateError("Password cannot be empty.")
        } else {
            password = newPassword
            errorMessage = "Your password has been updated."
            showErrorAlert = true
        }
    }

    /// Simulate clearing the user state
    private func clearState() {
        email = "mockuser@example.com"
        password = "password"
        profileImageData = nil
    }

    /// Helper method to simulate an error
    private func simulateError(_ message: String) {
        isAuthenticated = false
        errorMessage = message
        showErrorAlert = true
    }
}
