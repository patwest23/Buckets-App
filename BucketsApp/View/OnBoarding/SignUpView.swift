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

                VStack(spacing: 20) {
                    emailTextField
                    passwordSecureField
                    confirmPasswordSecureField
                    termsAndConditionsSection
                }
                .padding(.horizontal)

                signUpButton

                NavigationLink(value: SignUpNavigationDestination.listView) {
                    Text("Navigate to List View")
                        .hidden()
                }
            }
            .padding(.top)
        }
        .navigationDestination(for: SignUpNavigationDestination.self) { destination in
            switch destination {
            case .listView:
                ListView().environmentObject(viewModel)
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // Extracted subviews for readability
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

    var termsAndConditionsSection: some View {
        HStack {
            Text("I agree to the")
            Button("Terms and Conditions") {
                // Specify the URL you want to open
                if let url = URL(string: "https://www.bucketsapp.com/") {
                    // Check if the URL can be opened, then open it
                    UIApplication.shared.open(url)
                }
            }
            .foregroundColor(.blue)
            .underline()
            Toggle("", isOn: $agreedToTerms)
        }
        .font(.caption)
    }


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
                .buttonModifiers(isEnabled: agreedToTerms)
        }
        .disabled(!agreedToTerms)
    }
    
    // validate inputs in the email
    private func validateInput() -> Bool {
        // Check if the email is not empty and is in a valid format
        guard !viewModel.email.isEmpty, isValidEmail(viewModel.email) else {
            errorMessage = "Please enter a valid email address."
            return false
        }

        // Check if the password is not empty and meets minimum length criteria
        let minimumPasswordLength = 6
        guard !viewModel.password.isEmpty, viewModel.password.count >= minimumPasswordLength else {
            errorMessage = "Password must be at least \(minimumPasswordLength) characters long."
            return false
        }

        // Check if passwords match
        guard viewModel.password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return false
        }

        // Check if terms and conditions are agreed
        guard agreedToTerms else {
            errorMessage = "You must agree to the terms and conditions."
            return false
        }

        return true
    }

    // Helper function to validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Z0-9a-z.-]+\\.[A-Za-z]{2,}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }


    private func signUpUser() async {
        await viewModel.createUser()
        if viewModel.isAuthenticated {
            // Trigger navigation upon successful sign-up
            navigationPath.append(SignUpNavigationDestination.listView)
        } else if let errorMessage = viewModel.errorMessage {
            // Handle error
            self.errorMessage = errorMessage
            showErrorAlert = true
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

    func buttonModifiers(isEnabled: Bool) -> some View {
        self
            .fontWeight(.bold)
            .padding()
            .frame(maxWidth: .infinity)
            .background(isEnabled ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .opacity(isEnabled ? 1.0 : 0.5)
    }
}







struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView().environmentObject(OnboardingViewModel())
    }
}

