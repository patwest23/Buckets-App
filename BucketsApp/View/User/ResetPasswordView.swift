//
//  ResetPasswordView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 1/13/24.
//

import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var email: String = ""
    @State private var resetMessage: String = ""
    @State private var showAlert: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {  // Adjusted spacing to match profile view style
                
                // MARK: - Email Input Field
                TextField("✉️ Enter your email address", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                // MARK: - Divider
                Divider()
                
                // MARK: - Send Reset Link Button
                Button(action: { Task { await sendResetLink() } }) {
                    Text("✅ Send Reset Link")
                        .foregroundColor(email.isEmpty ? Color.accentColor : Color.red)
                        .frame(maxWidth: .infinity)
                }
                .disabled(email.isEmpty) // Disable button if email is empty
                .padding(.horizontal)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 2)
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Password Reset"),
                    message: Text(resetMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .padding()
    }

    // MARK: - Helper Functions

    /// Send the reset password link
    private func sendResetLink() async {
        guard !email.isEmpty else {
            showErrorMessage("Please enter a valid email address.")
            return
        }

        let result = await viewModel.resetPassword(for: email)
        switch result {
        case .success(let message):
            showSuccessMessage(message)
        case .failure(let error):
            showErrorMessage(error.localizedDescription)
        }
    }

    /// Display an error message
    private func showErrorMessage(_ message: String) {
        resetMessage = message
        showAlert = true
    }

    /// Display a success message
    private func showSuccessMessage(_ message: String) {
        resetMessage = message
        showAlert = true
    }
}

struct ResetPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ResetPasswordView()
            .environmentObject(MockOnboardingViewModel()) // Use mock view model for preview
    }
}
