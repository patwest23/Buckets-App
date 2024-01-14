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
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
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
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
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
    
    func resetPassword() {
        Auth.auth().sendPasswordReset(withEmail: self.email) { error in
            if error != nil {
                // Handle the error - maybe update an error message state variable
                return
            }
            // Handle success - maybe update a success message state variable
        }
    }
    
    func updateEmail(newEmail: String) {
        Auth.auth().currentUser?.updateEmail(to: newEmail) { error in
            if error != nil {
                // Handle the error - maybe update an error message state variable
                return
            }
            // Update the email in your ViewModel and handle success
            self.email = newEmail
        }
    }
    
    func resetPassword(for email: String, completion: @escaping (Result<String, Error>) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success("A link to reset your password has been sent to \(email)."))
        }
    }
    
    func updateEmail(newEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
        Auth.auth().currentUser?.updateEmail(to: newEmail) { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            // Optionally, update the email in the ViewModel if needed
            self.email = newEmail
            completion(.success("Your email has been updated to \(newEmail)."))
        }
    }
    
    func updatePassword(currentPassword: String, newPassword: String, completion: @escaping (Result<String, Error>) -> Void) {
        reauthenticateUser(currentPassword: currentPassword) { reauthResult in
            switch reauthResult {
            case .success:
                Auth.auth().currentUser?.updatePassword(to: newPassword) { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    completion(.success("Your password has been updated successfully."))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }


    // Implement reauthentication logic here
    private func reauthenticateUser(currentPassword: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Firebase reauthentication logic
    }



}
