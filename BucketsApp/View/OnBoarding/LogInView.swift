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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: BucketTheme.largeSpacing) {
                VStack(spacing: BucketTheme.mediumSpacing) {
                    Text("👋 Welcome back")
                        .font(.title.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Let's tick another dream off your list.")
                        .font(.callout)
                        .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: BucketTheme.mediumSpacing) {
                    TextField("Email Address", text: $onboardingViewModel.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .bucketTextField(systemImage: "envelope.fill")

                    SecureField("Password", text: $onboardingViewModel.password)
                        .bucketTextField(systemImage: "lock.fill")

                    Button {
                        if validateInput() {
                            isLoading = true
                            Task {
                                await onboardingViewModel.signIn()
                                if Auth.auth().currentUser != nil {
                                    await userViewModel.loadCurrentUser()
                                }
                                isLoading = false

                                if let errMsg = onboardingViewModel.errorMessage?.lowercased(),
                                   errMsg.contains("password is invalid") || errMsg.contains("wrong-password") {
                                    showWrongPasswordAlert = true
                                }
                            }
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Log In", systemImage: "arrow.forward.circle.fill")
                                .symbolVariant(.fill)
                        }
                    }
                    .buttonStyle(BucketPrimaryButtonStyle())
                    .disabled(onboardingViewModel.email.isEmpty || onboardingViewModel.password.isEmpty || isLoading)

                    Button {
                        Task {
                            guard !onboardingViewModel.email.isEmpty else {
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
                    } label: {
                        Label("Forgot password?", systemImage: "questionmark.circle")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(BucketSecondaryButtonStyle())

                    Button {
                        Task {
                            await onboardingViewModel.loginWithBiometrics()
                        }
                    } label: {
                        Label("Use Face ID", systemImage: "faceid")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(BucketSecondaryButtonStyle())
                    .disabled(isLoading)
                }
                .bucketCard()

                Text("Pro tip: save your favorite adventures to revisit them anytime. 📸")
                    .font(.footnote)
                    .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, BucketTheme.largeSpacing)
            .padding(.horizontal, BucketTheme.largeSpacing)
            .bucketBackground()
            .alert("Error", isPresented: $onboardingViewModel.showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(onboardingViewModel.errorMessage ?? "Unknown error")
            }
        }
        .bucketBackground()
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
            Text("It looks like the password might be wrong. Want to reset it?")
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
