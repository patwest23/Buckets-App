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
    @State private var confirmPassword: String = ""
    @State private var agreedToTerms = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                Spacer().frame(height: 40) // Add spacing at the top

                // App Logo
                Image("Image2")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 100, maxHeight: 100)
                    .padding(.bottom, 20)

                // Input Fields
                VStack(spacing: 20) {
                    emailTextField
                    passwordSecureField
                    confirmPasswordSecureField
                    termsAndConditionsSection
                }
                .padding(.horizontal)

                // Sign Up Button
                signUpButton
                    .padding(.top, 20) // Add spacing above the button

                Spacer()
            }
            .padding()
            .navigationDestination(for: SignUpNavigationDestination.self) { destination in
                switch destination {
                case .listView:
                    ListView()
                        .environmentObject(viewModel)
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Input Fields
    var emailTextField: some View {
        TextField("Email", text: $viewModel.email)
            .textFieldModifiers()
    }

    var passwordSecureField: some View {
        SecureField("Password", text: $viewModel.password)
            .textFieldModifiers()
    }

    var confirmPasswordSecureField: some View {
        SecureField("Confirm Password", text: $confirmPassword)
            .textFieldModifiers()
    }

    // MARK: - Terms and Conditions Section
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
    var signUpButton: some View {
        Button(action: {
            if validateInput() {
                Task {
                    await signUpUser()
                }
            } else {
                showErrorAlert = true
            }
        }) {
            Text("Sign Up")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(agreedToTerms ? Color.accentColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .disabled(!agreedToTerms)
    }

    // MARK: - Input Validation
    private func validateInput() -> Bool {
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

    // Helper function to validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Z0-9a-z.-]+\\.[A-Za-z]{2,}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    // MARK: - Navigation and Actions
    private func signUpUser() async {
        await viewModel.createUser()
        if viewModel.isAuthenticated {
            navigationPath.append(SignUpNavigationDestination.listView)
        } else if let errorMessage = viewModel.errorMessage {
            self.errorMessage = errorMessage
            showErrorAlert = true
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

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(OnboardingViewModel())
    }
}



