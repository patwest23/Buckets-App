//
//  UsernameSetupView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/7/25.
//

import SwiftUI

struct UsernameSetupView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var username: String = ""
    @State private var isUsernameValid: Bool = false
    @State private var isCheckingAvailability: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("Create a Username")
                .font(.largeTitle)
                .bold()

            TextField("Enter a unique username", text: $username)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: username) {
                    Task {
                        await validateUsername(username)
                    }
                }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                Task {
                    await onboardingViewModel.updateUsername(username)
                    if onboardingViewModel.username == username {
                        dismiss()
                    }
                }
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isUsernameValid ? Color.accentColor : Color.gray.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!isUsernameValid)
            .padding(.top)

            Spacer()
        }
        .padding()
    }

    private func validateUsername(_ input: String) async {
        isCheckingAvailability = true
        errorMessage = nil

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isUsernameValid = false
            return
        }

        let available = await onboardingViewModel.isUsernameAvailable(trimmed)
        if available {
            isUsernameValid = true
        } else {
            isUsernameValid = false
            errorMessage = "That username is already taken."
        }

        isCheckingAvailability = false
    }
}

#Preview {
    UsernameSetupView()
}
