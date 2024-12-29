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

            // Input Fields
            SecureField("Current Password", text: $currentPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            SecureField("New Password", text: $newPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            SecureField("Confirm New Password", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            // Update Button
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

    // MARK: - Validation and Update Logic

    /// Checks if the form is valid
    private var isFormValid: Bool {
        !currentPassword.isEmpty && !newPassword.isEmpty && !confirmPassword.isEmpty
    }

    /// Handles the password update process
    private func updatePassword() async {
        guard newPassword == confirmPassword else {
            showError("New passwords do not match.")
            return
        }

        let result = await viewModel.updatePassword(currentPassword: currentPassword, newPassword: newPassword)
        DispatchQueue.main.async {
            switch result {
            case .success(let message):
                showSuccess(message)
            case .failure(let error):
                showError(error.localizedDescription)
            }
        }
    }

    /// Displays a success message
    private func showSuccess(_ message: String) {
        updateMessage = message
        showAlert = true
    }

    /// Displays an error message
    private func showError(_ message: String) {
        updateMessage = message
        showAlert = true
    }
}

struct UpdatePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatePasswordView()
            .environmentObject(MockOnboardingViewModel()) // Mock view model for preview
    }
}
