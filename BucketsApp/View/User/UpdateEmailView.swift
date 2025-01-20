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
        ScrollView {
            VStack(spacing: 20) {  // Adjusted spacing for more compact layout
                
                // MARK: - Email Input Field
                TextField("✉️ Enter New Email Address", text: $newEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                // MARK: - Divider
                Divider()

                // MARK: - Update Email Button
                HStack {
                    Button(action: { Task { await updateEmail() } }) {
                        Text("✅ Update Email")
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(newEmail.isEmpty) // Disable button when no input
                    .padding(.horizontal)
                }

            }
            .padding() // Adding some top padding to avoid the text field being too close to the top
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 2)
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Email Update"),
                    message: Text(updateMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .padding()
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
