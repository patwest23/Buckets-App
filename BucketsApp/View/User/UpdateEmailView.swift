//
//  UpdateEmailView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 1/13/24.
//

import SwiftUI

struct UpdateEmailView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var newEmail: String = ""
    @State private var updateMessage: String = ""
    @State private var showAlert: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Update Email")
                .font(.title)
                .fontWeight(.bold)

            // Email Input Field
            TextField("New Email Address", text: $newEmail)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            // Update Email Button
            Button(action: { Task { await updateEmail() } }) {
                Text("Update Email")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(newEmail.isEmpty ? Color.gray : Color.blue) // Disable button for empty email
                    .cornerRadius(8)
            }
            .disabled(newEmail.isEmpty) // Disable button if no input
            .padding()

            Spacer()
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Email Update"),
                message: Text(updateMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func updateEmail() async {
        guard !newEmail.isEmpty else {
            updateMessage = "Please enter a valid email address."
            showAlert = true
            return
        }

        let result = await viewModel.updateEmail(newEmail: newEmail)
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

struct UpdateEmailView_Previews: PreviewProvider {
    static var previews: some View {
        UpdateEmailView()
            .environmentObject(MockOnboardingViewModel()) // Use mock view model for preview
    }
}
