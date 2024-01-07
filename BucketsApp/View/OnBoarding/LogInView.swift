//
//  LoginView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/8/23.
//

import SwiftUI

struct LogInView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack {
            Text("Log In")
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
            }
            .padding(.horizontal)

            Button(action: {
                if validateInput() {
                    Task {
                        await viewModel.signIn()
                    }
                }
            }) {
                Text("Log In")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            .alert("Error", isPresented: $viewModel.showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
        .padding(.top)
    }

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
    }
}
