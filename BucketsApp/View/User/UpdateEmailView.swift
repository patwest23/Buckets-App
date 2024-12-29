//
//  UpdateEmailView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 1/13/24.
//

import SwiftUI

struct UpdateEmailView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var newEmail: String = ""
    @State private var updateMessage: String = ""
    @State private var showAlert: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Update Email")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding()

            // Email Input Field
            TextField("Enter New Email Address", text: $newEmail)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            // Update Email Button
            Button(action: { Task { await updateEmail() } }) {
                Text("Update Email")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(newEmail.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(10)
            }
            .disabled(newEmail.isEmpty) // Disable button when no input
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Email Update"),
                message: Text(updateMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Helper Functions

    /// Handles the email update process
    private func updateEmail() async {
        guard !newEmail.isEmpty else {
            showError("Please enter a valid email address.")
            return
        }

        let result = await viewModel.updateEmail(newEmail: newEmail)
        DispatchQueue.main.async {
            switch result {
            case .success(let message):
                showSuccess(message)
            case .failure(let error):
                showError(error.localizedDescription)
            }
        }
    }

    /// Show error message in the alert
    private func showError(_ message: String) {
        updateMessage = message
        showAlert = true
    }

    /// Show success message in the alert
    private func showSuccess(_ message: String) {
        updateMessage = message
        showAlert = true
    }
}

struct UpdateEmailView_Previews: PreviewProvider {
    static var previews: some View {
        UpdateEmailView()
            .environmentObject(MockOnboardingViewModel()) // Use mock view model for preview
    }
}
