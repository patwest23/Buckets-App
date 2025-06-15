//
//  LoginView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/8/23.
//

import SwiftUI
import FirebaseAuth

struct LogInView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    
    @State private var isLoading = false
    @State private var showWrongPasswordAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer()
                
                // MARK: - Email Input
                TextField("✉️ Email Address", text: $onboardingViewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                // MARK: - Password Input
                SecureField("🔑 Password", text: $onboardingViewModel.password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Spacer()
                
                // MARK: - Log In Button
                Button {
                    if validateInput() {
                        isLoading = true
                        Task {
                            await onboardingViewModel.signIn()
                            if let user = Auth.auth().currentUser {
                                await userViewModel.loadCurrentUser()
                            }
                            isLoading = false
                            
                            // 1) Detect if the error is specifically "wrong password"
                            if let errMsg = onboardingViewModel.errorMessage?.lowercased(),
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
                                onboardingViewModel.email.isEmpty || onboardingViewModel.password.isEmpty
                                ? .red
                                : .primary
                            )
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                }
                .disabled(onboardingViewModel.email.isEmpty || onboardingViewModel.password.isEmpty || isLoading)
                .padding(.horizontal)
                .padding(.top, 20)
                
                // MARK: - Forgot Password
                Button("Forgot Password?") {
                    Task {
                        guard !onboardingViewModel.email.isEmpty else {
                            // Show error or prompt to enter email
                            onboardingViewModel.errorMessage = "Please enter your email above."
                            onboardingViewModel.showErrorAlert = true
                            return
                        }
                        let result = await onboardingViewModel.resetPassword(for: onboardingViewModel.email)
                        switch result {
                        case .success(let successMsg):
                            onboardingViewModel.errorMessage = successMsg
                            onboardingViewModel.showErrorAlert = true
                        case .failure(let error):
                            onboardingViewModel.errorMessage = error.localizedDescription
                            onboardingViewModel.showErrorAlert = true
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
                        await onboardingViewModel.loginWithBiometrics()
                    }
                }
                .padding(.top, 5)
                .disabled(isLoading)
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            
            // MARK: - General Error Alert
            .alert("Error", isPresented: $onboardingViewModel.showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(onboardingViewModel.errorMessage ?? "Unknown error")
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
                    let result = await onboardingViewModel.resetPassword(for: onboardingViewModel.email)
                    switch result {
                    case .success(let successMsg):
                        onboardingViewModel.errorMessage = successMsg
                        onboardingViewModel.showErrorAlert = true
                    case .failure(let err):
                        onboardingViewModel.errorMessage = err.localizedDescription
                        onboardingViewModel.showErrorAlert = true
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
        guard !onboardingViewModel.email.isEmpty, !onboardingViewModel.password.isEmpty else {
            onboardingViewModel.errorMessage = "Please fill in all fields."
            onboardingViewModel.showErrorAlert = true
            return false
        }
        onboardingViewModel.showErrorAlert = false
        return true
    }
}

// MARK: - Preview
#if DEBUG
struct LogInView_Previews: PreviewProvider {
    static var previews: some View {
        let mockOnboardingViewModel = OnboardingViewModel()
        
        return Group {
            // Light Mode
            NavigationView {
                LogInView()
                    .environmentObject(mockOnboardingViewModel)
            }
            .previewDisplayName("LogInView - Light Mode")
            
            // Dark Mode
            NavigationView {
                LogInView()
                    .environmentObject(mockOnboardingViewModel)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("LogInView - Dark Mode")
        }
    }
}
#endif
