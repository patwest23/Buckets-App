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
        ScrollView {
            VStack(spacing: 20) {  // Adjusted spacing to match profile view

                // MARK: - Current Password Input
                SecureField("🔒 Current Password", text: $currentPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                // MARK: - New Password Input
                SecureField("🔑 New Password", text: $newPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                // MARK: - Confirm New Password Input
                SecureField("🔐 Confirm New Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Spacer()

                // MARK: - Update Password Button
                Button(action: { Task { await updatePassword() } }) {
                    Text("✅ Update Password")
                        .foregroundColor(isFormValid ? Color.accentColor : Color.red)
                        .frame(maxWidth: .infinity)
                        .fontWeight(.bold)
                        .padding()
                        .background(.white)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .disabled(!isFormValid) // Disable button if form is invalid
                .padding(.horizontal)

            }
            .padding()
            .background(Color.white)
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Password Update"),
                    message: Text(updateMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .padding()
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

struct UpdatePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatePasswordView()
            .environmentObject(MockOnboardingViewModel()) // Use mock view model for preview
    }
}


