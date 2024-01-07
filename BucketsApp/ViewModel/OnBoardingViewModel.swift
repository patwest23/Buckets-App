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
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false

    init() {
        isAuthenticated = Auth.auth().currentUser != nil
    }

    func signIn() async {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            isAuthenticated = true
            errorMessage = nil
            // Handle successful sign in, e.g., navigate to the next screen
            print("User signed in successfully")
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            email = ""
            password = ""
            errorMessage = nil
        } catch {
            errorMessage = "Error signing out: \(error.localizedDescription)"
        }
    }

    func createUser() async {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            isAuthenticated = true
            errorMessage = nil
            // Handle successful user creation
            print("User created successfully")
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
    }

    func checkIfUserIsAuthenticated() {
        isAuthenticated = Auth.auth().currentUser != nil
    }
}
