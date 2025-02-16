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
        // 1) Use systemBackground so it’s white in Light, black in Dark
        ScrollView {
            VStack(spacing: 20) {

                // MARK: - Email Input Field
                TextField("✉️ Enter your email address", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Spacer()

                // MARK: - Send Reset Link Button
                Button(action: {
                    Task { await sendResetLink() }
                }) {
                    // a) If email is empty => gray text, else red
                    Text("🔗 Send Reset Link")
                        .foregroundColor(email.isEmpty ? .gray : .red)
                        .frame(maxWidth: .infinity)
                        .fontWeight(.bold)
                        .padding()
                        // b) Button background uses dynamic color
                        .background(Color(uiColor: .systemBackground))
                        // c) Button text color adapts to light/dark
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .disabled(email.isEmpty) // disable if no email
                .padding(.horizontal)
            }
            .padding()
            // 2) Rely on system colors to adapt in both modes
            .background(Color(uiColor: .systemBackground))
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Password Reset"),
                    message: Text(resetMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .background(Color(uiColor: .systemBackground))
        // If you want some extra spacing at the edges, you can keep `.padding()`
        .padding()
    }

    // MARK: - Helper Functions
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

    private func showErrorMessage(_ message: String) {
        resetMessage = message
        showAlert = true
    }

    private func showSuccessMessage(_ message: String) {
        resetMessage = message
        showAlert = true
    }
}

// MARK: - Preview
#if DEBUG
struct ResetPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = OnboardingViewModel()

        return Group {
            // Light Mode
            NavigationView {
                ResetPasswordView()
                    .environmentObject(mockViewModel)
            }
            .previewDisplayName("ResetPasswordView - Light Mode")

            // Dark Mode
            NavigationView {
                ResetPasswordView()
                    .environmentObject(mockViewModel)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("ResetPasswordView - Dark Mode")
        }
    }
}
#endif
