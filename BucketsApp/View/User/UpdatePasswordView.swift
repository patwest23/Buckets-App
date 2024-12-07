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
    @State private var showAlert: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Update Password")
                .font(.title)
                .fontWeight(.bold)

            // Current Password Field
            SecureField("Current Password", text: $currentPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            // New Password Field
            SecureField("New Password", text: $newPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            // Confirm New Password Field
            SecureField("Confirm New Password", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            // Update Password Button
            Button(action: { Task { await updatePassword() } }) {
                Text("Update Password")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(newPassword.isEmpty || confirmPassword.isEmpty || currentPassword.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(8)
            }
            .disabled(newPassword.isEmpty || confirmPassword.isEmpty || currentPassword.isEmpty)
            .padding()

            Spacer()
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Password Update"),
                message: Text(updateMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func updatePassword() async {
        guard newPassword == confirmPassword else {
            updateMessage = "New passwords do not match."
            showAlert = true
            return
        }

        let result = await viewModel.updatePassword(currentPassword: currentPassword, newPassword: newPassword)
        DispatchQueue.main.async {
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
            .environmentObject(MockOnboardingViewModel()) // Use mock data for preview
    }
}
