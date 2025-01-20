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
        ScrollView {
            VStack(spacing: 20) {  // Adjusted spacing to match ProfileView layout
                
                // MARK: - App Logo
                Image("Image2")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 60, maxHeight: 60)
                    .padding()
                
                Spacer()

                // MARK: - Email Input
                TextField("✉️ Email Address", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                // MARK: - Password Input
                SecureField("🔑 Password", text: $viewModel.password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Spacer()

                // MARK: - Log In Button
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
                            .background(Color.white)
                            .foregroundColor(viewModel.email.isEmpty || viewModel.password.isEmpty ? Color.red : Color.black)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                }
                .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty || isLoading)
                .padding(.horizontal)
                .padding(.top, 20)

            }
            .padding()
            .background(Color.white)  // Ensure background is consistent
            .alert("Error", isPresented: $viewModel.showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
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
        LogInView()
            .environmentObject(OnboardingViewModel()) // Use mock view model for preview
    }
}


