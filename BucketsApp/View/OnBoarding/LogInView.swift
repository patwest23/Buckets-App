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
            VStack(spacing: 20) {
                
                Spacer() // Remove the logo; just a spacer
                
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
                            // Use secondarySystemBackground instead of white
                            .background(Color(uiColor: .secondarySystemBackground))
                            // If fields are empty => red text, else .primary
                            .foregroundColor(
                                viewModel.email.isEmpty || viewModel.password.isEmpty ? .red : .primary
                            )
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                }
                .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty || isLoading)
                .padding(.horizontal)
                .padding(.top, 20)

            }
            .padding()
            // Base background color that adapts to Light/Dark
            .background(Color(uiColor: .systemBackground))
            .alert("Error", isPresented: $viewModel.showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
        // Another background layer if desired
        .background(Color(uiColor: .systemBackground))
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


