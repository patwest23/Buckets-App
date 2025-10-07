//
//  UsernameSetupView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/7/25.
//

import SwiftUI

struct UsernameSetupView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var username: String = "@"
    @State private var isUsernameValid: Bool = false
    @State private var isCheckingAvailability: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var validationTask: Task<Void, Never>?
    @State private var hasInteracted = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Create a Username")
                .font(.largeTitle)
                .bold()

            Text("Pick a unique handle to represent you in Buckets. We'll use this on your profile and posts.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Enter a unique username", text: $username)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: username) {
                    hasInteracted = true
                    validationTask?.cancel()
                    let latest = username
                    validationTask = Task {
                        await validateUsername(latest)
                    }
                }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if isCheckingAvailability {
                ProgressView("Checking availability…")
                    .progressViewStyle(.circular)
            }

            Button(action: {
                Task {
                    await submitUsername()
                }
            }) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(isUsernameValid ? Color.accentColor : Color.gray.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(!isUsernameValid || isSubmitting)
            .padding(.top)

            Spacer()
        }
        .padding()
        .onAppear {
            hasInteracted = false
            if let existing = userViewModel.user?.username,
               !existing.isEmpty,
               existing != "@unknown" {
                username = existing
                isUsernameValid = true
            }
        }
        .onDisappear {
            validationTask?.cancel()
        }
    }

    private func validateUsername(_ input: String) async {
        await MainActor.run {
            isCheckingAvailability = true
            errorMessage = nil
        }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        await MainActor.run {
            if trimmed.isEmpty {
                isUsernameValid = false
            }
        }

        guard !trimmed.isEmpty else {
            await MainActor.run {
                isCheckingAvailability = false
            }
            return
        }

        guard trimmed.hasPrefix("@") else {
            await MainActor.run {
                isUsernameValid = false
                errorMessage = "Username must start with @"
                isCheckingAvailability = false
            }
            return
        }

        guard trimmed.count >= 3 else {
            await MainActor.run {
                isUsernameValid = false
                errorMessage = "Usernames must be at least 3 characters."
                isCheckingAvailability = false
            }
            return
        }

        if trimmed == userViewModel.user?.username {
            await MainActor.run {
                isUsernameValid = true
                isCheckingAvailability = false
            }
            return
        }

        if Task.isCancelled {
            await MainActor.run {
                isCheckingAvailability = false
            }
            return
        }

        let available = await userViewModel.checkUsernameAvailability(trimmed)

        if Task.isCancelled {
            await MainActor.run {
                isCheckingAvailability = false
            }
            return
        }

        await MainActor.run {
            if available {
                isUsernameValid = true
            } else {
                isUsernameValid = false
                errorMessage = "That username is already taken."
            }
            isCheckingAvailability = false
        }
    }

    private func submitUsername() async {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isUsernameValid else { return }

        await MainActor.run {
            isSubmitting = true
            errorMessage = nil
        }

        await userViewModel.updateUserName(to: trimmed)
        onboardingViewModel.refreshUsernameRequirement(using: userViewModel)

        await MainActor.run {
            isSubmitting = false
            if onboardingViewModel.shouldPromptUsername {
                let fallback = userViewModel.errorMessage ?? "We couldn't save that username. Please try another one."
                errorMessage = fallback
                isUsernameValid = false
            } else {
                onboardingViewModel.username = trimmed
                dismiss()
            }
        }
    }
}

#Preview {
    UsernameSetupView()
        .environmentObject(UserViewModel())
        .environmentObject(OnboardingViewModel())
}
