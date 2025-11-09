//
//  OnBoardingView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/9/23.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var showSignUp = false
    @State private var showLogIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 32) {
                    Spacer(minLength: 24)

                    brandEmblem

                    header

                    VStack(alignment: .leading, spacing: 16) {
                        primaryButton
                        secondaryButton
                    }

                    dividerWithLabel

                    googleButton

                    Spacer()

                    Text("By continuing you agree to our Terms and Privacy Policy.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }
            .navigationBarHidden(true)
        }
        .id(onboardingViewModel.onboardingViewID)
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .environmentObject(onboardingViewModel)
        }
        .sheet(isPresented: $showLogIn) {
            LogInView()
                .environmentObject(onboardingViewModel)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
//            Text("BUCKETS")
//                .font(.footnote)
//                .fontWeight(.semibold)
//                .foregroundColor(.accentColor)
//                .tracking(2)

            Text("Plan a life well lived")
                .font(.largeTitle)
                .fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)

            Text("Curate your bucket list, attach memories, and track your personal milestones in one simple place.")
                .foregroundColor(.secondary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var brandEmblem: some View {
        VStack(spacing: 8) {
            Image("Image2")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)

            Text("buckets")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .textCase(.lowercase)
        }
        .frame(maxWidth: .infinity)
    }

    private var primaryButton: some View {
        Button {
            showSignUp = true
        } label: {
            Text("Create an account")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("createAccountButton")
    }

    private var secondaryButton: some View {
        Button {
            showLogIn = true
        } label: {
            Text("I already have an account")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.accentColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundColor(.accentColor)
        .accessibilityIdentifier("loginButton")
    }

    private var dividerWithLabel: some View {
        HStack(spacing: 12) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4))

            Text("or")
                .font(.footnote)
                .foregroundColor(.secondary)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4))
        }
    }

    private var googleButton: some View {
        Button {
            onboardingViewModel.signInWithGoogle()
        } label: {
            HStack(spacing: 12) {
                Image("google_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text("Continue with Google")
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("googleSignInButton")
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
