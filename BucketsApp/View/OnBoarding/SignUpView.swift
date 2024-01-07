//
//  RegistrationView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/8/23.
//

import SwiftUI

// Define the enum within the same file for easy access
enum NavigationDestination {
    case listView
}

struct SignUpView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var confirmPassword: String = ""
    @State private var agreedToTerms = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSignUpSuccessful = false // Use this state to control navigation


    var body: some View {
        NavigationStack {
            VStack {
                Text("Sign Up")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(spacing: 20) {
                    TextField("Email", text: $viewModel.email)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)

                    SecureField("Password", text: $viewModel.password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                    SecureField("Confirm Password", text: $confirmPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                    // Terms and Conditions Section
                    termsAndConditionsSection
                    
                }
                .padding(.horizontal)

                signUpButton
                // Conditional navigation based on sign-up success
                    if isSignUpSuccessful {
                        NavigationLink("Navigate to List View", isActive: $isSignUpSuccessful) {
                            ListView() // Replace with your actual list view
                                .environmentObject(viewModel)
                        }
                    }
                }
            
            .padding(.top)
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // Terms and Conditions Section
    var termsAndConditionsSection: some View {
        HStack {
            Text("I agree to the")
            Text("Terms and Conditions")
                .foregroundColor(.blue)
                .underline()
                .onTapGesture {
                    // Handle Terms and Conditions URL
                }
            Toggle("", isOn: $agreedToTerms)
        }
        .font(.caption)
    }

    // Sign Up Button
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
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
        }
        .disabled(!agreedToTerms)
        .opacity(agreedToTerms ? 1.0 : 0.5)
    }

    private func validateInput() -> Bool {
        guard !viewModel.email.isEmpty, !viewModel.password.isEmpty, confirmPassword == viewModel.password else {
            errorMessage = "Please ensure all fields are filled correctly and passwords match."
            return false
        }

        guard agreedToTerms else {
            errorMessage = "You must agree to the terms and conditions."
            return false
        }

        return true
    }
    
    // Function to sign up the user
    private func signUpUser() async {
        do {
            try await viewModel.createUser()
            isSignUpSuccessful = true  // Set to true on successful sign-up
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            isSignUpSuccessful = false // Set to false if there's an error
        }
    }

}






struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
    }
}
