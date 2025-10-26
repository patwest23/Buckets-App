//
//  OnBoardingView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/9/23.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var showSignUp = false
    @State private var showLogIn = false

    @Environment(\.colorScheme) private var colorScheme

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                BucketTheme.primary.opacity(colorScheme == .dark ? 0.45 : 0.3),
                BucketTheme.secondary.opacity(colorScheme == .dark ? 0.25 : 0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: BucketTheme.largeSpacing) {
                VStack(spacing: BucketTheme.mediumSpacing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: BucketTheme.cornerRadius, style: .continuous)
                            .fill(heroGradient)
                            .overlay(
                                RoundedRectangle(cornerRadius: BucketTheme.cornerRadius, style: .continuous)
                                    .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                            )
                            .shadow(color: BucketTheme.shadow(for: colorScheme), radius: 18, x: 0, y: 12)

                        VStack(spacing: BucketTheme.mediumSpacing) {
                            Text("Buckets")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(.white)

                            Text("Dream it. Do it. ✅")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.9))

                            Text("What do you want to experience next?")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                        .padding(BucketTheme.largeSpacing)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)

                    HStack(spacing: BucketTheme.mediumSpacing) {
                        Label("Curate your bucket list", systemImage: "sparkles")
                        Label("Share with friends", systemImage: "hands.clap")
                        Label("Capture memories", systemImage: "camera.fill")
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                }

                VStack(spacing: BucketTheme.mediumSpacing) {
                    Button {
                        showSignUp.toggle()
                    } label: {
                        Label("Create your account", systemImage: "wand.and.stars")
                            .symbolVariant(.fill)
                    }
                    .buttonStyle(BucketPrimaryButtonStyle())
                    .sheet(isPresented: $showSignUp) {
                        SignUpView()
                            .environmentObject(onboardingViewModel)
                    }

                    Button {
                        showLogIn.toggle()
                    } label: {
                        Label("I already have an account", systemImage: "person.crop.circle.badge.checkmark")
                            .symbolVariant(.fill)
                    }
                    .buttonStyle(BucketSecondaryButtonStyle())
                    .sheet(isPresented: $showLogIn) {
                        LogInView()
                            .environmentObject(onboardingViewModel)
                    }

                    Button {
                        onboardingViewModel.signInWithGoogle(using: userViewModel, completion: { _ in })
                    } label: {
                        HStack(spacing: BucketTheme.smallSpacing) {
                            Image("google_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)

                            Text("Continue with Google")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BucketSecondaryButtonStyle())
                }

                VStack(spacing: BucketTheme.smallSpacing) {
                    Text("✨ Your adventures, beautifully organized")
                        .font(.subheadline)
                        .foregroundStyle(BucketTheme.subtleText(for: colorScheme))

                    Text("Swipe, tap, and share milestones with the people that matter most. Let's make your memories playful and unforgettable.")
                        .font(.footnote)
                        .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, BucketTheme.largeSpacing)
            .padding(.horizontal, BucketTheme.largeSpacing)
            .bucketBackground()
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = OnboardingViewModel()

        return Group {
            // Light Mode
            NavigationStack {
                OnboardingView()
                    .environmentObject(mockViewModel)
            }
            .previewDisplayName("OnboardingView - Light Mode")

            // Dark Mode
            NavigationStack {
                OnboardingView()
                    .environmentObject(mockViewModel)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("OnboardingView - Dark Mode")
        }
    }
}
#endif
