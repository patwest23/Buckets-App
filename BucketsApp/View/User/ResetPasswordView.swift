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
        VStack(spacing: 20) {
            // Title
            Text("Reset Password")
                .font(.title)
                .fontWeight(.bold)

            // Email Input Field
            TextField("Enter your email address", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            // Send Reset Link Button
            Button(action: { Task { await sendResetLink() } }) {
                Text("Send Reset Link")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(email.isEmpty ? Color.gray : Color.blue) // Disable button for empty email
                    .cornerRadius(8)
            }
            .disabled(email.isEmpty) // Disable the button if email is empty
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Password Reset"),
                message: Text(resetMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func sendResetLink() async {
        guard !email.isEmpty else {
            resetMessage = "Please enter a valid email address."
            showAlert = true
            return
        }

        // Call the view model's async function
        let result = await viewModel.resetPassword(for: email)
        DispatchQueue.main.async {
            switch result {
            case .success(let message):
                resetMessage = message
            case .failure(let error):
                resetMessage = error.localizedDescription
            }
            showAlert = true
        }
    }
}

struct ResetPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ResetPasswordView()
            .environmentObject(MockOnboardingViewModel()) // Use mock view model for preview
    }
}
