//
//  MockOnBoardingViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 9/14/24.
//


import SwiftUI

class MockOnboardingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isAuthenticated: Bool = false
    @Published var requiresUsernameSetup: Bool = false
    @Published var email: String = "mockuser@example.com"
    @Published var password: String = "password"
    @Published var profileImageData: Data? = nil
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert: Bool = false
    
    /// Example user object. Defaults to a "mock" user with ID "mockUserId".
    @Published var user: UserModel? = UserModel(id: "mockUserId", email: "mockuser@example.com")
    
    // MARK: - Computed Property
    
    /// Lets you access `user?.id` directly. Useful if your real code does `onboardingViewModel.userId`.
    var userId: String? {
        user?.id
    }
    
    // MARK: - Simulated Auth Methods
    
    /// Simulate sign-in process
    func signIn() {
        if email == "mockuser@example.com" && password == "password" {
            isAuthenticated = true
            user = UserModel(id: "mockUserId", email: email)
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
            user = UserModel(id: "mockUserId", email: email)
            errorMessage = nil
        }
    }
    
    // MARK: - Profile Image
    
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
    
    // MARK: - Private Helpers
    
    /// Clears the user data and resets to defaults
    private func clearState() {
        email = "mockuser@example.com"
        password = "password"
        profileImageData = nil
        user = nil
    }
    
    /// Helper method to simulate an error
    private func simulateError(_ message: String) {
        isAuthenticated = false
        errorMessage = message
        showErrorAlert = true
    }
}


