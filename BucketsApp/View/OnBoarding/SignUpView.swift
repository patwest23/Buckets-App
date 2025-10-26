//
//  RegistrationView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/8/23.
//

import SwiftUI
import UIKit
import FirebaseAuth

enum SignUpNavigationDestination {
    case listView
}

struct SignUpView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var userViewModel: UserViewModel

    @State private var username: String = ""
    @State private var confirmPassword: String = ""
    @State private var agreedToTerms = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var navigationPath = NavigationPath()

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: BucketTheme.largeSpacing) {
                    VStack(spacing: BucketTheme.smallSpacing) {
                        Text("Create your ✨ Buckets ✨ account")
                            .font(.title.weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Just a few quick fields before we start exploring.")
                            .font(.callout)
                            .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(spacing: BucketTheme.mediumSpacing) {
                        usernameTextField
                        emailTextField
                        passwordSecureField
                        confirmPasswordSecureField
                        termsAndConditionsSection

                        signUpButton
                            .padding(.top, BucketTheme.mediumSpacing)
                    }
                    .bucketCard()

                    Text("We use your email only for login and important updates. No spam, just adventures. 🧭")
                        .font(.footnote)
                        .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BucketTheme.largeSpacing)
                }
                .padding(.vertical, BucketTheme.largeSpacing)
                .padding(.horizontal, BucketTheme.largeSpacing)
                .bucketBackground()
                .alert("Error", isPresented: $showErrorAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
            }
            .bucketBackground()
            .navigationDestination(for: SignUpNavigationDestination.self) { destination in
                switch destination {
                case .listView:
                    ListView()
                        .environmentObject(userViewModel)
                }
            }
        }
    }

    // MARK: - Text Fields
    
    /// Username field with a custom Binding to always enforce "@" at the start
    var usernameTextField: some View {
        TextField("Username", text: Binding(
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
        .bucketTextField(systemImage: "at")
    }

    /// Email address field (stored in OnboardingViewModel)
    var emailTextField: some View {
        TextField("Email Address", text: $viewModel.email)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .keyboardType(.emailAddress)
            .bucketTextField(systemImage: "envelope.fill")
    }

    /// Password field (stored in OnboardingViewModel)
    var passwordSecureField: some View {
        SecureField("Password", text: $viewModel.password)
            .bucketTextField(systemImage: "lock.fill")
    }

    /// Confirm password field (local state in this view)
    var confirmPasswordSecureField: some View {
        SecureField("Confirm Password", text: $confirmPassword)
            .bucketTextField(systemImage: "lock.rotation")
    }

    // MARK: - Terms and Conditions
    
    /// A row with a link to T&C and a toggle
    var termsAndConditionsSection: some View {
        VStack(alignment: .leading, spacing: BucketTheme.smallSpacing) {
            Toggle(isOn: $agreedToTerms) {
                Text("I agree to the Terms & Conditions")
                    .font(.footnote.weight(.medium))
            }
            .toggleStyle(SwitchToggleStyle(tint: BucketTheme.primary))

            Button {
                openTermsAndConditions()
            } label: {
                Label("Read the playful fine print", systemImage: "doc.text.magnifyingglass")
                    .font(.caption)
            }
            .buttonStyle(BucketSecondaryButtonStyle())
        }
    }

    // MARK: - Sign Up Button
    var signUpButton: some View {
        Button {
            Task {
                if validateInput() {
                    await signUpUser()
                } else {
                    showErrorAlert = true
                }
            }
        } label: {
            Label("Sign Up", systemImage: "sparkles")
                .symbolVariant(.fill)
        }
        .buttonStyle(BucketPrimaryButtonStyle())
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
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.username = trimmed

        await viewModel.createUser(using: userViewModel)

        guard viewModel.isAuthenticated,
              Auth.auth().currentUser != nil else {
            showError(viewModel.errorMessage ?? "Sign up failed.")
            return
        }

        await userViewModel.updateUserName(to: trimmed)
        await userViewModel.loadCurrentUser()

        navigationPath.append(SignUpNavigationDestination.listView)
    }

    private func openTermsAndConditions() {
        if let url = URL(string: "https://www.bucketsapp.com/") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - View Modifiers


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
