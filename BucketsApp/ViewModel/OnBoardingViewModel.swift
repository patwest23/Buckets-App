//
//  OnBoardingViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/15/23.
//

import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false
    @Published var profileImageData: Data? // Store the profile image data

    init() {
        // Simulate authentication status, as Firebase Auth is removed
        isAuthenticated = false
    }

    func signIn() {
        // Removed Firebase signIn logic
    }

    func signOut() {
        // Removed Firebase signOut logic
    }

    func createUser() {
        // Removed Firebase createUser logic
    }

    func checkIfUserIsAuthenticated() {
        // Simulate authentication status, as Firebase Auth is removed
        isAuthenticated = false
    }

    func resetPassword() {
        // Removed Firebase resetPassword logic
    }

    func updateEmail(newEmail: String) {
        // Removed Firebase updateEmail logic
    }

    func resetPassword(for email: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Removed Firebase resetPassword logic
    }

    func updateEmail(newEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Removed Firebase updateEmail logic
    }

    func updatePassword(currentPassword: String, newPassword: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Removed Firebase updatePassword logic
    }

    // Method to update the profile image
    func updateProfileImage(with data: Data?) {
        profileImageData = data
    }

    // Removed reauthentication method
}

