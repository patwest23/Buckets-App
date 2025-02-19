//
//  LoginView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/8/23.
//

import SwiftUI

struct LogInView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    @State private var isLoading = false
    @State private var showWrongPasswordAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
                Button {
                    if validateInput() {
                        isLoading = true
                        Task {
                            await viewModel.signIn()
                            isLoading = false
                            
                            // 1) Detect if the error is specifically "wrong password"
                            if let errMsg = viewModel.errorMessage?.lowercased(),
                               errMsg.contains("password is invalid") || errMsg.contains("wrong-password") {
                                // Show alert offering to reset the password
                                showWrongPasswordAlert = true
                            }
                        }
                    }
                } label: {
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
                            .background(Color(uiColor: .secondarySystemBackground))
                            .foregroundColor(
                                viewModel.email.isEmpty || viewModel.password.isEmpty
                                ? .red
                                : .primary
                            )
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                }
                .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty || isLoading)
                .padding(.horizontal)
                .padding(.top, 20)
                
                // MARK: - Forgot Password
                Button("Forgot Password?") {
                    Task {
                        guard !viewModel.email.isEmpty else {
                            // Show error or prompt to enter email
                            viewModel.errorMessage = "Please enter your email above."
                            viewModel.showErrorAlert = true
                            return
                        }
                        let result = await viewModel.resetPassword(for: viewModel.email)
                        switch result {
                        case .success(let successMsg):
                            viewModel.errorMessage = successMsg
                            viewModel.showErrorAlert = true
                        case .failure(let error):
                            viewModel.errorMessage = error.localizedDescription
                            viewModel.showErrorAlert = true
                        }
                    }
                }
                .padding(.top, 10)
                
                // MARK: - Use Face ID / Touch ID
                Button("Use Face ID") {
                    Task {
                        // This calls OnboardingViewModel.loginWithBiometrics()
                        // which fetches stored credentials from Keychain
                        // and tries to sign in
                        await viewModel.loginWithBiometrics()
                    }
                }
                .padding(.top, 5)
                .disabled(isLoading)
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            
            // MARK: - General Error Alert
            .alert("Error", isPresented: $viewModel.showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
        // Additional .padding() or styling as you see fit
        .background(Color(uiColor: .systemBackground))
        
        // MARK: - Wrong Password Alert
        .alert(
            "Wrong Password?",
            isPresented: $showWrongPasswordAlert
        ) {
            Button("Reset Password", role: .destructive) {
                Task {
                    let result = await viewModel.resetPassword(for: viewModel.email)
                    switch result {
                    case .success(let successMsg):
                        viewModel.errorMessage = successMsg
                        viewModel.showErrorAlert = true
                    case .failure(let err):
                        viewModel.errorMessage = err.localizedDescription
                        viewModel.showErrorAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It looks like the password might be wrong. Would you like to reset it?")
        }
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

// MARK: - Preview
#if DEBUG
struct LogInView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = OnboardingViewModel()
        
        return Group {
            // Light Mode
            NavigationView {
                LogInView()
                    .environmentObject(mockViewModel)
            }
            .previewDisplayName("LogInView - Light Mode")
            
            // Dark Mode
            NavigationView {
                LogInView()
                    .environmentObject(mockViewModel)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("LogInView - Dark Mode")
        }
    }
}
#endif


