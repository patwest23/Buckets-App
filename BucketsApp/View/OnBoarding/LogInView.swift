//
//  LoginView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/8/23.
//

import SwiftUI

struct LogInView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var isLoading = false // State to handle loading indicator

    var body: some View {
        VStack {
            Spacer().frame(height: 40) // Add space at the top

            // App Logo
            Image("Image2")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 100, maxHeight: 100)
                .padding(.bottom, 30)

            // Input Fields
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
            }
            .padding(.horizontal)

            // Log In Button
            Button(action: {
                if validateInput() {
                    isLoading = true
                    Task {
                        await viewModel.signIn()
                        isLoading = false
                    }
                }
            }) {
                if isLoading {
                    ProgressView()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                } else {
                    Text("Log In")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.email.isEmpty || viewModel.password.isEmpty ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty || isLoading)
            .padding(.horizontal)
            .padding(.top, 20) // Add space above the button
            .alert("Error", isPresented: $viewModel.showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }

            Spacer() // Push content to the top
        }
        .padding()
    }

    // MARK: - Input Validation
    private func validateInput() -> Bool {
        guard !viewModel.email.isEmpty, !viewModel.password.isEmpty else {
            viewModel.errorMessage = "Please fill in all fields."
            viewModel.showErrorAlert = true
            return false
        }
        viewModel.showErrorAlert = false
        return true
    }
}

struct LogInView_Previews: PreviewProvider {
    static var previews: some View {
        LogInView().environmentObject(OnboardingViewModel())
    }
}


