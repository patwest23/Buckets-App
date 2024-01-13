//
//  UpdatePasswordView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 1/13/24.
//

import SwiftUI

struct UpdatePasswordView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var updateMessage: String = ""
    @State private var showAlert = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Update Password")
                .font(.title)
                .fontWeight(.bold)

            SecureField("Current Password", text: $currentPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            SecureField("New Password", text: $newPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            SecureField("Confirm New Password", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Update Password") {
                updatePassword()
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Password Update"), message: Text(updateMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func updatePassword() {
        guard newPassword == confirmPassword else {
            updateMessage = "New passwords do not match."
            showAlert = true
            return
        }

        viewModel.updatePassword(currentPassword: currentPassword, newPassword: newPassword) { result in
            switch result {
            case .success(let message):
                updateMessage = message
            case .failure(let error):
                updateMessage = error.localizedDescription
            }
            showAlert = true
        }
    }
}


struct UpdatePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatePasswordView()
    }
}
