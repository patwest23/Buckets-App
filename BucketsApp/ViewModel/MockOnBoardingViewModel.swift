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

    func signIn() {
        // Simulate sign-in without Firebase
        self.isAuthenticated = true
    }

    func signOut() {
        // Simulate sign-out
        self.isAuthenticated = false
    }

    func updateProfileImage(with data: Data?) {
        // Simulate updating the profile image
        self.profileImageData = data
    }

    // You can simulate other methods here if needed, e.g., for password reset, user creation, etc.
}
