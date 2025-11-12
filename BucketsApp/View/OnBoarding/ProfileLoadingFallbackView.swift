//
//  ProfileLoadingFallbackView.swift
//  BucketsApp
//
//  Created by OpenAI on 2025-02-14.
//

import SwiftUI

/// A fallback screen that is displayed when the app is unable to finish loading
/// the authenticated user's profile in a timely manner.
struct ProfileLoadingFallbackView: View {
    @EnvironmentObject private var onboardingViewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)

            VStack(spacing: 8) {
                Text("We couldn't finish loading your profile.")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                if let message = onboardingViewModel.profileLoadingErrorMessage,
                   !message.isEmpty {
                    Text(message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                } else {
                    Text("Please try again or return to the sign-in screen.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Button {
                    onboardingViewModel.retryProfileLoad()
                } label: {
                    Text("Try Again")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task {
                        await onboardingViewModel.signOut()
                    }
                } label: {
                    Text("Back to Sign In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)
        }
        .padding()
        .frame(maxWidth: 480)
    }
}

