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
        // Simulate a successful sign-in
        if email == "mockuser@example.com" && password == "password" {
            isAuthenticated = true
            errorMessage = nil
        } else {
            // Simulate an error
            isAuthenticated = false
            errorMessage = "Invalid email or password."
            showErrorAlert = true
        }
    }

    /// Simulate sign-out process
    func signOut() {
        isAuthenticated = false
        clearState()
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
            errorMessage = "Email not found."
            showErrorAlert = true
        }
    }

    /// Clear user state
    private func clearState() {
        email = "mockuser@example.com"
        password = "password"
        profileImageData = nil
    }
}
