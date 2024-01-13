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
    @State private var showAlert = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Update Email")
                .font(.title)
                .fontWeight(.bold)

            TextField("New Email Address", text: $newEmail)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Update Email") {
                updateEmail()
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Email Update"), message: Text(updateMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func updateEmail() {
        viewModel.updateEmail(newEmail: newEmail) { result in
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
    }
}
