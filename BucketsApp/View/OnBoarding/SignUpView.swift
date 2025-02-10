//
//  RegistrationView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/8/23.
//

import SwiftUI
import UIKit

enum SignUpNavigationDestination {
    case listView
}

struct SignUpView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var username: String = ""
    @State private var confirmPassword: String = ""
    @State private var agreedToTerms = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 20) {

                    Spacer()  // Removed the image/logo, just a spacer now

                    // MARK: - Input Fields
                    usernameTextField  // <--- Updated
                    emailTextField
                    passwordSecureField
                    confirmPasswordSecureField
                    termsAndConditionsSection

                    // MARK: - Sign Up Button
                    signUpButton
                        .padding(.top, 20)

                    Spacer()
                }
                .padding()
                // Base background that adapts to Light/Dark
                .background(Color(uiColor: .systemBackground))
                .alert("Error", isPresented: $showErrorAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
            }
            .padding(.horizontal)
            // Another background layer if you want
            .background(Color(uiColor: .systemBackground))
            .navigationDestination(for: SignUpNavigationDestination.self) { destination in
                switch destination {
                case .listView:
                    // Navigate to ListView after successful sign-up
                    ListView()
                        .environmentObject(viewModel)
                }
            }
        }
    }

    // MARK: - Text Fields
    
    /// Username field with a custom Binding to always enforce "@" at the start
    var usernameTextField: some View {
        TextField("📛 Username", text: Binding(
            get: {
                // If empty, return blank. Otherwise ensure it starts with "@"
                username.isEmpty
                    ? ""
                    : (username.hasPrefix("@") ? username : "@" + username)
            },
            set: { newVal in
                // If user clears everything, we allow blank
                if newVal.isEmpty {
                    username = ""
                }
                // Otherwise enforce a single "@" at the start
                else if !newVal.hasPrefix("@") {
                    // Remove any existing "@" to avoid @@
                    let rawVal = newVal.replacingOccurrences(of: "@", with: "")
                    username = "@" + rawVal
                } else {
                    // Already has @ at start, so just update
                    username = newVal
                }
            }
        ))
        .textFieldModifiers()
    }

    /// Email address field (stored in OnboardingViewModel)
    var emailTextField: some View {
        TextField("✉️ Email Address", text: $viewModel.email)
            .textFieldModifiers()
    }

    /// Password field (stored in OnboardingViewModel)
    var passwordSecureField: some View {
        SecureField("🔑 Password", text: $viewModel.password)
            .textFieldModifiers()
    }

    /// Confirm password field (local state in this view)
    var confirmPasswordSecureField: some View {
        SecureField("🔐 Confirm Password", text: $confirmPassword)
            .textFieldModifiers()
    }

    // MARK: - Terms and Conditions
    
    /// A row with a link to T&C and a toggle
    var termsAndConditionsSection: some View {
        HStack {
            Text("I agree to the")
                .foregroundColor(.primary)
            Button("Terms and Conditions") {
                openTermsAndConditions()
            }
            .foregroundColor(.blue)
            .underline()

            Toggle("", isOn: $agreedToTerms)
        }
        .font(.caption)
    }

    // MARK: - Sign Up Button
    
    /// The "Sign Up" button checks input validity, username, then calls signUpUser
    var signUpButton: some View {
        Button {
            Task {
                if validateInput() {
                    // 1) Check if username is used
                    if await viewModel.isUsernameUsed(username) {
                        showError("Username is already taken. Please pick another.")
                        return
                    }
                    // 2) If not taken, do normal sign-up
                    await signUpUser()
                } else {
                    showErrorAlert = true
                }
            }
        } label: {
            Text("Sign Up")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding()
                // Use secondarySystemBackground for button background
                .background(Color(uiColor: .secondarySystemBackground))
                // If not agreed => text is red, else .primary
                .foregroundColor(agreedToTerms ? .primary : .red)
                .cornerRadius(10)
                .shadow(radius: 5)
        }
        .disabled(!agreedToTerms)
    }

    // MARK: - Validation
    
    /// Validates username, email, password, terms, etc.
    private func validateInput() -> Bool {
        // Check final trimmed username
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else {
            errorMessage = "Please enter a username."
            return false
        }
        guard !viewModel.email.isEmpty, isValidEmail(viewModel.email) else {
            errorMessage = "Please enter a valid email address."
            return false
        }
        guard !viewModel.password.isEmpty, viewModel.password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters long."
            return false
        }
        guard viewModel.password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return false
        }
        guard agreedToTerms else {
            errorMessage = "You must agree to the terms and conditions."
            return false
        }
        return true
    }

    /// Simple regex check
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Z0-9a-z.-]+\\.[A-Za-z]{2,}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }

    // MARK: - Sign Up Logic
    
    /// Actually performs the sign-up in OnboardingViewModel after storing typed username
    private func signUpUser() async {
        // Transfer the final username (with "@") to the ViewModel
        viewModel.username = username
        await viewModel.createUser()
        
        if viewModel.isAuthenticated {
            navigationPath.append(SignUpNavigationDestination.listView)
        } else if let msg = viewModel.errorMessage {
            showError(msg)
        }
    }

    private func openTermsAndConditions() {
        if let url = URL(string: "https://www.bucketsapp.com/") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - View Modifiers
private extension View {
    func textFieldModifiers() -> some View {
        self
            .padding()
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(8)
            .autocapitalization(.none)
            .disableAutocorrection(true)
    }
}

// MARK: - Preview
#if DEBUG
struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = OnboardingViewModel()
        
        return Group {
            // Light Mode
            NavigationStack {
                SignUpView()
                    .environmentObject(mockViewModel)
            }
            .previewDisplayName("SignUpView - Light Mode")
            
            // Dark Mode
            NavigationStack {
                SignUpView()
                    .environmentObject(mockViewModel)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("SignUpView - Dark Mode")
        }
    }
}
#endif

