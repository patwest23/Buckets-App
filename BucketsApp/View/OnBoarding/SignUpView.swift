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
    
    @State private var username: String = ""       // Local property to store typed username
    @State private var confirmPassword: String = ""
    @State private var agreedToTerms = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - App Logo
                    Image("Image2")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 60, maxHeight: 60)
                        .padding()
                    
                    Spacer()

                    // MARK: - Input Fields
                    usernameTextField
                    emailTextField
                    passwordSecureField
                    confirmPasswordSecureField
                    termsAndConditionsSection

                    // MARK: - Sign Up Button
                    signUpButton
                        .padding(.top, 20)
                }
                .padding()
                .background(Color.white)
                .alert("Error", isPresented: $showErrorAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
            }
            .padding(.horizontal)
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
    
    /// Username field at the top
    var usernameTextField: some View {
        TextField("📛 Username", text: $username)
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
    
    /// A row with a text link to T&C and a toggle
    var termsAndConditionsSection: some View {
        HStack {
            Text("I agree to the")
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
    
    /// The "Sign Up" button that checks input validity, username availability, and then calls signUpUser.
    var signUpButton: some View {
        Button(action: {
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
        }) {
            Text("Sign Up")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .foregroundColor(agreedToTerms ? Color.black : Color.red)
                .cornerRadius(10)
                .shadow(radius: 5)
        }
        .disabled(!agreedToTerms)
    }

    // MARK: - Validation
    
    /// Validates the username, email, password, etc.
    private func validateInput() -> Bool {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
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

    /// Basic email regex check
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Z0-9a-z.-]+\\.[A-Za-z]{2,}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }

    // MARK: - Sign Up User
    
    /// Actually performs the sign-up in OnboardingViewModel after storing the chosen username
    private func signUpUser() async {
        // Optionally store the typed username so it can be saved to Firestore in createUserDocument
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
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .autocapitalization(.none)
            .disableAutocorrection(true)
    }
}

// MARK: - Preview
struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(OnboardingViewModel())
    }
}


