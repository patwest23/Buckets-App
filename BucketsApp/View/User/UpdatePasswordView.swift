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
            VStack(spacing: 20) {
                
                // MARK: - Current Password
                SecureField("🔒 Current Password", text: $currentPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                // MARK: - New Password
                SecureField("🔑 New Password", text: $newPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                // MARK: - Confirm New Password
                SecureField("🔐 Confirm New Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Spacer()

                // MARK: - Update Password Button
                Button {
                    Task { await updatePassword() }
                } label: {
                    Text("✅ Update Password")
                        // If form valid => .accentColor, else .red
                        .foregroundColor(isFormValid ? .accentColor : .red)
                        .frame(maxWidth: .infinity)
                        .fontWeight(.bold)
                        .padding()
                        // Use system color that adapts to Light/Dark
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .disabled(!isFormValid) // disable if not valid
                .padding(.horizontal)

            }
            .padding()
            // Overall background color - white in Light, black in Dark
            .background(Color(uiColor: .systemBackground))
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Password Update"),
                    message: Text(updateMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        // Another layer of system background if desired
        .background(Color(uiColor: .systemBackground))
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

    private func showSuccess(_ message: String) {
        updateMessage = message
        showAlert = true
    }

    private func showError(_ message: String) {
        updateMessage = message
        showAlert = true
    }
}

// MARK: - Preview
#if DEBUG
struct UpdatePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = OnboardingViewModel()
        
        return Group {
            // Light Mode
            NavigationView {
                UpdatePasswordView()
                    .environmentObject(mockViewModel)
            }
            .previewDisplayName("UpdatePasswordView - Light Mode")
            
            // Dark Mode
            NavigationView {
                UpdatePasswordView()
                    .environmentObject(mockViewModel)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("UpdatePasswordView - Dark Mode")
        }
    }
}
#endif


