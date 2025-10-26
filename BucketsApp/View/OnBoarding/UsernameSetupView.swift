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
    @Environment(\.colorScheme) private var colorScheme

    @State private var username: String = "@"
    @State private var isUsernameValid: Bool = false
    @State private var isCheckingAvailability: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var validationTask: Task<Void, Never>?
    @State private var hasInteracted = false

    var body: some View {
        ScrollView {
            VStack(spacing: BucketTheme.largeSpacing) {
                VStack(spacing: BucketTheme.smallSpacing) {
                    Text("Claim your playful handle")
                        .font(.largeTitle.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Pick a unique username so friends can find you and celebrate your wins.")
                        .multilineTextAlignment(.leading)
                        .font(.callout)
                        .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                }

                VStack(spacing: BucketTheme.mediumSpacing) {
                    TextField("@username", text: $username)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .bucketTextField(systemImage: "at")
                        .onChange(of: username, initial: false) { _, newValue in
                            hasInteracted = true
                            validationTask?.cancel()
                            validationTask = Task {
                                await validateUsername(newValue)
                            }
                        }

                    if let error = errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if isCheckingAvailability {
                        ProgressView("Checking availability…")
                            .progressViewStyle(.circular)
                    }

                    Button {
                        Task {
                            await submitUsername()
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Continue", systemImage: "arrow.right.circle.fill")
                                .symbolVariant(.fill)
                        }
                    }
                    .buttonStyle(BucketPrimaryButtonStyle())
                    .disabled(!isUsernameValid || isSubmitting)
                }
                .bucketCard()

                Text("Tip: keep it short, sweet, and unmistakably you. 🌟")
                    .font(.footnote)
                    .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, BucketTheme.largeSpacing)
            .padding(.horizontal, BucketTheme.largeSpacing)
            .bucketBackground()
        }
        .bucketBackground()
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
