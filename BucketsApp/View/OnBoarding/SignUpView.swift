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
            ScrollView {
                VStack(spacing: 20) {  // Adjusted spacing for consistency with other views

                    // MARK: - App Logo
                    Image("Image2")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 60, maxHeight: 60)
                        .padding()
                    
                    Spacer()

                    // MARK: - Input Fields
                    emailTextField
                    passwordSecureField
                    confirmPasswordSecureField
                    termsAndConditionsSection

                    // MARK: - Sign Up Button
                    signUpButton
                        .padding(.top, 20) // Add spacing above the button
                }
                .padding()
                .background(Color.white)  // Ensure background is consistent
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
                    ListView()
                        .environmentObject(viewModel)
                }
            }
        }
    }

    // MARK: - Input Fields
    var emailTextField: some View {
        TextField("✉️ Email Address", text: $viewModel.email)
            .textFieldModifiers()
    }

    var passwordSecureField: some View {
        SecureField("🔑 Password", text: $viewModel.password)
            .textFieldModifiers()
    }

    var confirmPasswordSecureField: some View {
        SecureField("🔐 Confirm Password", text: $confirmPassword)
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
                .background(Color.white)
                .foregroundColor(agreedToTerms ? Color.black : Color.red)
                .cornerRadius(10)
                .shadow(radius: 5)
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



