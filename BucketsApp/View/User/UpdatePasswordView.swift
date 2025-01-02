//
//  UpdatePasswordView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 1/13/24.
//

import SwiftUI

struct UpdatePasswordView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var updateMessage: String = ""
    @State private var showAlert: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Update Password")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding()

            // Current Password Input
            SecureField("Current Password", text: $currentPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            // New Password Input
            SecureField("New Password", text: $newPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            // Confirm New Password Input
            SecureField("Confirm New Password", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            // Update Password Button
            Button(action: { Task { await updatePassword() } }) {
                Text("Update Password")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(!isFormValid) // Disable button if form is invalid
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Password Update"),
                message: Text(updateMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Validation
    private var isFormValid: Bool {
        !currentPassword.isEmpty && !newPassword.isEmpty && !confirmPassword.isEmpty
    }

    // MARK: - Update Password Logic
    private func updatePassword() async {
        guard newPassword == confirmPassword else {
            showError("Passwords do not match.")
            return
        }

        do {
            let message = try await viewModel.updatePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            showSuccess(message)
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Helper Methods
    private func showSuccess(_ message: String) {
        updateMessage = message
        showAlert = true
    }

    private func showError(_ message: String) {
        updateMessage = message
        showAlert = true
    }
}
