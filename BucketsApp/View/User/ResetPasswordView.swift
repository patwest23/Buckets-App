//
//  ResetPasswordView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 1/13/24.
//

import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var email: String = ""
    @State private var resetMessage: String = ""
    @State private var showAlert = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Reset Password")
                .font(.title)
                .fontWeight(.bold)

            TextField("Email address", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Send Reset Link") {
                resetPassword()
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Password Reset"), message: Text(resetMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func resetPassword() {
        viewModel.resetPassword(for: email) { result in
            switch result {
            case .success(let message):
                resetMessage = message
            case .failure(let error):
                resetMessage = error.localizedDescription
            }
            showAlert = true
        }
    }
}

struct ResetPassowrdView_Previews: PreviewProvider {
    static var previews: some View {
        ResetPasswordView()
    }
}

